<#- Start of Script -#>
# Expected Runtime Var PolicyName: set to the Value of the policy running the script
# Expected Asset Custom Field: AppliedPolicies

#region set Vars
$workfolder = 'C:\ProgramData\MSPName'
$cliX = 'policies.clixml'
$date = Get-Date -Format 'yyyy.MM.dd'

$FullName = Join-Path -Path $workfolder -ChildPath $cliX
#endregion set Vars

'============ Syncro Inserted Code ============'
# Log all code Syncro incserts before the start of the script
foreach ($line in (Get-Content -Path  $MyInvocation.MyCommand.Path -ErrorAction Stop)){
    if ($line -eq '<#- Start of Script -#>') {break}
    $line
}
'============== END Syncro Code ==============='
''
#Ensure path exists for local log
$path,$folders = ($workfolder.Split('\'))
foreach ($f in $folders){
    $p1 = Join-Path -Path $path -ChildPath $f
    if (-not (Test-Path -Path $p1)){
        New-Item -Path $path -Name $f -ItemType Directory
    }
    $path = $p1
}

try {
    $Policies = Import-Clixml -Path $FullName -ErrorAction Stop
}
catch [System.IO.FileNotFoundException] {
    $Policies = @{}
}

if ($Policies.ContainsKey($date)){
    $Policies.$date = (($Policies.$date -split ',') + $PolicyName | Select-Object -Unique) -join ','
} else {
    $Policies.Add($date,$PolicyName)
}

$Now = Get-Date
$Keys = $Policies.Keys | Where-Object {[datetime]$_ -lt $Now.AddDays(-7)}
foreach ($k in $Keys){
    $Policies.Remove($k)
}
Export-Clixml -Path $FullName -InputObject $Policies

If ($null -ne $env:SyncroModule -and $Policies[$date] -notmatch '^\s*$') {
    Import-Module $env:SyncroModule -WarningAction SilentlyContinue
    Set-Asset-Field -Name 'AppliedPolicies' -Value $Policies[$date]
}
