# Prerequisites: You must have a custom asset field
#                Name: "Bitlocker Drives"
#                Type: "Text area"
#

try{
    # Get Bitlocker Volumes or exit.
    $BitLockerVolume = Get-BitLockerVolume -ErrorAction stop

    # Create output as [string] for Text area Asset-Field.
    $Report = $BitLockerVolume |
        ForEach-Object {
            $MountPoint = $_.MountPoint
            $RecoveryKey = [string]($_.KeyProtector).RecoveryPassword
            if ($RecoveryKey.Length -gt 5) {
                Write-Output ("Drive $MountPoint recovery key: $RecoveryKey")
            }
        } | Out-String

    if ($Report.Length -ge 56){
        if ($env:SyncroModule){
            Import-Module $env:SyncroModule
            Set-Asset-Field -Name "Bitlocker Drives" -Value $Report
        } else {
            $Report
        }
    }
} catch [System.Management.ManagementException] {
    "Bitlocker Not Detected"
} catch [System.Management.Automation.CommandNotFoundException] {
    "Bitlocker Not Detected"
} catch {
    "Unexpected Error"
    (($Error[0] | Select-Object -Property Exception | Out-String).trim() -split '\r')[-1]
    exit 1
}
