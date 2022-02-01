# Required Variables
# $InstType (recomend Dropdown)
# $ClientID (recomend Platform variable set to customer custom field)
# $ClientSecret (recomend Platform variable set to customer custom field)
#
# $Source OR Required File (use to specify download link or save cybercnsagent.exe to C:\Windows\Temp)

if ($InstType -notin ('Probe','LightWeight','Scan')){
    throw "`$InstType must equal one of ('Probe','LightWeight','Scan')"
    exit 1
}

$destination = Join-Path -Path 'C:\Windows\Temp\' -ChildPath 'cybercnsagent.exe'
switch -Regex ($Source) {
    'https://\w+\.mycybercns\.com/.*/cybercnsagent\.exe' {
        Invoke-WebRequest -Uri $Source -OutFile $destination
        }
    Default {
        if(!(Test-Path -Path $destination)){
            Throw "'$Destination' not found"
            exit 2
        }
    }
}

"Running: Start-Process $destination -ArgumentList `"-c $ClientID -a $ClientID -s `$ClientSecret -b eberlysystemsv2.mycybercns.com -i $InstType`" -NoNewWindow"
Start-Process $destination -ArgumentList "-c $ClientID -a $ClientID -s $ClientSecret -b eberlysystemsv2.mycybercns.com -i $InstType" -NoNewWindow
