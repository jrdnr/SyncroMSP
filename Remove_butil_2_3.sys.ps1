$path = "C:\Users"

$child_path = "AppData\Local\Temp"

$files_filter = "dbutil_2_3.sys"

$paths = @("C:\Windows\Temp")
[array]$paths += Get-ChildItem $path -Directory -Exclude Default*,Public | ForEach-Object {
    Join-Path -Path $_.FullName -ChildPath $child_path
}

foreach ($p in $paths) {
    If (test-path "$p\$files_filter") {
        Remove-Item "$joined_path\$files_filter" -Force -Verbose
    } else {
        "NO File `"$p\$files_filter`""
    }
}
