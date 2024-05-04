#!/bin/bash

# Check if an argument was provided
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <IP or hostname>"
    exit 1
fi

# Assign the first argument to 'target'
target=$1

# Default ports (to save time)
ports="21,23,80,443,5985"
# File to store results
results_file="nmap_results_$target.txt"

# Confirm the target
echo "### An initial basic port scan of the $target"

# Perform a quick ping test
echo -e "\n#### Perform a quick ping test"
echo "\`\`\`"
echo "% ping -c 5 $target"
ping -c 5 $target
echo "\`\`\`"

# Perform Nmap version scan with no ping (to ensure scan runs even if host blocks pings)
echo -e "\n#### Perform Nmap version scan with no ping (to ensure scan runs even if host blocks pings)"
echo "\`\`\`"
echo "% nmap -sV -Pn $target -p $ports"
nmap -sV -Pn $target -p $ports | tee "$results_file"
echo "\`\`\`"
