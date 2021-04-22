Get-ChildItem -Path C:\ProgramData\Syncro\bin -Filter setupdownloader*.exe | Remove-Item -Force -Verbose
Get-ChildItem -Path C:\Windows\Temp\ -Directory -Filter RarSFX* | Remove-Item -Recurse -Force -Verbose
