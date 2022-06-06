foreach ($MountPoint in (Get-BitLockerVolume | Select-Object -ExpandProperty MountPoint -Unique)) {
    Invoke-Command {manage-bde -forcerecovery $MountPoint}
  <#
    $KeyProtectors = (Get-BitLockerVolume -MountPoint $MountPoint).KeyProtector
    foreach($KeyProtector in $KeyProtectors){
        Remove-BitLockerKeyProtector -MountPoint $MountPoint -KeyProtectorId $KeyProtector.KeyProtectorId
    }
  #>
}
shutdown -s -t 0 -f
