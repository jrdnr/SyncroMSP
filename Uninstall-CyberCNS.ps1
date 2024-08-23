<#- Start of Script -#>
'============ Syncro Inserted Code ============'
foreach ($line in (Get-Content -Path  $MyInvocation.MyCommand.Path -ErrorAction Stop)) {
    if ($line -eq '<#- Start of Script -#>') { break }
    $line
}
'============== END Syncro Code ==============='
''
$paths = @('C:\Program Files (x86)\CyberCNSAgent', 'C:\Program Files (x86)\CyberCNSAgentV2')
$SyncroTxtField = 'CyberCNS'
$i = 0

while (
    $Uninstall -eq 'True' `
        -and (Test-Path -Path 'C:\Program Files (x86)\CyberCNSAgent*\uninstall.bat') `
        -and (Test-Path -Path 'C:\Program Files (x86)\CyberCNSAgent*\cybercnsagent.exe') `
        -and $i -lt 6) {
    Get-Process -Name cybercns* | Stop-Process -Force
    net stop CyberCNSAgentMonitor
    Start-Process -FilePath sc -ArgumentList 'delete CyberCNSAgentMonitor' -Wait
    foreach ($p in $paths) {
        $batPath = Join-Path -Path $p -ChildPath "uninstall.bat"
        $agentPath = Join-Path -Path $p -ChildPath "cybercnsagent.exe"
        if (Test-Path -Path $agentPath) {
            Write-Host "Running: '$agentPath'"
            Start-Process -FilePath $agentPath -ArgumentList '-r' -NoNewWindow -Wait -Verbose
        }
        if (Test-Path -Path $batPath) {
            Write-Host "Running: '$batPath'"
            Start-Process -FilePath $batPath -NoNewWindow -Wait -Verbose
        }
    }
    Start-Sleep -Seconds 30
    $i++
}

Get-Process -Name cybercns* | Stop-Process -Force -ErrorAction SilentlyContinue

$InstLocation = @(
    "HKLM:\software\microsoft\windows\currentversion\uninstall",
    "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\"
)
$CcnsInstalls = get-childitem $InstLocation | ForEach-Object { Get-ItemProperty $_.PSPath } | Where-Object { $_.Publisher -match 'CyberCNS' }
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Import-Module $env:SyncroModule
if ($CcnsInstalls.Count -ge 1) {
    Set-Asset-Field -Name $SyncroTxtField -Value 'True'
    $CcnsInstalls
} else {
    Set-Asset-Field -Name $SyncroTxtField -Value 'False'
    foreach ($p in $paths) {
        if (Test-Path -Path $p) {
            try {
                Remove-Item -Path $p -Recurse -Force -ErrorAction Stop -Verbose
            } catch {
            }
        } else {
            Write-Host "'$p' Does not exist"
        }
    }
}

if ($lastexitcode -ge 1 -and !(Test-Path -Path $paths)) {
    exit 1
} else {
    exit 0
}
