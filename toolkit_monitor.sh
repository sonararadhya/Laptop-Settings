#!/bin/bash
# ============================================================
#  toolkit_monitor.sh --- Background System Health Daemon
# ============================================================
set -euo pipefail

LOG_FILE="/var/log/toolkit_monitor.log"

# ── Signal handling for graceful shutdown ──────────────────
trap 'log_event "INFO" "Daemon shutting down gracefully"; exit 0' SIGTERM SIGINT

# ── Logging function ───────────────────────────────────────
log_event() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$1] $2" >> "$LOG_FILE" 2>/dev/null || {
        echo "ERROR: Cannot write to $LOG_FILE" >&2
        exit 1
    }
}

# ── Validate required commands exist ───────────────────────
# [FIX] Added 'sed' — used in disk check but was missing from validation list
for cmd in df awk ping cat sed; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "ERROR: Required command '$cmd' not found" >&2
        exit 1
    fi
done

# ── Initialize log file ────────────────────────────────────
if ! touch "$LOG_FILE" 2>/dev/null; then
    echo "ERROR: Cannot create/access $LOG_FILE. Check permissions." >&2
    exit 1
fi
chmod 640 "$LOG_FILE" 2>/dev/null || true
log_event "INFO" "Toolkit Monitoring Daemon Started (PID: $$)"

# ── Configurable ping target ───────────────────────────────
# [FIX] Allow override via env var — some networks block 8.8.8.8
PING_TARGET="${PING_TARGET:-8.8.8.8}"

# ── Alert state tracking (prevents log flood on sustained issues) ──
# [FIX] Each alert fires once when condition is first triggered, and
# resets only when the condition clears — avoids per-minute log spam.
LAST_DISK_ALERT=0
LAST_NET_ALERT=0
LAST_BATT_ALERT=0

# ── Main monitoring loop ───────────────────────────────────
while true; do

    # ── 1. Disk Usage (alert if > 90%, suppress until condition clears) ──
    DISK_USAGE=$(df / | awk 'NR==2 {print $5}' | sed 's/%//' || echo "0")
    if [[ "$DISK_USAGE" =~ ^[0-9]+$ ]]; then
        if [ "$DISK_USAGE" -gt 90 ]; then
            if [ "$LAST_DISK_ALERT" -eq 0 ]; then
                log_event "CRITICAL" "Disk usage at ${DISK_USAGE}%! Clean up required."
                LAST_DISK_ALERT=1
            fi
        else
            LAST_DISK_ALERT=0
        fi
    fi

    # ── 2. Network Connectivity (alert once on loss, once on recovery) ──
    if ! ping -c 1 -W 2 "$PING_TARGET" &>/dev/null; then
        if [ "$LAST_NET_ALERT" -eq 0 ]; then
            log_event "WARNING" "Network connection lost or unreachable (target: $PING_TARGET)."
            LAST_NET_ALERT=1
        fi
    else
        if [ "$LAST_NET_ALERT" -eq 1 ]; then
            log_event "INFO" "Network connectivity restored."
        fi
        LAST_NET_ALERT=0
    fi

    # ── 3. Battery / Power state (if applicable) ──────────
    if [ -d "/sys/class/power_supply/BAT0" ]; then
        CAPACITY=$(cat /sys/class/power_supply/BAT0/capacity 2>/dev/null || echo "100")
        STATUS=$(cat /sys/class/power_supply/BAT0/status 2>/dev/null || echo "Unknown")

        if [[ "$CAPACITY" =~ ^[0-9]+$ ]]; then
            if [ "$CAPACITY" -lt 15 ] && [ "$STATUS" = "Discharging" ]; then
                if [ "$LAST_BATT_ALERT" -eq 0 ]; then
                    log_event "ALERT" "Battery low (${CAPACITY}%). Connect charger."
                    LAST_BATT_ALERT=1
                fi
            else
                LAST_BATT_ALERT=0
            fi
        fi
    fi

    sleep 60

done
