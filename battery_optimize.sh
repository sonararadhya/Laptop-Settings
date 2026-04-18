#!/bin/bash

# ============================================================
#  battery_optimize.sh --- Battery Health & Power Manager
#  Audits battery status and activates eco-mode when needed.
# ============================================================

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; 
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

# Helper Functions
log_info() { echo -e "${BLUE}[i]${NC} $1"; }
log_ok()   { echo -e "${GREEN}[✓]${NC} $1"; }
log_fail() { echo -e "${RED}[✗]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[!]${NC} $1"; }
section()  { echo -e "\n${CYAN}${BOLD}[*] $1${NC}"; }

# --- ROOT CHECK ---
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
    log_info "This system may be a desktop or virtual machine."
    exit 1
fi

# Safely read battery stats with error handling
if [ ! -r "$BAT_PATH/capacity" ] || [ ! -r "$BAT_PATH/status" ]; then
    log_fail "Cannot read battery status files. Check permissions."
    exit 1
fi

CAPACITY=$(cat "$BAT_PATH/capacity" 2>/dev/null)
STATUS=$(cat "$BAT_PATH/status" 2>/dev/null)

# Validate that we got valid data
if [ -z "$CAPACITY" ] || [ -z "$STATUS" ]; then
    log_fail "Failed to read battery information."
    exit 1
fi

# Validate capacity is a number
if ! [[ "$CAPACITY" =~ ^[0-9]+$ ]]; then
    log_fail "Invalid capacity value: $CAPACITY"
    exit 1
fi

log_info "Current Charge: ${BOLD}${CAPACITY}%${NC} (${STATUS})"

# Battery health calculation (with safety checks)
if [ -r "$BAT_PATH/energy_full" ] && [ -r "$BAT_PATH/energy_full_design" ]; then
    HEALTH_FULL=$(cat "$BAT_PATH/energy_full" 2>/dev/null)
    HEALTH_DESIGN=$(cat "$BAT_PATH/energy_full_design" 2>/dev/null)
    
    # Validate numeric values and check for division by zero
    if [[ "$HEALTH_FULL" =~ ^[0-9]+$ ]] && [[ "$HEALTH_DESIGN" =~ ^[0-9]+$ ]] && [ "$HEALTH_DESIGN" -gt 0 ]; then
        HEALTH_PERCENT=$(( 100 * HEALTH_FULL / HEALTH_DESIGN ))
        log_info "Battery Health: ${BOLD}${HEALTH_PERCENT}%${NC}"
        
        if [ "$HEALTH_PERCENT" -lt 70 ]; then
            log_warn "Battery health is degrading. Consider a replacement soon."
        else
            log_ok "Battery is in good condition."
        fi
    else
        log_warn "Could not calculate battery health (invalid or missing data)."
    fi
else
    log_warn "Battery health metrics not available on this system."
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
        if brightnessctl set 30% > /dev/null 2>&1; then
            log_ok "Brightness reduced."
        else
            log_warn "Failed to adjust brightness."
        fi
    else
        log_info "Hint: Install 'brightnessctl' for automatic dimming."
    fi

    # 2. Check for heavy processes (CPU hogs)
    log_info "Scanning for high-CPU background tasks..."
    if command -v ps >/dev/null 2>&1; then
        ps -eo pid,ppid,%cpu,comm --sort=-%cpu 2>/dev/null | head -n 6
    fi

    # 3. Bluetooth Toggling (Major Power Saver)
    if command -v bluetoothctl >/dev/null 2>&1; then
        log_info "Disabling Bluetooth to save power..."
        if bluetoothctl power off > /dev/null 2>&1; then
            log_ok "Bluetooth disabled."
        else
            log_warn "Failed to disable Bluetooth (may already be off)."
        fi
    fi

    # 4. Keyboard Backlight (Specific to XFCE/Laptops)
    if command -v brightnessctl >/dev/null 2>&1; then
        # Safely parse brightnessctl output
        KBD_DEVICE=$(brightnessctl --list 2>/dev/null | grep -i "kbd" | awk -F "'" '{print $2}' | head -n 1)
        if [ -n "$KBD_DEVICE" ]; then
            log_info "Turning off keyboard backlight..."
            if brightnessctl --device="$KBD_DEVICE" set 0 > /dev/null 2>&1; then
                log_ok "Keyboard LEDs off."
            else
                log_warn "Failed to adjust keyboard backlight."
            fi
        fi
    fi

    echo -e "\n${GREEN}${BOLD}⚡ System is now in Maximum Eco-Mode.${NC}"
fi
