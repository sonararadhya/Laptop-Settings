#!/bin/bash
# ============================================================
#  network_dashboard.sh --- Live Traffic Analytics
# ============================================================
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; 
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}[✗] Run with sudo.${NC}"
   exit 1
fi

# ============================================================
# ROBUST INTERFACE DETECTION
# ============================================================
detect_interface() {
    # Get all UP interfaces, excluding virtual/loopback
    local candidates=$(ip -o link show up | \
        awk -F': ' '{print $2}' | \
        grep -Ev '^(lo|docker|veth|br-|virbr|vmnet|vbox|tun|tap)')
    
    # No suitable interfaces found
    if [ -z "$candidates" ]; then
        echo -e "${RED}[✗] No suitable network interfaces found.${NC}" >&2
        echo -e "${YELLOW}[!] Available interfaces:${NC}" >&2
        ip -o link show | awk -F': ' '{print "    " $2}' >&2
        return 1
    fi
    
    # Count available candidates
    local count=$(echo "$candidates" | wc -l)
    
    # Single interface: use it
    if [ "$count" -eq 1 ]; then
        echo "$candidates"
        return 0
    fi
    
    # Multiple interfaces: prioritize wireless (wlan, wlp, wl)
    local wireless=$(echo "$candidates" | grep -E '^(wlan|wlp|wl)')
    if [ -n "$wireless" ]; then
        echo "$wireless" | head -n1
        return 0
    fi
    
    # Fallback: use first ethernet interface
    echo "$candidates" | head -n1
}

# Allow manual interface override via argument
if [ -n "$1" ]; then
    INTERFACE="$1"
    # Validate interface exists and is UP
    if ! ip link show "$INTERFACE" up &>/dev/null; then
        echo -e "${RED}[✗] Interface '$INTERFACE' not found or not UP.${NC}"
        echo -e "${YELLOW}[!] Try one of these:${NC}"
        ip -o link show up | awk -F': ' '{print "    " $2}'
        exit 1
    fi
else
    INTERFACE=$(detect_interface) || exit 1
fi

echo -e "${CYAN}${BOLD}[*] Starting Dashboard on interface: $INTERFACE${NC}"
echo -e "${BLUE}[i] Press Ctrl+C to stop and view summary.${NC}"
echo -e "${YELLOW}[!] Tip: Specify interface manually: sudo $0 <interface>${NC}\n"

# ============================================================
# LIVE TRAFFIC CAPTURE & ANALYSIS
# ============================================================
tcpdump -l -i "$INTERFACE" -n -q 2>/dev/null | \
awk -v grn="$GREEN" -v yel="$YELLOW" -v nc="$NC" -v cyn="$CYAN" -v bld="$BOLD" '
{
    count++;
    src=$3;
    gsub(/\.[0-9]+$/, "", src); 
    ips[src]++;
    
    printf "\r%s[✓] Packets Processed: %d | Last IP: %s%s%s   ", grn, count, yel, src, nc;
    fflush();
}
END {
    printf "\n\n%s%s--- SESSION SUMMARY ---%s\n", cyn, bld, nc
    printf "Total Packets: %d\n\n", count
    printf "%sTop Traffic Sources:%s\n", bld, nc
    
    n = asorti(ips, sorted_ips, "@val_num_desc")
    limit = (n < 5) ? n : 5
    
    for (i = 1; i <= limit; i++) {
        ip = sorted_ips[i]
        printf "  %-20s %s%d%s packets\n", ip, yel, ips[ip], nc
    }
}'
