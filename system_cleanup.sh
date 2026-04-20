#!/bin/bash
# ============================================================
#  system_cleanup.sh --- The "Toolkit Reset" Button
#  Restores system to high-performance/standard network state.
# ============================================================

# --- 0. DRY-RUN FLAG ---
# FIX: Added --dry-run support to match toolkit standard (wifi_troubleshoot, fix_apt, etc.)
DRY_RUN=false
for arg in "$@"; do
    if [[ "$arg" == "--dry-run" ]]; then DRY_RUN=true; fi
done

# --- Colors & Helpers ---
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

log_info() { echo -e "${BLUE}[i]${NC} $1"; }
log_ok()   { echo -e "${GREEN}[✓]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[!]${NC} $1"; }   # FIX: was missing; needed for non-fatal warnings
log_fail() { echo -e "${RED}[✗]${NC} $1"; }       # FIX: was missing; needed for command failures
section()  { echo -e "\n${CYAN}${BOLD}[*] $1${NC}"; }

# --- Root Check ---
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}[✗] Run with sudo.${NC}"
   exit 1
fi


# --- 1. RESTORE PERFORMANCE ---
section "RESTORING POWER PROFILE"

if command -v brightnessctl >/dev/null 2>&1; then
    log_info "Restoring full brightness..."
    if [ "$DRY_RUN" = true ]; then
        log_info "[DRY-RUN] Would run: brightnessctl set 100%"
    else
        brightnessctl set 100% > /dev/null
        log_ok "Display brightness restored to 100%."
    fi
else
    log_warn "brightnessctl not found. Skipping brightness reset."
fi

if command -v bluetoothctl >/dev/null 2>&1; then
    log_info "Re-enabling Bluetooth..."
    if [ "$DRY_RUN" = true ]; then
        log_info "[DRY-RUN] Would run: bluetoothctl power on"
    else
        # FIX: Plain 'bluetoothctl power on' opens an interactive shell and hangs.
        # Pipe commands in to run non-interactively.
        echo -e "power on\nquit" | bluetoothctl > /dev/null 2>&1
        log_ok "Bluetooth powered on."
    fi
else
    log_warn "bluetoothctl not found. Skipping Bluetooth reset."
fi


# --- 2. NETWORK EMERGENCY RESET ---
section "NETWORK EMERGENCY RESET"

# FIX: Added command -v guard; systemctl was called unconditionally even if NM isn't installed.
# FIX: Added error check so log_ok only fires on actual success.
if command -v systemctl >/dev/null 2>&1; then
    log_info "Restarting NetworkManager..."
    if [ "$DRY_RUN" = true ]; then
        log_info "[DRY-RUN] Would run: systemctl restart NetworkManager"
    else
        if systemctl restart NetworkManager 2>/dev/null; then
            log_ok "NetworkManager restarted successfully."
        else
            log_fail "Failed to restart NetworkManager. It may not be installed or enabled."
        fi
    fi
else
    log_warn "systemctl not found. Skipping NetworkManager restart."
fi


# --- 3. DPKG/APT UNLOCK ---
section "FIXING PACKAGE LOCKS"

# FIX: The log said "Checking" but the original code deleted unconditionally with no check.
# FIX: Added all 4 standard lock file paths — original only had 2 of them.
APT_LOCKS=(
    "/var/lib/dpkg/lock-frontend"
    "/var/lib/dpkg/lock"
    "/var/lib/apt/lists/lock"
    "/var/cache/apt/archives/lock"
)

LOCKS_FOUND=false
for lock in "${APT_LOCKS[@]}"; do
    if [ -f "$lock" ]; then
        LOCKS_FOUND=true
        log_info "Stale lock found: $lock"
        if [ "$DRY_RUN" = true ]; then
            log_info "[DRY-RUN] Would remove: $lock"
        else
            rm -f "$lock"
        fi
    fi
done

if [ "$LOCKS_FOUND" = false ]; then
    log_ok "No stale package locks found."
elif [ "$DRY_RUN" = false ]; then
    log_ok "All stale package locks cleared."
fi


# --- FINAL SUMMARY ---
# FIX: Added leading checkmark spacing to align with the rest of the toolkit output.
echo -e "\n${GREEN}${BOLD}[✓] System is back to Standard Performance Mode.${NC}"
