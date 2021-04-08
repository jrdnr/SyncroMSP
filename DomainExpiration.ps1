# This script uses the jsonwhois.com api to do whois lookups.  You will need to create a free account to try it out.
# Required Syncro Script Variables
# $CustomerEmail, Var Type = Platform, Value = {{customer_email}}
# $DomainsCSV, Var Type = Platform, Value = {{customer_custom_field_YOUR-CUSTOME-FILD-NAME}} # the script expects a comma seperated list if more than one domain to monitor.
# ApiToken, Var Type = Password, Value = Your API Token for jsonwhois.com

# Test system, will only run on the PDCEmulator role holder.
try {
    $PDCEmulator = (Get-ADDomain -ErrorAction Stop).pdcemulator -match $env:COMPUTERNAME
}
catch {
    $PDCEmulator = $false
}
finally {
    if (!($PDCEmulator) -and (Get-WmiObject -Class Win32_ComputerSystem).PartOfDomain){
        "Computer is part of domain, and does not hold the PDCEmulator role"
        Exit 0
    }
}

if ($env:SyncroModule){
    Import-Module $env:SyncroModule
}

# Process Platform vars to find Domains
$DomainList = @()

if (-not [string]::IsNullOrWhiteSpace($DomainsCsv)){
    "Domains $DomainsCsv"
    [array]$DomainList += $DomainsCsv.split(',').trim()
}

if (-not [string]::IsNullOrWhiteSpace($CustomerEmail)){
    $emlDom = $CustomerEmail.split('@')[1]
    [array]$DomainList += $emlDom
    if ($env:SyncroModule){ Close-Rmm-Alert -Category 'Missing Company Email' -CloseAlertTicket "true" }
}

[array]$DomainList = $DomainList | Select-Object -Unique | Sort-Object
if ($DomainList.Count -lt 1) {
    "No Domains to monitor. Exiting"
    $missingEmail = 'Please Go to Company Settings and add a valid email address'
    if ($env:SyncroModule){
        Rmm-Alert -Category 'Missing Company Email' -Body $missingEmail
    } else {
        Write-Warning 'Please Go to Company Settings and add a valid email address'
    }
    exit 1
}

#set $Date -1 second ago for retry failure
$date = (Get-Date).AddSeconds(-1)
[array]$ResultArray = foreach ($d in $DomainList){
    $splat = @{
        Uri     = 'https://jsonwhois.com/api/v1/whois'
        Headers = @{
            Accept        = "application/json"
            Authorization = "Token token=$ApiToken"
        }
        Body    = @{domain = $d}
        UseBasicParsing = $true
        ContentType = 'json'
    }

    $Backoff = 1
    $Success = $false
    do {
        if (($WaitT = ($date.AddSeconds(1) - (Get-Date))).TotalSeconds -gt 0){
            Start-Sleep -Milliseconds $WaitT.TotalMilliseconds
        }
        try {
            $lookup = (Invoke-WebRequest @splat -ErrorAction Stop).Content | ConvertFrom-Json
            $Success = $true
        }
        catch {
            Write-Host (($Error[0] | Select-Object -Property Exception | Out-String).trim() -split '\r')[-1]
            Write-Host "Sleeping for $backoff"
            Start-Sleep -Seconds $Backoff
            $rand = [math]::round((Get-Random -Minimum ($Backoff * .9) -Maximum ($Backoff * 1.2)),3)
            $Backoff = ($Backoff + $rand)
        }
    } until ($Backoff -ge 70 -or $Success -eq $true)

    if ($Success) {
        $ht = @{
            Domain  = $lookup.domain
            Expires = $lookup.expires_on
            Registrar = @($lookup.registrar.Name, $lookup.registrar.url)
            Nameservers = $lookup.nameservers.name
        }

        if([datetime]$lookup.expires_on -lt (Get-Date).AddDays(-15)){
            $AlertMessage = '{0} expires {1}. Registrar: {2}, {3}' -f $lookup.domain, $lookup.expires_on, $lookup.registrar.Name, $lookup.registrar.url
            Try {
                Rmm-Alert -Category 'Expiring_Domain' -Body $AlertMessage -ErrorAction Stop
            } catch {
                Write-Host -Object $AlertMessage
                $AlertFailed = $true
            }
        } else {
            Write-Host -Object $('{0} expires on {1}' -f $lookup.domain, $lookup.expires_on)
        }

        $ht
    }
    $date = Get-Date
}

$DomainStatus = foreach ($r in $ResultArray){
@"
$($r.Domain):
`tExpires:`t$($r.Expires)
`tRegistrar:
`t`t$($r.Registrar -join ' | ')
`tNameServers:
`t`t$($r.NameServers -join ' | ')
"@
}
$DomainStatus = $DomainStatus -join "`r`n"

if ($ResultArray.Count -ge 1) {
    try {
        ''
        Write-Host "Updating Asset Field: " -NoNewline
        Set-Asset-Field -Name "Monitored Domains" -Value $DomainStatus -ErrorAction Stop
    } catch {
        $ResultArray
    }
}

# exit 1 if syncro alert failed
if ($AlertFailed -or !($Success)){
    if ($env:SyncroModule){
        Rmm-Alert -Category 'DomainMonitoring' -Body 'Domain Monitoring Failed Please check Logs'
    }
    "Exit 1"
    exit 1
}
