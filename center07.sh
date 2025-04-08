#!/bin/bash
#
# =============================================================================
# Script Name : center07.sh
# Description : Interactive tool using `dialog` and `nmcli` to add all IPs
#               (including network and broadcast) from a CIDR range as /32
#               to a selected network interface on RHEL-based systems.
#
# URL         : https://github.com/gothickitty93/center07
# Author      : gothickitty93 (modified)
# License     : CC BY-SA 4.0 
# Version     : 25.04.4
# =============================================================================

# Ensure required commands are present
for cmd in dialog nmcli ipcalc; do
    if ! command -v $cmd >/dev/null 2>&1; then
        echo "Missing command: $cmd. Please install it first (e.g., sudo dnf install $cmd)."
        exit 1
    fi
done

TMPFILE=$(mktemp)

# Get list of available interfaces (excluding loopback)
interfaces=()
while IFS= read -r line; do
    dev=$(echo "$line" | awk '{print $1}')
    state=$(echo "$line" | awk '{print $3}')
    [[ "$dev" == "lo" ]] && continue
    [[ "$state" == "connected" || "$state" == "disconnected" ]] && interfaces+=("$dev" "$state")
done < <(nmcli device status | tail -n +2)

if [ ${#interfaces[@]} -eq 0 ]; then
    echo "No active or disconnected interfaces found."
    exit 1
fi

# Use dialog to select interface
dialog --clear --title "Select Network Interface" \
    --menu "Choose an interface to add IPs to. The interface and profile name MUST match!" 15 50 6 \
    "${interfaces[@]}" 2>"$TMPFILE"

retval=$?
iface=$(<"$TMPFILE")
rm -f "$TMPFILE"

if [[ $retval -ne 0 || -z "$iface" ]]; then
    echo "Interface selection cancelled."
    exit 1
fi

# Ask for CIDR input
TMPFILE=$(mktemp)
dialog --inputbox "Enter the CIDR IP range to add (e.g., 192.168.0.0/30):" 8 50 2>"$TMPFILE"
cidr=$(<"$TMPFILE")
rm -f "$TMPFILE"

# Validate input
if [[ ! "$cidr" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]{1,2}$ ]]; then
    dialog --msgbox "Invalid CIDR format." 6 40
    exit 1
fi

# Use ipcalc to get network/broadcast
eval $(ipcalc -n -b "$cidr")  # sets NETWORK and BROADCAST

# IP conversion helpers
ip_to_int() {
    local a b c d
    IFS=. read -r a b c d <<< "$1"
    echo $(( (a<<24) + (b<<16) + (c<<8) + d ))
}

int_to_ip() {
    local ip_int=$1
    echo "$(( (ip_int>>24)&255 )).$(( (ip_int>>16)&255 )).$(( (ip_int>>8)&255 )).$(( ip_int&255 ))"
}

start=$(ip_to_int "$NETWORK")
end=$(ip_to_int "$BROADCAST")

# Add all IPs including network and broadcast as /32
log=""
for ((i = start; i <= end; i++)); do
    ip_addr=$(int_to_ip "$i")
    log+="Adding $ip_addr/32 to $iface\n"
    nmcli connection modify "$iface" +ipv4.addresses "$ip_addr/32"
done

# Apply changes
nmcli connection down "$iface" && nmcli connection up "$iface"

# Show result
dialog --msgbox "All IPs have been added as /32 to $iface:\n\n$log" 20 70

clear
