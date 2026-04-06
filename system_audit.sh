#!/bin/bash

# ============================================================
#  system_audit.sh \u2014 Kali Linux System Diagnostic Tool
#  Run as root: sudo bash system_audit.sh
# ============================================================

REPORT="$(dirname "$0")/system_report_$(date +%Y%m%d_%H%M%S).txt"

# Colours for terminal output
RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

divider() { echo "============================================================" >> "$REPORT"; }
section() {
    echo -e "\n${CYAN}${BOLD}[*] $1...${NC}"
    echo "" >> "$REPORT"
    divider
    echo "  $1" >> "$REPORT"
    divider
}

# \u2500\u2500 Root check \u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}[!] This script must be run as root.  \u2192  sudo bash system_audit.sh${NC}"
    exit 1
fi

echo -e "${BOLD}${GREEN}"
echo "  \u2588\u2588\u2588\u2588\u2588\u2588\u2557 \u2588\u2588\u2557 \u2588\u2588\u2588\u2588\u2588\u2557  \u2588\u2588\u2588\u2588\u2588\u2588\u2557 \u2588\u2588\u2588\u2557   \u2588\u2588\u2557 \u2588\u2588\u2588\u2588\u2588\u2588\u2557 \u2588\u2588\u2588\u2588\u2588\u2588\u2588\u2557"
echo "  \u2588\u2588\u2554\u2550\u2550\u2588\u2588\u2557\u2588\u2588\u2551\u2588\u2588\u2554\u2550\u2550\u2588\u2588\u2557\u2588\u2588\u2554\u2550\u2550\u2550\u2550\u255d \u2588\u2588\u2588\u2588\u2557  \u2588\u2588\u2551\u2588\u2588\u2554\u2550\u2550\u2550\u2588\u2588\u2557\u2588\u2588\u2554\u2550\u2550\u2550\u2550\u255d"
echo "  \u2588\u2588\u2551  \u2588\u2588\u2551\u2588\u2588\u2551\u2588\u2588\u2588\u2588\u2588\u2588\u2588\u2551\u2588\u2588\u2551  \u2588\u2588\u2588\u2557\u2588\u2588\u2554\u2588\u2588\u2557 \u2588\u2588\u2551\u2588\u2588\u2551   \u2588\u2588\u2551\u2588\u2588\u2588\u2588\u2588\u2588\u2588\u2557"
echo "  \u2588\u2588\u2551  \u2588\u2588\u2551\u2588\u2588\u2551\u2588\u2588\u2554\u2550\u2550\u2588\u2588\u2551\u2588\u2588\u2551   \u2588\u2588\u2551\u2588\u2588\u2551\u255a\u2588\u2588\u2557\u2588\u2588\u2551\u2588\u2588\u2551   \u2588\u2588\u2551\u255a\u2550\u2550\u2550\u2550\u2588\u2588\u2551"
echo "  \u2588\u2588\u2588\u2588\u2588\u2588\u2554\u255d\u2588\u2588\u2551\u2588\u2588\u2551  \u2588\u2588\u2551\u255a\u2588\u2588\u2588\u2588\u2588\u2588\u2554\u255d\u2588\u2588\u2551 \u255a\u2588\u2588\u2588\u2588\u2551\u255a\u2588\u2588\u2588\u2588\u2588\u2588\u2554\u255d\u2588\u2588\u2588\u2588\u2588\u2588\u2588\u2551"
echo "  \u255a\u2550\u2550\u2550\u2550\u2550\u255d \u255a\u2550\u255d\u255a\u2550\u255d  \u255a\u2550\u255d \u255a\u2550\u2550\u2550\u2550\u2550\u255d \u255a\u2550\u255d  \u255a\u2550\u2550\u2550\u255d \u255a\u2550\u2550\u2550\u2550\u2550\u255d \u255a\u2550\u2550\u2550\u2550\u2550\u2550\u255d"
echo -e "${NC}"
echo -e "${BOLD}        Kali Linux System Audit \u2014 $(date)${NC}\n"

# Initialise report file
{
    echo "============================================================"
    echo "       KALI LINUX SYSTEM AUDIT REPORT"
    echo "       Generated : $(date)"
    echo "       Hostname  : $(hostname)"
    echo "       User      : $(whoami)"
    echo "============================================================"
} > "$REPORT"

echo -e "${GREEN}[+] Report will be saved to:${NC} $REPORT\n"


# \u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550
#  1. CRASH & FORCED-SHUTDOWN ANALYSIS
# \u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550
section "CRASH & FORCED-SHUTDOWN ANALYSIS"

{
    echo ""
    echo "\u2500\u2500 Last 20 system boots / shutdowns \u2500\u2500"
    last -x 2>/dev/null | head -40

    echo ""
    echo "\u2500\u2500 Abnormal shutdowns (last-b) \u2500\u2500"
    last -x -F 2>/dev/null | grep -iE "crash|reboot|shutdown|halt" | head -20

    echo ""
    echo "\u2500\u2500 Kernel panic / OOM messages (dmesg) \u2500\u2500"
    dmesg --time-format iso 2>/dev/null | grep -iE \
        "panic|oom|killed|segfault|call trace|bug:|null pointer|oops|hardware error|mce|machine check" \
        | tail -60

    echo ""
    echo "\u2500\u2500 Journal: critical & emergency entries \u2500\u2500"
    journalctl -p 0..2 --no-pager -n 60 2>/dev/null

    echo ""
    echo "\u2500\u2500 Journal: last boot errors \u2500\u2500"
    journalctl -b -p err --no-pager -n 80 2>/dev/null

    echo ""
    echo "\u2500\u2500 Systemd failed units \u2500\u2500"
    systemctl --failed --no-pager 2>/dev/null

    echo ""
    echo "\u2500\u2500 /var/log/syslog (last 100 lines) \u2500\u2500"
    tail -100 /var/log/syslog 2>/dev/null || echo "syslog not available"

    echo ""
    echo "\u2500\u2500 Kernel crash dumps (kdump) \u2500\u2500"
    ls -lh /var/crash/ 2>/dev/null || echo "No crash dumps found in /var/crash/"

    echo ""
    echo "\u2500\u2500 APPORT crash reports \u2500\u2500"
    ls -lh /var/crash/*.crash 2>/dev/null || echo "No .crash files found"
} >> "$REPORT"

echo -e "${GREEN}  [\u2713] Crash analysis complete${NC}"


# \u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550
#  2. MALWARE DETECTION
# \u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550
section "MALWARE DETECTION"

{
    echo ""
    echo "\u2500\u2500 Suspicious SUID/SGID binaries \u2500\u2500"
    find / -xdev \( -perm -4000 -o -perm -2000 \) -type f 2>/dev/null | \
        while read -r f; do
            md5sum "$f" 2>/dev/null
        done

    echo ""
    echo "\u2500\u2500 World-writable files (outside /tmp /proc /sys /dev) \u2500\u2500"
    find / -xdev -not \( -path "/tmp/*" -o -path "/proc/*" \
         -o -path "/sys/*" -o -path "/dev/*" \) \
         -perm -0002 -type f 2>/dev/null | head -40

    echo ""
    echo "\u2500\u2500 Hidden files in /tmp and /var/tmp \u2500\u2500"
    find /tmp /var/tmp -name ".*" 2>/dev/null

    echo ""
    echo "\u2500\u2500 Processes with deleted executables (potential fileless malware) \u2500\u2500"
    ls -la /proc/*/exe 2>/dev/null | grep "(deleted)" | head -20

    echo ""
    echo "\u2500\u2500 Unusual processes listening on network (cross-check with ss) \u2500\u2500"
    for pid in $(ls /proc | grep -E '^[0-9]+$'); do
        exe=$(readlink /proc/$pid/exe 2>/dev/null)
        if [[ -n "$exe" && ! "$exe" == /usr/* && ! "$exe" == /bin/* \
              && ! "$exe" == /sbin/* && ! "$exe" == /lib* \
              && ! "$exe" == /opt/* && ! "$exe" == "(deleted)" ]]; then
            echo "  PID $pid \u2192 $exe"
        fi
    done

    echo ""
    echo "\u2500\u2500 Crontabs (root + all users) \u2500\u2500"
    crontab -l 2>/dev/null && echo "---"
    for u in $(cut -f1 -d: /etc/passwd); do
        ct=$(crontab -u "$u" -l 2>/dev/null)
        [[ -n "$ct" ]] && echo "=== $u ===" && echo "$ct"
    done
    ls -la /etc/cron* /var/spool/cron/ 2>/dev/null

    echo ""
    echo "\u2500\u2500 Suspicious /etc/passwd entries (UID 0 non-root) \u2500\u2500"
    awk -F: '($3 == 0 && $1 != "root") { print "ALERT: "$0 }' /etc/passwd

    echo ""
    echo "\u2500\u2500 Recently modified system binaries (past 7 days) \u2500\u2500"
    find /bin /sbin /usr/bin /usr/sbin -newer /etc/passwd \
         -mtime -7 -type f 2>/dev/null

    echo ""
    echo "\u2500\u2500 /etc/hosts anomalies \u2500\u2500"
    cat /etc/hosts

    echo ""
    echo "\u2500\u2500 Loaded kernel modules \u2500\u2500"
    lsmod

    echo ""
    echo "\u2500\u2500 Rkhunter scan \u2500\u2500"
    if command -v rkhunter &>/dev/null; then
        rkhunter --check --sk --nocolors 2>/dev/null | tail -60
    else
        echo "rkhunter not installed. Install with: apt install rkhunter"
    fi

    echo ""
    echo "\u2500\u2500 Chkrootkit scan \u2500\u2500"
    if command -v chkrootkit &>/dev/null; then
        chkrootkit 2>/dev/null | grep -iE "infected|warning|suspicious" | head -40
    else
        echo "chkrootkit not installed. Install with: apt install chkrootkit"
    fi

    echo ""
    echo "\u2500\u2500 ClamAV quick scan (/tmp /var/tmp /home) \u2500\u2500"
    if command -v clamscan &>/dev/null; then
        clamscan -r --bell --no-summary /tmp /var/tmp /home 2>/dev/null | \
            grep -iE "found|infected|warning"
    else
        echo "ClamAV not installed. Install with: apt install clamav"
    fi
} >> "$REPORT"

echo -e "${GREEN}  [\u2713] Malware detection complete${