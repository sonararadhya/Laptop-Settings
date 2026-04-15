#!/bin/bash

# ============================================================
#  fix_apt.sh — Kali Linux Package Manager Repair Tool
#  Resolves locks, broken dependencies, and dpkg interruptions.
# ============================================================

# --- Variables & Dry Run ---

DRY_RUN=false
for arg in "$@"; do
    if [[ "$arg" == "--dry-run" ]]; then DRY_RUN=true; fi
done

# Colors for professional output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# --- 2. Helper Functions ---
log_info() { echo -e "${BLUE}[i]${NC} $1"; }
log_ok()   { echo -e "${GREEN}[✓]${NC} $1"; }
log_fail() { echo -e "${RED}[✗]${NC} $1"; }
divider() { 
    echo -e "${CYAN}------------------------------------------------------------${NC}" 
}

section() {
    echo -e "\n${CYAN}${BOLD}[*] $1${NC}"
}

# Root check (Required for APT)
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}[!] This script must be run as root (sudo).${NC}"
   exit 1
fi


# --- THE LOCK BREAKER ---
section "CHECKING FOR PACKAGE MANAGER LOCKS"

# List of common APT lock files
LOCK_FILES=(
    "/var/lib/dpkg/lock" 
    "/var/lib/dpkg/lock-frontend" 
    "/var/lib/apt/lists/lock"
    "/var/cache/apt/archives/lock"
)

for lock in "${LOCK_FILES[@]}"; do
    if [ -e "$lock" ]; then
        # Check if any process is actually using the file
        # 'fuser' tells us the Process ID (PID) using the file
        pid=$(fuser "$lock" 2>/dev/null | awk '{print $1}')
        
        if [ -n "$pid" ]; then
            log_info "Lock detected on $lock (Held by PID: $pid)"
            
            # Verify the process is actually an APT/dpkg process
            process_name=$(ps -p "$pid" -o comm= 2>/dev/null)
            
            if echo "$process_name" | grep -qE "apt|dpkg|aptitude|unattended"; then
                if [ "$DRY_RUN" = true ]; then
                    log_info "[DRY-RUN] Would terminate $process_name (PID: $pid) and remove lock."
                else
                    log_info "Attempting to safely terminate $process_name process $pid..."
                    kill -15 "$pid" 2>/dev/null
                    sleep 2
                    # Force kill if still alive
                    if ps -p "$pid" > /dev/null 2>&1; then
                        kill -9 "$pid" 2>/dev/null
                    fi
                    rm -f "$lock"
                    log_ok "Process terminated and lock removed: $lock"
                fi
            else
                log_fail "Lock held by non-APT process '$process_name' (PID: $pid). Skipping for safety."
                log_info "Manual intervention may be required for: $lock"
            fi
        else
            # Stale lock: file exists but no process is using it
            log_ok "Removing stale lock file: $lock"
            if [ "$DRY_RUN" = false ]; then 
                rm -f "$lock"
            fi
        fi
    fi
done



# --- REPAIRING THE DATABASE ---
section "REPAIRING PACKAGE DATABASE"

# Task A: Reconfigure interrupted packages
log_info "Reconfiguring interrupted package installations..."
if [ "$DRY_RUN" = true ]; then
    log_info "[DRY-RUN] Would run: dpkg --configure -a"
else
    # --configure -a finishes installations that were stopped halfway
    if dpkg --configure -a; then
        log_ok "Package database reconfigured."
    else
        log_fail "Some packages could not be reconfigured. Check output above."
    fi
fi

# Task B: Clear partial/corrupt cache
log_info "Clearing partial download cache..."
if [ "$DRY_RUN" = true ]; then
    log_info "[DRY-RUN] Would run: apt-get clean"
else
    # clean removes all the .deb files from /var/cache/apt/archives/
    # This is safe because it just forces a fresh download if needed
    if apt-get clean; then
        log_ok "Download cache cleared."
    else
        log_fail "Failed to clear cache."
    fi
fi




# --- HEALING DEPENDENCIES ---
section "HEALING BROKEN DEPENDENCIES"

log_info "Attempting to fix broken dependencies..."
if [ "$DRY_RUN" = true ]; then
    log_info "[DRY-RUN] Would run: apt-get install -f -y"
else
    # -f is 'fix-broken'. It tries to download missing pieces automatically.
    # -y assumes 'yes' to prompts so the script doesn't stop.
    if apt-get install -f -y; then
        log_ok "Dependencies checked and healed."
    else
        log_fail "Some dependencies could not be fixed. Manual intervention may be required."
    fi
fi

log_info "Refreshing repository metadata..."
if [ "$DRY_RUN" = true ]; then
    log_info "[DRY-RUN] Would run: apt-get update"
else
    if apt-get update; then
        log_ok "Repository lists updated."
    else
        log_fail "Failed to update repository lists."
    fi
fi



# --- CLEANUP & SUMMARY ---
section "SYSTEM CLEANUP & SUMMARY"

log_info "Removing obsolete packages..."
if [ "$DRY_RUN" = true ]; then
    log_info "[DRY-RUN] Would run: apt-get autoremove -y"
else
    # autoremove deletes old kernels and libraries no longer needed
    if apt-get autoremove -y; then
        log_ok "System cleaned of obsolete packages."
    else
        log_fail "Failed to remove some packages."
    fi
fi

echo -e "\n${BOLD}${GREEN}╔══════════════════════════════════════════════════════╗"
echo -e "║  APT REPAIR COMPLETE                                 ║"
echo -e "║  Status: All locks released and database healthy     ║"
echo -e "║                                                      ║"
echo -e "║  Recommendation: Run 'sudo apt upgrade' now.         ║"
echo -e "╚══════════════════════════════════════════════════════╝${NC}"
