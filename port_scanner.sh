#!/bin/bash

# Check if an argument was provided
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <IP or hostname>"
    exit 1
fi

# Assign the first argument to 'target'
target=$1

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

# Perform traceroute
# echo -e "\n#### Perform traceroute"
# echo "\`\`\`"
# echo "% traceroute $target"
# traceroute $target
# echo "\`\`\`"

# Perform Nmap version scan with no ping (to ensure scan runs even if host blocks pings)
echo -e "\n#### Perform Nmap version scan with no ping (to ensure scan runs even if host blocks pings)"
echo "\`\`\`"
echo "% nmap -sV -Pn $target -p 80,5985"
nmap -sV -Pn $target -p 80,5985 | tee "$results_file"
echo "\`\`\`"

# # Extract and display open ports from the results
# open_ports=$(grep -oP '^\d+/tcp\s+open' "$results_file" | awk '{ print $1 }' | sort -u)

# if [ -z "$open_ports" ]; then
#     echo "No open ports found!"
# else
#     echo "Open ports found:"
#     echo "$open_ports"
# fi


# if [ -z "$open_ports" ]; then
#     echo "No open ports found. Performing a comprehensive port scan..."
#     nmap -p- -sV -Pn $target | tee -a "$results_file"
# else
#     echo "Open ports found:"
#     echo "$open_ports"
# fi

# if [ -z "$open_ports" ]; then
#     echo "No open ports found. Performing a comprehensive port scan..."
#     nmap -p- --min-rate=1000 -sV $target | tee -a "$results_file"
# else
#     echo "Open ports found:"
#     echo "$open_ports"
# fi


#Port 135 TCP : https://www.speedguide.net/port.php?port=135
#Port 139 TCP : https://www.speedguide.net/port.php?port=139
#Port 445 TCP : https://www.speedguide.net/port.php?port=445
#Port 3389 TCP : https://www.speedguide.net/port.php?port=3389
#Port 5357 TCP : https://www.speedguide.net/port.php?port=5357