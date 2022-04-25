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

$hosts = Get-Content -Path "$env:SystemRoot\System32\drivers\etc\hosts" | Where-Object {$_ -notlike '#*' -and ![string]::IsNullOrWhiteSpace($_)} | Out-String
$diff = try {
    Compare-Object -ReferenceObject $HostsFile -DifferenceObject $hosts -ErrorAction SilentlyContinue
}
catch {
    $null
}

"Current Hosts Values"
$hosts

if ([string]::IsNullOrWhiteSpace($HostsFile) -and ![string]::IsNullOrWhiteSpace($hosts)){
    Set-Asset-Field -Name HostsFile -Value $hosts
} elseif ($null -ne $diff) {
    $diff
    Rmm-Alert -Category 'Hosts File Diff' -Body $hosts
    Set-Asset-Field -Name HostsFile -Value $hosts
}
