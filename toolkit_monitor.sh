#!/bin/bash
# ============================================================
#  toolkit_monitor.sh --- Background System Health Daemon
# ============================================================

LOG_FILE="/var/log/toolkit_monitor.log"

log_event() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$1] $2" >> "$LOG_FILE"
}

# Ensure log file exists
touch "$LOG_FILE" && chmod 644 "$LOG_FILE"

log_event "INFO" "Toolkit Monitoring Daemon Started."

while true; do
    # 1. Check Disk Usage (Alert if > 90%)
    DISK_USAGE=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
    if [ "$DISK_USAGE" -gt 90 ]; then
        log_event "CRITICAL" "Disk usage at ${DISK_USAGE}%! Clean up required."
    fi

    # 2. Check Network Connectivity
    if ! ping -c 1 8.8.8.8 &>/dev/null; then
        log_event "WARNING" "Network connection lost."
    fi

    # 3. Check Battery/Power state (if applicable)
    if [ -d "/sys/class/power_supply/BAT0" ]; then
        CAPACITY=$(cat /sys/class/power_supply/BAT0/capacity)
        STATUS=$(cat /sys/class/power_supply/BAT0/status)
        if [ "$CAPACITY" -lt 15 ] && [ "$STATUS" == "Discharging" ]; then
            log_event "ALERT" "Battery low (${CAPACITY}%). Connect charger."
        fi
    fi

    sleep 60 # Run every minute
done
