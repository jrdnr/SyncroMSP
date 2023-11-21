#!/bin/bash

# Download URL lists
url_list1=$(curl -sS https://urlhaus.abuse.ch/downloads/text_recent/)
url_list2=$(curl -sS https://hole.cert.pl/domains/domains.txt)

# Convert URLs to FQDNs, remove ports and IP addresses for the first list
fqdn_list1=$(echo "$url_list1" | grep -oP '(?<=://)[^:/]+(?=\/|$)')

# Combine the FQDN list from the first list and the second list, and deduplicate
combined_fqdn_list=$(echo -e "$fqdn_list1\n$url_list2" | grep -vE '([0-9]{1,3}\.){3}[0-9]{1,3}' | sort -u)

# IP addresses of the nameservers used for lookups
# Cloudflare,Google,Cloudflare-Filtered,CleanBrowsing,FlashStart,dns0,Quad9
nameservers=("1.1.1.1" "8.8.8.8" "1.1.1.2" "185.228.169.9" "185.236.104.104" "193.110.81.0" "9.9.9.9")

# Output CSV header to a file
echo "Domain name,$(IFS=,; echo "${nameservers[*]}")" > output.csv

# Loop through domains and perform DNS lookups
while read -r domain
do
    # IP address lookup for the first nameserver (1.1.1.1)
    ip_1_1_1_1=$(dig "@${nameservers[0]}" +short "$domain")

    # Check if the lookup for 1.1.1.1 returned anything
    if [ -n "$ip_1_1_1_1" ]; then
        # IP address lookup for all nameservers
        ip=()
        for ns_ip in "${nameservers[@]}"; do
            # Perform DNS lookup, filter out errors, and handle line breaks
            ip+=("$(dig "@$ns_ip" +short "$domain" 2>/dev/null | tail -n1)")
        done

        # Append the results to the CSV file
        echo "$domain,$(IFS=,; echo "${ip[*]}")" >> output.csv
    fi
done < <(echo -e "$combined_fqdn_list")

echo "Results written to output.csv"
