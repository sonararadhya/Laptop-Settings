#!/bin/bash

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; 
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

# Helper Functions
log_info() { echo -e "${BLUE}[i]${NC} $1"; }
log_ok()   { echo -e "${GREEN}[✓]${NC} $1"; }
log_fail() { echo -e "${RED}[✗]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[!]${NC} $1"; }
section()  { echo -e "\n${CYAN}${BOLD}[*] $1${NC}"; }

# --- ROOT CHECK  ---
if [[ $EUID -ne 0 ]]; then
   log_fail "This script must be run as root (use sudo)."
   exit 1
fi

# --- BATTERY AUDIT ---
section "BATTERY HEALTH AUDIT"

BAT_PATH="/sys/class/power_supply/BAT0"

# Check if battery path exists
if [ ! -d "$BAT_PATH" ]; then
    log_fail "Battery directory not found at $BAT_PATH."
    exit 1
fi

# Read battery stats
CAPACITY=$(cat "$BAT_PATH/capacity")
STATUS=$(cat "$BAT_PATH/status")
HEALTH_FULL=$(cat "$BAT_PATH/energy_full")
HEALTH_DESIGN=$(cat "$BAT_PATH/energy_full_design")

# Calculate Health Percentage
# Formula: (Full / Design) * 100
HEALTH_PERCENT=$(( 100 * HEALTH_FULL / HEALTH_DESIGN ))

log_info "Current Charge: ${BOLD}${CAPACITY}%${NC} (${STATUS})"
log_info "Battery Health: ${BOLD}${HEALTH_PERCENT}%${NC}"

if [ "$HEALTH_PERCENT" -lt 70 ]; then
    log_warn "Battery health is degrading. Consider a replacement soon."
else
    log_ok "Battery is in good condition."
fi


# --- ECO-MODE ACTIVATION ---
section "POWER OPTIMIZATION"

if [ "$STATUS" = "Charging" ] || [ "$STATUS" = "Full" ]; then
    log_info "Power Source: ${GREEN}AC Adapter${NC}"
    log_info "System is in Performance Mode. No changes made."
else
    log_warn "Power Source: ${YELLOW}Battery${NC}"
    log_info "Activating Eco-Mode..."

    # 1. Dim the brightness (XFCE/Laptop standard)
    if command -v brightnessctl >/dev/null 2>&1; then
        log_info "Setting brightness to 30%..."
        brightnessctl set 30% > /dev/null
        log_ok "Brightness reduced."
    else
        log_info "Hint: Install 'brightnessctl' for automatic dimming."
    fi

    # 2. Check for heavy processes (CPU hogs)
    log_info "Scanning for high-CPU background tasks..."
    ps -eo pid,ppid,%cpu,comm --sort=-%cpu | head -n 6
fi

# 3. Bluetooth Toggling (Major Power Saver)
    if command -v bluetoothctl >/dev/null 2>&1; then
        log_info "Disabling Bluetooth to save power..."
        bluetoothctl power off > /dev/null
        log_ok "Bluetooth disabled."
    fi

    # 4. Keyboard Backlight (Specific to XFCE/Laptops)
    # Brightnessctl can often find the keyboard too
    KBD_DEVICE=$(brightnessctl --list | grep -i "kbd" | awk -F "'" '{print $2}' | head -n 1)
    if [ -n "$KBD_DEVICE" ]; then
        log_info "Turning off keyboard backlight..."
        brightnessctl --device="$KBD_DEVICE" set 0 > /dev/null
        log_ok "Keyboard LEDs off."
    fi

    echo -e "\n${GREEN}${BOLD}⚡ System is now in Maximum Eco-Mode.${NC}"

