$FileLocation = @(
    'C:\Program Files\'
    'C:\Program Files (x86)\'
    'C:\ProgramData'
)

function Import-SyncroModule {
    param (
        #Defaults to the UUID of local system but you can provide the UUID of Any other Syncro Asset instead.
        $UUID = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\WOW6432Node\RepairTech\Syncro' -Name uuid -ErrorAction Stop).uuid
    )

    # Set up $env: vars for Syncro Module
    $env:SyncroModule               = "$env:ProgramData\Syncro\bin\module.psm1"
    $env:RepairTechApiBaseURL       = 'syncromsp.com'
    $env:RepairTechApiSubDomain     = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\WOW6432Node\RepairTech\Syncro' -Name shop_subdomain).shop_subdomain
    $env:RepairTechFilePusherPath   = 'C:\ProgramData\Syncro\bin\FilePusher.exe'
    $env:RepairTechUUID             = $UUID

    Import-Module -Name $env:SyncroModule -WarningAction SilentlyContinue
}
function Get-InstalledApps {
    param (
        [string]$App = '*',
        [string]$Publisher = '*'
    )
    $installLocation = @(
        "HKLM:\software\microsoft\windows\currentversion\uninstall"
        "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\"
    )
    foreach ($il in $installLocation){
        get-childitem $il | ForEach-Object { Get-ItemProperty $_.PSPath } |
            #Select-Object DisplayVersion,InstallDate,ModifyPath,Publisher,UninstallString,Language,DisplayName |
            Where-Object {$_.DisplayName -like $App -and $_.Publisher -like $Publisher}
    }
}

$nable = Get-InstalledApps -App n-able

if($null -eq $nable){
    foreach ($l in $FileLocation) {
        Get-ChildItem -Path $l -Filter N-Able* | Remove-Item -Recurse -Force
    }
} else {
    Import-SyncroModule
    Rmm-Alert -Category 'N-Able Installed' -Body "Uninstall N-Able`n$($nable | out-string)"
}
