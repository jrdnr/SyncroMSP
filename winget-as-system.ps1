<#
  .SYNOPSIS
  A basic script to demonstrate Winget
  Origional source https://forums.lawrencesystems.com/t/running-winget-from-another-admin-account-than-the-one-actually-logged-in/12816/2

  .DESCRIPTION
  A basic script to demonstrate Winget running as either a logged on user or as the 'System' user.

  Use with PSExec https://docs.microsoft.com/en-gb/sysinternals/downloads/psexec to see it running as the 'System' user

  .INPUTS
  None.

  .OUTPUTS
  When run with '-debug', a debug log file will be created under the current users 'temp' folder, as well as details being output to the console. The log file is useful if running the script as 'system' on a scheduled task etc. as obviously you can not see the console output.

  .EXAMPLE
  PS> .\wingetExample.ps1

  .EXAMPLE
  PS> .\wingetExample.ps1 -debug
#>

[CmdletBinding()]
param()

#Editable Variables
$excludedPackages = @("Microsoft.Office", "Microsoft.dotnet", "7zip.7zip") #Skip these packages as they cause issues when upgrading
$logFile = $env:TEMP + "\Winget_log.txt"

#Variables
$Head = 0
$packageCount = 0
$runningUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name

#Function to write debug information to a log file
function Write-DebugLog($message) {
    if ($DebugPreference -eq 'Continue') {
        add-content -Encoding ASCII $logFile ("$(get-date -f dd-MM-yyyy_hh:mm:ss) $message")
    }
    Write-Debug ("$message")
}

#Wipe previous log file if it exists
if (Test-Path -Path $logFile -PathType Leaf) {
    Remove-Item $logFile
}

Write-DebugLog -message "Running as $runningUser"

#Get a list of packages to upgrade
if ($runningUser -eq "NT Authority\system") {
    $AppPath = Resolve-Path "C:\Program Files\WindowsApps\Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe"
    set-location -path $AppPath
    ((.\AppInstallerCLI.exe upgrade --accept-source-agreements | Format-Table -AutoSize) | Out-String).Split([Environment]::NewLine, [System.StringSplitOptions]::RemoveEmptyEntries) > $null #Run this to accept agreements, doesn't work as one command for 'upgrade'
    $Winget_Upgrade_Search = ((.\AppInstallerCLI.exe upgrade | Format-Table -AutoSize) | Out-String).Split([Environment]::NewLine, [System.StringSplitOptions]::RemoveEmptyEntries)
}
else {
    ((winget upgrade --accept-source-agreements | Format-Table -AutoSize) | Out-String).Split([Environment]::NewLine, [System.StringSplitOptions]::RemoveEmptyEntries) > $null
    $Winget_Upgrade_Search = ((winget upgrade | Format-Table -AutoSize) | Out-String).Split([Environment]::NewLine, [System.StringSplitOptions]::RemoveEmptyEntries)
}

#If we have packages to upgrade convert the list to a PowerShell object so we can work with items more easliy
If ($Winget_Upgrade_Search[$Winget_Upgrade_Search.Count - 1] -like "*upgrades available*") {

    #Get the header details
    $Winget_Upgrade_Search | ForEach-Object {

        If ($_ -like "------------------------------*") {
            $Head = ($Winget_Upgrade_Search.IndexOf($_))
        }
    }
    $Winget_Header = $Winget_Upgrade_Search[($Head) - 1] -split "\s{2,}"

    $Winget_Upgrade_App_List = @()
    $Winget_Upgrade_Search[($Head + 1)..($Winget_Upgrade_Search.Count + 1)] | ForEach-Object {

        If ($_ -notlike "*upgrades available*") {

            $results = $_ | Select-String "([^\s]+)" -AllMatches

            $Splits = @('', '', '', '')
            $Splits[3] = $results.Matches[$results.Matches.Length - 2]
            $Splits[2] = $results.Matches[$results.Matches.Length - 3]
            $Splits[1] = $results.Matches[$results.Matches.Length - 4]

            for ($i = 0; $i -lt ($results.Matches.Length - 4); $i++) {
                if ($i -ne ($results.Matches.Length - 5)) {
                    $Splits[0] += $results.Matches[$i].Value + " "
                }
                else {
                    $Splits[0] += $results.Matches[$i].Value
                }
            }

            $Stack = new-object psobject
            $Stack | Add-Member -membertype noteproperty -name "$($Winget_Header[0])" -Value $($Splits[0])
            $Stack | Add-Member -membertype noteproperty -name "$($Winget_Header[1])" -Value $($Splits[1])
            $Stack | Add-Member -membertype noteproperty -name "$($Winget_Header[2])" -Value $($Splits[2])
            $Stack | Add-Member -membertype noteproperty -name "$($Winget_Header[3])" -Value $($Splits[3])
            $Winget_Upgrade_App_List += $Stack
        }
    }
}

foreach ($item in $Winget_Upgrade_App_List) {

    if (!$excludedPackages.Contains($item.Id.Value)) {
        Write-DebugLog -message "Upgrade available for $($item.Name), from $($item.Version.Value), to $($item.Available.Value)"
        $packageCount ++
    }
    else {
        Write-DebugLog -message "Skipping $($item.Name) as it is on an exclusion list"
    }
}

Write-DebugLog -message "$packageCount with upgrades available"
