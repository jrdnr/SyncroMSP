<#- Start of Script -#>
'============ Syncro Inserted Code ============'
foreach ($line in (Get-Content -Path  $MyInvocation.MyCommand.Path -ErrorAction Stop)){
    if ($line -eq '<#- Start of Script -#>') {break}
    $line
}
'============== END Syncro Code ==============='
''

$i = 0
while ($Uninstall -eq 'True' -and (Test-Path -Path 'C:\Program Files (x86)\CyberCNSAgentV2\uninstall.bat') -and $i -lt 6){
    Get-Process -Name cybercns* | Stop-Process -Force
    net stop CyberCNSAgentMonitor
    Start-Process -FilePath sc -ArgumentList 'delete CyberCNSAgentMonitor'
    Start-Process -FilePath 'C:\Program Files (x86)\CyberCNSAgentV2\uninstall.bat' -NoNewWindow -Wait
    Start-Sleep -Seconds 10
    $i++
}

Get-Process -Name cybercns* | Stop-Process -Force
Remove-Item -Path 'C:\Program Files (x86)\CyberCNSAgentV2' -Recurse -Force
