# Kali Linux Toolkit & XFCE Utilities

A modular suite of Bash scripts designed for system maintenance, security auditing, data recovery, and UI automation in Kali Linux environments.

## Featured Tools

| Script | Category | Description | Status |
|---|---|---|---|
| `check_deps.sh` | Setup | Audits system for required binaries and hardware capabilities. |  New |
| `wifi_troubleshoot.sh` | Networking | Fixes wlo1/wlan0 connectivity, RFKill blocks, and driver hangs. | ✅ Stable |
| `fix_apt.sh` | Maintenance | Safely resolves DPKG locks, broken dependencies, and update errors. | ✅ Stable |
| `log_analyzer.sh` | Security | Audits failed logins, sudo usage, and kernel health logs. | ✅ Stable |
| `file_recovery.sh` | Recovery | Identifies and restores corrupted media and mismatched MIME types. | ✅ Stable |
| `system_audit.sh` | Diagnostics | Deep-dive diagnostic tool to identify system bottlenecks. | ✅ Stable |
| `auto_cursor.sh` | UI/UX | Automatically cycles through XFCE cursors every 2 seconds. | ✅ Stable |

## Key Features

- **Dry Run Support:** Most maintenance scripts include a `--dry-run` flag to preview changes safely.
- **Auto-Discovery:** Tools like `wifi_troubleshoot.sh` automatically detect hardware (e.g., `wlo1`) and drivers (e.g., `iwlwifi`).
- **Production-Grade Safety:** Includes process validation to prevent accidental termination of system-critical tasks.
- **Rich Logging:** Standardized color-coded output for Information, Success, and Critical alerts.

## Installation & Usage

### 1. Clone and Enter

```bash
git clone https://github.com/sonararadhya/Laptop-Settings.git
cd Laptop-Settings
```

### 2. Make Scripts Executable

```bash
chmod +x *.sh
```

### 3. Execute a Repair or Audit

Run the script normally to apply fixes or generate reports:

```bash
sudo ./fix_apt.sh
sudo ./log_analyzer.sh
```

> All maintenance and diagnostic scripts require root privileges (`sudo`) to interact with hardware and system logs.

### 4. Run with Safety Preview (Recommended)

Before applying any fixes, see what the script would do using the dry-run flag:

```bash
sudo ./wifi_troubleshoot.sh --dry-run
```

---
*📝 Last maintained: April 19, 2026 at 03:21 UTC*
