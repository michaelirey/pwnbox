#!/bin/bash
set -x

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
echo "The script will perform various network scans on the target: $target"

# Perform a quick ping test
echo "Performing ping test..."
time ping -c 10 $target

# Perform traceroute
echo "Performing traceroute..."
time traceroute $target

# Perform Nmap version scan with no ping (to ensure scan runs even if host blocks pings)
echo "Performing Nmap service version scan..."
time nmap -sV -Pn $target | tee "$results_file"

# Extract and display open ports from the results
echo "Checking for open ports:"
open_ports=$(grep -oP '^\d+/tcp\s+open' "$results_file" | awk '{ print $1 }' | sort -u)

if [ -z "$open_ports" ]; then
    echo "No open ports found. Performing a comprehensive port scan..."
    nmap -p- -sV -Pn $target | tee -a "$results_file"
else
    echo "Open ports found:"
    echo "$open_ports"
fi

if [ -z "$open_ports" ]; then
    echo "No open ports found. Performing a comprehensive port scan..."
    nmap -p- --min-rate=1000 -sV $target | tee -a "$results_file"
else
    echo "Open ports found:"
    echo "$open_ports"
fi


#Port 135 TCP : https://www.speedguide.net/port.php?port=135
#Port 139 TCP : https://www.speedguide.net/port.php?port=139
#Port 445 TCP : https://www.speedguide.net/port.php?port=445
#Port 3389 TCP : https://www.speedguide.net/port.php?port=3389
#Port 5357 TCP : https://www.speedguide.net/port.php?port=5357