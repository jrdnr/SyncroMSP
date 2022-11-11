<#
Required Syncro Field: Monitors, Type: Text Area
#>

$connections = try {
    Get-CimInstance -Namespace 'root/wmi' -ClassName 'WmiMonitorConnectionParams' -ErrorAction stop |
        Group-Object -AsHashTable -Property InstanceName
}
catch {
    Get-WmiObject -Namespace 'root/wmi' -ClassName 'WmiMonitorConnectionParams' |
        Group-Object -AsHashTable -Property InstanceName
}

$VideoOutput = @{
    '-2' = 'UNINITIALIZED'
    '-1' = 'OTHER'
    '0'  = 'VGA_HD15'
    '1'  = 'SVIDEO'
    '2'  = 'SCOMPOSITE_VIDEO'
    '3'  = 'COMPONENT_VIDEO'
    '4'  = 'DVI'
    '5'  = 'HDMI'
    '6'  = 'LVDS'
    '7'  = 'UNKNOWN'
    '8'  = 'D_JPN'
    '9'  = 'SDI'
    '10' = 'DP_EXTERNAL'
    '11' = 'DP_EMBEDDED'
    '12' = 'UDI_EXTERNAL'
    '13' = 'UDI_EMBEDDED'
    '14' = 'SDTVDONGLE'
    '15' = 'MIRACAST'
    '16' = 'INDIRECT_WIRED'
    '2147483648' = 'BUILT_IN'
}

$ManufacturerHt = @{
    AAC = 'AcerView'; ACI = 'Asus'; ACR = 'Acer'; ACT = 'Targa'; AMW = 'AMW'; API = 'Acer'; APP = 'Apple Computer'; ART = 'ArtMedia'; AST = 'AST Research'; AUO = 'Asus';
    BNQ = 'BenQ Corp'; BOE = 'BOE Display Tech'
    CMO = 'Acer'; CMN = 'Chi Mei Innolux'; CPL = 'Compal / ALFA'; CPQ = 'Compaq';
    DEC = 'Digital Equipment Corp'; DEL = 'Dell'; DPC = 'Delta Electronics'; DWE = 'Daewoo Telecom'
    ECS = 'ELITEGROUP'; EIZ = 'EIZO'; EPI = 'Envision Peripherals';
    FUS = 'Fujitsu';
    GSM = 'LG (Goldstar)'
    HEI = 'Hyundai'; HIQ = 'Hyundai'; HIT = 'Hitachi'; HPE = 'HP'; HSD = 'Hannspree'; HSL = 'Hansol'; HTC = 'Hitachi'; HWP = 'HP'
    IBM = 'IBM PC Company'; ICL = 'Fujitsu'; IFS = 'InFocus'; IQT = 'Hyundai'; IVM = 'Idek Iiyama'
    KDS = 'KDS USA'; KFC = 'KFC Computek'
    LEN = 'Lenovo'; LGD = 'LG Display'; LKM = 'ADLAS / AZALEA'; LNK = 'LINK Tech'; LPL = 'LG'; LTN = 'Lite-On'
    MAG = 'MAG InnoVision'; MEI = 'Panasonic'; MEL = 'Mitsubishi'; MTC = 'MITAC'
    NAN = 'NANAO'; NEC = 'NEC Tech'; NOK = 'Nokia'; NVD = 'Nvidia'
    OQI = 'OPTIQUEST'
    PBN = 'Packard Bell'; PCK = 'Daewoo'; PDC = 'Polaroid'; PHL = 'Philips'
    REL = 'Relisys'
    SAN = 'Samsung'; SAM = 'Samsung'; SEC = 'Hewlett-Packard'; SNI = 'Siemens'; SNY = 'Sony'; SPT = 'Sceptre'; STP = 'Sceptre'; SRC = 'Shamrock'; SUN = 'Sun Microsystems'
    TAT = 'Tatung'; TOS = 'Toshiba'; TSB = 'Toshiba'
    VSC = 'ViewSonic'
    WET = 'Westinghouse'
    UNK = 'Unknown'
    ZCM = 'Zenith Data'
    _YV = 'Fujitsu'
}

#Grabs the Monitor objects from WMI
$Monitors = try {
    Get-CimInstance -Namespace 'root\WMI' -ClassName 'WMIMonitorID' -ErrorAction Stop
}
catch {
    Get-WmiObject -Namespace 'root\WMI' -Class 'WMIMonitorID' -ErrorAction SilentlyContinue
}

#Takes each monitor object found and runs the following code:
[array]$Monitor_Array = ForEach ($Monitor in $Monitors) {
    #Grabs respective data and converts it from ASCII encoding and removes any trailing ASCII null values
    If ($null -ne $Monitor.UserFriendlyName) {
        $Mon_Model = ([System.Text.Encoding]::ASCII.GetString($Monitor.UserFriendlyName)).Replace("$([char]0x0000)","")
    } elseif ($null -ne $Monitor.ProductCodeID) {
        $Mon_Model = ([System.Text.Encoding]::ASCII.GetString($Monitor.ProductCodeID)).Replace("$([char]0x0000)","")
    } else {
        $Mon_Model = $null
    }
    $Mon_Serial_Number = ([System.Text.Encoding]::ASCII.GetString($Monitor.SerialNumberID)).Replace("$([char]0x0000)","")
    #$Mon_Attached_Computer = ($Monitor.PSComputerName).Replace("$([char]0x0000)","")
    $Mon_Manufacturer = ([System.Text.Encoding]::ASCII.GetString($Monitor.ManufacturerName)).Replace("$([char]0x0000)","")


    #Sets a friendly name based on the hash table above. If no entry found sets it to the original 3 character code
    $Mon_Manufacturer_Friendly = $ManufacturerHt.$Mon_Manufacturer
    If ($null -eq $Mon_Manufacturer_Friendly) {
        $Mon_Manufacturer_Friendly = $Mon_Manufacturer
    }

    $VideoPort = $VideoOutput[$($connections.$($Monitor.InstanceName).VideoOutputTechnology).ToString()]

    #Creates a custom monitor object and fills it with 4 NoteProperty members and the respective data
    $Monitor_Obj = [PSCustomObject]@{
        Manufacturer     = $Mon_Manufacturer_Friendly
        Model            = $Mon_Model
        SerialNumber     = $Mon_Serial_Number
        Year             = $Monitor.YearOfManufacture
        ShortCode        = $Mon_Manufacturer
        Port             = $VideoPort
    }

    $Monitor_Obj
} #End ForEach Monitor

#Outputs the Array
$Monitor_Array | Format-Table -AutoSize

if ($null -ne $Monitor_Array){
    $Note = ($Monitor_Array | ConvertTo-Csv -NoTypeInformation | Out-String).Replace('"','') -replace "`r",""

    Import-Module $env:SyncroModule
    Set-Asset-Field -Name 'Monitors' -Value $Note
} else {
    'No Monitors Detected'
}
