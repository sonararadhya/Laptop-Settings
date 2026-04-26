#!/bin/bash
# ============================================================
#  setup.sh --- Toolkit Orchestrator & Installer
#  The entry point for the Laptop-Settings environment.
#  Version: 3.1 (Minor fixes applied)
# ============================================================

# [C3] Strict mode: exit on error, undefined vars, pipe failures
set -euo pipefail

# ── Color definitions ──────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ── Log file ───────────────────────────────────────────────
LOG_FILE="/var/log/toolkit_setup.log"

# ── Helper functions ───────────────────────────────────────

section() {
    echo -e "\n${CYAN}${BOLD}>>> $1${NC}"
    log_action "SECTION: $1"
}

log_action() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE" 2>/dev/null || true
}

error_exit() {
    echo -e "${RED}[✗] ERROR: $1${NC}" >&2
    log_action "ERROR: $1"
    exit 1
}

# ── Script integrity check ─────────────────────────────────

verify_check_deps() {
    [ -f "./check_deps.sh" ]  || error_exit "check_deps.sh not found in current directory!"
    [ -r "./check_deps.sh" ]  || error_exit "check_deps.sh is not readable!"
    head -n 1 "./check_deps.sh" | grep -Eq '^#!.*bash' \
        || error_exit "check_deps.sh does not appear to be a valid bash script!"
    log_action "check_deps.sh integrity check passed"
}

# ── Package extraction (POSIX-safe) ───────────────────────
# [P1] Uses grep -oE + sed instead of grep -oP (Perl regex, GNU-only).
#
# CONTRACT [F3]: check_deps.sh MUST emit missing packages on a line formatted as:
#   INSTALL: curl net-tools isc-dhcp-client
#
# If that line is absent (all deps satisfied, or format mismatch), this
# function returns empty string and the installer silently skips installation —
# which is the correct behaviour when deps are satisfied, but will also silently
# skip if check_deps.sh changes its output format.
#
# To verify the contract is still honoured after editing check_deps.sh, run:
#   bash check_deps.sh | grep '^INSTALL:'
# and confirm it produces the expected line when deps are missing.

extract_packages() {
    local output="$1"
    # Match structured "INSTALL: pkg1 pkg2 ..." prefix — not free-form prose.
    # [C4] This is intentionally strict to avoid matching injected/comment lines.
    echo "$output" \
        | grep -oE '^INSTALL: [a-z0-9][a-z0-9 \-]*' \
        | sed 's/^INSTALL: //' \
        | head -n 1 \
        || true
}

# ── Validate package names ─────────────────────────────────
# Ensures every token is a sane Debian package name before apt sees it.

validate_packages() {
    local pkg
    for pkg in "$@"; do
        if [[ ! "$pkg" =~ ^[a-z0-9][a-z0-9+\.\-]+$ ]]; then
            error_exit "Invalid package name detected: '$pkg'. Aborting installation."
        fi
    done
}

# =============================================================
#  PRE-FLIGHT CHECKS
# =============================================================

section "INITIALIZING TOOLKIT SETUP"

# Must run as root
if [[ $EUID -ne 0 ]]; then
    error_exit "Setup must be run with sudo or as root."
fi

log_action "Setup initiated by: ${SUDO_USER:-root}"

# Must run from the toolkit root directory
[ -f "./setup.sh" ] || error_exit "Must be run from the toolkit root directory!"

# [M2] Debian check — now asks explicitly before continuing on foreign OS
if [ ! -f /etc/debian_version ]; then
    echo -e "${YELLOW}[!] Warning: Non-Debian system detected. APT commands may fail.${NC}"
    log_action "WARNING: Non-Debian system detected"
    read -rp "Continue anyway? (type 'yes' to proceed): " os_confirm
    if [[ "$os_confirm" != "yes" ]]; then
        echo -e "${BLUE}[i] Setup aborted by user.${NC}"
        log_action "Aborted by user on non-Debian system"
        exit 0
    fi
fi

# =============================================================
#  PERMISSION MANAGEMENT
# =============================================================

section "SECURING SCRIPT PERMISSIONS"

# [C2] [M1] Build whitelist automatically from git index (falls back to find).
# This avoids both the security hole of chmod +x *.sh and the maintenance
# burden of a hardcoded array.
#
# FIX [F1]: git ls-files exits 0 with empty output when git is installed but
# the directory is not a git repo. The old "|| find" pattern would never
# trigger in that case. We now probe with git rev-parse first.

echo -e "${BLUE}[i] Detecting trusted scripts...${NC}"

if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    mapfile -t TRUSTED_SCRIPTS < <(git ls-files '*.sh')
    log_action "Script discovery: using git ls-files"
else
    mapfile -t TRUSTED_SCRIPTS < <(find . -maxdepth 2 -name '*.sh' -type f)
    log_action "Script discovery: using find (not a git repo)"
fi

if [ ${#TRUSTED_SCRIPTS[@]} -eq 0 ]; then
    echo -e "${YELLOW}[!] No .sh scripts found to permission.${NC}"
else
    for script in "${TRUSTED_SCRIPTS[@]}"; do
        if [ -f "$script" ]; then
            chmod +x "$script"
            echo -e "${GREEN}  ✓ ${script}${NC}"
            log_action "Made executable: $script"
        fi
    done
fi

# =============================================================
#  DEPENDENCY RESOLUTION
# =============================================================

section "RUNNING DEPENDENCY AUDIT"

verify_check_deps

echo -e "${BLUE}[i] Executing dependency audit...${NC}"

# Capture output; allow non-zero exit from check_deps (signals missing deps)
AUDIT_OUTPUT=""
AUDIT_OUTPUT=$(bash ./check_deps.sh 2>&1) || true

echo "$AUDIT_OUTPUT"

# [P1] POSIX-safe extraction — no grep -oP
PKG_STRING=$(extract_packages "$AUDIT_OUTPUT")

# [S1] Store packages in an array, not a plain string
PACKAGES=()
if [ -n "$PKG_STRING" ]; then
    read -ra PACKAGES <<< "$PKG_STRING"
fi

if [ ${#PACKAGES[@]} -eq 0 ]; then
    echo -e "\n${GREEN}[✓] No missing dependencies found. System is healthy.${NC}"
    log_action "No missing dependencies detected"
else
    echo -e "\n${YELLOW}[!] Missing packages: ${PACKAGES[*]}${NC}"
    log_action "Missing packages: ${PACKAGES[*]}"

    # Show exactly what will be done — no surprises
    echo -e "${CYAN}${BOLD}Proposed installation:${NC}"
    echo -e "${BLUE}  1. apt update${NC}"
    echo -e "${BLUE}  2. apt install -y ${PACKAGES[*]}${NC}"

    read -rp "Proceed with installation? (type 'yes' to confirm): " install_confirm

    if [[ "$install_confirm" == "yes" ]]; then

        # [S1] Validate every package name before touching apt
        validate_packages "${PACKAGES[@]}"

        echo -e "\n${BLUE}[i] Updating package lists...${NC}"
        log_action "Executing: apt update"

        # [C1] Direct apt calls — no eval, no shell injection surface
        if apt update; then
            echo -e "${GREEN}[✓] Package lists updated${NC}"

            echo -e "\n${BLUE}[i] Installing: ${PACKAGES[*]}${NC}"
            log_action "Executing: apt install -y ${PACKAGES[*]}"

            # [S1] Properly quoted array expansion — no shellcheck suppress needed
            if apt install -y "${PACKAGES[@]}"; then
                echo -e "${GREEN}[✓] Installation completed successfully${NC}"
                log_action "Installation successful: ${PACKAGES[*]}"
            else
                log_action "ERROR: Installation failed for: ${PACKAGES[*]}"
                error_exit "Package installation failed. Check your network and repository config."
            fi
        else
            error_exit "Failed to update package lists. Check your network connection."
        fi

    else
        echo -e "${YELLOW}[i] Installation skipped. Some tools may not work correctly.${NC}"
        log_action "Installation skipped by user"
    fi
fi


# --- SERVICE INSTALLATION ---
section "BACKGROUND MONITORING SERVICE"

SERVICE_NAME="toolkit-monitor.service"
SERVICE_PATH="/etc/systemd/system/$SERVICE_NAME"
DAEMON_PATH="$(pwd)/toolkit_monitor.sh"

read -p "Install background health-monitor service? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    log_info "Creating systemd unit file..."
    
    # Generate the service file dynamically with the correct path
    cat <<EOF > $SERVICE_NAME
[Unit]
Description=Kali Toolkit System Health Monitor
After=network.target

[Service]
ExecStart=/usr/bin/bash $DAEMON_PATH
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

    # Move to system directory and enable
    mv $SERVICE_NAME $SERVICE_PATH
    systemctl daemon-reload
    systemctl enable $SERVICE_NAME
    systemctl start $SERVICE_NAME
    
    log_ok "Service installed and started successfully."
    log_info "Monitor logs: tail -f /var/log/toolkit_monitor.log"
else
    log_info "Skipping background service installation."
fi


# =============================================================
#  FINAL VERIFICATION
# =============================================================

section "FINAL VERIFICATION"

echo -e "${BLUE}[i] Running post-install audit...${NC}"

# [S2] Use exit code to detect missing deps — not string-matching stdout.
# check_deps.sh must exit 0 when all deps are satisfied, non-zero otherwise.
POST_AUDIT_EXIT=0
POST_AUDIT=$(bash ./check_deps.sh 2>&1) || POST_AUDIT_EXIT=$?

echo "$POST_AUDIT"

if [ "$POST_AUDIT_EXIT" -ne 0 ]; then
    echo -e "\n${YELLOW}[!] Some dependencies are still missing. Review the output above.${NC}"
    log_action "WARNING: Post-install audit reports missing dependencies (exit $POST_AUDIT_EXIT)"
else
    echo -e "\n${GREEN}${BOLD}[✓] All dependencies satisfied!${NC}"
    log_action "All dependencies satisfied"
fi

# =============================================================
#  COMPLETION
# =============================================================

section "SETUP COMPLETE"

echo -e "${GREEN}${BOLD}The toolkit is ready for use!${NC}"
echo -e "${BLUE}Next steps:${NC}"
echo -e "  • Start with:      ${CYAN}sudo bash network_dashboard.sh${NC}"
echo -e "  • View logs:       ${CYAN}sudo cat $LOG_FILE${NC}"
echo -e "  • Check deps:      ${CYAN}bash check_deps.sh${NC}"

log_action "Setup completed"
exit 0
