# Upgrade Windows 10 with Enablement Package
Import-Module $env:SyncroModule -DisableNameChecking

# Target release version registry settings portion needs testing to confirm functionality

# Todo:
# - Add support for upgrading Windows 11 with UA
# - Add support for older packages/specific builds
# Windows 10 21H2 x64 http://b1.download.windowsupdate.com/c/upgr/2021/08/windows10.0-kb5003791-x64_b401cba483b03e20b2331064dd51329af5c72708.cab
# Windows 10 21H2 x86 http://b1.download.windowsupdate.com/c/upgr/2021/08/windows10.0-kb5003791-x86_1bf1a29db06015e9deaefba26cf1f300e8ac18b8.cab
# Windows 10 21H2 arm64 http://b1.download.windowsupdate.com/c/upgr/2021/08/windows10.0-kb5003791-arm64_05c00a882a8cb93b8dc1b94ef8133f909f3cd937.cab

# These will need updating with each new enablement package
$Win10CabURL = "https://catalog.s.download.windowsupdate.com/c/upgr/2022/07/windows10.0-kb5015684-x64_d2721bd1ef215f013063c416233e2343b93ab8c1.cab"
$Win10TargetVersion = "22H2"

# Other variables
$Reboot = $true # If changing this to false you will also want to disable AttemptUpgradeAssistant
# Attempt Upgrade Assistant method if enablement fails/not possible
$AttemptUpgradeAssistant = $true # True can cause a reboot regardless of reboot setting above as UA always restarts
# Ignore Windows Update Target Release Version registry settings
$IgnoreTargetReleaseVersion = $false
# Location to download files
$TargetFolder = "$env:Temp"
# Name for Syncro alerts
$SyncroAlertCategory = "Upgrade Windows 10"

# Get version/build info
$MajorVersion = ([System.Environment]::OSVersion.Version).Major
# 19041 and older do not have DisplayVersion key, if so we grab ReleaseID instead (no longer updated in new versions)
if ((Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").DisplayVersion) {
    $DisplayVersion = ((Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").DisplayVersion)
} else {
    $DisplayVersion = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").ReleaseId
}
# Convert versions to numerical form so comparison operators can be used
$DisplayVersionNumerical = ($DisplayVersion).replace('H1', '05').replace('H2', '10')
$Win10TargetVersionNumerical = ($Win10TargetVersion).replace('H1', '05').replace('H2', '10')
# Compile build number, it's also useful to have separate as UBR can be 3 or 4 digits which confuses comparison operators in combined form
$Build = ([System.Environment]::OSVersion.Version).Build
$UBR = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name UBR).UBR
$BuildUBR = $Build + ".$UBR"
# Correct Microsoft's version number for Windows 11
if ($Build -ge 22000) { $MajorVersion = '11' }
Write-Host "Windows $MajorVersion $DisplayVersion build $BuildUBR detected."

# Exit if not eligible
if ($MajorVersion -lt '10') {
    Write-Host "Windows versions prior to 10 cannot be updated with this script."
    exit 0
}
if ($Build -ge '22000') {
    Write-Host "Windows 11 cannot be updated with this script."
    exit 0
}
if ($DisplayVersionNumerical -ge $Win10TargetVersionNumerical) {
    Write-Host "Already running $DisplayVersion which is the same or newer than target release $Win10TargetVersion, no update required."
    Close-Rmm-Alert -Category $SyncroAlertCategory
    exit 0
}
if ($AttemptUpgradeAssistant -eq $false -and $MajorVersion -eq '10' -and $Build -le '19041' -and $UBR -lt '1247') {
    $notification = "Windows 10 builds older than 19041.1247 (September 14, 2021 patch for 2004/20H1) cannot be upgraded with enablement package and Upgrade Assistant method is disabled."
    Write-Host $notification
    Rmm-Alert -Category $SyncroAlertCategory -Body $notification
    exit 1
}
if ($IgnoreTargetReleaseVersion -eq $false -and (Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate") -eq $true) {
    $WindowsUpdateKey = Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" -ErrorAction SilentlyContinue
    if ($WindowsUpdateKey.TargetReleaseVersion -eq 1 -and $WindowsUpdateKey.TargetReleaseVersionInfo) {
        $WindowsUpdateTargetReleaseNumerical = ($WindowsUpdateKey.TargetReleaseVersionInfo).replace('H1', '05').replace('H2', '10')
        if ($WindowsUpdateTargetReleaseNumerical -lt $win10TargetVersionNumerical) {
            $notification = "Windows Update TargetReleaseVersion registry settings are in place limiting upgrade to $($WindowsUpdateKey.TargetReleaseVersionInfo). To ignore these settings, change the script variable or target version and run again."
            Rmm-Alert -Category $SyncroAlertCategory -Body $notification
            exit 1
        }
    }
}

function Invoke-UpgradeAssistant {
    $URL = 'https://go.microsoft.com/fwlink/?LinkID=799445'
    $Arg = "/QuietInstall /SetPriorityLow /SkipEULA /ShowOOBE none"
    $DiskSpaceRequired = '11' # in GBs
    $DiskSpace = [Math]::Round((Get-CimInstance -Class Win32_Volume | Where-Object { $_.DriveLetter -eq $env:SystemDrive } | Select-Object -ExpandProperty FreeSpace) / 1GB)
    if ($DiskSpace -lt $DiskSpaceRequired) {
        $notification = "Only $DiskSpace GB free, $DiskSpaceRequired GB required."
        Rmm-Alert -Category $SyncroAlertCategory -Body $notification
        exit 1
    }
    # Retrieve headers to make sure we have the final destination redirected file URL
    $DLURL = (Invoke-WebRequest -UseBasicParsing -Uri $URL -MaximumRedirection 0 -ErrorAction Ignore).headers.location
    $DLFileName = [io.path]::GetFileName("$DLURL")
    Invoke-WebRequest -Uri "$dlurl" -OutFile "$TargetFolder\$DLFileName"
    Start-Process "$TargetFolder\$DLFileName" -ArgumentList "$Arg"
    Start-Sleep -s 120
    Remove-Item "$TargetFolder\$DLFileName" -Force
    Close-Rmm-Alert -Category $SyncroAlertCategory
}

# Attempt upgrade
if ($MajorVersion -eq '10' -and $Build -ge '19041' -and $UBR -ge '1247' -and $Build -lt '22000') {
    Write-Host "Attempting enablement upgrade."
    # Download the cab file for install
    $TargetFile = "$TargetFolder\$(([uri]$Win10CabURL).Segments[-1])"
    Invoke-WebRequest -Uri $Win10CabURL -OutFile $TargetFile
    # Add the Enablement Package to the image
    try {
        dism /Online /Add-Package /PackagePath:$TargetFile /Quiet /NoRestart
        Remove-Item $TargetFile
    } catch {
        if ($AttemptUpgradeAssistant) {
            Write-Host "Enablement failed, attempting Upgrade Assistant method instead."
            Invoke-UpgradeAssistant
        } else {
            Rmm-Alert -Category $SyncroAlertCategory -Body $_
            exit 1
        }
    } finally {
        if (-not $Error) {
            Write-Host "Package added successfully."
            Close-Rmm-Alert -Category $SyncroAlertCategory
        }
    }
    # Reboot if desired
    if ($Reboot -and -not $Error) {
        "Reboot variable enabled, initiating reboot."
        # If Automatic Restart Sign-On is enabled, /g allows the device to automatically sign in and lock
        # based on the last interactive user. After sign in, it restarts any registered applications.
        shutdown /g /f
    }
} elseif ($AttemptUpgradeAssistant -eq $true -and $MajorVersion -eq '10' -and $Build -le '19041' -and $UBR -lt '1247') {
    Write-Host "Build is not compatible with enablement upgrade, attempting Upgrade Assistant method instead."
    Invoke-UpgradeAssistant
} else {
    $notification = "System detection logic failed, check script for issues."
    Rmm-Alert -Category $SyncroAlertCategory -Body $notification
    exit 1
}
