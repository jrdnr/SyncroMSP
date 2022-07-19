<#- Start of Script -#>
# Required Variables
#   $InstType (recomend Dropdown), Values: 'Probe','LightWeight','Scan','auto'
#   $ClientID (recomend Platform variable set to customer custom field)
#   $ClientSecret (recomend Platform variable set to customer custom field)
#   $Uninstall (recomend Dropdown), Values: 'True', 'False'
#   $environment = Should be your environment/domain for -e in installer
$Url = 'portaluseast2.mycybercns.com'

'============ Syncro Inserted Code ============'
foreach ($line in (Get-Content -Path  $MyInvocation.MyCommand.Path -ErrorAction Stop)){
    if ($line -eq '<#- Start of Script -#>') {break}
    $line
}
'============== END Syncro Code ==============='
''

#
# $Source OR Required File (use to specify download link or save cybercnsagent.exe to C:\Windows\Temp)
$installTypes = @('Probe','LightWeight','Scan','auto')
if ($installTypes -notcontains $InstType){
    Write-Warning "`$InstType must equal one of ($($installTypes -join ', '))"
    "Setting InstType to auto"
    $InstType = 'auto'
}

if ($ClientID -match '^\s*$' -or $ClientSecret -match '^\s*$'){
    Write-Warning '$ClientID and $ClientSecret are both required to install the agent.'
    exit 2
}

if ($Uninstall -eq 'True' -and (Test-Path -Path 'C:\Program Files (x86)\CyberCNSAgentV2\uninstall.bat')){
    net stop cybercnsagentv2
    Start-Process -FilePath 'C:\Program Files (x86)\CyberCNSAgentV2\uninstall.bat' -NoNewWindow -Wait
    Start-Sleep -Seconds 5
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
            $InstType = 'LightWeight'
        }
    }
    catch {
        $InstType = 'LightWeight'
    }
}

$destination = Join-Path -Path 'C:\Windows\Temp\' -ChildPath 'cybercnsagent.exe'
switch -Regex ($Source) {
    'https://\w+\.mycybercns\.com/.*/cybercnsagent\.exe' {
        try {
            Start-BitsTransfer -Source $Source -Destination $destination -Description 'Downloading CyberCNS Agent using Bits' -ErrorAction Stop
        }
        catch {
            (New-Object Net.WebClient).DownloadFile($Source, $destination)
        }
    }
    Default {
        if(!(Test-Path -Path $destination)){
            Throw "'$Destination' not found"
            exit 2
        }
    }
}

"Running: Start-Process $destination -ArgumentList `"-c $ClientID -a $ClientID -s `$ClientSecret -b $Url -e $environment -i $InstType`" -NoNewWindow"
Start-Process $destination -ArgumentList "-c $ClientID -a $ClientID -s $ClientSecret -b $Url -e $environment -i $InstType" -NoNewWindow
