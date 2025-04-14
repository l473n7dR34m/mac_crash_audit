macOS Crash Audit - Quick Setup Guide

First-time setup

Download the mac_crash_audit.sh script
Open Terminal (find it in Applications > Utilities > Terminal)
Navigate to your Downloads folder (or wherever the script is saved):
cd ~/Downloads
Make the script executable:
chmod +x mac_crash_audit.sh
Run the script:
./mac_crash_audit.sh

By default, it will check logs from the past 1 day. To specify a different timeframe:
./mac_crash_audit.sh 3    # Checks the past 3 days

If you get permission errors, you may need to run with admin privileges:
sudo ./mac_crash_audit.sh

The script will create a report on your Desktop named mac_crash_audit_YYYYMMDD_HHMMSS.txt with system diagnostics.

If SEP-related issues are detected (which may cause the pink screen reboot loop), the script will automatically collect a full system diagnostic (sysdiagnose) and save it to your Desktop. This requires admin privileges and may take several minutes to complete.

Notes

The script requires admin permissions (sudo) to access all system logs and collect sysdiagnose
The report shows FileVault status, system crashes, update errors, and SEP-related issues
No data is sent outside your computer
The script specifically looks for the SEP-related pink screen reboot loop issue
If problems are found, both the basic report and the full sysdiagnose file should be provided to Apple Support
