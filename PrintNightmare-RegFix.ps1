# Set up $env: vars for Syncro Module
if($env:SyncroModule -match '^\s*$'){
    $SyncroRegKey = Get-ItemProperty -Path 'HKLM:\SOFTWARE\WOW6432Node\RepairTech\Syncro' -Name uuid, shop_subdomain
    $env:RepairTechFilePusherPath   = 'C:\ProgramData\Syncro\bin\FilePusher.exe'
    $env:RepairTechKabutoApiUrl     = 'https://rmm.syncromsp.com'
    $env:RepairTechSyncroApiUrl     = 'https://{subdomain}.syncromsp.com'
    $env:RepairTechSyncroSubDomain  = $SyncroRegKey.shop_subdomain
    $env:RepairTechUUID             = $SyncroRegKey.uuid
    $env:SyncroModule               = "$env:ProgramData\Syncro\bin\module.psm1"
}
if (Test-Path -Path $env:SyncroModule) {
    Import-Module -Name $env:SyncroModule -WarningAction SilentlyContinue
}

$path = 'hklm:'
foreach ($folder in 'SOFTWARE\Policies\Microsoft\Windows NT\Printers\PointAndPrint'.split('\')) {
    $path = Join-Path -Path $path -ChildPath $folder
    if(!(Test-Path -Path $path)){
        New-Item -Path $path -ItemType Directory | Out-Null
    }
}

$key = Get-ItemProperty -Path $path
foreach ($prop in @('NoWarningNoElevationOnInstall','UpdatePromptSettings')) {
    if(($key | Get-Member | Where-Object { $_.name -eq $prop }).count -ge 1){
        if($key.$prop -ne 0){
            try {
                Set-ItemProperty -Name $key -Path $path -Value 0 -ErrorAction Stop
                $message = "Set $Prop to 0"
                Log-Activity -Message $message
                $message
            }
            catch {
                $message = "Could not set $Prop -eq $($key.$prop)"
                Log-Activity -Message $message
                Write-Warning $message
            }
        }
    } else {
        try {
            New-ItemProperty -Path $path -Name $prop -Value 0 -ErrorAction Stop
            $message = "Set $Prop to 0"
            Log-Activity -Message $message
            $message
        }
        catch {
            $message = "Could not create new property $Prop -eq $($key.$prop)"
            Log-Activity -Message $message
            Write-Warning $message
        }
    }
}
