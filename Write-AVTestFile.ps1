# Writes an EICAR string to faile specified by $OutPath

#$Base64 = [Convert]::ToBase64String([char[]]$String)
#$bytes  = [Convert]::FromBase64String($Base64)
#$String = [System.Text.Encoding]::UTF8.GetString($bytes)

$OutPath = 'C:\ProgramData\eicar.com'

# EICAR string represented as a byte array to avoid av detection w/in this script.
$bytes = [Byte[]]@(
    88, 53, 79, 33, 80, 37, 64, 65, 80, 91, 52, 92, 80, 90, 88, 53, 52, 40, 80, 94, 41, 55, 67, 67, 41, 55, 125,
    36, 69, 73, 67, 65, 82, 45, 83, 84, 65, 78, 68, 65, 82, 68, 45, 65, 78, 84, 73, 86, 73, 82, 85, 83, 45, 84,
    69, 83, 84, 45, 70, 73, 76, 69, 33, 36, 72, 43, 72, 42
)

Out-File -FilePath $OutPath -InputObject [System.Text.Encoding]::UTF8.GetString($bytes)

& $OutPath | Out-Null
