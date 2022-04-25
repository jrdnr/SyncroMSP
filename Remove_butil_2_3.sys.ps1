$path = "C:\Users"

$child_path = "AppData\Local\Temp"

$files_filter = "dbutil_*_*.sys"

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

$paths = @("C:\Windows\Temp")
[array]$paths += Get-ChildItem $path -Directory -Exclude Default*,Public | ForEach-Object {
    Join-Path -Path $_.FullName -ChildPath $child_path
}

"Paths to scan for dangerous files"
$paths

Get-ChildItem -Path $paths -Filter $files_filter -OutVariable f | ForEach-Object {
    $filePath = $_.FullName
    "Cleaning $filePath"
    try {
        Remove-Item $filePath -Force -Verbose -ErrorAction Stop
        "Removed $filePath"
        Log-Activity -Message "Removed $filePath" -EventName 'PowershellScript' -ErrorAction SilentlyContinue
    }
    catch {
        "Could not remove $filePath. Remove Manually"
        Rmm-Alert -Category Script_Error -Body "Could not remove $filePath. Remove Manually"
        exit 1
    }
}

if ($null -eq $f -or $f.count -eq 0){"Scan Successful: $files_filter, was not found on this system"}
