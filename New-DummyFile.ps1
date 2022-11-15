function New-DummyFile {
    param(
        [int]$FileCount = 1,
        [int64]$FileBytes,
        [string]$Folder = $PWD,
        $name = 'DummyFile',
        $extension = 'txt'
    )

    # Check for input
    if (Test-Path $folder){
        #Set-Location -Path $Folder -ErrorAction Continue
        if ($extension -contains '.') {
            $extension = $extension.Substring(($extension.LastIndexOf(".") + 1), ($extension.Length - 1))
        }

        foreach($i in (1..$FileCount)) {
            do {
                $path = $folder + '\' + $name + $r + '_' + $i + '.' + $extension
                $r++
            } while (Test-Path -Path $path)

            try {
                $f = new-object System.IO.FileStream $path, Create, ReadWrite
                $f.SetLength($FileBytes)
                $f.Close()
            }
            catch {
                Get-PSDrive -Name ($Folder.split(':')[0])
                return "$i files created"
            }

            Start-Sleep -Seconds 0.5
        }

    } else {
        Write-Warning "The folder $folder doesn't exist"
    }
}
