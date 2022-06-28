if ($Uninstall -eq 'True' -and (Test-Path -Path 'C:\Program Files (x86)\CyberCNSAgentV2\uninstall.bat')){
    net stop cybercnsagentv2
    Start-Process -FilePath 'C:\Program Files (x86)\CyberCNSAgentV2\uninstall.bat' -NoNewWindow -Wait
    Start-Sleep -Seconds 5
}
