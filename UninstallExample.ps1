#Example application uninstall. Not all apps register in either of these locations but this will work for some apps

# $AppSearch = 'Screenconnect'
$Publisher = 'MspPlatform|N-able|SolarWinds'
$SilentUninstallFlag = '/SILENT'
$exit = 0
function Get-InstalledApps {
    param (
        [string]$App,
        [string]$Publisher,
        [switch]$or
    )
    $installLocation = @(
        "HKLM:\software\microsoft\windows\currentversion\uninstall"
        "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\"
    )
    $AllApps = get-childitem $installLocation | ForEach-Object { Get-ItemProperty $_.PSPath }
        #| Select-Object DisplayVersion,InstallDate,ModifyPath,Publisher,UninstallString,Language,DisplayName

    foreach ($a in $AllApps){
        $test = @(
            ($a.DisplayName -match $App),
            ($a.Publisher -match $Publisher)
        )
        if ($true -ne $or -and $test -notcontains $false){
            $a
        } elseif ($true -eq $or -and $test -contains $true) {
            $a
        }
    }
}

$splat = @{}
if (![string]::IsNullOrWhiteSpace($AppSearch)){
    $splat.Add('App',$AppSearch)
}
if (![string]::IsNullOrWhiteSpace($Publisher)){
    $splat.Add('Publisher',$Publisher)
}
if ($or -eq $true){
    $splat.Add('or',$true)
}

Get-InstalledApps @splat | Tee-Object -Variable Applist | Format-Table -Property InstallDate, DisplayName, Publisher, DisplayVersion

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

exit $exit
