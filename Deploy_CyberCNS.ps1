<#- Start of Script -#>
# Required Variables
#   $InstType (recomend Dropdown), Values: 'Probe','LightWeight','Scan','auto'
#   $ClientID (recomend Platform variable set to customer custom field)
#   $ClientSecret (recomend Platform variable set to customer custom field)
#   $Uninstall (recomend Dropdown), Values: 'True', 'False'
#   $environment = Should be your environment/domain for -e in installer
#   $DLSecret    = Any credentials required to access DL URI in format "Username:Password@"

$Url = 'portaluseast2.mycybercns.com'
# Should Generate a valid download link, but moved to Azure Blob due to reliability issues.
$AgentURI = (Invoke-RestMethod -Method "Get" -URI "https://configuration.mycybercns.com/api/v3/configuration/agentlink?ostype=windows")
$AgentName = $AgentURI.Split('/')[-1]

'#============ Syncro Inserted Code ============#'
foreach ($line in (Get-Content -Path  $MyInvocation.MyCommand.Path -ErrorAction Stop)){
    if ($line -eq '<#- Start of Script -#>') {
        break
    } else {
        # Mask Guid in log
        $line -replace '([0-9a-fA-F]{3})[0-9a-fA-F]{5}-(?:[0-9a-fA-F]{4}-){3}[0-9a-fA-F]{8}([0-9a-fA-F]{4})|^(\w{3})\w{23,}(\w{4})$', '$1$3*****-****-****-****-********$2$4'
    }
}
'#============== END Syncro Code ===============#'
''

#
# $AgentURI OR Required File (use to specify download link or save cybercnsagent.exe to C:\Windows\Temp)
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$installTypes = @('Probe','LightWeight','Scan','auto')
if ($installTypes -notcontains $InstType){
    Write-Warning "`$InstType must equal one of ($($installTypes -join ', '))"
    "Setting InstType to auto"
    $InstType = 'auto'
}

if ("$ClientID$ClientSecret" -match 'Skip'){
    "Skip Install"
    exit
} elseif ($ClientID -match '^\s*$' -or $ClientSecret -match '^\s*$'){
    Write-Warning '$ClientID and $ClientSecret are both required to install the agent.'
    exit 2
}

if ($Uninstall -eq 'True'){
    Get-Process cybercns* | Stop-Process -Force
    Get-Service cybercns* | Stop-Service -Force

    if ((Test-Path -Path 'C:\Program Files (x86)\CyberCNSAgentV2\uninstall.bat')){
        Start-Process -FilePath 'C:\Program Files (x86)\CyberCNSAgentV2\uninstall.bat' -NoNewWindow -Wait
        Start-Sleep -Seconds 5
    }
    if (Test-Path 'C:\Program Files (x86)\CyberCNSAgentV2\cybercnsagentv2.exe'){
        Start-Process -FilePath 'C:\Program Files (x86)\CyberCNSAgentV2\cybercnsagentv2.exe' -ArgumentList '--uninstall' -NoNewWindow -Wait
        Start-Sleep -Seconds 5
    }

    Get-Service CyberCNS* | ForEach-Object { sc.exe delete $_.Name }
    if (Test-Path -Path 'C:\Program Files (x86)\CyberCNSAgentV2'){
        Remove-item -Path 'C:\Program Files (x86)\CyberCNSAgentV2\Cyber*' -Recurse -Force
    }
}

$CyberCNSService = Get-Service -Name CyberCNSAgent* -ErrorAction SilentlyContinue

if ($null -ne $CyberCNSService -and $CyberCNSService.Status -ne 'Running'){
    try {
        Start-Service -InputObject $CyberCNSService -ErrorAction Stop
        Start-Sleep -Seconds 3
        if (Get-Service -Name CyberCNSAgent* -ErrorAction SilentlyContinue -eq 'Running'){
            exit 0
        }

    }
    catch {
        'Could not start service, Proceed to install'
    }
} elseif ($env:SyncroModule) {
    <#
    Import-Module $env:SyncroModule -WarningAction SilentlyContinue
    # the Issue with closing this is that "PS Monitor" is all Process monitors.
    Close-Rmm-Alert -Category "Ps Monitor"
    #>
}

if ($InstType -eq 'auto'){
    try {
        if ((Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -ErrorAction SilentlyContinue).State -eq 'Enabled') {
            $InstType = 'Probe'
        } else {
            throw
        }
    }
    catch {
        $InstType = 'LightWeight'
    }
}

$SystemTemp = Join-Path -Path $env:SystemRoot -ChildPath 'Temp'
if (!(Test-Path -Path $SystemTemp)) {
    $SystemTemp = $env:TEMP
}
$destination = Join-Path -Path $SystemTemp -ChildPath $AgentName
if (!(Test-Path -Path $destination)) {
    Get-ChildItem -Path $SystemTemp -Filter *cybercns* | Remove-Item -Force
    "Downloading '$AgentName'"
    try {
        Start-BitsTransfer -Source $AgentURI -Destination $destination -Description 'Downloading CyberCNS Agent using Bits' -ErrorAction Stop
    }
    catch {
        Invoke-WebRequest -Uri $AgentURI -OutFile $destination -UseBasicParsing
    }
}

"Running: Start-Process $destination -ArgumentList `"-c $ClientID -a $ClientID -s `$ClientSecret -b $Url -e $environment -i $InstType`" -NoNewWindow"
Start-Process $destination -ArgumentList "-c $ClientID -a $ClientID -s $ClientSecret -b $Url -e $environment -i $InstType" -NoNewWindow -Wait
