# Download plain-text recent list from URLhaus https://urlhaus.abuse.ch/api/
$urlhausRaw = Invoke-WebRequest -Uri 'https://urlhaus.abuse.ch/downloads/text_recent/' |
    Select-Object -ExpandProperty Content
$urlhaus = $urlhausRaw.Split() |
    .{process {if($_.Length -ge 10){($_ -replace 'https*://','' ) -replace '[:/].*',''}}} |
    Where-Object {$_ -notmatch '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$'} | Select-Object -Unique
# Download text format list from cert.pl
$certPl = (Invoke-WebRequest -Uri 'https://hole.cert.pl/domains/domains.txt').Content.Split()

[Linq.Enumerable]::Distinct(
  [string[]] ($certPl + $urlhaus),
  [StringComparer]::InvariantCultureIgnoreCase
) | Foreach-Object -ThrottleLimit 5 -Parallel {
  #Action that will run in Parallel. Reference the current object via $PSItem and bring in outside variables with $USING:varname
    $request = @{
        Name = $_
        Type = 'A'
        ErrorAction = 'SilentlyContinue'
    }
    if ((Resolve-DnsName -Server 8.8.8.8 @request) -or (Resolve-DnsName -Server 1.1.1.1 @request)){
        $ErrorActionPreference = 'SilentlyContinue'
        [pscustomobject]@{
            'Domain'        = $_
            'CloudFlare'    = (Resolve-DnsName -Server 1.1.1.1 @request | Select-Object -ExpandProperty IPAddress) -join ';'
            'Google'        = (Resolve-DnsName -Server 8.8.8.8 @request | Select-Object -ExpandProperty IPAddress) -join ';'
            'CF-Filtered'   = (Resolve-DnsName -Server 1.1.1.2 @request | Select-Object -ExpandProperty IPAddress) -join ';'
            'Quad9'         = (Resolve-DnsName -Server 9.9.9.9 @request | Select-Object -ExpandProperty IPAddress) -join ';'
            'CleanBrowsing' = (Resolve-DnsName -Server 185.228.169.9 @request | Select-Object -ExpandProperty IPAddress) -join ';'
            'FlashStart'    = (Resolve-DnsName -Server 185.236.104.104 @request | Select-Object -ExpandProperty IPAddress) -join ';'
            'dns0'          = (Resolve-DnsName -Server 193.110.81.0 @request | Select-Object -ExpandProperty IPAddress) -join ';'
            'zero.dns0'     = (Resolve-DnsName -Server 193.110.81.9 @request | Select-Object -ExpandProperty IPAddress) -join ';'
        }
    }
} | Export-Csv -Path ~/DNSFilters_Comparison.csv
