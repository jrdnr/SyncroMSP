#Example application uninstall. Not all apps register in either of these locations but this will work for some apps

$AppSearch = 'screenconnect*'

function Get-InstalledApps {
    param (
        [string]$App
    )
    $installLocation = @(
        "HKLM:\software\microsoft\windows\currentversion\uninstall"
        "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\"
    )
    foreach ($il in $installLocation){
        get-childitem $il | ForEach-Object { Get-ItemProperty $_.PSPath } |
            Select-Object DisplayVersion,InstallDate,ModifyPath,Publisher,UninstallString,Language,DisplayName |
            Where-Object {$_.DisplayName -like $App}
    }
}

$cmd = (Get-InstalledApps $AppSearch).UninstallString -split ' '
Start-Process $cmd[0] -ArgumentList "$($cmd[1]) /qn"
