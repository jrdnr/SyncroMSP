$Publisher = 'MspPlatform|N-able|SolarWinds'
$SilentUninstallFlag = '/SILENT'
$exit = 0

$FileLocation = @(
    'C:\Program Files\'
    'C:\Program Files (x86)\'
    'C:\ProgramData\'
)

$folderList = @(
    'BeAnywhere'
    'MspPlatform'
    'N-able'
    '^Package Cache$'
    'SolarWinds'
)
$SvcPath = @(
    'HKLM:\SYSTEM\CurrentControlSet\Services',
    'HKLM:\SYSTEM\CurrentControlSet001\Services',
    'HKLM:\SYSTEM\CurrentControlSet002\Services',
    'HKLM:\SYSTEM\CurrentControlSet003\Services'
)
$SvcSubKey = @(
    'AssetDiscovery',
    'InterfaceDiscovery',
    'N-ablesyslog',
    'N-ableTechnologies Windows Software Probe',
    'N-ableTechnologies Windows Software Probe Maintenance'
)

$RegPath = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\N-ableTechnologies Inc. Windows Agent',
    'HKLM:\SOFTWARE\N-ableTechnologies\Windows Agent',
    'HKLM:\SYSTEM\CurrentControlSet\Services\N-ableTechnologies Windows Agent',
    'HKLM:\SYSTEM\CurrentControlSet\Services\N-ableTechnologies Windows Agent Maintenance',
    'HKLM:\SOFTWARE\N-ableTechnologies\Windows Software Probe',
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\N-ableTechnologies Inc. Windows Probe'
)

function Import-SyncroModule {
    param (
        #Defaults to the UUID of local system but you can provide the UUID of Any other Syncro Asset instead.
        $UUID
    )

    # Set up $env: vars for Syncro Module
    if($env:SyncroModule -match '^\s*$'){
        $SyncroRegKey = Get-ItemProperty -Path 'HKLM:\SOFTWARE\WOW6432Node\RepairTech\Syncro' -Name uuid, shop_subdomain
        $env:RepairTechFilePusherPath  = 'C:\ProgramData\Syncro\bin\FilePusher.exe'
        $env:RepairTechKabutoApiUrl    = 'https://rmm.syncromsp.com'
        $env:RepairTechSyncroApiUrl    = 'https://{subdomain}.syncromsp.com'
        $env:RepairTechSyncroSubDomain = $SyncroRegKey.shop_subdomain
        $env:RepairTechUUID            = if($UUID -match '^\s*$'){ $SyncroRegKey.uuid } else {$UUID}
        $env:SyncroModule              = "$env:ProgramData\Syncro\bin\module.psm1"
    }
    if ((Test-Path -Path $env:SyncroModule) -and ($PSVersionTable.PSVersion -ge [system.version]'4.0')) {
        Import-Module -Name $env:SyncroModule -WarningAction SilentlyContinue
    } elseif ($PSVersionTable.PSVersion.Major -lt 4) {
        Write-Warning "$($PSVersionTable.PSVersion) is not compatible with SyncroModule"
        [Environment]::SetEnvironmentVariable('SyncroModule',$null)
        $false
    }
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
if($null -ne $Applist){
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
}

Get-ChildItem -Path $FileLocation -ErrorAction SilentlyContinue | Where-Object {$_.name -match ($folderList -join '|')} | Remove-Item -Recurse -Force -ErrorAction Continue -Verbose
Get-ChildItem -Path $SvcPath -ErrorAction SilentlyContinue | Where-Object {$_.name -match ($SvcSubKey -join '|')} | Remove-Item -Recurse -Force -ErrorAction Continue -Verbose
Get-ChildItem -Path $RegPath -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction Continue -Verbose
try {
    $CredPovider = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\Credential Providers\'
    $dll = 'MSPACredentialProvider_.+_N-Central'

    Get-ChildItem $CredPovider | Where-Object {
        (Get-ItemProperty (Join-Path -Path $CredPovider -ChildPath $_.PSChildName) |
        Select-Object -ExpandProperty '(default)') -match $dll} |
        Remove-Item -Force -ErrorAction Stop -Verbose
    Get-ChildItem -Path "$env:SystemRoot\system32\MSPACredentialProvider*" |
        Where-Object {$_.name -match $dll } -OutVariable MSPACredentialProvider |
        Remove-Item -Force -ErrorAction Stop -Verbose
}
catch {
    if ($MSPACredentialProvider.Count -lt 1){
        Write-Warning "Error Cleaning up registry keys"
    } else {
        Write-Warning "Could not Delete MSPACredentialProvider dll"
        $HKLMPath = 'HKLM:'
        foreach ($p in ('SOFTWARE\Microsoft\ServerManager').Split('\')){
            $NewPath = Join-Path -Path $HKLMPath -ChildPath $p
            if (!(Test-Path -Path $NewPath)){
                New-Item -Path $HKLMPath -Name $p
            }
            $HKLMPath = $NewPath
        }
        if (!(Test-Path -Path (Join-Path -Path $HKLMPath -ChildPath CurrentRebootAttemps))) {
            New-Item -Path $HKLMPath -Name CurrentRebootAttemps -Value 'Reboot required after Registry Update'
        }
    }
    $exit = 1
}

Import-SyncroModule
if (Test-Path -Path $env:SyncroModule) {Close-Rmm-Alert -Category 'Ncentral_DLL' }

exit $exit
