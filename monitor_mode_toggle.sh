#!/usr/bin/env bash
# =============================================================================
# monitor_mode_toggle.sh — Enable/Disable Wi-Fi Monitor Mode Safely
# Repo: https://github.com/sonararadhya/Laptop-Settings
# =============================================================================

set -euo pipefail

# ── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

log()    { echo -e "${CYAN}[INFO]${RESET}  $*"; }
ok()     { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn()   { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
err()    { echo -e "${RED}[ERROR]${RESET} $*" >&2; }
die()    { err "$*"; exit 1; }
dryrun() { echo -e "${YELLOW}[DRY-RUN]${RESET} (would run) $*"; }

# ── Global state ──────────────────────────────────────────────────────────────
DRY_RUN=false
IFACE=""
TMP_LOG=""      # fix [1][5]: populated by mktemp, freed by EXIT trap
RESULT_IFACE="" # fix [8]: populated for summary
RESULT_MODE=""  # fix [8]: populated for summary

# ── fix [5]: Temp file cleanup on any exit ────────────────────────────────────
cleanup() {
    [[ -n "$TMP_LOG" && -f "$TMP_LOG" ]] && rm -f "$TMP_LOG"
}
trap cleanup EXIT

# ── fix [7]: Argument parsing ─────────────────────────────────────────────────
parse_args() {
    for arg in "$@"; do
        case "$arg" in
            --dry-run|-n)
                DRY_RUN=true
                warn "DRY-RUN mode — no changes will be made."
                ;;
            -h|--help)
                echo -e "\nUsage: sudo $0 [--dry-run]\n"
                echo "  --dry-run   Show what would happen without making changes"
                echo
                exit 0
                ;;
            *)
                warn "Unknown argument: $arg"
                ;;
        esac
    done
}

# ── Root check ────────────────────────────────────────────────────────────────
[[ $EUID -eq 0 ]] || die "Run as root: sudo $0"

# ── Dependency check ──────────────────────────────────────────────────────────
check_deps() {
    for cmd in airmon-ng ip iw; do
        command -v "$cmd" &>/dev/null \
            || die "'$cmd' not found. Install aircrack-ng: apt install aircrack-ng"
    done
}

# ── fix [3]: Interface existence guard ───────────────────────────────────────
assert_iface_exists() {
    local iface="$1"
    ip link show "$iface" &>/dev/null \
        || die "Interface '$iface' not found — it may have been renamed, unplugged, or taken down."
}

# ── Detect wireless interfaces ────────────────────────────────────────────────
detect_interfaces() {
    iw dev 2>/dev/null | awk '/Interface/{print $2}'
}

# ── List wireless interfaces ──────────────────────────────────────────────────
list_interfaces() {
    echo -e "\n${BOLD}Available wireless interfaces:${RESET}"
    local i=1
    while IFS= read -r iface; do
        local mode
        mode=$(iw dev "$iface" info 2>/dev/null | awk '/type/{print $2}')
        printf "  %d) %-15s [mode: %s]\n" "$i" "$iface" "${mode:-unknown}"
        ((i++))
    done < <(detect_interfaces)
    echo
}

# ── Select interface ──────────────────────────────────────────────────────────
select_interface() {
    local ifaces
    mapfile -t ifaces < <(detect_interfaces)
    [[ ${#ifaces[@]} -eq 0 ]] && die "No wireless interfaces found."

    list_interfaces

    if [[ ${#ifaces[@]} -eq 1 ]]; then
        IFACE="${ifaces[0]}"
        log "Auto-selected: $IFACE"
    else
        read -rp "Select interface number [1-${#ifaces[@]}]: " sel
        # fix [6]: trim whitespace before validating
        sel=$(echo "$sel" | xargs)
        [[ "$sel" =~ ^[0-9]+$ ]] && (( sel >= 1 && sel <= ${#ifaces[@]} )) \
            || die "Invalid selection: '$sel'"
        IFACE="${ifaces[$((sel-1))]}"
    fi

    # fix [3]: confirm the chosen interface still exists at this moment
    assert_iface_exists "$IFACE"
}

# ── fix [9]: Detect resulting monitor interface name ─────────────────────────
# Priority: 1) airmon-ng log brackets  2) ip link scan  3) conventional fallback
detect_mon_iface() {
    local iface="$1" log_file="$2"

    # Method 1: parse bracketed name from airmon-ng output
    # fix [2]: POSIX grep -o instead of grep -P '\[\K...'
    local from_log
    from_log=$(grep -o '\[[^]]*\]' "$log_file" 2>/dev/null \
        | tr -d '[]' \
        | grep -E '^[a-zA-Z]' \
        | tail -1)
    if [[ -n "$from_log" ]] && ip link show "$from_log" &>/dev/null 2>&1; then
        echo "$from_log"
        return
    fi

    # Method 2: scan ip link for any interface that looks like a monitor variant
    local from_ip
    from_ip=$(ip link 2>/dev/null \
        | awk -F': ' '/^[0-9]+:/{print $2}' \
        | grep -E "^${iface}mon$|^mon${iface}$|^${iface}[0-9]+mon$" \
        | head -1)
    if [[ -n "$from_ip" ]] && ip link show "$from_ip" &>/dev/null 2>&1; then
        echo "$from_ip"
        return
    fi

    # Method 3: conventional ${iface}mon fallback
    echo "${iface}mon"
}

# ── fix [4]: systemctl wrappers (guard with command -v) ──────────────────────
svc_stop() {
    local svc="$1"
    if ! command -v systemctl &>/dev/null; then
        warn "systemctl not available; cannot stop $svc (non-systemd system?)."
        return
    fi
    $DRY_RUN && { dryrun "systemctl stop $svc"; return; }
    systemctl stop "$svc" 2>/dev/null \
        && ok "$svc stopped." \
        || warn "$svc was not running or could not be stopped."
}

svc_start() {
    local svc="$1"
    if ! command -v systemctl &>/dev/null; then
        warn "systemctl not available; cannot start $svc."
        return
    fi
    $DRY_RUN && { dryrun "systemctl start $svc"; return; }
    systemctl start "$svc" 2>/dev/null \
        && ok "$svc started." \
        || warn "Could not start $svc."
}

# ── Enable monitor mode ───────────────────────────────────────────────────────
enable_monitor() {
    local iface="$1"

    # fix [3]: re-verify at the last moment before touching anything
    assert_iface_exists "$iface"

    local mode
    mode=$(iw dev "$iface" info 2>/dev/null | awk '/type/{print $2}')
    if [[ "$mode" == "monitor" ]]; then
        warn "$iface is already in monitor mode."
        RESULT_IFACE="$iface"
        RESULT_MODE="monitor (already set)"
        return 0
    fi

    if $DRY_RUN; then
        dryrun "systemctl stop NetworkManager wpa_supplicant"
        dryrun "airmon-ng check kill"
        dryrun "airmon-ng start $iface"
        log "DRY-RUN: would rename $iface → ${iface}mon"
        RESULT_IFACE="${iface}mon"
        RESULT_MODE="monitor"
        return 0
    fi

    log "Stopping conflicting services (NetworkManager, wpa_supplicant) ..."
    svc_stop NetworkManager
    svc_stop wpa_supplicant

    log "Killing interfering processes via airmon-ng ..."
    airmon-ng check kill 2>/dev/null \
        || warn "airmon-ng check kill had warnings (continuing)."

    log "Enabling monitor mode on $iface ..."

    # fix [1]: mktemp — private, no race condition, no predictable path
    TMP_LOG=$(mktemp)

    local airmon_ok=false
    airmon-ng start "$iface" 2>&1 | tee "$TMP_LOG" | grep -qiE "monitor mode|enabled" \
        && airmon_ok=true || true

    if $airmon_ok; then
        # fix [2][9]: robust, POSIX-safe interface name detection
        local mon_iface
        mon_iface=$(detect_mon_iface "$iface" "$TMP_LOG")
        ok "Monitor mode enabled on: ${BOLD}${mon_iface}${RESET}"
        echo -e "\n${BOLD}Usage examples:${RESET}"
        echo -e "  airodump-ng $mon_iface"
        echo -e "  aireplay-ng --test $mon_iface"
        RESULT_IFACE="$mon_iface"
        RESULT_MODE="monitor"
    else
        warn "airmon-ng output unclear; using manual fallback ..."
        # fix [3]: re-check — USB dongle might have been re-enumerated
        assert_iface_exists "$iface"
        ip link set "$iface" down         || die "Cannot bring $iface down."
        iw dev "$iface" set type monitor  || die "Cannot set monitor type on $iface."
        ip link set "$iface" up           || die "Cannot bring $iface up."
        ok "Monitor mode enabled on $iface (manual fallback)."
        RESULT_IFACE="$iface"
        RESULT_MODE="monitor"
    fi
}

# ── Disable monitor mode ──────────────────────────────────────────────────────
disable_monitor() {
    local iface="$1"

    # fix [3]: verify before proceeding
    assert_iface_exists "$iface"

    if $DRY_RUN; then
        dryrun "airmon-ng stop $iface"
        dryrun "systemctl start NetworkManager wpa_supplicant"
        log "DRY-RUN: would restore $iface → managed"
        RESULT_IFACE="${iface%mon}"
        RESULT_MODE="managed"
        return 0
    fi

    log "Disabling monitor mode on $iface ..."

    # fix [1]: mktemp for per-invocation temp file
    TMP_LOG=$(mktemp)
    local stop_ok=false
    airmon-ng stop "$iface" 2>&1 | tee "$TMP_LOG" \
        | grep -qiE "disabled|removed|managed" && stop_ok=true || true

    if $stop_ok; then
        ok "Monitor mode disabled via airmon-ng."
    else
        warn "airmon-ng stop unclear; using manual fallback ..."
        assert_iface_exists "$iface"
        ip link set "$iface" down         || die "Cannot bring $iface down."
        iw dev "$iface" set type managed  || die "Cannot set managed mode on $iface."
        ip link set "$iface" up           || die "Cannot bring $iface up."
        ok "Interface $iface set to managed mode (manual fallback)."
    fi

    # fix [2][9]: detect the restored (un-renamed) interface name
    local restored
    restored=$(grep -o '\[[^]]*\]' "$TMP_LOG" 2>/dev/null \
        | tr -d '[]' | grep -E '^[a-zA-Z]' | tail -1)
    # Strip 'mon' suffix as best-effort fallback if parse failed
    restored="${restored:-${iface%mon}}"

    log "Restarting NetworkManager ..."
    svc_start NetworkManager
    log "Restarting wpa_supplicant ..."
    svc_start wpa_supplicant

    RESULT_IFACE="$restored"
    RESULT_MODE="managed"
}

# ── fix [8]: Summary block ────────────────────────────────────────────────────
print_summary() {
    local iface_display="${RESULT_IFACE:-${IFACE}}"
    local mode_display="${RESULT_MODE:-unknown}"
    local dry_display="$( $DRY_RUN && echo 'YES (no changes made)' || echo 'no' )"

    echo
    echo -e "┌──────────────────────────────────────────┐"
    printf  "│  %-40s│\n" "Result Summary"
    echo -e "├──────────────────────────────────────────┤"
    printf  "│  Interface : %-27s│\n" "$iface_display"
    printf  "│  Mode      : %-27s│\n" "$mode_display"
    printf  "│  Dry-run   : %-27s│\n" "$dry_display"
    echo -e "└──────────────────────────────────────────┘"
    echo
}

# ── Main ──────────────────────────────────────────────────────────────────────
main() {
    parse_args "$@"
    check_deps

    echo -e "\n${BOLD}${CYAN}=== Wi-Fi Monitor Mode Toggle ===${RESET}\n"
    $DRY_RUN && warn "Running in DRY-RUN mode — no system changes will be made.\n"

    select_interface

    local mode
    mode=$(iw dev "$IFACE" info 2>/dev/null | awk '/type/{print $2}')

    if [[ "$mode" == "monitor" ]]; then
        warn "$IFACE is currently in MONITOR mode."
        read -rp "Disable monitor mode and restore managed mode? [y/N]: " ans
        # fix [6]: trim whitespace before comparison
        ans=$(echo "$ans" | xargs)
        if [[ "${ans,,}" == "y" ]]; then
            disable_monitor "$IFACE"
        else
            log "Aborted by user."
            RESULT_IFACE="$IFACE"
            RESULT_MODE="$mode (unchanged)"
        fi
    else
        log "$IFACE is currently in ${mode:-managed} mode."
        read -rp "Enable monitor mode on $IFACE? [y/N]: " ans
        # fix [6]: trim whitespace before comparison
        ans=$(echo "$ans" | xargs)
        if [[ "${ans,,}" == "y" ]]; then
            enable_monitor "$IFACE"
        else
            log "Aborted by user."
            RESULT_IFACE="$IFACE"
            RESULT_MODE="${mode:-managed} (unchanged)"
        fi
    fi

    # fix [8]: always print summary regardless of path taken
    print_summary
}

main "$@"
