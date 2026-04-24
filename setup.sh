#!/bin/bash
# ============================================================
#  setup.sh --- Toolkit Orchestrator & Installer
#  The entry point for the Laptop-Settings environment.
# ============================================================

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; 
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

section() { echo -e "\n${CYAN}${BOLD}>>> $1${NC}"; }

# --- PRE-FLIGHT CHECKS ---
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}[✗] Setup must be run with sudo.${NC}"
   exit 1
fi

section "INITIALIZING TOOLKIT SETUP"

# Ensure it is a Debian-based environment
if [ ! -f /etc/debian_version ]; then
    echo -e "${YELLOW}[!] Warning: Non-Debian system detected. APT commands may fail.${NC}"
fi

# --- PERMISSION SYNC ---
echo -e "${BLUE}[i] Securing script permissions...${NC}"
chmod +x *.sh
echo -e "${GREEN}[✓] All scripts are now executable.${NC}"

# --- DEPENDENCY RESOLUTION ---
section "RUNNING DEPENDENCY AUDIT"

# Run the existing auditor and capture the output
if [ ! -f "./check_deps.sh" ]; then
    echo -e "${RED}[✗] Critical Error: check_deps.sh not found in current directory!${NC}"
    exit 1
fi

# Run auditor and look for the 'apt install' suggestion line
INSTALL_SUGGESTION=$(bash check_deps.sh | grep "sudo apt update" | sed 's/\x1b\[[0-9;]*m//g')

if [ -z "$INSTALL_SUGGESTION" ]; then
    echo -e "${GREEN}[✓] No missing dependencies found. System is healthy.${NC}"
else
    echo -e "${YELLOW}[!] Missing dependencies detected.${NC}"
    read -p "Would you like to install them now? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}[i] Executing installation...${NC}"
        eval "$INSTALL_SUGGESTION"
    else
        echo -e "${YELLOW}[i] Skipping installation. Some tools may not work.${NC}"
    fi
fi

# --- FINAL VERIFICATION ---
section "FINAL VERIFICATION"
bash check_deps.sh

echo -e "\n${GREEN}${BOLD}Setup Complete! The toolkit is ready for use.${NC}"
echo -e "${BLUE}Tip: Start with 'sudo bash network_dashboard.sh' to see live traffic.${NC}"
