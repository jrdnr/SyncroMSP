$Publisher = 'MspPlatform|N-able|SolarWinds|Solve IT'
$SilentUninstallFlag = '/SILENT'
$exit = 0

$FileLocation = @(
    'C:\Program Files\'
    'C:\Program Files (x86)\'
    'C:\ProgramData'
)

$folderList = @(
    'Avast*'
    'BeAnywhere'
    'Level Platforms'
    'MspPlatform'
    'N-able*'
    'Package Cache'
    'Rmm'
    'SolarWinds*'
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
        [string]$App,
        [string]$Publisher
    )
    $installLocation = @(
        "HKLM:\software\microsoft\windows\currentversion\uninstall"
        "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\"
    )
    $AllApps = get-childitem $installLocation | ForEach-Object { Get-ItemProperty $_.PSPath }

    foreach ($a in $AllApps){
        if ($a.DisplayName -match $App -and $a.Publisher -match $Publisher){
            $a
        }
    }
}

$Applist = Get-InstalledApps -Publisher $Publisher
foreach ($a in $Applist){
    'Uninstalling "{0}" by "{1}"' -f $a.DisplayName, $a.Publisher
    if($a.QuietUninstallString -match '"(.*)"\s(/.*)'){
        Start-Process -FilePath $Matches[1] -ArgumentList $Matches[2] -Wait
    } elseif ($a.UninstallString -like 'C:\Program Files*'){
        Start-Process -FilePath $a.UninstallString -ArgumentList $SilentUninstallFlag -Wait
    } elseif ($a.UninstallString -like 'MsiExec.exe*'){
        $ArgList = (($a.UninstallString -split 'MsiExec.exe')[1].trim() -replace '/I{','/X{').ToString()
        $ArgList = '{0} /quiet /norestart' -f $ArgList
        Start-Process -FilePath MsiExec.exe -ArgumentList $ArgList -Wait
    } else {
        "Could not auto uninstall $($a.DisplayName)"
        "Uninstall String: '$($a.UninstallString)'"
        $exit = 2
    }
}

Get-ChildItem -Path $FileLocation -Include $folderList | Remove-Item -Recurse -Force -ErrorAction Continue

exit $exit
