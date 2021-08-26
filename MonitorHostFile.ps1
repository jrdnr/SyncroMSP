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
