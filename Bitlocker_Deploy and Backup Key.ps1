# Copied from Pastebin
#  https://pastebin.com/M8WrgsZd?fbclid=IwAR3lt2oyPNzURIc6dpJrunk4RYrPF8YdZzrh_nmS3N1lnGCmp_ZHb8vNRl0
#  Origional Author: AJJAXNET (https://pastebin.com/u/AJJaxNet)
#
#  Updated for usability and conistent formating.
#  Added backup to Azure AD and onprem Domain


[cmdletbinding()]
  param(
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string] $OSDrive = $env:SystemDrive,
    [string] $SyncroBL = 'Bitlocker Drives'
  )

# Set the TLS version used by the PowerShell client to TLS 1.2.
if ([System.Net.ServicePointManager]::SecurityProtocol -lt [System.Net.SecurityProtocolType]::Tls12){
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
}

# Set up $env: vars for Syncro Module
if([string]::IsNullOrWhiteSpace($env:SyncroModule)){
    $SyncroRegKey = Get-ItemProperty -Path 'HKLM:\SOFTWARE\WOW6432Node\RepairTech\Syncro' -Name uuid, shop_subdomain
    $env:RepairTechFilePusherPath   = 'C:\ProgramData\Syncro\bin\FilePusher.exe'
    $env:RepairTechKabutoApiUrl     = 'https://rmm.syncromsp.com'
    $env:RepairTechSyncroApiUrl     = 'https://{subdomain}.syncroapi.com'
    $env:RepairTechSyncroSubDomain  = $SyncroRegKey.shop_subdomain
    $env:RepairTechUUID             = $SyncroRegKey.uuid
    $env:SyncroModule               = "$env:ProgramData\Syncro\bin\module.psm1"
}
if (Test-Path -Path $env:SyncroModule) {
    Import-Module -Name $env:SyncroModule -WarningAction SilentlyContinue
}

function Save-BitlockerRecoveryPasswords {
    param(
        [Parameter(Mandatory=$true)]
        [string] $SyncroBL
    )

    [bool]$saveToAD = (Get-CimInstance win32_computersystem).PartOfDomain
    $dsregcmd = dsregcmd /status
    [bool]$SavetoAzAd = $dsregcmd | Where-Object {$_ -match 'AzureAdJoined'} |
                    ForEach-Object {($_ -split ':' | Select-Object -Last 1).trim() -eq 'YES'}

    $textOutput = ""

    # Identify all the Bitlocker volumes.
    [array]$BitlockerVolumes = Get-BitLockerVolume

    # For each volume, get the RecoveryPassword and display it.
    $BitlockerVolumes |
        ForEach-Object {
            $MountPoint = $_.MountPoint
            $RecoveryKey = $_.KeyProtector | Where-Object { $_.KeyProtectorType -eq 'RecoveryPassword' }
            foreach($rk in $RecoveryKey){
                [string]$RecoveryPw = $rk.RecoveryPassword
                if ($saveToAD -eq $true) {
                    Backup-BitLockerKeyProtector -MountPoint $MountPoint -KeyProtectorId $rk.KeyProtectorID
                }
                if ($saveToAzAD -eq $true) {
                    BackupToAAD-BitLockerKeyProtector -MountPoint $MountPoint -KeyProtectorId $rk.KeyProtectorID
                }
                if ($RecoveryPw.Length -gt 5) {
                    Write-Verbose ("The drive $MountPoint has a recovery key $RecoveryPw.")
                    $textOutput += "$MountPoint\ $RecoveryPw"
                    $textOutput += "`r`n"
                }
            }
        }

    if ($SyncroBL -notmatch '^\s*$') {
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

    Save-BitlockerRecoveryPasswords -SyncroBL $SyncroBL
}
catch {
    Write-Host "Error while setting up Bitlocker, make sure that you are running the cmdlet as an admin: $_"
    Create-Syncro-Ticket -Subject "BitLocker Deployment Issue" -IssueType "PC Issue" -Status "New"
}
