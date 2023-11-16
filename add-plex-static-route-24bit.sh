# Current date and time
echo "Running script at $(date)"

# Define netmask and gateway and interface
netmask="24"
gateway="10.0.0.1"
interface="bond0"

# Query the current IP addresses of plex.tv using nslookup
ips=$(nslookup plex.tv | awk '/^Address: / { print $2 }')

# Check if the IP addresses were successfully retrieved
if [ -z "$ips" ]; then
    echo "Failed to retrieve IP addresses for plex.tv"
    exit 1
else
    echo "Retrieved IP addresses for plex.tv:"
    echo "$ips"
    echo '-----'
fi

# Convert each IP address into a subnet
new_subnets=()
for current_ip in $ips; do
    subnet_ip=$(echo $current_ip | cut -d '.' -f 1,2,3).0
    new_subnets+=("$subnet_ip/$netmask")
    echo "Prepared subnet IP for static route: $subnet_ip/$netmask"
done

# Remove existing routes that do not match the new subnets
echo "Removing outdated routes from static-table..."
for existing_route in $(ip route show table static-table | awk '{print $1}'); do
    if [[ ! " ${new_subnets[*]} " =~ " ${existing_route} " ]]; then
        sudo ip route del table static-table $existing_route
        echo "Removed outdated static route: $existing_route"
    fi
done

# Add new subnets to the static table
for subnet in "${new_subnets[@]}"; do
    if ip route show table static-table | grep -q "$subnet"; then
        echo "Subnet $subnet already exists in static-table. Not changed."
    else
        sudo ip route add table static-table $subnet via $gateway dev $interface
        echo "Static Route added for $subnet with netmask $netmask and gateway $gateway"
    fi
done

echo "-------"
echo "Current Static Table at $(date)"
sudo ip route show table static-table
echo "-------"

