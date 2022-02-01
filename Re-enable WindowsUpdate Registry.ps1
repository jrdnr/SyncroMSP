Get-Item HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate |
    Select-Object -ExpandProperty Property |
    Where-Object {$_ -ne 'ElevateNonAdmins'} |
    ForEach-Object {
        Remove-ItemProperty -Path HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate -Name $_ -ErrorAction Continue
    }

Get-Item HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate -OutVariable p
if ($p.Property -contains 'DisableWindowsUpdateAccess'){
    exit 2
}
