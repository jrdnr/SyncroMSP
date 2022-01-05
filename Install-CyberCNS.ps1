# Required Variables
# $InstType (recomend Dropdown)
# $ClientID (recomend Platform variable set to customer custom field)
# $ClientSecret (recomend Platform variable set to customer custom field)

function Install-CyberCNS {
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Probe','LightWeight','Scan')]
        [String]$InstType,
        [guid]$ClientID,
        [guid]$ClientSecret
    )
    $InstType = $InstType.Trim()

    $source = 'https://cybercnsagent.s3.amazonaws.com/cybercnsagent.exe'
    $destination = Join-Path -Path $env:TEMP -ChildPath 'cybercnsagent.exe'
    if(!(Test-Path $destination) -or (Get-Item -Path $destination | Select-Object -ExpandProperty LastWriteTime) -lt (Get-Date).AddMinutes(-15)){
        Invoke-WebRequest -Uri $source -OutFile $destination
    }

    "Running: Start-Process $destination -ArgumentList `"-c $ClientID -a $ClientID -s `$ClientSecret -b eberlysystemsv2.mycybercns.com -i $InstType`" -NoNewWindow"
    Start-Process $destination -ArgumentList "-c $ClientID -a $ClientID -s $ClientSecret -b eberlysystemsv2.mycybercns.com -i $InstType" -NoNewWindow
}

Install-CyberCNS -InstType $InstType -ClientID $ClientID -ClientSecret $ClientSecret
