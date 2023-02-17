function Import-SyncroModule {
    param (
        #Defaults to the UUID of local system but you can provide the UUID of Any other Syncro Asset instead.
        $UUID
    )

    # Ensure TLS -ge 1.2
    if ([Net.ServicePointManager]::SecurityProtocol -lt [Net.SecurityProtocolType]::Tls12){
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    }

    # Set up $env: vars for Syncro Module
    if($env:SyncroModule -match '^\s*$'){
        $SyncroRegKey = Get-ItemProperty -Path 'HKLM:\SOFTWARE\WOW6432Node\RepairTech\Syncro' -Name uuid, shop_subdomain
        $env:RepairTechFilePusherPath  = 'C:\ProgramData\Syncro\bin\FilePusher.exe'
        $env:RepairTechKabutoApiUrl    = 'https://rmm.syncromsp.com'
        $env:RepairTechSyncroApiUrl    = 'https://{subdomain}.syncroapi.com'
        $env:RepairTechSyncroSubDomain = $SyncroRegKey.shop_subdomain
        $env:RepairTechUUID            = if($UUID -match '^\s*$'){ $SyncroRegKey.uuid } else {$UUID}
        $env:SyncroModule              = "$env:ProgramData\Syncro\bin\module.psm1"
    }
    if ((Test-Path -Path $env:SyncroModule) -and ($PSVersionTable.PSVersion -ge [system.version]'4.0')) {
        Import-Module -Name $env:SyncroModule -WarningAction SilentlyContinue
    } elseif ($PSVersionTable.PSVersion.Major -lt 4) {
        Write-Warning "$($PSVersionTable.PSVersion) is not compatible with SyncroModule"
        [Environment]::SetEnvironmentVariable('SyncroModule',$null)
        $false
    }
}

<# non Function version
# Ensure TLS -ge 1.2
if ([Net.ServicePointManager]::SecurityProtocol -lt [Net.SecurityProtocolType]::Tls12){
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
}
# Set up $env: vars for Syncro Module
if($env:SyncroModule -match '^\s*$'){
    $SyncroRegKey = Get-ItemProperty -Path 'HKLM:\SOFTWARE\WOW6432Node\RepairTech\Syncro' -Name uuid, shop_subdomain
    $env:RepairTechFilePusherPath   = 'C:\ProgramData\Syncro\bin\FilePusher.exe'
    $env:RepairTechKabutoApiUrl     = 'https://rmm.syncromsp.com'
    $env:RepairTechSyncroApiUrl     = 'https://{subdomain}.syncroapi.com'
    $env:RepairTechSyncroSubDomain  = $SyncroRegKey.shop_subdomain
    $env:RepairTechUUID             = $SyncroRegKey.uuid
    $env:SyncroModule               = "$env:ProgramData\Syncro\bin\module.psm1"
}
if ((Test-Path -Path $env:SyncroModule) -and ($PSVersionTable.PSVersion -ge [system.version]'4.0')) {
    Import-Module -Name $env:SyncroModule -WarningAction SilentlyContinue
} elseif ($PSVersionTable.PSVersion.Major -lt 4) {
    Write-Warning "$($PSVersionTable.PSVersion) is not compatible with SyncroModule"
    [Environment]::SetEnvironmentVariable('SyncroModule',$null)
    $false
}
#>
