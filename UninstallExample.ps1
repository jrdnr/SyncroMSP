#Requires -RunAsAdministrator

#Example application uninstall, will attempt to find apps installed in system locations as well as User hives.
# Not all apps record uninstall info in these locations so may not work for all apps.

# $AppSearch = 'Wave Browser'
# $Publisher = 'Piriform'
$SilentUninstallFlag = '/SILENT'
$exit = 0

function Get-InstalledApps {
    param (
        [string]$App,
        [string]$Publisher,
        [switch]$or
    )

    if ((Get-PSDrive | Where-Object {$_.Name -eq 'HKU'}).count -lt 1){
        New-PSDrive -Name HKU -PSProvider Registry -Root Registry::HKEY_USERS | Out-Null
    }
    [array]$users = Get-WMIObject -class Win32_UserProfile | Sort-Object -Property LastUseTime |
        Where-Object { $_.LocalPath -like 'c:\user*' }
    $users += [PSCustomObject]@{LocalPath = 'c:\users\.DEFAULT'; SID = '.DEFAULT'}

    $InstLocation = @{}
    foreach ($u in $Users) {
        $hkuPath = "HKU\$($u.SID)"
        $ntuserdat = Join-Path -Path $u.LocalPath -ChildPath NTUSER.DAT
        $UserHive = "HKU:\$($u.SID)"
        $unload = $false

        if (!(Test-Path -Path $UserHive)){
            reg load $hkuPath $ntuserdat 2>&1 | Out-Null
            $unload = $true
        }
        $UPath = Join-Path -Path $UserHive -ChildPath 'Software\Microsoft\Windows\CurrentVersion\Uninstall'
        if (Test-Path -Path $UPath){
            $InstLocation.Add($UPath,$unload)
        }
    }

    $InstLocation += @{
        "HKLM:\software\microsoft\windows\currentversion\uninstall" = $false
        "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\" = $false
    }
    $AllApps = get-childitem $InstLocation.Keys.split() | ForEach-Object { Get-ItemProperty $_.PSPath }
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

    foreach ($k in $InstLocation.Keys){
        if($InstLocation.$k -eq $true){
            reg unload $hkuPath 2>&1 | Out-Null
        }
    }
}

$splat = @{}
if ($AppSearch -notmatch '^\s*$'){
    $splat.Add('App',$AppSearch)
}
if ($Publisher -notmatch '^\s*$'){
    $splat.Add('Publisher',$Publisher)
}
if ($or -eq 'True'){
    $splat.Add('or',$true)
}

Get-InstalledApps @splat | Tee-Object -Variable Applist | Format-Table -Property InstallDate, DisplayName, Publisher, DisplayVersion

if (($AppSearch + $Publisher) -notmatch '^[\.\s\*\+]*$' -and $Applist.count -lt 5){
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
            try {
                $ErrorActionPreference = 'Stop'
                Get-Package -Name $a.DisplayName -IncludeWindowsInstaller | Uninstall-Package
            }
            catch {
                "Could not auto uninstall $($a.DisplayName)"
                "Uninstall String: '$($a.UninstallString)'"
                $exit = 2
            }
            finally {
                $ErrorActionPreference = 'Continue'
            }
        }
    }
} else {
    Write-Warning "Search terms to broad to auto uninstall"
    $totalApps = $Applist.count
    Write-Host "INFO: `$Applist.count is $totalApps"
    Write-Host "INFO: Apps: '$AppSearch', Publisher: '$Publisher'"
    $exit = 3
}

exit $exit
