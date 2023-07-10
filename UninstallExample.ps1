<#- Start of Script -#>
'============ Syncro Inserted Code ============'
foreach ($line in (Get-Content -Path  $MyInvocation.MyCommand.Path -ErrorAction Stop)){
    if ($line -eq '<#- Start of Script -#>') {break}
    $line
}
'============== END Syncro Code ==============='
''

#Example application uninstall, will attempt to find apps installed in system locations as well as User hives.
# Not all apps record uninstall info in these locations so may not work for all apps.

# version 1.0
# changes: update Var names, improve blank bypass for listing installed apps.

# $RegexAppName = 'Wave Browser'
# $RegexPublisher = 'Piriform'
# $MaxNumberApps
$SilentUninstallFlag = '/SILENT'
$exit = 0
$log = "$env:TEMP\installedApps.csv"

function Get-InstalledApps {
    param (
        [string]$AppName,
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
        if ((Test-Path -Path $UPath) -and -not $InstLocation.ContainsKey($UPath)){
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
            ($a.DisplayName -match $AppName),
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
if ($RegexAppName -notmatch '^\s*$'){
    $splat.Add('AppName',$RegexAppName)
}
if ($RegexPublisher -notmatch '^\s*$'){
    $splat.Add('Publisher',$RegexPublisher)
}
if ($or -eq 'True'){
    $splat.Add('or',$true)
}

$ht = @{}
[array]$Applist = Get-InstalledApps @splat | Sort-Object -Property DisplayName
$Applist | Where-Object {$_.DisplayName -notmatch '^[\.\s\*\+]*$' -and -not $ht.ContainsKey($_.DisplayName) } |
    ForEach-Object {$ht.Add($_.DisplayName,$_.Publisher), $_} |
    Select-Object -Property InstallDate, DisplayName, Publisher, DisplayVersion, UninstallString, QuietUninstallString -OutVariable report |
    Export-Csv -NoTypeInformation -Path $log
$report | Format-Table -AutoSize

$totalApps = $Applist.count
Write-Host "INFO: `$Applist.count is $totalApps"

try {
    [int]$MaxNumberApps = [int]$MaxNumberApps
    if ($MaxNumberApps -lt 1){$MaxNumberApps = 5}
}
catch {
    $MaxNumberApps = 5
}

if (($RegexAppName + $RegexPublisher) -notmatch '^[\.\s\*\+]*$' -and $Applist.count -le $MaxNumberApps){
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
    Start-Sleep -Seconds 10 -Verbose
    Get-InstalledApps @splat | Sort-Object -Property DisplayName |
        Where-Object {$_.DisplayName -notmatch '^[\.\s\*\+]*$'} |
        Select-Object -Property InstallDate, DisplayName, Publisher, DisplayVersion, UninstallString, QuietUninstallString |
        Format-Table -AutoSize
} elseif (($RegexAppName + $RegexPublisher) -notmatch '^[\.\s\*\+]*$' -and $Applist.count -gt 5){
    Write-Warning "Search terms to broad to auto uninstall"
    $exit = 3
}

if ($report.count -ge 83){
    Write-Host "Log Path: $log"
    if ($env:SyncroModule){
        Import-Module -Name $env:SyncroModule -WarningAction silentlycontinue
        Upload-File -FilePath $log
    }
}

Remove-Item -Path $log

exit $exit
