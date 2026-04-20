#!/bin/bash
# ============================================================
#  system_cleanup.sh --- The "Toolkit Reset" Button
#  Restores system to high-performance/standard network state.
# ============================================================

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; 
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

log_info() { echo -e "${BLUE}[i]${NC} $1"; }
log_ok()   { echo -e "${GREEN}[✓]${NC} $1"; }
section()  { echo -e "\n${CYAN}${BOLD}[*] $1${NC}"; }

if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}[✗] Run with sudo.${NC}"
   exit 1
fi

# --- 1. RESTORE PERFORMANCE ---
section "RESTORING POWER PROFILE"
if command -v brightnessctl >/dev/null 2>&1; then
    log_info "Restoring full brightness..."
    brightnessctl set 100% > /dev/null
    log_ok "Display restored."
fi

if command -v bluetoothctl >/dev/null 2>&1; then
    log_info "Re-enabling Bluetooth..."
    bluetoothctl power on > /dev/null
    log_ok "Bluetooth active."
fi

# --- 2. NETWORK EMERGENCY RESET ---
section "NETWORK EMERGENCY RESET"
log_info "Restarting NetworkManager..."
systemctl restart NetworkManager
log_ok "Services refreshed."

# --- 3. DPKG/APT UNLOCK ---
section "FIXING PACKAGE LOCKS"
log_info "Checking for stale apt locks..."
rm -f /var/lib/dpkg/lock-frontend /var/lib/apt/lists/lock 2>/dev/null
log_ok "Package manager unlocked."

echo -e "\n${GREEN}${BOLD} System is back to Standard Performance Mode.${NC}"




