#!/bin/bash

# Download URL lists
# Download plain-text recent list from URLhaus https://urlhaus.abuse.ch/api/
url_list1=$(curl -sS https://urlhaus.abuse.ch/downloads/text_recent/)
# Download text format list from cert.pl
url_list2=$(curl -sS https://hole.cert.pl/domains/domains.txt)

# Convert URLs to FQDNs, remove ports and IP addresses for the first list
fqdn_list1=$(echo "$url_list1" | grep -oP '(?<=://)[^:/]+(?=\/|$)')

# Combine the FQDN list from the first list and the second list, and deduplicate
combined_fqdn_list=$(echo -e "$fqdn_list1\n$url_list2" | grep -vE '([0-9]{1,3}\.){3}[0-9]{1,3}' | sort -u)

# Save the combined FQDN list to a temporary file
echo "$combined_fqdn_list" > temp_fqdn_list.txt

# File name/path of domain list:
domain_list='temp_fqdn_list.txt' # Use the temporary FQDN list

# IP address of the nameserver used for lookups:
ns1_ip='1.1.1.1' # Cloudflare
ns2_ip='8.8.8.8' # Google
ns3_ip='1.1.1.2' # Cloudflare-Filtered
ns4_ip='185.228.169.9' # CleanBrowsing
ns5_ip='185.236.104.104' # FlashStart
ns6_ip='193.110.81.0' # dns0
ns7_ip='9.9.9.9' # Quad9

# Seconds to wait between lookups:
loop_wait='1' # Is set to 1 second.

# Output CSV header
echo "Domain name,$ns1_ip,$ns2_ip,$ns3_ip,$ns4_ip,$ns5_ip,$ns6_ip,$ns7_ip"

# Loop through domains and perform DNS lookups
while IFS= read -r domain
do
    ip1=$(dig "@$ns1_ip" +short "$domain" | tail -n1) # IP address lookup DNS Server1
    ip2=$(dig "@$ns2_ip" +short "$domain" | tail -n1) # IP address lookup DNS server2
    ip3=$(dig "@$ns3_ip" +short "$domain" | tail -n1) # IP address lookup DNS server3
    ip4=$(dig "@$ns4_ip" +short "$domain" | tail -n1) # IP address lookup DNS server4
    ip5=$(dig "@$ns5_ip" +short "$domain" | tail -n1) # IP address lookup DNS server5
    ip6=$(dig "@$ns6_ip" +short "$domain" | tail -n1) # IP address lookup DNS server6
    ip7=$(dig "@$ns7_ip" +short "$domain" | tail -n1) # IP address lookup DNS server7

    echo -en "$domain,$ip1,$ip2,$ip3,$ip4,$ip5,$ip6,$ip7\n"
    sleep "$loop_wait" # Pause before the next lookup to avoid flooding NS
done < "$domain_list"
