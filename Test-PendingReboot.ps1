<#- Start of Script -#>
# Addapted from https://adamtheautomator.com/pending-reboot-registry-windows/
# see origional source for running against multiple computers.
<#
.SYNOPSIS
Tests Pending reboot

.DESCRIPTION
Tests multiple registry keys for anythign that would indicate a pending reboot.
It can clear pending reboots and trigger a reboot or generate a syncro alert.

.PARAMETER AutoReboot
Optional Runtime variable to say if the script should auto reboot.
default behavior without $AutoReboot set is to just trigger an alert

.PARAMETER RebootLocalTime
Optional Runtime variable $RebootTime to set the local time to reboot.
If the string matches \d\d and is less than 60 the reboot will be scheduled for T+minutes.
If the string matches a time that can be parsed by Get-Date and that Date in local time is
in the future a reboot will be scheduled at that time. Otherwise Reboot time will default to 2 min

.OUTPUTS
Default behavior this script will self log to host, and generate a Syncro alert
Alternate behavior, it will log results to activity Log and reboot.

#>
'#============ Syncro Inserted Code ============#'
foreach ($line in (Get-Content -Path  $MyInvocation.MyCommand.Path -ErrorAction SilentlyContinue)) {
    if ($line -eq '<#- Start of Script -#>') { break }
    $line
}
'#============== END Syncro Code ===============#'
''
$RequiredModules = @(
    'BurntToast',
    'RunAsUser',
    'PSSQLite'
)

if ($RebootDelayMin0_30 -notmatch '^\s*$' -and $RebootTime -match '^\s*$') {
    $RebootLocalTime = $RebootDelayMin0_30
}
$RebootTime = switch -regex ($RebootLocalTime) {
    '^[6-9]\d$' { (Get-Date).AddSeconds($_) }
    '^[0-5]?\d$' { (Get-Date).AddMinutes($_) }
    '^\d?\d:\d\d' {
        try {
            $d = Get-Date -Date $_ -ErrorAction Stop
            if ($d -ge (Get-Date)) {
                $d
            } else {
                Get-Date
            }
        } catch { Get-Date }
    }
    Default { Get-Date }
}
switch ($AutoReboot) {
    'True' { $AutoReboot = $true }
    Default { $AutoReboot = $false }
}


#Region Functions
function InstallOrUpdateModule {
    param (
        [string[]]$Name
    )

    begin {
        if ((Get-PSRepository -Name PSGallery).InstallationPolicy -ne 'Trusted') {
            Install-PackageProvider -Name NuGet -Force
            Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted
        }
    }

    process {
        foreach ($n in $Name) {
            if (Get-InstalledModule -Name $n -ErrorAction SilentlyContinue) {
                Update-Module -Name $n
            } else {
                Install-Module -Name $n -Scope AllUsers -Force
            }
        }
        foreach ($m in $Name) {
            $allversions = Get-InstalledModule -Name $m -AllVersions -ErrorAction SilentlyContinue | Sort-Object Version -Descending
            if ($allversions.Count -gt 1) {
                "Uninstalling $m v$($allversions[1])"
                Uninstall-Module $allversions[1..$allversions.Count] -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

Function New-ScheduledTaskFolder {
    Param ($TaskPath)

    $ErrorActionPreference = "stop"
    $scheduleObject = New-Object -ComObject schedule.service
    $scheduleObject.connect()

    $rootFolder = $scheduleObject.GetFolder("\")
    Try { $null = $scheduleObject.GetFolder($TaskPath) }
    Catch { $null = $rootFolder.CreateFolder($TaskPath) }
    Finally { $ErrorActionPreference = "continue" }
}

function Add-ScheduledReboot {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param (
        [datetime]$RebootTime,
        [int]$RebootDelaySeconds = 30,
        [string]$RebootReason = 'Scripted Maintenance Reboot',
        [string]$TaskPath = 'EberlySystems',
        [switch]$OutObject
    )

    begin {
        $WUStatus = Get-WURebootStatus -Silent -ErrorAction SilentlyContinue
        if ($RebootTime -lt (Get-Date).AddSeconds($RebootDelaySeconds + 10)) {
            $RebootTime = (Get-Date).AddSeconds($RebootDelaySeconds + 10)
            $SchTaskTime = (Get-Date).AddSeconds(10)
        } else {
            $SchTaskTime = $RebootTime.AddSeconds(-$RebootDelaySeconds)
        }

        $RebootComment = @'
Windows Will shutdown at {1}
Please Save your work and close all applications
Reason: {0}
'@ -f $RebootReason, $RebootTime.ToShortTimeString()

        $ShutdownArgs = '/r /t {0} /d p:0:0 /c "{1}"' -f $RebootDelaySeconds, $RebootComment

        $POSHScript = @'
Get-WURebootStatus -AutoReboot -ea SilentlyContinue; Start-Sleep -Seconds {0}; shutdown.exe {1}
'@ -f $RebootDelaySeconds, $ShutdownArgs

        $Base64encode = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($POSHScript))
        $PoshArgs = "-ExecutionPolicy RemoteSigned -EncodedCommand $Base64encode"

        if ($true -eq $WUStatus) {
            $SchTaskAction = @{
                Execute  = 'powershell.exe'
                Argument = $PoshArgs
            }
        } else {
            $SchTaskAction = @{
                Execute  = 'shutdown.exe'
                Argument = $ShutdownArgs
            }
        }
    }

    process {
        New-ScheduledTaskFolder -TaskPath $TaskPath

        if ($PSCmdlet.ShouldProcess($env:COMPUTERNAME)) {
            $TAction = New-ScheduledTaskAction @SchTaskAction
            $TTrigger = New-ScheduledTaskTrigger -Once -At $SchTaskTime
            $TSchedule = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -DontStopOnIdleEnd
            try {
                Get-ScheduledTask -TaskName 'RebootComputer' -ErrorAction SilentlyContinue | Unregister-ScheduledTask -Confirm:$false
                Register-ScheduledTask -TaskName 'RebootComputer' -TaskPath $TaskPath -Action $TAction -Trigger $TTrigger -RunLevel Highest -User System -Settings $TSchedule -ErrorAction Stop
                $SchTaskFailed = $false
            } catch {
                $SchTaskFailed = $true
            }


            # try {
            #     Register-ScheduledTask -TaskName 'RebootComputer' -TaskPath $TaskPath -Action $TAction -Trigger $TTrigger -RunLevel Highest -User System -Settings $TSchedule -ErrorAction Stop
            # } catch [Microsoft.Management.Infrastructure.CimException] {
            #     Set-ScheduledTask -TaskName 'RebootComputer' -TaskPath $TaskPath -Action $TAction -Trigger $TTrigger -User System -Settings $TSchedule
            # } catch {
            #     (($Error[0] | Select-Object -Property Exception | Out-String).trim() -split '\r')[-1]
            #     exit 1
            # }

            Write-Host $RebootComment
        }

        if ($PSBoundParameters.ContainsKey('OutObject')) {
            [PSCustomObject]@{
                RebootReason  = $RebootReason
                RebootTime    = $RebootTime
                RebootComment = $RebootComment
                WinUpdateReq  = $WUStatus
                SchTaskFailed = $SchTaskFailed
            }
        }
    }

    end {}
}

function New-ToastPopUp {
    [CmdletBinding()]
    param (

    )

    begin {
        New-PSDrive -Name HKCR -PSProvider Registry -Root HKEY_CLASSES_ROOT -erroraction silentlycontinue | out-null
        $ProtocolHandler = get-item 'HKCR:\ToastReboot' -erroraction 'silentlycontinue'
        if (!$ProtocolHandler) {
            #create handler for reboot
            New-item 'HKCR:\ToastReboot' -force
            set-itemproperty 'HKCR:\ToastReboot' -name '(DEFAULT)' -value 'url:ToastReboot' -force
            set-itemproperty 'HKCR:\ToastReboot' -name 'URL Protocol' -value '' -force
            new-itemproperty -path 'HKCR:\ToastReboot' -propertytype dword -name 'EditFlags' -value 2162688
            New-item 'HKCR:\ToastReboot\Shell\Open\command' -force
            set-itemproperty 'HKCR:\ToastReboot\Shell\Open\command' -name '(DEFAULT)' -value 'C:\Windows\System32\shutdown.exe -r -t 30' -force
        }
        if (-not (Test-Path C:\ProgramData\EberlySystems)) {
            New-Item -Path C:\ProgramData -Name EberlySystems -ItemType Directory
        }
    }

    process {
        invoke-ascurrentuser -scriptblock {
            $heroimage = New-BTImage -Source 'https://dlpool0dd7ff86378b.blob.core.windows.net/warning-pubic-blob/EberlyOnWhite.gif' -HeroImage
            $Text1 = New-BTText -Content  "Eberly Systems - Reboot Required"
            $Text2 = New-BTText -Content "Your computer has a pending reboot. Please select if you'd like to reboot now, or snooze this message. It is important to reboot when possible for the security and performance of your system."
            $Button = New-BTButton -Content "Snooze" -snooze -id 'SnoozeTime'
            $Button2 = New-BTButton -Content "Reboot now" -Arguments "ToastReboot:" -ActivationType Protocol
            $5Min = New-BTSelectionBoxItem -Id 5 -Content '5 minutes'
            $10Min = New-BTSelectionBoxItem -Id 10 -Content '10 minutes'
            $1Hour = New-BTSelectionBoxItem -Id 60 -Content '1 hour'
            $4Hour = New-BTSelectionBoxItem -Id 240 -Content '4 hours'
            $1Day = New-BTSelectionBoxItem -Id 1440 -Content '1 day'
            $Items = $5Min, $10Min, $1Hour, $4Hour, $1Day
            $SelectionBox = New-BTInput -Id 'SnoozeTime' -DefaultSelectionBoxItemId 10 -Items $Items
            $action = New-BTAction -Buttons $Button, $Button2 -inputs $SelectionBox
            $Binding = New-BTBinding -Children $text1, $text2 -HeroImage $heroimage
            $Visual = New-BTVisual -BindingGeneric $Binding
            $Content = New-BTContent -Visual $Visual -Actions $action
            Submit-BTNotification -Content $Content -Verbose
        }
    }

    end {
    }
}

function New-CleanupSchTask {
    param (
        [scriptblock]$ScriptBlock,
        [string]$ScriptPath = "$env:ProgramFiles\WindowsPowerShell\Scripts\Test-PendingReboot.ps1",
        [string]$TaskPath,
        [string]$TaskName = 'ClearPendingReboot'
    )
    New-ScheduledTaskFolder -TaskPath $TaskPath

    $ScriptFolderPath = Split-Path -Path $ScriptPath -Parent
    if (! (Test-Path -Path $ScriptFolderPath)) {
        New-Item -Path $ScriptFolderPath -ItemType Directory
    }

    # Write $ScriptBlock block to Scripts folder
    if ($ScriptBlock -notmatch '^\s*$') {
        $ScriptBlock.ToString() | Out-File -FilePath $ScriptPath -Force
    } elseif (-not (Test-Path -Path $ScriptPath)) {
        throw 'Missing $ScriptBlock Block and script file'
    }

    $fileHash = Get-FileHash -Path $ScriptPath -Algorithm SHA256
    # Use ScheduledTask to cleanup after reboot
    $ScriptArgs = "-ClearKeys"
    $B64Script = "`$fp = '$ScriptPath'; if((Get-FileHash -Path `$fp -Algorithm SHA256).Hash -eq '$($fileHash.Hash)'){ & `$fp $ScriptArgs }; "
    $B64Script += "Remove-Item -Path `$fp -force; Get-ScheduledTask -TaskName $TaskName* | Disable-ScheduledTask"
    Write-Verbose "ScriptBlock"
    Write-Verbose "{$B64Script}"
    $Base64encode = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($B64Script))
    $TArgs = "-ExecutionPolicy RemoteSigned -EncodedCommand $Base64encode"
    $TProgram = "C:\Windows\system32\WindowsPowerShell\v1.0\powershell.exe"
    $TAction = New-ScheduledTaskAction -Execute $TProgram -Argument $TArgs
    $TTrigger = New-ScheduledTaskTrigger -AtStartUp #-RandomDelay (New-TimeSpan -Seconds 90)
    $TSchedule = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -DontStopOnIdleEnd

    if (Get-ScheduledTask -TaskName "$TaskName*" -ErrorAction SilentlyContinue -OutVariable SchTsk) {
        Set-ScheduledTask -TaskName $SchTsk[0].TaskName -TaskPath $SchTsk[0].TaskPath -Action $TAction -Trigger $TTrigger -User System -Settings $TSchedule
    } else {
        Unregister-ScheduledTask -Confirm:$false -TaskName "$TaskName*" -ErrorAction SilentlyContinue
        Remove-Item -Path "C:\Windows\System32\Tasks\$TaskPath\$TaskName*" -ErrorAction SilentlyContinue -Force
        try {
            Register-ScheduledTask -TaskName $TaskName -TaskPath $TaskPath -Action $TAction -Trigger $TTrigger -RunLevel Highest -User System -Settings $TSchedule
        } catch {
            shutdown /r /t 30
        }
    }
}

function Enable-AppNotifications {
    [CmdletBinding()]
    param (
        [Parameter(
            Position = 0,
            Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName
        )]
        [Alias('UserName')]
        [string[]]$Users,
        [string]$AppName = 'powershell.exe'
    )

    begin {
        New-PSDrive -Name HKU -PSProvider Registry -Root Registry::HKEY_USERS | Out-Null
        [array]$CimUsers = Get-CimInstance -ClassName Win32_UserProfile | Where-Object { $_.LocalPath -like 'c:\user*' }
        if (($Users -eq '*' -or $Users -eq 'All') -and $Users.Count -eq 1) {
            $Users = $CimUsers.LocalPath | ForEach-Object { ($_ -split '\\')[-1] }
        }
    }

    process {
        foreach ($u in $Users) {
            $cimU = $CimUsers.where({ $_.localpath -match $u })
            $hkuPath = "HKU\$($cimU.SID)"
            $ntuserdat = Join-Path -Path $cimU.LocalPath -ChildPath NTUSER.DAT
            $UserHive = "HKU:\$($cimU.SID)"
            $AppDataFldr = Join-Path -Path $cimU.localpath -ChildPath 'AppData\Local'
            $unload = $false

            if (!(Test-Path -Path $UserHive)) {
                reg load $hkuPath $ntuserdat
                $unload = $true
            }

            try {
                ##Database
                #Import SQLite module
                Import-Module PSSQLite

                #Set DBPath
                $DatabasePath = "$AppDataFldr\Microsoft\Windows\Notifications\wpndatabase.db"

                #Define select query
                $SelectQuery = "
SELECT HS.HandlerId, HS.SettingKey, HS.Value
FROM NotificationHandler AS NH
INNER JOIN HandlerSettings AS HS ON NH.RecordId = HS.HandlerID
WHERE NH.PrimaryId LIKE '%$AppName'
AND HS.SettingKey = 's:toast'
"
                #Invoke selectquery
                $NotificationSettings = Invoke-SqliteQuery -DataSource $DatabasePath -Query $SelectQuery

                #If the setting are wrong
                if ($NotificationSettings.Value -ne 1) {
                    Write-Verbose 'NotificationSettings -ne 1'
                    #Create update query
                    $UpdateQuery = "
UPDATE HandlerSettings
SET Value = 1
WHERE HandlerId = '$($NotificationSettings.HandlerId)' AND SettingKey = 's:toast'
"
                    #Invoke updatequery
                    Invoke-SqliteQuery -DataSource $DatabasePath -Query $UpdateQuery
                }

                ##Registry
                #Get registry path for application Powershell
                $RegistryPath = (Get-ChildItem -Recurse -Path "$UserHive\SOFTWARE\Microsoft\Windows\CurrentVersion\Notifications\Settings" | Where-Object -Property Name -Like "*$AppName*" | Select-Object -ExpandProperty Name) -Replace 'HKEY_USERS', 'HKU:'

                #Get current value for Enabled
                $Enabled = Get-ItemProperty -Path $RegistryPath -Name "Enabled" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Enabled

                #If the value are wrong
                if ($Enabled -ne 1) {
                    #Update registry
                    Set-ItemProperty -Path $RegistryPath -Name "Enabled" -Value 1 -Force
                }
            } catch {
                $LogPath = 'C:\ProgramData\EberlySystems\Log'
                $LogName = 'PowershellNotifications.log'
                Remove-Variable -Name p1, fTemp -ErrorAction SilentlyContinue
                foreach ($folder in $LogPath.split('\')) {
                    if ($null -ne $p1) {
                        $p1 = Join-Path -Path $fTemp -ChildPath $folder
                    } else {
                        $p1 = $folder
                    }
                    if (!(Test-Path -Path $p1)) {
                        New-Item -Path $fTemp -Name $folder -ItemType Directory
                    }
                    $fTemp = $p1
                }
                "$(Get-Date) | RemediationScript | ERROR: $($_)" | Out-File "$LogPath\$LogName" -Append
                return $_
            }

            if ($unload) {
                reg unload $hkuPath
            }
        }
    }

    end {
    }
}
#Endregion Functions

#Region !!!ScriptBlock!!!
#  Any edit to this script block requires updating AppWhitelisting and AV alow list
$TestPendingReboot = {
    [CmdletBinding()]
    param (
        [Parameter()]
        [switch]
        $ClearKeys
    )

    # Set up $env: vars for Syncro Module
    if ($env:SyncroModule -match '^\s*$') {
        $SyncroRegKey = Get-ItemProperty -Path 'HKLM:\SOFTWARE\WOW6432Node\RepairTech\Syncro' -Name uuid, shop_subdomain
        $env:RepairTechFilePusherPath = 'C:\ProgramData\Syncro\bin\FilePusher.exe'
        $env:RepairTechKabutoApiUrl = 'https://rmm.syncromsp.com'
        $env:RepairTechSyncroApiUrl = 'https://{subdomain}.syncromsp.com'
        $env:RepairTechSyncroSubDomain = $SyncroRegKey.shop_subdomain
        $env:RepairTechUUID = $SyncroRegKey.uuid
        $env:SyncroModule = "$env:ProgramData\Syncro\bin\module.psm1"
    }
    if (Test-Path -Path $env:SyncroModule) {
        Import-Module -Name $env:SyncroModule -WarningAction SilentlyContinue
    }


    $BitDefenderSvcs = @('EPIntegrationService', 'EPProtectedService', 'EPRedline', 'EPSecurityService', 'EPUpdateServer', 'EPUpdateService')

    #Region Functions
    function Get-Uptime {
        [datetime]$BootTime = (Get-CimInstance -ClassName win32_operatingsystem).LastBootUpTime
    ((Get-Date) - $BootTime)
    }

    function Test-RegistryKey {
        [OutputType('bool')]
        [CmdletBinding()]
        param
        (
            [Parameter(Mandatory)]
            [ValidateNotNullOrEmpty()]
            [string]$Key,
            [switch]$HasChildren,
            [switch]$Clear
        )

        process {
            switch -Regex (($PSBoundParameters.Keys) -join ' ') {
                'HasChildren' {
                    if ($Children = Get-ChildItem -Path $Key -ErrorAction Ignore) {
                        if ($PSBoundParameters.ContainsKey('Clear')) {
                            $Children | Remove-Item -Recurse -ErrorAction Ignore
                        } else {
                            $true
                        }
                    }

                }
                Default {
                    if (Get-Item -Path $Key -ErrorAction Ignore) {
                        if ($PSBoundParameters.ContainsKey('Clear')) {
                            Remove-Item -Path $Key -Recurse -ErrorAction Ignore
                        } else {
                            $true
                        }
                    }
                }
            }
        }

        end {}
    }

    function Test-RegistryValue {
        [OutputType('bool')]
        [CmdletBinding()]
        param
        (
            [Parameter(Mandatory)]
            [ValidateNotNullOrEmpty()]
            [string]$Key,

            [Parameter(Mandatory)]
            [ValidateNotNullOrEmpty()]
            [string]$Value,

            [switch]$NotNull,
            [string]$NotEqualValue,
            [switch]$Clear
        )

        begin {
            $ErrorActionPreference = 'Stop'
        }

        process {
            switch -Regex (($PSBoundParameters.Keys) -join ' ') {
                'NotNull' {
                    if (($regVal = Get-ItemProperty -Path $Key -Name $Value -ErrorAction Ignore) -and $regVal.($Value)) {
                        if ($PSBoundParameters.ContainsKey('Clear')) {
                            Remove-ItemProperty -Path $Key -Name $Value -ErrorAction Ignore
                        } else {
                            $true
                        }
                    }
                }
                'NotEqual' {
                    if (($regVal = Get-ItemProperty -Path $Key -Name $Value -ErrorAction Ignore) -and $regVal.($Value) -ne $NotEqualValue) {
                        if ($PSBoundParameters.ContainsKey('Clear')) {
                            Remove-ItemProperty -Path $Key -Name $Value -ErrorAction Ignore
                        } else {
                            $true
                        }
                    }
                }
                Default {
                    if (Get-ItemProperty -Path $Key -Name $Value -ErrorAction Ignore) {
                        if ($PSBoundParameters.ContainsKey('Clear')) {
                            Remove-ItemProperty -Path $Key -Name $Value -ErrorAction Ignore
                        } else {
                            $true
                        }
                    }
                }
            }
        }

        end {}
    }
    #Endregion Functions

    $tests = @(
        { Test-RegistryKey -Key 'HKLM:\SOFTWARE\Microsoft\ServerManager\CurrentRebootAttemps' }
        { Test-RegistryKey -Key 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending' }
        { Test-RegistryKey -Key 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootInProgress' }
        { Test-RegistryKey -Key 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired' }
        { Test-RegistryKey -Key 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Component Based Servicing\PackagesPending' }
        { Test-RegistryKey -Key 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\PostRebootReporting' }
        { Test-RegistryKey -Key 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Services\Pending' -HasChildren }
        #{ Test-RegistryValue -Key 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Value 'PendingFileRenameOperations' -NotNull }
        #{ Test-RegistryValue -Key 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Value 'PendingFileRenameOperations2' -NotNull }
        { Test-RegistryValue -Key 'HKLM:\SOFTWARE\Microsoft\Updates' -Value 'UpdateExeVolatile' -NotEqualValue 0 }
        { Test-RegistryValue -Key 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce' -Value 'DVDRebootSignal' }
        { Test-RegistryValue -Key 'HKLM:\SYSTEM\CurrentControlSet\Services\Netlogon' -Value 'JoinDomain' }
        { Test-RegistryValue -Key 'HKLM:\SYSTEM\CurrentControlSet\Services\Netlogon' -Value 'AvoidSpnSet' }
        { Get-Service -Name $BitDefenderSvcs -ErrorAction SilentlyContinue | Where-Object { $_.Status -ne 'Running' } }
        { try { Get-WURebootStatus -Silent } catch { $false } }
    )

    [array]$RebootRequred = foreach ($test in $tests) {
        if (& $test) {
            $test.ToString().trim()
        }
    }

    if (($RebootRequred.count -ge 1 -and (Get-Uptime).TotalMinutes -lt 15) -or $PSBoundParameters.ContainsKey('ClearKeys')) {
        foreach ($r in $RebootRequred) {
            if ($r -notmatch 'JoinDomain' -and $r -match 'Test-Registry') {
                $sb = [Scriptblock]::Create($r + " -Clear")
                & $sb
            }
        }
        if ($env:SyncroModule) {
            Write-Host 'No Reboot Required, Clearing Rmm-Aerts'
            Close-Rmm-Alert -Category 'Reboot_Required'
            Close-Rmm-Alert -Category 'Ps_Monitor'
        }
    } else {
        if ($env:SyncroModule) {
            Write-Host 'No Reboot Required, Clearing Rmm-Aerts'
            Close-Rmm-Alert -Category 'Reboot_Required'
            Close-Rmm-Alert -Category 'Ps_Monitor'
        }
    }
}
#Endregion !!!ScriptBlock!!!

"Checking for Pending Reboot"
.$TestPendingReboot
'LastExitCode: "{0}"' -f $LASTEXITCODE

if ($RebootRequred.count -gt 0) {
    # Disable Hiberbootenabled (fast boot)
    Set-ItemProperty 'hklm:\SYSTEM\CurrentControlSet\Control\Session Manager\Power\' -Name hiberbootenabled -Value 0
    $lastCode = $LASTEXITCODE
    try {
        [array]$qUsers = ((query user) -split "\n").trim(' >') -replace '\s\s+', ';' | convertfrom-csv -Delimiter ';'
    } catch {
    } finally {
        $LASTEXITCODE = $lastCode
    }

    "Reboot Required"
    $RebootRequred
    'LastExitCode: "{0}"' -f $LASTEXITCODE

    try {
        InstallOrUpdateModule -Name $RequiredModules -ErrorAction Stop
    } catch {
        Write-Warning "Could not update RequiredModules"
        Write-Host "Powershell version $($PSVersionTable.PSVersion)"
    }

    New-CleanupSchTask -ScriptBlock $TestPendingReboot -TaskPath 'EberlySystems'

    if ($AutoReboot -eq 'True') {
        $reboot = Add-ScheduledReboot -Confirm:$false -RebootTime $RebootTime -OutObject -ErrorAction Stop
        if ($reboot.SchTaskFailed) {
            $now = Get-Date
            switch ($now) {
                { $_ -lt [datetime]"2:30 am" } { [int]$seconds = ([datetime]"2:45 am" - $now).TotalSeconds }
                { $_ -gt [datetime]"4:00 am" } { [int]$seconds = ((Get-Date "2:45 am").AddDays(1) - $now).TotalSeconds }
                Default { [int]$seconds = 1 }
            }
            .$TestPendingReboot -ClearKeys
            shutdown /r /t $seconds /f
        }
        Log-Activity -Message "$($reboot.RebootReason) Scheduled at $($reboot.RebootTime), For WU: $($reboot.WinUpdateReq)" -EventName "RMM Automation"
    } elseif ($qUsers.Count -gt 0) {
        "Enable Notifications for: $($qusers.username)"
        $qUsers.username |
            Where-Object { Test-Path -Path "C:\Users\$_\AppData\Local\Microsoft\Windows\Notifications\wpndatabase.db" } |
            Enable-AppNotifications
        try {
            New-ToastPopUp -ErrorAction Stop
            "Sending ToastMessage"
        } catch {
            Write-Warning -Message "Unable to send ToastMessage"
        }
    } else {
        [string]$body = ($RebootRequred | Out-String)
        ""
        "New RMM Alert Reboot_Required"
        Rmm-Alert -Category 'Reboot_Required' -Body $body
    }
    if ($LASTEXITCODE -gt 0) {
        exit $LASTEXITCODE
    } else {
        exit 0
    }
}
