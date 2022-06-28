function New-DummyFile {
    param(
        [int]$FileCount = 1,
        [int64]$FileBytes,
        [string]$Folder = 'C:\',
        $name = 'DummyFile',
        $extension = 'txt'
    )

    # Check for input
    if (Test-Path $folder){
        if ($extension -contains '.') {
            $extension = $extension.Substring(($extension.LastIndexOf(".") + 1), ($extension.Length - 1))
        }

        foreach($i in (1..$FileCount)) {
            $path = $folder + '\' + $name + '_' + $i + '.' + $extension
            $f = new-object System.IO.FileStream $path, Create, ReadWrite
            $f.SetLength($FileBytes)
            $f.Close()

            Start-Sleep -Seconds 0.5
        }

    } else {
        Write-Warning "The folder $folder doesn't exist"
        Exit
    }
}
