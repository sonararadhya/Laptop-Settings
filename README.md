# Kali Linux Toolkit & XFCE Utilities

A modular suite of Bash scripts designed for system maintenance, security auditing, data recovery, and UI automation in Kali Linux environments.

## Featured Tools

| Script | Category | Description | Status |
|---|---|---|---|
| 'toolkit_monitor.sh' | Monitoring | Always-on systemd daemon for real-time health & connectivity logging. | New |
| `setup.sh` | Orchestration | Master installer that configures permissions and resolves all dependencies. | Stable |
| `check_deps.sh` | Setup | Audits system for required binaries and hardware capabilities. | New |
| `network_dashboard.sh` | Security | Live traffic analytics dashboard tracking packet counts and "Top Talker" IPs. | Stable |
| `battery_optimize.sh` | Hardware | "Eco-Mode" for laptops: health audits, brightness control, and service management. | Stable |
| `system_cleanup.sh` | Maintainance | Emergency recovery tool to restore network states and clear system locks. | Stable |
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

### 5. Monitoring & Persistence

The toolkit includes a background health monitor that runs as a systemd service. This ensures your system stays under audit even when the terminal is closed.

#### Service Management
The setup.sh orchestrator automatically generates and installs the toolkit-monitor.service. You can manage it using standard system commands:

1. Check Status: ```bash 
sudo systemctl status toolkit-monitor.service

2. View Live Logs: ```bash 
tail -f /var/log/toolkit_monitor.log

3. Restart Service: ```bash
sudo systemctl restart toolkit-monitor.service

```

#### Event Logging
The daemon tracks the following events in /var/log/toolkit_monitor.log:

1. [CRITICAL] Disk usage exceeding 90%

2. [WARNING] Network connectivity drops

3. [ALERT] Low battery states (<15%)

*📝 Last maintained: April 26, 2026 at 20:22 UTC*
