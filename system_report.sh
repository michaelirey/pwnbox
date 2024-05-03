#!/bin/bash

echo -e "### System Report\n"

# OS and Version
user_info=$(whoami)
echo "#### Current user"
echo "- **User**: $user_info"

# OS and Version
os_info=$(cat /etc/os-release | grep PRETTY_NAME | cut -d '=' -f2)
echo "#### OS and Version"
echo "- **OS**: $os_info"

# Local IP
local_ip=$(hostname -I | awk '{for (i=1; i<=NF; i++) if ($i ~ /^(10\.|172\.(1[6-9]|2[0-9]|3[0-1])\.|192\.168\.)/) {print $i; exit}}')
echo "#### Local IP"
echo "- **Local IP**: $local_ip"

# Public IP
public_ip=$(curl -s https://ifconfig.me)
echo "#### Public IP"
echo "- **Public IP**: $public_ip"

# Hostname
hostname=$(hostname)
echo "#### Hostname"
echo "- **Hostname**: $hostname"

# System Architecture
architecture=$(uname -m)
echo "#### System Architecture"
echo "- **Architecture**: $architecture"

# CPU and Memory Information
cpu_info=$(lscpu | grep "Model name:" | cut -d ':' -f2 | xargs)
cpu_cores=$(lscpu | grep "^CPU(s):" | cut -d ':' -f2 | xargs)
total_mem=$(grep MemTotal /proc/meminfo | awk '{print $2 $3}')
echo "#### CPU and Memory Information"
echo "- **CPU Info**: $cpu_info"
echo "- **CPU Cores**: $cpu_cores"
echo "- **Total Memory**: $total_mem"

# Disk Space
disk_space=$(df -h / | awk 'NR==2 {print $4}')
echo "#### Disk Space"
echo "- **Available Disk Space**: $disk_space"

# Network Interfaces
network_interfaces=$(ip link show | awk -F: '$0 !~ "lo|vir|wl|^[^0-9]"{print $2;getline}' | xargs)
echo "#### Network Interfaces"
echo "- **Interfaces**: $network_interfaces"

# Available Package Managers
package_managers=$(echo $(which apt yum dnf 2>/dev/null))
echo "#### Available Package Managers"
echo "- **Package Managers**: $package_managers"

# List of scripting language interpreters to check and their versions
echo "#### Programming Languages and Details"
languages=("python" "ruby" "perl" "php" "node")
for lang in "${languages[@]}"; do
    if command -v $lang &>/dev/null; then
        path=$(which $lang)
        version=$($path --version 2>&1 | head -n 1)
        echo "- **$lang**"
        echo "  - **Version**: $version"
        echo "  - **Path**: $path"
    else
        echo "- **$lang** is not installed."
    fi
done
