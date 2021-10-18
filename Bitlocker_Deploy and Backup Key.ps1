# Copied from Pastebin
#  https://pastebin.com/M8WrgsZd?fbclid=IwAR3lt2oyPNzURIc6dpJrunk4RYrPF8YdZzrh_nmS3N1lnGCmp_ZHb8vNRl0
#  Origional Author: AJJAXNET (https://pastebin.com/u/AJJaxNet)
#
#  Updated for usability and conistent formating.


[cmdletbinding()]
  param(
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string] $OSDrive = $env:SystemDrive,
    # Required Field Type: Text
    [string] $SyncroBL = "Bitlocker Backup Key"

  )

Import-Module $env:SyncroModule

function Get-Bitlocker-RecoveryPasswords {
    param(
        [Parameter(Mandatory=$true)]
        [Boolean]
        $SaveToSyncro
    )

    $textOutput = ""

    # Identify all the Bitlocker volumes.
    $BitlockerVolumes = Get-BitLockerVolume

    # For each volume, get the RecoveryPassword and display it.
    $BitlockerVolumes |
        ForEach-Object {
            $MountPoint = $_.MountPoint
            $RecoveryKey = [string]($_.KeyProtector).RecoveryPassword
            if ($RecoveryKey.Length -gt 5) {
                Write-Output ("The drive $MountPoint has a recovery key $RecoveryKey.")
                $textOutput += "$MountPoint/ $RecoveryKey"
                $textOutput += "`r`n"
            }
        }

    if ($saveToSyncro -eq $true) {
        Set-Asset-Field -Name $SyncroBL -Value $textOutput
    }
}

try {
    $ErrorActionPreference = "stop"

    Write-Host "Enabling BitLocker with TPM."

    # Enable Bitlocker using TPM
    Enable-BitLocker -MountPoint $OSDrive -UsedSpaceOnly -TpmProtector -ErrorAction Continue

    # Only add RecoveryPassword if none is already defined
    if (((Get-BitLockerVolume -MountPoint $OSDrive).KeyProtector | Where-Object {$_.KeyProtectorType -eq 'RecoveryPassword'} | Measure-Object).Count -eq 0) {
        Write-Host "Adding a recovery password..."
        Enable-BitLocker -MountPoint $OSDrive -UsedSpaceOnly -RecoveryPasswordProtector
    }
    else {
        Write-Host "A recovery password is already defined, skipping creation."
    }

    Start-Sleep -Seconds 30

    #$key = (Get-BitLockerVolume -MountPoint $OSDrive).KeyProtector|?{$_.KeyProtectorType -eq 'RecoveryPassword'}
    #$keyPass = [String]$key.RecoveryPassword
    #Write-Host "Recovery key: $keyPass"

    Get-Bitlocker-RecoveryPasswords -SaveToSyncro $true
}
catch {
    Write-Host "Error while setting up Bitlocker, make sure that you are running the cmdlet as an admin: $_"
    Create-Syncro-Ticket -Subject "BitLocker Deployment Issue" -IssueType "PC Issue" -Status "New"
}
