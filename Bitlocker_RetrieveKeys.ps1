# ==============================================================================
# ==            Created by Jordan Ritz, Eberly Systems LLC.                   ==
# ==============================================================================
#
# Prerequisites: You must have a custom asset field
#                Name: "Bitlocker Drives"
#                Type: "Text area"
#

try{
    # Get Bitlocker Volumes or exit.
    $BitLockerVolume = Get-BitLockerVolume -ErrorAction stop

} catch [System.Management.ManagementException] {
    "Bitlocker Not Detected"
} catch [System.Management.Automation.CommandNotFoundException] {
    "Bitlocker Not Detected"
} catch {
    "Unexpected Error"
    (($Error[0] | Select-Object -Property Exception | Out-String).trim() -split '\r')[-1]
    exit 1
}

$Report = $BitLockerVolume |
ForEach-Object {
    $MountPoint = $_.MountPoint
    $_.KeyProtector | Where-Object {$_.RecoveryPassword -notmatch '^\s$' -and $_.RecoveryPassword.Length -gt 5} |
        ForEach-Object {
            Write-Output "$MountPoint Id:$($_.KeyProtectorId), key:$($_.RecoveryPassword)"
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
