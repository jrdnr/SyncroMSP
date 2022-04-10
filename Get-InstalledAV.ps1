#requires -version 5.1
# This Script will not work on Server OS versions
# For Syncro all Vars/Fields are optional
# Runtime ScriptVariable:
#   Name: AlertIfEnabledAV
#   Description: This Var will be used in a regex match aganst AV Display Name. If Match -eq $True will raise RMM Alert
#
# Asset Custom Fields
#   Name:
    $EnabledAV = "Enabled AV" #Type: "Text Field"
#       Description: Will only contain the "Display Name" of the Enabled AV(s)
#   Name:
    $AllAV = "All AV"         #Type: "Text Area"
#       Description: Multi line output CSV for all detected AVs "DisplayName,Enabled,Date"

Function Get-AVStatus {

    <#
    .Synopsis
    Get anti-virus product information.
    .Description
        This command queries the state of installed anti-virus products via the Get-CimInstance command.
        The default behavior is to only display enabled products, unless you use -All. You can query by computername or existing CIMSessions.
    .Example
        PS C:\> Get-AVStatus
        Displayname  : ESET NOD32 Antivirus 9.0.386.0
        ProductState : 266256
        Enabled      : True
        UpToDate     : True
        Path         : C:\Program Files\ESET\ESET NOD32 Antivirus\ecmd.exe
        Timestamp    : Thu, 21 Jul 2016 15:20:18 GMT
    .Notes
        version: 1.1
        Learn more about PowerShell:
        http://jdhitsolutions.com/blog/essential-powershell-resources/
        Fork of origional https://gist.github.com/jrdnr/fb2473d6080b7f2b381dc790be679236
    .Inputs
    [string[]]
    [Microsoft.Management.Infrastructure.CimSession[]]
    .Outputs
    [pscustomboject]
    .Link
    Get-CimInstance
    #>

    [cmdletbinding(DefaultParameterSetName = "computer")]

    Param(
        #The name of a computer to query.
        [Parameter(
            Position = 0,
            ValueFromPipeline,
            ValueFromPipelineByPropertyName,
            ParameterSetName = "computer")]
        [ValidateNotNullorEmpty()]
        [string[]]$Computername = $env:COMPUTERNAME,

        #An existing CIMsession.
        [Parameter(ValueFromPipeline, ParameterSetName = "session")]
        [Microsoft.Management.Infrastructure.CimSession[]]$CimSession,

        #The default is enabled products only.
        [switch]$All
    )

    Begin {
        Write-Verbose "[BEGIN  ] Starting: $($MyInvocation.Mycommand)"

        Function ConvertTo-Hex {
            Param([int]$Number)
            '0x{0:x}' -f $Number
        }

        If ($All) {
            Write-Verbose "[BEGIN  ] Getting all AV products"
        }

    } #begin

    Process {
        #initialize an hashtable of paramters to splat to Get-CimInstance
        $cimParams = @{
            Namespace   = "root/SecurityCenter2"
            ClassName   = "Antivirusproduct"
            ErrorAction = "Stop"
        }

        #initialize an empty array to hold results
        $AV = @()

        Write-Verbose "[PROCESS] Using parameter set: $($pscmdlet.ParameterSetName)"
        Write-Verbose "[PROCESS] PSBoundparameters: "
        Write-Verbose ($PSBoundParameters | Out-String)

        if ($pscmdlet.ParameterSetName -eq 'computer') {
            foreach ($computer in $Computername) {

                Write-Verbose "[PROCESS] Querying $($computer.ToUpper())"
                if ($computer -ne $env:COMPUTERNAME){
                    $cimParams.ComputerName = $computer
                }
                Try {
                    $AV += Get-CimInstance @CimParams
                }
                Catch {
                    Write-Warning "[$($computer.ToUpper())] $($_.Exception.Message)"
                    $cimParams.ComputerName = $null
                }

            } #foreach computer
        } else {
            foreach ($session in $CimSession) {

                Write-Verbose "[PROCESS] Using session $($session.computername.toUpper())"
                $cimParams.CimSession = $session
                Try {
                    $AV += Get-CimInstance @CimParams
                }
                Catch {
                    Write-Warning "[$($session.computername.ToUpper())] $($_.Exception.Message)"
                    $cimParams.cimsession = $null
                }

            } #foreach computer
        }

        foreach ($item in $AV) {
            Write-Verbose "[PROCESS] Found $($item.Displayname)"
            $hx = ConvertTo-Hex $item.ProductState
            $mid = $hx.Substring(3, 2)
            [bool]$Enabled = $mid -notmatch "00|01"

            $end = $hx.Substring(5)
            [bool]$UpToDate = $end -eq "00"

            if ($All -or $Enabled){
                $item | Select-Object Displayname, ProductState,
                @{Name = "Enabled"; Expression = { $Enabled } },
                @{Name = "UpToDate"; Expression = { $UptoDate } },
                instanceGuid,
                @{Name = "Path"; Expression = { $_.pathToSignedProductExe } },
                Timestamp,
                @{Name = "Computername"; Expression = {
                    if([string]::IsNullOrWhiteSpace($_.PSComputername)){$env:COMPUTERNAME}else{$_.PSComputername.toUpper()}
                } }
            }

        } #foreach

    } #process

    End {
        Write-Verbose "[END    ] Ending: $($MyInvocation.Mycommand)"
    } #end

} #end function

function Import-SyncroModule {
    param (
        #Defaults to the UUID of local system but you can provide the UUID of Any other Syncro Asset instead.
        $UUID = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\WOW6432Node\RepairTech\Syncro' -Name uuid -ErrorAction Stop).uuid
    )

    # Set up $env: vars for Syncro Module
    $env:SyncroModule               = "$env:ProgramData\Syncro\bin\module.psm1"
    $env:RepairTechApiBaseURL       = 'syncromsp.com'
    $env:RepairTechApiSubDomain     = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\WOW6432Node\RepairTech\Syncro' -Name shop_subdomain).shop_subdomain
    $env:RepairTechFilePusherPath   = 'C:\ProgramData\Syncro\bin\FilePusher.exe'
    $env:RepairTechUUID             = $UUID

    if (Test-Path -Path $env:SyncroModule) {
        Import-Module -Name $env:SyncroModule -WarningAction SilentlyContinue
    } else {
        [Environment]::SetEnvironmentVariable('SyncroModule',$null)
    }
}

Get-AVStatus -All | Tee-Object -Variable InstalledAV

if ($env:SyncroModule -and $null -ne $InstalledAV){
    Import-SyncroModule
    $AvEnabled = $InstalledAV | Where-Object {$_.Enabled -eq $true}
    if (![string]::IsNullOrWhiteSpace($AlertIfEnabledAV) -and $AvEnabled.Displayname -match $AlertIfEnabledAV){
        # Remove `r from string so Syncro doesn't Barf
        $body = ($AvEnabled | Out-String) -replace "`r",""
        Rmm-Alert -Category 'Enabled_AV_Error' -Body $body
    }
    $enabledAVBody = $AvEnabled.Displayname -join ','
    Set-Asset-Field -Name $EnabledAV -Value $enabledAVBody

    $AllAV = @('Displayname,Enabled,Date')
    $AllAV += foreach ($a in $InstalledAV){'{0},{1},{2}' -f $a.Displayname, $a.Enabled, ([datetime]$a.Timestamp).ToString('yyyy/MM/dd')}
    $AllAV = ($AllAV | Out-String) -replace "`r",""
    Set-Asset-Field -Name $AllAV -Value $AllAV
}
