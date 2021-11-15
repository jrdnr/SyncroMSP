<#
    .SYNOPSIS
    When using chocolatey Syncro's internal Chocolatey seems broken and to have messed up the paths for strate
    installes of chocolatey as well

    .DESCRIPTION
    Checks for the presents of 'C:\Program Files\RepairTech\Syncro\kabuto_app_manager\choco.exe' and if its missing
    copies the correct executable to that path
#>
$ChocoPath  = 'C:\Program Files\RepairTech\Syncro\kabuto_app_manager\choco.exe'
$KpmPath    = 'C:\Program Files\RepairTech\Syncro\kabuto_app_manager\kabuto_patch_manager.exe'
if(!(Test-Path -Path $ChocoPath) -and (Test-Path -Path $KpmPath)){
    Copy-Item -Path $KpmPath -Destination $ChocoPath -Force -Verbose
}
