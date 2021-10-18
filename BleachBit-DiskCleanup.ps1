if ($env:SyncroModule){
    Import-Module $env:SyncroModule -WarningAction SilentlyContinue
} else {
    # Set up $env: Variables and import the syncro module
    try {
        $syncroReg = Get-ItemProperty -Path 'HKLM:\SOFTWARE\WOW6432Node\RepairTech\Syncro' -Name shop_subdomain,uuid -ErrorAction Stop
        $env:RepairTechApiBaseURL       = 'syncromsp.com'
        $env:RepairTechApiSubDomain     = $syncroReg.shop_subdomain
        $env:RepairTechFilePusherPath   = 'C:\ProgramData\Syncro\bin\FilePusher.exe'
        $env:RepairTechUUID             = $syncroReg.uuid
        $env:SyncroModule               = "$env:ProgramData\Syncro\bin\module.psm1"
        Import-Module $env:SyncroModule -WarningAction SilentlyContinue
    }
    catch {
        'Could not find Syncro Module info'
    }
}

$workingdir = $env:TEMP
If(!(test-path $workingdir))
{
New-Item -ItemType Directory -Force -Path $workingdir
}
# Get disk space available BEFORE the Cleanup
$Before = Get-WmiObject Win32_LogicalDisk | Where-Object { $_.DriveType -eq "3" } | Select-Object SystemName,
@{ Name = "Drive" ; Expression = { ( $_.DeviceID ) } },
@{ Name = "Size (GB)" ; Expression = {"{0:N1}" -f( $_.Size / 1gb)}},
@{ Name = "FreeSpace (GB)" ; Expression = {"{0:N1}" -f( $_.Freespace / 1gb ) } },
@{ Name = "PercentFree" ; Expression = {"{0:P1}" -f( $_.FreeSpace / $_.Size ) } } |
Format-Table -AutoSize | Out-String
# Perform Cleanup Tasks
Expand-Archive $workingdir\bleachbit-portable.zip -DestinationPath $workingdir -Force
$Params = "-c adobe_reader.cache adobe_reader.tmp chromium.cache chromium.history chromium.vacuum firefox.cache firefox.url_history firefox.vacuum flash.cache flash.cookies google_chrome.cache google_chrome.history google_chrome.vacuum internet_explorer.cache internet_explorer.downloads java.cache opera.cache opera.history opera.vacuum silverlight.temp silverlight.cookies system.recycle_bin system.tmp system.memory_dump system.logs windows_explorer.mru winrar.history winrar.temp"
$ParsedParams = $Params.Split(" ")
& $workingdir\Bleachbit-Portable\bleachbit_console.exe $ParsedParams
# Get disk space available After the Cleanup
$After = Get-WmiObject Win32_LogicalDisk | Where-Object { $_.DriveType -eq "3" } | Select-Object SystemName,
@{ Name = "Drive" ; Expression = { ( $_.DeviceID ) } },
@{ Name = "Size (GB)" ; Expression = {"{0:N1}" -f( $_.Size / 1gb)}},
@{ Name = "FreeSpace (GB)" ; Expression = {"{0:N1}" -f( $_.Freespace / 1gb ) } },
@{ Name = "PercentFree" ; Expression = {"{0:P1}" -f( $_.FreeSpace / $_.Size ) } } |
Format-Table -AutoSize | Out-String
$LogDate = get-date -format "MM-d-yy-HH"
#Start-Transcript -Path $workingdir\$LogDate.log
#write-output "Space Before"
#write-output $Before
#write-output "space After"
#write-output $After
#stop-transcript
$Disk += "$($LogDate)`rBefore$($Before)After$($After)"
Set-Asset-Field -Name "Weekly Temp Files" -Value $Disk | Out-Null
