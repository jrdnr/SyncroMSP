<#
Credit: Dale Hudson
Origiona: https://pastebin.com/wNhbVhtW?fbclid=IwAR1jUgEdgsDh66JNymg37jXoRncZ5QBiBHFyVI3exssZ1mOdg6JeXGDmtqc

Required Syncro Field: Monitors, Type: Text Area
#>

Import-Module $env:SyncroModule

$connections = try {
    get-ciminstance -namespace root/wmi -classname WmiMonitorConnectionParams -ErrorAction
}
catch {
    Get-WmiObject -Namespace root/wmi -ClassName WmiMonitorConnectionParams
}

$arrayforsyncrofield = @()

$arrayforsyncrofield = foreach ($output in $connections){
    $monitor = $output.InstanceName
    $monitor = $monitor.Split("\")
    switch ($output.VideoOutputTechnology){
        -2 {$type = "UNINITIALIZED"}
        -1 {$type = "OTHER"}
        0 {$type = "VGA_HD15"}
        1 {$type = "SVIDEO"}
        2 {$type = "SCOMPOSITE_VIDEO"}
        3 {$type = "COMPONENT_VIDEO"}
        4 {$type = "DVI"}
        5 {$type = "HDMI"}
        6 {$type = "LVDS"}
        7 {$type = "UNKNOWN"}
        8 {$type = "D_JPN"}
        9 {$type = "SDI"}
        10 {$type = "DP_EXTERNAL"}
        11 {$type = "DP_EMBEDDED"}
        12 {$type = "UDI_EXTERNAL"}
        13 {$type = "UDI_EMBEDDED"}
        14 {$type = "SDTVDONGLE"}
        15 {$type = "MIRACAST"}
        16 {$type = "INDIRECT_WIRED"}

        Default {$type = 'unknown connection type "{0}"' -f $output.VideoOutputTechnology}
    }
    $type + ": " + $monitor[1]
}

$arrayforsyncrofield

Set-Asset-Field -Name "Monitors" -Value ($arrayforsyncrofield | Out-String)
