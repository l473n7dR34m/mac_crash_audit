**mac_crash_audit.sh**
A full-featured macOS crash and system audit script that gathers key diagnostic information from the last 3 days, including shutdown causes, kernel panics, security agents, update errors, and more.
Outputs a timestamped report to your Desktop with a real-time progress bar and clear step-by-step structure.

**What It Does**
This script runs a 7-step diagnostic audit on a macOS system and saves the results to a .txt file. It uses macOS’s unified logging system and command-line tools to extract recent system issues or unusual behaviour. Each step appends to the report and displays a live progress bar in the terminal.

**Steps performed:**

**FileVault Status**

Checks whether FileVault disk encryption is enabled.

**Recent Shutdown Causes**

Parses logs from the past 3 days for shutdown reasons (e.g., power loss, kernel panic, etc.).

**Kernel Panics**

Searches for signs of recent kernel panics or system traps in the logs.

**CPU Wake Violations**

Identifies violations related to CPU wake limits (e.g., apps preventing proper sleep).

**Firmware or ANE/BridgeOS Warnings**

Scans for firmware-related errors, including Apple Neural Engine and BridgeOS events.

**Update & Install Issues**

Reviews logs from update/install daemons (softwareupdated, osinstallersetupd) for failure or error messages.

**Active Security / MDM Agents**

Lists currently running processes related to common security or MDM tools like Intune, Zscaler, GlobalProtect, etc.

**Output**
Saves a detailed report to your Desktop with a filename like:
mac_crash_audit_20250403_104512.txt

Each step is clearly labeled with its findings or a “None found” message if nothing was detected.

**How to Use**
Download or copy the script to your Mac.

Open Terminal and make it executable:

bash
chmod +x mac_crash_audit.sh
Run it:

bash
./mac_crash_audit.sh
View the output file on your Desktop after it completes.

**Requirements**
macOS 10.15+ (uses log show, available in Catalina and later)

Admin privileges not required

Internet not required

**Tip**
You can adjust the --last 3d parameter in the log queries to scan a different time window (e.g. --last 1w for one week).
