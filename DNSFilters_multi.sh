#!/bin/bash

# List of websites for DNS lookups
websites=(
  "adobe.com"
  "amazon.com"
  "apple.com"
  "att.com"
  "bankofamerica.com"
  "bbc.com"
  "baidu.com"
  "chase.com"
  "costco.com"
  "cnn.com"
  "dropbox.com"
  "ebay.com"
  "espn.com"
  "facebook.com"
  "google.com"
  "groupon.com"
  "homedepot.com"
  "hulu.com"
  "imdb.com"
  "instagram.com"
  "linkedin.com"
  "microsoft.com"
  "netflix.com"
  "nike.com"
  "npr.org"
  "nytimes.com"
  "paypal.com"
  "pinterest.com"
  "reddit.com"
  "snapchat.com"
  "spotify.com"
  "stackoverflow.com"
  "starbucks.com"
  "target.com"
  "tumblr.com"
  "twitter.com"
  "uber.com"
  "usbank.com"
  "verizon.com"
  "walmart.com"
  "weather.com"
  "wellsfargo.com"
  "whatsapp.com"
  "wikipedia.org"
  "yahoo.com"
  "youtube.com"
  "zillow.com"
)

# Associative array for resolver names and IP addresses
declare -A resolvers=(
    ["Cloudflare"]="1.1.1.1"
    ["Google"]="8.8.8.8"
    ["Cloudflare-Filtered"]="1.1.1.2"
    ["CleanBrowsing"]="185.228.169.9"
    ["dns0"]="193.110.81.0"
    ["Quad9"]="9.9.9.9"
)

# Function to perform DNS lookup and measure time in milliseconds
benchmark_lookup() {
    local resolver="$1"
    local resolver_ip="${resolvers[$resolver]}"
    local total_time=0

    echo -n "Testing $resolver: "

    li=$((${#websites[@]} - 1))

    for website in "${websites[@]}"; do
        start_time=$(date +%s%N)  # Start time in nanoseconds
        dig +short "@$resolver_ip" "$website" > /dev/null
        end_time=$(date +%s%N)    # End time in nanoseconds

        # Calculate elapsed time in milliseconds and add to total time
        elapsed_time=$(( (end_time - start_time) / 1000000 ))
        total_time=$((total_time + elapsed_time))
        if [ "$website" != "${websites[$li]}" ]; then
            echo -n "$elapsed_time,"
        else
            echo "$elapsed_time"
        fi
    done

    # Calculate and print average lookup time in milliseconds
    average_time=$((total_time / ${#websites[@]}))
    echo "($resolver_ip): ${average_time}ms"
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
# Server Order: Cloudflare, Cloudflare-Filtered, CleanBrowsing, dns0, Quad9
nameservers=("1.1.1.1" "1.1.1.2" "185.228.169.9" "193.110.81.0" "9.9.9.9")

dnsLookup() {
    # Domain passed as a command-line argument
    domain="$1"

    # IP addresses of the nameservers used for lookups
    # Server Order: Cloudflare, Cloudflare-Filtered, CleanBrowsing, dns0, Quad9
    nameservers=("1.1.1.1" "1.1.1.2" "185.228.169.9" "193.110.81.0" "9.9.9.9")

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
