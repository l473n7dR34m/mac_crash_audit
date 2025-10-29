# macOS Crash Audit - Setup & Usage Guide

## Overview
This script performs a comprehensive audit of your Mac for:
- System crashes and kernel panics
- Hardware errors (disk, memory, SMC, T2 chip)
- GPU crashes and graphics issues
- SEP panics and pink screen problems
- Thermal issues and overheating
- Watchdog timeouts (system hangs)
- Third-party driver conflicts
- Update and firmware problems

It creates a detailed report and automatically collects full system diagnostics when critical issues are detected.

## First-time Setup
1. Download the `mac_crash_audit.sh` script
2. Open Terminal (find it in Applications > Utilities > Terminal)
3. Navigate to your Downloads folder (or wherever the script is saved):
   ```bash
   cd ~/Downloads
   ```
4. Make the script executable:
   ```bash
   chmod +x mac_crash_audit.sh
   ```

## Usage Options

### Standard Audit
```bash
./mac_crash_audit.sh
```

### Specify a Timeframe
```bash
./mac_crash_audit.sh 7  # Checks the past 7 days
```

### Run with Admin Privileges
For full system access (recommended):
```bash
sudo ./mac_crash_audit.sh
```

## What the Script Checks

1. **FileVault and system status** - Basic system information
2. **SEP panic and critical errors** - Pink screen issues, kernel traps
3. **Kernel panics** - System crashes with detailed panic logs
4. **Hardware errors** - Disk I/O, memory, NVMe, SMC, T2 chip failures
5. **GPU issues** - Graphics crashes, WindowServer failures
6. **Watchdog timeouts** - System hangs and unresponsive processes
7. **Thermal issues** - Overheating, CPU throttling, fan problems
8. **Third-party kernel extensions** - Non-Apple drivers that may cause conflicts
9. **Recent crash reports** - Frequency analysis of app crashes
10. **Last shutdown cause** - Why your Mac last shut down or restarted
11. **Repeated crashes** - Pattern analysis of recurring issues
12. **Power and firmware issues** - Wake/sleep problems
13. **Update volume errors** - Software update failures

## Output Files

1. **Audit Report**:
   - Saved to: `~/Desktop/mac_crash_audit_YYYYMMDD_HHMMSS.txt`
   - Contains comprehensive analysis of all system issues

2. **System Diagnostics** (if critical issues are detected):
   - Saved to: `/var/tmp/sysdiagnose_*.tar.gz`
   - Copy saved to: `~/Desktop/crash_issue_sysdiagnose_YYYYMMDD_HHMMSS.tar.gz`
   - Collection requires admin privileges and may take several minutes

## For IT Support Teams

If assisting a user remotely:
1. Have them download the script
2. Guide them to Terminal
3. Run: `cd Desktop && sudo bash mac_crash_audit.sh 7`
4. Collect both files from their Desktop
5. Review the audit report first - it will indicate the type of issue

## Understanding Results

- **"None found"** = That check passed, no issues
- **Panic logs listed** = System crashes occurred
- **Hardware errors** = Potential physical component failure
- **Third-party kexts listed** = May need driver updates
- **Thermal issues** = Possible overheating/cooling problems

## Notes

- The script requires admin permissions (sudo) to access all system logs
- No data is sent outside your computer
- Collection is completely local
- If critical issues are found, provide both the report and sysdiagnose file to Apple Support
- Safe to run multiple times - won't affect system stability

## When to Use This Script

- Mac randomly rebooting or crashing
- Seeing "Your computer restarted because of a problem" messages
- Pink screen or boot loops
- System freezes or becomes unresponsive
- Before taking Mac to Apple Store for diagnostics
