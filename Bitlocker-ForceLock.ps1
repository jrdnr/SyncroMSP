try{
    # Get Bitlocker Volumes or exit.
    $BitLockerVolume = Get-BitLockerVolume -ErrorAction stop

} catch [System.Management.ManagementException] {
    "Bitlocker Not Detected"
    exit 1
} catch [System.Management.Automation.CommandNotFoundException] {
    "Bitlocker Not Detected"
    exit 1
} catch {
    "Unexpected Error"
    (($Error[0] | Select-Object -Property Exception | Out-String).trim() -split '\r')[-1]
}

foreach ($MountPoint in ($BitLockerVolume | Select-Object -ExpandProperty MountPoint -Unique)) {
    # Wipe existing BitLocker protections
    Invoke-Command {manage-bde -protectors -delete $MountPoint}
    # Create new, randomly generated recovery password
    Invoke-Command {manage-bde -protectors -add $MountPoint -RecoveryPassword}
    # Verify new recovery password will be required on next reboot
    Invoke-Command {manage-bde -protectors -enable $MountPoint}
}

$Report = Get-BitLockerVolume |
    ForEach-Object {
        $MountPoint = $_.MountPoint
        $_.KeyProtector | Where-Object {$_.RecoveryPassword -notmatch '^\s$' -and $_.RecoveryPassword.Length -gt 5} |
            ForEach-Object {
                Write-Output "$MountPoint Id:$($_.KeyProtectorId), key:$($_.RecoveryPassword)"
            }
    } | Out-String

if ($Report.Length -ge 56){
    $Report
    if ($env:SyncroModule){
        Import-Module $env:SyncroModule -WarningAction SilentlyContinue
        Set-Asset-Field -Name "Bitlocker Drives" -Value $Report
    }
}

foreach ($MountPoint in (Get-BitLockerVolume | Select-Object -ExpandProperty MountPoint -Unique)) {
    # Force the user to be prompted for new recovery password
    Invoke-Command {manage-bde -forcerecovery $MountPoint}
}
shutdown -s -t 0 -f
