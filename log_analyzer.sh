#!/bin/bash

# ============================================================
#  log_analyzer.sh — Kali Linux System & Security Auditor
#  Parses system logs for errors, failed logins, and changes.
# ============================================================

# --- Variables ---
MAX_LINES=20  # Limits output so your terminal doesn't explode
LOG_AUTH="/var/log/auth.log"
LOG_SYS="/var/log/syslog"

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; 
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

# --- 2. Helper Functions ---
section() { echo -e "\n${CYAN}${BOLD}[*] $1${NC}"; }
log_info() { echo -e "${BLUE}[i]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[!]${NC} $1"; }
log_crit() { echo -e "${RED}[CRITICAL]${NC} $1"; }

# Root check
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}[!] Run as root to access system logs.${NC}"
   exit 1
fi

# --- SECURITY AUDIT ---
section "SECURITY: FAILED LOGIN ATTEMPTS"

if [ -f "$LOG_AUTH" ]; then
    # Look for "Failed password" or "authentication failure"
    FAILED_LOGINS=$(grep -i "failed" "$LOG_AUTH" | tail -n "$MAX_LINES")
    
    if [ -z "$FAILED_LOGINS" ]; then
        echo -e "${GREEN}  No failed login attempts detected.${NC}"
    else
        log_warn "Recent failed attempts detected:"
        echo "$FAILED_LOGINS" | awk '{print "  → " $1, $2, $3, $11}' # Prints Date, Time, and User/IP
    fi
else
    log_info "Auth log not found. skipping..."
fi

# Check for sudo usage
section "SECURITY: RECENT SUDO COMMANDS"
grep "COMMAND=" "$LOG_AUTH" 2>/dev/null | tail -n 5 | awk -F'COMMAND=' '{print "  → " $2}'


# --- SYSTEM HEALTH (Kernel & Hardware) ---
section "SYSTEM HEALTH: KERNEL ERRORS"

# dmesg is the kernel ring buffer
K_ERRORS=$(dmesg --level=err,crit,alert 2>/dev/null | tail -n 5)

if [ -z "$K_ERRORS" ]; then
    echo -e "${GREEN}  Kernel reports no recent critical errors.${NC}"
else
    log_crit "Hardware/Kernel issues found:"
    echo "$K_ERRORS" | sed 's/^/  / '
fi


# --- AUDIT TRAIL (PACKAGE CHANGES) ---
section "AUDIT: RECENT PACKAGE CHANGES"

LOG_DPKG="/var/log/dpkg.log"

if [ -f "$LOG_DPKG" ]; then
    # Look for "install" or "remove" actions
    CHANGES=$(grep -E "install |remove " "$LOG_DPKG" | tail -n 10)
    
    if [ -z "$CHANGES" ]; then
        echo -e "${GREEN}  No recent package changes found.${NC}"
    else
        log_info "Last 10 package operations:"
        echo "$CHANGES" | awk '{print "  → " $1, $2, ":", $3, $4}'
    fi
else
    log_info "DPKG log not found."
fi

echo -e "\n${BOLD}${CYAN}------------------------------------------------------------${NC}"
echo -e "${BOLD}${GREEN}  LOG ANALYSIS COMPLETE${NC}"
echo -e "${BOLD}${CYAN}------------------------------------------------------------${NC}"
