Import-Module $env:SyncroModule -WarningAction SilentlyContinue
#Requires -Version 3.0
#Requires -RunAsAdministrator
# Note: The threshold values used below are mostly guesses as to what might be concerning and sometimes
#       manufacturers even use the same attribute number for different purposes, so don't take any
#       one value as critical and feel free to adjust as you feel appropreiate, or even remove attributes
#       from monitoring entirely. It's also possible some should be monitoring Worst vs RawValue.
#
#   Author: Nullzilla on Pastebin
#   Edit: Jrdn

# If this is a virtual machine, we don't need to continue
$Computer = Get-CimInstance -ClassName 'Win32_ComputerSystem'
if ($Computer.Model -like 'Virtual*') {
    exit
}

$disks = (Get-CimInstance -Namespace 'Root\WMI' -ClassName 'MSStorageDriver_FailurePredictStatus' |
    Select-Object 'InstanceName')

$Warnings = @()

function Select-ErrorData {
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline)]
        [array]$Item
    )

    begin {}

    process {
        foreach($i in $Item){
            $test = switch ($i.ID) {
                # Reallocated Sectors Count
                5 { $i.RawValue -gt 1 }

                # Spin Retry Count
                10 { $i.RawValue -ne 0 }

                # Recalibration Retries
                11 { $i.RawValue -ne 0 }

                # Spare Blocks Available
                16 { $i.RawValue -lt 100 }

                # Remaining Spare Blocks
                17 { $i.RawValue -lt 100 }

                # Used Reserved Block Count Total
                179 { $i.RawValue -gt 1 }

                # Unused Reserved Block Count (Available Spare Blocks on PCIe SSDs) (Crucial Brand)
                180 { $i.RawValue -lt 100 }

                # Erase Failure Count
                182 { $i.RawValue -ne 0 }

                # SATA Downshift Error Count or Runtime Bad Block
                183 { $i.RawValue -ne 0 }

                # End-to-End error / IOEDC
                184 { $i.RawValue -ne 0 }

                # Reported Uncorrectable Errors
                187 { $i.RawValue -ne 0 }

                # Command Timeout
                188 { $i.RawValue -gt 2 }

                # High Fly Writes
                189 { $i.RawValue -ne 0 }

                # Temperature Celcius
                194 { $i.RawValue -gt 50 }

                # Reallocation Event Count
                196 { $i.RawValue -ne 0 }

                # Current Pending Sector Count
                197 { $i.RawValue -ne 0 }

                # Uncorrectable Sector Count
                198 { $i.RawValue -ne 0 }

                # UltraDMA CRC Error Count
                199 { $i.RawValue -ne 0 }

                # Soft Read Error Rate
                201 { $i.Worst -lt 95 }

                # RAIN Successful Recovery Page Count (Crucial Brand)
                210 { $i.Worst -lt 95 }

                # SSD Life Left
                231 { $i.Worst -lt 30 }

                # SSD Media Wear Out Indicator
                233 { $i.Worst -lt 30 }

                default {$false}
            }
            if ($test) {
                $i
            }
        }
    }

    end {}
}

foreach ($disk in $disks.InstanceName) {
    # Retrieve SMART data
    $SmartData = (Get-CimInstance -Namespace 'Root\WMI' -ClassName 'MSStorageDriver_ATAPISMartData' |
    Where-Object 'InstanceName' -eq $disk)

    [Byte[]]$RawSmartData = $SmartData | Select-Object -ExpandProperty 'VendorSpecific'

    # Starting at the third number (first two are irrelevant)
    # get the relevant data by iterating over every 12th number
    # and saving the values from an offset of the SMART attribute ID
    [PSCustomObject[]]$Output = for ($i = 2; $i -lt $RawSmartData.Count; $i++) {
        if (0 -eq ($i - 2) % 12 -and $RawSmartData[$i] -ne 0) {
            # Construct the raw attribute value by combining the two bytes that make it up
            [Decimal]$RawValue = ($RawSmartData[$i + 6] * [Math]::Pow(2, 8) + $RawSmartData[$i + 5])

            $InnerOutput = [PSCustomObject]@{
                DiskID   = $disk
                ID       = [int]$RawSmartData[$i]
                #Flags    = $RawSmartData[$i + 1]
                #Value    = $RawSmartData[$i + 3]
                Worst    = $RawSmartData[$i + 4]
                RawValue = $RawValue
            }

            $InnerOutput
        }
    }
    $output| Sort-Object ID | Out-String

    $Warnings += $Output | Select-ErrorData | Format-Table
}

$Warnings += Get-CimInstance -Namespace 'Root\WMI' -ClassName 'MSStorageDriver_FailurePredictStatus' |
    Select-Object InstanceName, PredictFailure, Reason |
    Where-Object {$_.PredictFailure -ne $False} | Format-Table

$Warnings += Get-CimInstance -ClassName 'Win32_DiskDrive' |
    Select-Object Model, SerialNumber, Name, Size, Status |
    Where-Object {$_.status -ne 'OK'} | Format-Table

$Warnings += Get-PhysicalDisk |
    Select-Object FriendlyName, Size, MediaType, OperationalStatus, HealthStatus |
    Where-Object {$_.OperationalStatus -ne 'OK' -or $_.HealthStatus -ne 'Healthy'} | Format-Table

if ($Warnings) {
    $Warnings = $warnings | Out-String
    $Warnings
    Rmm-Alert -Category 'Monitor - Drive SMART Values' -Body "$Warnings"
    Exit 1
}

if ($Error) {
    if ($Error -match "Not supported") {
        $notsup = "You may need to switch from AHCI to RAID/RST mode, see the link for how to do this non-destructively: https://www.top-password.com/blog/switch-from-raid-to-ahci-without-reinstalling-windows/"
        $notsup
    }
    Rmm-Alert -Category 'Monitor - Drive SMART Values' -Body "$Error $notsup"
    exit 1
}

Close-Rmm-Alert -Category "Monitor - Drive SMART Values"
