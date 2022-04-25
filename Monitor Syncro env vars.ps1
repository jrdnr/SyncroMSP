$UUID = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\WOW6432Node\RepairTech\Syncro' -Name uuid -ErrorAction Stop).uuid
$ExpectedVars = [Ordered]@{
    RepairTechFilePusherPath   = 'C:\ProgramData\Syncro\bin\FilePusher.exe'
    RepairTechKabutoApiUrl     = 'https://rmm.syncromsp.com'
    RepairTechSyncroApiUrl     = 'https://{subdomain}.syncroapi.com'
    RepairTechSyncroSubDomain  = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\WOW6432Node\RepairTech\Syncro' -Name shop_subdomain).shop_subdomain
    RepairTechUUID             = $UUID
    SyncroModule               = "$env:ProgramData\Syncro\bin\module.psm1"
}

'Local $env: vars'
Get-ChildItem -Path env:\ | ? name -match 'RepairTech|Syncro' -OutVariable vars
''

if (($vars.name -join ',') -ne ($ExpectedVars.Keys -join ',')){
    $vars.name -join ','
    $ExpectedVars.Keys -join ','
    ''
    $Alert = $true
}

foreach ($v in $vars){
    if ($v.Value -ne $ExpectedVars[$v.name]){
        "Syncro: $($v.Value)"
        "Expect: $($ExpectedVars[$v.name])"
        ''
        $Alert = $true
    }
}

if ($Alert){
    Import-Module -Name $env:SyncroModule -WarningAction SilentlyContinue
    Rmm-Alert -Category 'Env:Vars Changed' -Body 'Review and update changed Env Vars'
} else {
    'All Vars match'
}
