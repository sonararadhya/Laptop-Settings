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

# Auto-detect interface
INTERFACE=$(ip -o link show | awk -F': ' '$3 !~ /lo|vir/ && $3 ~ /UP/ {print $2; exit}')

echo -e "${CYAN}${BOLD}[*] Starting Dashboard on interface: $INTERFACE${NC}"
echo -e "${BLUE}[i] Press Ctrl+C to stop and view summary.${NC}\n"

# Pass colors to AWK using -v to avoid "format string" errors
tcpdump -l -i "$INTERFACE" -n -q 2>/dev/null | \
awk -v grn="$GREEN" -v yel="$YELLOW" -v nc="$NC" -v cyn="$CYAN" -v bld="$BOLD" '
{
    count++;
    src=$3;
    gsub(/\.[0-9]+$/, "", src); 
    ips[src]++;
    
    # Live update with correctly mapped variables
    printf "\r%s [✓] Packets Processed: %d | Last IP: %s%s   ", grn, count, yel, src, nc;
}
END {
    printf "\n\n%s%s--- SESSION SUMMARY ---%s\n", cyn, bld, nc
    print "Total Packets: " count "\n"
    printf "%sTop Traffic Sources:%s\n", bld, nc
    for (ip in ips) {
        print ips[ip] " " ip
    }
}' | sort -rn | head -n 5 | awk '{printf "  %-20s %d packets\n", $2, $1}'
