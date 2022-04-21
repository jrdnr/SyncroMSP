# Required Variables
# $InstType (recomend Dropdown), Values: 'Probe','LightWeight','Scan','auto'
# $ClientID (recomend Platform variable set to customer custom field)
# $ClientSecret (recomend Platform variable set to customer custom field)
# $Uninstall (recomend Dropdown), Values: 'True', 'False'
#
# $Source OR Required File (use to specify download link or save cybercnsagent.exe to C:\Windows\Temp)
$installTypes = @('Probe','LightWeight','Scan','auto')
if ($installTypes -notcontains $InstType){
    throw "`$InstType must equal one of ($($installTypes -join ', '))"
    exit 1
}

if ([string]::IsNullOrEmpty($ClientID) -or [string]::IsNullOrEmpty($ClientSecret)){
    throw '$ClientID and $ClientSecret are both required to install the agent.'
    exit 1
}

if ($Uninstall -eq 'True' -and (Test-Path -Path 'C:\Program Files (x86)\CyberCNSAgentV2\uninstall.bat')){
    net stop cybercnsagentv2
    Start-Process -FilePath 'C:\Program Files (x86)\CyberCNSAgentV2\uninstall.bat' -NoNewWindow -Wait
    Start-Sleep -Seconds 5
}

$CyberCNSService = Get-Service -Name CyberCNSAgent* -ErrorAction SilentlyContinue

if ($null -ne $CyberCNSService){
    $i = 0
    while ($CyberCNSService.Status -ne 'Running' -and $i -lt 7) {
        Start-Service -InputObject $CyberCNSService
        Start-Sleep -Seconds 3
        $CyberCNSService = Get-Service -Name CyberCNSAgent* -ErrorAction SilentlyContinue
    }
    if ($CyberCNSService.Status -eq 'Running'){
        Write-Output "CyberCNS already running"
        exit 0
    }
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

"Running: Start-Process $destination -ArgumentList `"-c $ClientID -a $ClientID -s `$ClientSecret -b eberlysystemsv2.mycybercns.com -i $InstType`" -NoNewWindow"
Start-Process $destination -ArgumentList "-c $ClientID -a $ClientID -s $ClientSecret -b eberlysystemsv2.mycybercns.com -i $InstType" -NoNewWindow
