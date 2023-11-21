#!/bin/bash

# List of top websites for DNS lookups
websites=("google.com" "youtube.com" "facebook.com" "baidu.com" "wikipedia.org" "reddit.com" "yahoo.com" "amazon.com" "twitter.com" "instagram.com" "linkedin.com" "netflix.com" "stackoverflow.com" "microsoft.com" "ebay.com")

# Associative array for resolver names and IP addresses
declare -A resolvers=(
    ["Cloudflare"]="1.1.1.1"
    ["Cloudflare-Filtered"]="1.1.1.2"
    ["CleanBrowsing"]="185.228.169.9"
    ["dns0"]="193.110.81.0"
    ["Quad9"]="9.9.9.9"
    ["FlashStart"]="185.236.104.104"
)

# Function to perform DNS lookup and measure time in milliseconds
benchmark_lookup() {
    local resolver="$1"
    local resolver_ip="${resolvers[$resolver]}"
    local total_time=0

    echo "Benchmarking lookup using resolver $resolver ($resolver_ip):"

    for website in "${websites[@]}"; do
        start_time=$(date +%s%N)  # Start time in nanoseconds
        dig +short "@$resolver_ip" "$website" > /dev/null
        end_time=$(date +%s%N)    # End time in nanoseconds

        # Calculate elapsed time in milliseconds and add to total time
        elapsed_time=$(( (end_time - start_time) / 1000000 ))
        total_time=$((total_time + elapsed_time))
    done

    # Calculate and print average lookup time in milliseconds
    average_time=$((total_time / ${#websites[@]}))
    echo "Average lookup time: ${average_time}ms"
    echo
}

# Perform DNS lookups for each resolver for all websites
for resolver in "${!resolvers[@]}"; do
    benchmark_lookup "$resolver"
done

# Download URL lists
url_list1=$(curl -sS https://urlhaus.abuse.ch/downloads/text_recent/)
url_list2=$(curl -sS https://hole.cert.pl/domains/domains.txt)

# Convert URLs to FQDNs, remove ports and IP addresses for the first list
fqdn_list1=$(echo "$url_list1" | grep -oP '(?<=://)[^:/]+(?=\/|$)')

# Combine the FQDN list from the first list and the second list, and deduplicate
combined_fqdn_list=$(echo -e "$fqdn_list1\n$url_list2" | grep -vE '([0-9]{1,3}\.){3}[0-9]{1,3}' | sort -u)

# IP addresses of the nameservers used for lookups
# Server Order: Cloudflare, Cloudflare-Filtered, CleanBrowsing, dns0, Quad9, FlashStart
nameservers=("1.1.1.1" "1.1.1.2" "185.228.169.9" "193.110.81.0" "9.9.9.9" "185.236.104.104")

dnsLookup() {
    # Domain passed as a command-line argument
    domain="$1"

    # IP addresses of the nameservers used for lookups
    # Server Order: Cloudflare, Cloudflare-Filtered, CleanBrowsing, dns0, Quad9, FlashStart
    nameservers=("1.1.1.1" "1.1.1.2" "185.228.169.9" "193.110.81.0" "9.9.9.9" "185.236.104.104")

    ip_1_1_1_1=$(dig "@${nameservers[0]}" +short "$domain" 2>/dev/null | tail -n1)

    # Check if the lookup for 1.1.1.1 returned anything
    if [ -n "$ip_1_1_1_1" ] && [ "$ip_1_1_1_1" != '127.0.0.1' ]; then
        # IP address lookup for all nameservers
        ip=()
        for ((i = 1; i < ${#nameservers[@]}; i++)); do
            # Perform DNS lookup, filter out errors, and handle line breaks
            ip+=("$(dig "@${nameservers[$i]}" +short "$domain" 2>/dev/null | tail -n1)")
        done

        # Append the results to the CSV file
        echo "$domain,$ip_1_1_1_1,$(IFS=,; echo "${ip[*]}")" >> dnsBench.csv
    fi
}

export -f dnsLookup

# Output CSV header to a file
echo "Domain name,$(IFS=,; echo "${nameservers[*]}")" > dnsBench.csv

# Loop through domains and perform DNS lookups in parallel
(echo "$combined_fqdn_list" | head -n10) | parallel --jobs 8 "dnsLookup {}" > /dev/null

echo "Results written to dnsBench.csv
