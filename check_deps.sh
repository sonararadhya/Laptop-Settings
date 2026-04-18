#!/bin/bash
# ============================================================
#  check_deps.sh --- Toolkit Dependency & Health Auditor
#  Ensures all required binaries and hardware are available.
# ============================================================

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; 
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

log_info() { echo -e "${BLUE}[i]${NC} $1"; }
log_ok()   { echo -e "${GREEN}[✓]${NC} $1"; }
log_fail() { echo -e "${RED}[✗]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[!]${NC} $1"; }
section()  { echo -e "\n${CYAN}${BOLD}[*] $1${NC}"; }

# --- TOOL DEFINITIONS ---
CORE_TOOLS=("grep" "awk" "sed" "sudo")
WIFI_TOOLS=("iw" "nmcli" "rfkill" "ethtool" "dhclient")
APT_TOOLS=("apt" "dpkg")
RECOVERY_TOOLS=("file")

# Binary-to-Package mapping (critical for correct installation commands)
declare -A BINARY_TO_PACKAGE=(
    # Core utilities
    ["grep"]="grep"
    ["awk"]="gawk"
    ["sed"]="sed"
    ["sudo"]="sudo"
    # Networking tools
    ["iw"]="iw"
    ["nmcli"]="network-manager"
    ["rfkill"]="rfkill"
    ["ethtool"]="ethtool"
    ["dhclient"]="isc-dhcp-client"
    # Package management
    ["apt"]="apt"
    ["dpkg"]="dpkg"
    # Recovery tools
    ["file"]="file"
)

check_binary() {
    local tool=$1
    if command -v "$tool" >/dev/null 2>&1; then
        log_ok "Binary found: ${BOLD}$tool${NC}"
        return 0
    else
        log_fail "Binary missing: ${BOLD}$tool${NC}"
        return 1
    fi
}

section "AUDITING SYSTEM DEPENDENCIES"

MISSING_COUNT=0
declare -a MISSING_BINARIES

# Core tools
log_info "Checking Core System Utilities..."
for tool in "${CORE_TOOLS[@]}"; do
    if ! check_binary "$tool"; then
        MISSING_BINARIES+=("$tool")
        ((MISSING_COUNT++))
    fi
done

# Networking tools
log_info "Checking Networking Utilities..."
for tool in "${WIFI_TOOLS[@]}"; do
    if ! check_binary "$tool"; then
        MISSING_BINARIES+=("$tool")
        ((MISSING_COUNT++))
    fi
done

# Package tools
log_info "Checking Package Utilities..."
for tool in "${APT_TOOLS[@]}"; do
    if ! check_binary "$tool"; then
        MISSING_BINARIES+=("$tool")
        ((MISSING_COUNT++))
    fi
done

echo -e "\n---"
if [ "$MISSING_COUNT" -eq 0 ]; then
    log_ok "All required binaries are present."
else
    log_warn "Detected $MISSING_COUNT missing binaries."
fi

# --- HARDWARE CHECK ---
section "AUDITING HARDWARE CAPABILITIES"

# Wireless hardware detection (with error handling)
WIRELESS_FOUND=false
if command -v lspci >/dev/null 2>&1; then
    if lspci 2>/dev/null | grep -Ei "wireless|network|802.11" > /dev/null; then
        log_ok "Wireless Hardware: ${GREEN}Detected (PCI)${NC}"
        WIRELESS_FOUND=true
    fi
fi

if ! $WIRELESS_FOUND && command -v lsusb >/dev/null 2>&1; then
    if lsusb 2>/dev/null | grep -Ei "wireless|network|802.11" > /dev/null; then
        log_ok "Wireless Hardware: ${GREEN}Detected (USB)${NC}"
        WIRELESS_FOUND=true
    fi
fi

if ! $WIRELESS_FOUND; then
    log_warn "Wireless Hardware: ${YELLOW}Not Found${NC} (Ignore if using Ethernet)"
fi

# Battery detection
if [ -d "/sys/class/power_supply/BAT0" ] || [ -d "/sys/class/power_supply/BAT1" ]; then
    log_ok "Battery Hardware: ${GREEN}Detected${NC}"
    BAT_STATUS="present"
else
    log_warn "Battery Hardware: ${YELLOW}Not Found${NC} (Desktop or VM mode)"
    BAT_STATUS="absent"
fi

# Virtualization check (with error handling)
if command -v systemd-detect-virt >/dev/null 2>&1; then
    VIRT_TYPE=$(systemd-detect-virt 2>/dev/null)
    if [ "$VIRT_TYPE" != "none" ] && [ -n "$VIRT_TYPE" ]; then
        log_info "Environment: ${CYAN}Virtual Machine ($VIRT_TYPE)${NC}"
        log_warn "Some hardware scripts may have limited functionality in a VM."
    else
        log_ok "Environment: ${GREEN}Physical Hardware (Bare Metal)${NC}"
    fi
else
    log_info "Environment: ${CYAN}Unknown (systemd-detect-virt not available)${NC}"
fi

# --- INSTALL SUGGESTION ---
section "REPAIR & INSTALLATION GUIDE"

if [ "$MISSING_COUNT" -eq 0 ]; then
    log_ok "System is fully optimized for the Kali Linux Toolkit."
    log_info "No further action required."
else
    log_warn "Your system is missing $MISSING_COUNT required tools."
    echo -e "\n${BOLD}To install all missing dependencies, run:${NC}"
    
    # Build install list using correct package names
    INSTALL_PACKAGES=""
    declare -A SEEN_PACKAGES  # Prevent duplicate packages
    
    for binary in "${MISSING_BINARIES[@]}"; do
        if [ -n "${BINARY_TO_PACKAGE[$binary]}" ]; then
            package="${BINARY_TO_PACKAGE[$binary]}"
            # Only add if we haven't seen this package before
            if [ -z "${SEEN_PACKAGES[$package]}" ]; then
                INSTALL_PACKAGES+="$package "
                SEEN_PACKAGES[$package]=1
            fi
        else
            log_warn "Warning: No package mapping found for binary '$binary'"
        fi
    done
    
    # Print the install command with correct package names
    if [ -n "$INSTALL_PACKAGES" ]; then
        # Sort packages alphabetically for cleaner output
        SORTED_PACKAGES=$(echo "$INSTALL_PACKAGES" | tr ' ' '\n' | sort -u | tr '\n' ' ')
        echo -e "${CYAN}sudo apt update && sudo apt install -y $SORTED_PACKAGES${NC}"
    else
        log_warn "Could not determine packages to install."
    fi
fi

# --- FINAL STATUS ---
echo -e "\n${BOLD}${CYAN}------------------------------------------------------------${NC}"
if [ "$MISSING_COUNT" -eq 0 ] && [ "$BAT_STATUS" = "present" ]; then
    echo -e "${GREEN}  READY: System is verified for Hardware & Software tasks.${NC}"
elif [ "$MISSING_COUNT" -eq 0 ]; then
    echo -e "${YELLOW}  READY: Software verified (Battery not detected).${NC}"
else
    echo -e "${YELLOW}  CAUTION: Limited functionality detected.${NC}"
fi
echo -e "${BOLD}${CYAN}------------------------------------------------------------${NC}"
