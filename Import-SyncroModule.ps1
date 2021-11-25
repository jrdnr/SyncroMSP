function Import-SyncroModule {
    param (
        #Defaults to the UUID of local system but you can provide the UUID of your test system.
        $UUID = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\WOW6432Node\RepairTech\Syncro' -Name uuid -ErrorAction Stop).uuid
    )

    # Set up $env: vars for Syncro Module
    $env:SyncroModule               = "$env:ProgramData\Syncro\bin\module.psm1"
    $env:RepairTechApiBaseURL       = 'syncromsp.com'
    $env:RepairTechApiSubDomain     = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\WOW6432Node\RepairTech\Syncro' -Name shop_subdomain).shop_subdomain
    $env:RepairTechFilePusherPath   = 'C:\ProgramData\Syncro\bin\FilePusher.exe'
    $env:RepairTechUUID             = $UUID

    Import-Module -Name $env:SyncroModule -WarningAction SilentlyContinue
}
