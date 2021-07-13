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
