$UpdateTime = (Get-Date).ToUniversalTime().AddMinutes(5).ToString("yyyy-MM-ddTH:mm:ss.0000000Z")
#Update Syncro last_sync registry value
Set-ItemProperty -Path "HKLM:\SOFTWARE\WOW6432Node\RepairTech\Syncro" -Name "last_sync" -Value "$UpdateTime"

function Run-InNewProcess{
  param([String] $code)
  $code = "function Run{ $code }; Run $args"
  $encoded = [Convert]::ToBase64String( [Text.Encoding]::Unicode.GetBytes($code))

  start-process -WindowStyle hidden PowerShell.exe -argumentlist '-windowstyle','hidden','-noExit','-encodedCommand',$encoded
}

$script = {
    $CurrentDateString = (Get-Date).ToString("yyyyMMdd")
    $LogLocation = "C:\ProgramData\Syncro\logs\$CurrentDateString-Syncro.Service.Runner.log"

    Import-Module $env:SyncroModule

    Start-Sleep -s 10;
    Restart-Service -Name "Syncro" -Force

    Log-Activity -Message "Restarted Syncro Service for Full Sync" -EventName "SyncroRestart"

    # Hack to get Get-Content -wait to work properly
    $hackJob = Start-Job {
      $f=Get-Item $LogLocation
      while (1) {
        $f.LastWriteTime = Get-Date
        Start-Sleep -Seconds 1
      }
    }

    # Job that confirms if the sync happened
    $job = Start-Job { param($LogLocation)
        Import-Module $env:SyncroModule

        Get-Content $LogLocation -tail 0 -wait | where { $_ -match "Large sync complete" } |% { Log-Activity -Message "Full Sync Successful" -EventName "SyncroFullSync"; break }
    } -Arg $LogLocation

    # Wait for the Activity-Log job to complete or to timeout
    Wait-Job $job -Timeout 60

    # Cleanup jobs
    Get-Job | Stop-Job
    Get-Job | Remove-Job
}

Run-InNewProcess $script | Out-Null

Exit 0
