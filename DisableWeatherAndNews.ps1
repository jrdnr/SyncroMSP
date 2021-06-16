$path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds"
$name = "EnableFeeds"
$value = "0"
#Disables Windows Weather and News
write-host "Disabling Weather and News"
New-Item -Path $path -Force
New-ItemProperty -Path $path -Name $name -Value $value -PropertyType DWORD -Force | Out-Null
