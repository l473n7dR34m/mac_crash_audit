# macOS Crash Audit - Setup & Usage Guide

## Overview

This script audits your Mac for system crashes, SEP panics, firmware issues and update problems. It creates a detailed report and automatically collects full system diagnostics when SEP-related issues are detected (which may cause the pink screen reboot loop).

## First-time Setup

1. Download the `mac_crash_audit.sh` script
2. Open Terminal (find it in Applications > Utilities > Terminal)
3. Navigate to your Downloads folder (or wherever the script is saved):
   cd ~/Downloads
4. Make the script executable:
   chmod +x mac_crash_audit.sh

## Usage Options

### Standard Audit

./mac_crash_audit.sh

By default, it checks logs from the past 1 day.

### Specify a Timeframe

./mac_crash_audit.sh 7    # Checks the past 7 days

### Test Mode (Force Sysdiagnose Collection)

To verify sysdiagnose collection works without needing actual issues:

./mac_crash_audit.sh test

### Detection Test Mode

To verify the script can properly detect SEP issues:

./mac_crash_audit.sh detection-test

This creates a test log file with sample SEP issues to verify pattern matching works correctly.

### Run with Admin Privileges

If you get permission errors:

sudo ./mac_crash_audit.sh

## Output Files

1. **Audit Report**:
   - Saved to: `~/Desktop/mac_crash_audit_YYYYMMDD_HHMMSS.txt`
   - Contains FileVault status, system crashes, update errors, and SEP-related issues

2. **System Diagnostics** (if SEP issues are detected):
   - Saved to: `/var/tmp/sysdiagnose_*.tar.gz` 
   - Copy saved to: `~/Desktop/SEP_issue_sysdiagnose_YYYYMMDD_HHMMSS.tar.gz`
   - Collection requires admin privileges and may take several minutes

## Notes

- The script requires admin permissions (sudo) to access all system logs and collect sysdiagnose
- No data is sent outside your computer
- The script specifically looks for:
  - SEP (Secure Enclave Processor) panics
  - Pink screen issues and reboot loops
  - Update volume errors
  - AppleHPMLibRTUpdater issues
  - Power and firmware problems
- If problems are found, both the basic report and the full sysdiagnose file should be provided to Apple Support
