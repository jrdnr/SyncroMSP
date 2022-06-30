<#
.SYNOPSIS
    Simple script to set PowerPlan

.DESCRIPTION
    This Script uses pre-defined Microsoft Guids (https://docs.microsoft.com/en-us/windows/win32/power/power-policy-settings)
    to set the power plan to High performance, Balanced, or Power saver

.PARAMETER PowerPlan
    Parameter PowerPlan should be set up as a Syncro Runtime Variable
    Variable Name: PowerPlan
    Variable Type: dropdown
    Values: High performance, Balanced, Power saver


.EXAMPLE
    Set-PowerPlan -PowerPlan Balanced
#>
function Set-PowerPlan ($PowerPlan) {
    switch ($PowerPlan) {
        "Balanced"     {$PwrGuid = '381b4222-f694-41f0-9685-ff5bb260df2e'}
        "Power saver"  {$PwrGuid = 'a1841308-3541-4fab-bc81-f71556f20b4a'}
        default {
            # High performance
            $PwrGuid = '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c'
        }
    }
    try {
        $crntPlan = $(powercfg -getactivescheme).split()[3]

        if ($crntPlan -ne $PwrGuid) {
            powercfg -setactive $PwrGuid
        }
    } catch {
        Write-Warning -Message "Unabled to set power plan to $PowerPlan"
    }

    Get-CimInstance -Name root\cimv2\power -Class win32_PowerPlan -Filter "IsActive = 'True'" |
        Select-Object -Property ElementName, Description
}

function New-PowerPlan {
    [CmdletBinding()]
    param (
        [string]$SourcePowerPlan,
        [string]$PowerPlanName,
        [int]$LidCloseAction,
        [int]$MonitorTimeoutAC = 30,
        [int]$MonitorTimeoutDC = 30,
        [int]$StandbyTimeoutAC = 0,
        [int]$StandbyTimeoutDC = 0,
        [int]$HybernateTimeoutAC = 0,
        [int]$HybernateTimeoutDC = 0,
        [Switch]$EnableFastboot
    )

    begin {
        # Create custom power plan: https://www.tenforums.com/tutorials/43655-create-custom-power-plan-windows-10-a.html
        # Change lid close action: https://www.tenforums.com/tutorials/69762-how-change-default-lid-close-action-windows-10-a.html
        switch ($SourcePowerPlan) {
            "Balanced"     {$PwrGuid = '381b4222-f694-41f0-9685-ff5bb260df2e'}
            "Power saver"  {$PwrGuid = 'a1841308-3541-4fab-bc81-f71556f20b4a'}
            default {
                # High performance
                $PwrGuid = '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c'
            }
        }
        $regex = '[{]?[0-9a-fA-F]{8}-(?:[0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}[}]?'
    }

    process {
        $NewGuid = New-Guid
        POWERCFG -DUPLICATESCHEME $PwrGuid $NewGuid
        POWERCFG -CHANGENAME $NewGuid $PowerPlanName
        POWERCFG -SETACTIVE $NewGuid
        POWERCFG -Change -monitor-timeout-ac 30
        POWERCFG -CHANGE -monitor-timeout-dc 30
        POWERCFG -CHANGE -disk-timeout-ac 0
        POWERCFG -CHANGE -disk-timeout-dc 0
        POWERCFG -CHANGE -standby-timeout-ac 0
        POWERCFG -CHANGE -standby-timeout-dc 0
        POWERCFG -CHANGE -hibernate-timeout-ac 0
        POWERCFG -CHANGE -hibernate-timeout-dc 0
    }

    end {

    }
}

Set-PowerPlan -PowerPlan $PowerPlan
