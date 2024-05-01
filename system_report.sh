#!/bin/bash

# OS and Version
os_info=$(cat /etc/os-release | grep PRETTY_NAME | cut -d '=' -f2)

# Local IP
local_ip=$(hostname -I | awk '{for (i=1; i<=NF; i++) if ($i ~ /^(10\.|172\.(1[6-9]|2[0-9]|3[0-1])\.|192\.168\.)/) {print $i; exit}}')

# Public IP
public_ip=$(curl -s https://ifconfig.me)

# Hostname
hostname=$(hostname)

# System Architecture
architecture=$(uname -m)

# CPU and Memory Information
cpu_info=$(lscpu | grep "Model name:" | cut -d ':' -f2 | xargs)
cpu_cores=$(lscpu | grep "^CPU(s):" | cut -d ':' -f2 | xargs)
total_mem=$(grep MemTotal /proc/meminfo | awk '{print $2 $3}')

# Disk Space
disk_space=$(df -h / | awk 'NR==2 {print $4}')

# Network Interfaces
network_interfaces=$(ip link show | awk -F: '$0 !~ "lo|vir|wl|^[^0-9]"{print $2;getline}' | xargs)

# Available Package Managers
package_managers=$(echo $(which apt yum dnf 2>/dev/null))

# List of scripting language interpreters to check
languages=("python" "ruby" "perl" "php" "node" "lua")

# Function to get version information
get_version() {
    if command -v $1 &>/dev/null; then
        path=$(which $1)
        version=$($path --version 2>&1 | head -n 1)
        echo "$1 - Version: $version, Path: $path"
    else
        echo "$1 is not installed."
    fi
}

# Generate Report
echo "OS and Version: $os_info"
echo "Local IP: $local_ip"
echo "Public IP: $public_ip"
echo "Hostname: $hostname"
echo "System Architecture: $architecture"
echo "CPU Info: $cpu_info, Cores: $cpu_cores"
echo "Total Memory: $total_mem"
echo "Available Disk Space: $disk_space"
echo "Network Interfaces: $network_interfaces"
echo "Available Package Managers: $package_managers"
echo "Programming Languages and Details:"
for lang in "${languages[@]}"; do
    get_version $lang
done
