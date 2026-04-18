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


# --- BINARY & TOOL SCANNER ---

# Define the required tools for each module
CORE_TOOLS=("grep" "awk" "sed" "sudo")
WIFI_TOOLS=("iw" "nmcli" "rfkill" "ethtool" "dhclient")
APT_TOOLS=("apt" "dpkg")
RECOVERY_TOOLS=("file") # Used for MIME-type checking

# Map binaries to their actual package names
declare -A BINARY_TO_PACKAGE=(
    ["iw"]="iw"
    ["nmcli"]="network-manager"
    ["rfkill"]="rfkill"
    ["ethtool"]="ethtool"
    ["dhclient"]="isc-dhcp-client"
    ["file"]="file"
    ["grep"]="grep"
    ["awk"]="gawk"
    ["sed"]="sed"
    ["sudo"]="sudo"
    ["apt"]="apt"
    ["dpkg"]="dpkg"
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

# 1. Check Core Tools
log_info "Checking Core System Utilities..."
for tool in "${CORE_TOOLS[@]}"; do
    if ! check_binary "$tool"; then
        MISSING_BINARIES+=("$tool")
        ((MISSING_COUNT++))
    fi
done

# 2. Check Networking Tools (for wifi_troubleshoot.sh)
log_info "Checking Networking Utilities..."
for tool in "${WIFI_TOOLS[@]}"; do
    if ! check_binary "$tool"; then
        MISSING_BINARIES+=("$tool")
        ((MISSING_COUNT++))
    fi
done

# 3. Check Package Management Tools (for fix_apt.sh)
log_info "Checking Package Utilities..."
for tool in "${APT_TOOLS[@]}"; do
    if ! check_binary "$tool"; then
        MISSING_BINARIES+=("$tool")
        ((MISSING_COUNT++))
    fi
done

# Summary of Phase 1
echo -e "\n---"
if [ "$MISSING_COUNT" -eq 0 ]; then
    log_ok "All required binaries are present."
else
    log_warn "Detected $MISSING_COUNT missing binaries."
fi



# --- HARDWARE FACT-FINDER ---
section "AUDITING HARDWARE CAPABILITIES"

# 1. Check for Wireless Hardware
if command -v lspci >/dev/null 2>&1 && lspci | grep -Ei "wireless|network|802.11" > /dev/null; then
    log_ok "Wireless Hardware: ${GREEN}Detected (PCI)${NC}"
elif command -v lsusb >/dev/null 2>&1 && lsusb | grep -Ei "wireless|network|802.11" > /dev/null; then
    log_ok "Wireless Hardware: ${GREEN}Detected (USB)${NC}"
else
    log_warn "Wireless Hardware: ${YELLOW}Not Found${NC} (Ignore if using Ethernet)"
fi

# 2. Check for Battery (for upcoming battery_optimize.sh)
if [ -d "/sys/class/power_supply/BAT0" ] || [ -d "/sys/class/power_supply/BAT1" ]; then
    log_ok "Battery Hardware: ${GREEN}Detected${NC}"
    BAT_STATUS="present"
else
    log_warn "Battery Hardware: ${YELLOW}Not Found${NC} (Desktop or VM mode)"
    BAT_STATUS="absent"
fi

# 3. Virtualization Detection
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


# --- THE AUTO-HEALER ---
section "REPAIR & INSTALLATION GUIDE"

if [ "$MISSING_COUNT" -eq 0 ]; then
    log_ok "System is fully optimized for the Kali Linux Toolkit."
    log_info "No further action required."
else
    log_warn "Your system is missing $MISSING_COUNT required tools."
    echo -e "\n${BOLD}To install all missing dependencies, run the following command:${NC}"
    
    # Build the install list using proper package names
    INSTALL_PACKAGES=""
    declare -A SEEN_PACKAGES  # Prevent duplicates
    
    for binary in "${MISSING_BINARIES[@]}"; do
        if [ -n "${BINARY_TO_PACKAGE[$binary]}" ]; then
            package="${BINARY_TO_PACKAGE[$binary]}"
            # Only add if we haven't seen this package before
            if [ -z "${SEEN_PACKAGES[$package]}" ]; then
                INSTALL_PACKAGES+="$package "
                SEEN_PACKAGES[$package]=1
            fi
        else
            log_warn "No package mapping for binary: $binary"
        fi
    done
    
    # Print the command with proper package names
    if [ -n "$INSTALL_PACKAGES" ]; then
        echo -e "${CYAN}sudo apt update && sudo apt install -y $INSTALL_PACKAGES${NC}"
    else
        log_warn "Could not determine packages to install."
    fi
fi

# Final Toolkit Readiness Check
echo -e "\n${BOLD}${CYAN}------------------------------------------------------------${NC}"
if [ "$MISSING_COUNT" -eq 0 ] && [ "$BAT_STATUS" = "present" ]; then
    echo -e "${GREEN}  READY: System is verified for Hardware & Software tasks.${NC}"
elif [ "$MISSING_COUNT" -eq 0 ]; then
    echo -e "${YELLOW}  READY: Software verified (Battery not detected).${NC}"
else
    echo -e "${YELLOW}  CAUTION: Limited functionality detected.${NC}"
fi
echo -e "${BOLD}${CYAN}------------------------------------------------------------${NC}"
