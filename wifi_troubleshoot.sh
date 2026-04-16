#!/bin/bash

# ============================================================
#  wifi_troubleshoot.sh — Kali Linux Network Repair Tool
#  Diagnoses and fixes Wi-Fi connectivity, blocks, and drivers.
# ============================================================

# --- 1. Variables & Colors ---
DRY_RUN=false
for arg in "$@"; do
    if [[ "$arg" == "--dry-run" ]]; then DRY_RUN=true; fi
done

# Aradhya-Approved Production Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; 
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

# --- 2. Helper Functions ---
log_info() { echo -e "${BLUE}[i]${NC} $1"; }
log_ok()   { echo -e "${GREEN}[✓]${NC} $1"; }
log_fail() { echo -e "${RED}[✗]${NC} $1"; }
section()  { echo -e "\n${CYAN}${BOLD}[*] $1${NC}"; }

# Root Check
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}[!] This script must be run as root (sudo).${NC}"
   exit 1
fi


# --- INTERFACE DISCOVERY ---
section "IDENTIFYING WIRELESS HARDWARE"

# Automatically find the first wireless interface
WIFI_IFACE=$(iw dev | awk '$1=="Interface"{print $2}' | head -n 1)

if [ -z "$WIFI_IFACE" ]; then
    log_fail "No wireless interface detected! Is your Wi-Fi card plugged in?"
    exit 1
else
    log_ok "Found wireless interface: ${BOLD}$WIFI_IFACE${NC}"
fi


# --- HARDWARE/SOFTWARE LOCKS (RFKILL) ---
section "CHECKING FOR HARDWARE & SOFTWARE LOCKS"

# Check the status of rfkill
SOFT_BLOCK=$(rfkill list all | grep -i "Soft blocked: yes")
HARD_BLOCK=$(rfkill list all | grep -i "Hard blocked: yes")

if [ -n "$SOFT_BLOCK" ]; then
    log_info "Software block detected. Attempting to unblock..."
    if [ "$DRY_RUN" = true ]; then
        log_info "[DRY-RUN] Would run: rfkill unblock wifi"
    else
        rfkill unblock wifi
        log_ok "Software blocks released."
    fi
fi

if [ -n "$HARD_BLOCK" ]; then
    log_fail "HARDWARE BLOCK DETECTED!"
    log_warn "Your Wi-Fi is disabled by a physical switch or Fn-key combo."
    log_warn "Please toggle your physical Wi-Fi switch and run the script again."
    # We don't exit here, because sometimes restarting the stack helps anyway
else
    log_ok "No hardware locks detected."
fi


# --- PHASE 3: SERVICE REFRESH (NETWORKMANAGER) ---
section "REFRESHING NETWORK SERVICES"

log_info "Toggling Wi-Fi radio via nmcli..."
if [ "$DRY_RUN" = true ]; then
    log_info "[DRY-RUN] Would run: nmcli radio wifi off && nmcli radio wifi on"
else
    nmcli radio wifi off
    sleep 1
    nmcli radio wifi on
    log_ok "Wi-Fi radio toggled."
fi

log_info "Restarting NetworkManager service..."
if [ "$DRY_RUN" = true ]; then
    log_info "[DRY-RUN] Would run: systemctl restart NetworkManager"
else
    systemctl restart NetworkManager
    # Give it a moment to initialize
    sleep 2
    log_ok "NetworkManager service restarted."
fi


# --- DRIVER RELOAD (KERNEL MODULES) ---
section "DRIVER DIAGNOSTICS & RELOAD"

# Identify the driver for our specific interface
# We use ethtool to find the 'driver' field
WIFI_DRIVER=$(ethtool -i "$WIFI_IFACE" 2>/dev/null | awk -F': ' '/driver/{print $2}')

if [ -n "$WIFI_DRIVER" ]; then
    log_info "Active driver detected: ${BOLD}$WIFI_DRIVER${NC}"
    
    # Reloading drivers is aggressive, so we guard it
    if [ "$DRY_RUN" = true ]; then
        log_info "[DRY-RUN] Would reload kernel module: modprobe -r $WIFI_DRIVER && modprobe $WIFI_DRIVER"
    else
        log_warn "Attempting to reload driver $WIFI_DRIVER (Connection will drop)..."
        modprobe -r "$WIFI_DRIVER" 2>/dev/null
        sleep 1
        if modprobe "$WIFI_DRIVER" 2>/dev/null; then
            log_ok "Driver $WIFI_DRIVER successfully reloaded."
        else
            log_fail "Failed to reload driver. You may need to reboot."
        fi
    fi
else
    log_info "Could not identify driver for $WIFI_IFACE. Skipping driver reload."
fi



# --- PHASE 5: CONNECTIVITY TEST ---
section "TESTING CONNECTIVITY"

log_info "Refreshing DHCP lease for $WIFI_IFACE..."
if [ "$DRY_RUN" = true ]; then
    log_info "[DRY-RUN] Would run: dhclient -v $WIFI_IFACE"
else
    # Release the old IP first
    dhclient -r "$WIFI_IFACE" 2>/dev/null
    # Request a new one
    if dhclient "$WIFI_IFACE" 2>/dev/null; then
        log_ok "IP address renewed."
    else
        log_warn "DHCP renewal failed. You might need to check your router."
    fi
fi

log_info "Performing Ping test to 8.8.8.8..."
if ping -c 1 -W 2 8.8.8.8 > /dev/null 2>&1; then
    log_ok "Internet connectivity: ${GREEN}ONLINE${NC}"
else
    log_fail "Internet connectivity: ${RED}OFFLINE${NC}"
    log_info "Hint: Try connecting to a different network or check SSID credentials."
fi

# --- FINAL SUMMARY ---
echo -e "\n${BOLD}${CYAN}╔══════════════════════════════════════════════════════╗"
echo -e "║  WIFI TROUBLESHOOTING COMPLETE                       ║"
echo -e "║  Interface: $WIFI_IFACE                              ║"
echo -e "║  Driver:    ${WIFI_DRIVER:-Unknown}                  ║"
echo -e "║                                                      ║"
echo -e "║  Status: Check the NetworkManager applet to connect. ║"
echo -e "╚══════════════════════════════════════════════════════╝${NC}"
