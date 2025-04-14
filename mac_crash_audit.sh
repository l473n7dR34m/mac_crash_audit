#!/bin/bash
# macOS crash audit script with progress bar and sysdiagnose collection

# Default timeframe (in days)
DAYS=1

# Check if a timeframe argument was provided
if [ "$1" ]; then
  if [[ "$1" =~ ^[0-9]+$ ]]; then
    DAYS=$1
  else
    echo "Error: Please provide a number for days (e.g., ./mac_crash_audit.sh 3)"
    exit 1
  fi
fi

# Use a temporary file for collection
TEMP_OUTPUT=$(mktemp)
OUTPUT=~/Desktop/mac_crash_audit_$(date +"%Y%m%d_%H%M%S").txt
TOTAL_STEPS=3
CURRENT_STEP=0
ISSUE_DETECTED=false

# Create header for the temp file
{
  echo "macOS Crash & Update Audit"
  echo "=========================="
  echo "Date: $(date)"
  echo "Timeframe: Last $DAYS day(s)"
  echo ""
} > "$TEMP_OUTPUT"

# Simpler spinner animation
spin() {
  local spinstr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
  local i=0
  while :; do
    i=$(( (i+1) % 10 ))
    printf "\b%s" "${spinstr:$i:1}"
    sleep 0.1
  done
}

# Function to run each step with proper progress tracking
run_step() {
  local step_name="$1"
  local command="$2"
  
  CURRENT_STEP=$((CURRENT_STEP + 1))
  
  # Clear line and show which step is running
  printf "\r%-40s [ Step %d of %d ] " "$step_name" "$CURRENT_STEP" "$TOTAL_STEPS"
  
  # Start spinner
  spin &
  local SPIN_PID=$!
  # Make sure spinner process is terminated on exit
  trap "kill -9 $SPIN_PID 2>/dev/null" EXIT
  
  # Add header to output file
  echo -e "\n## $step_name" >> "$TEMP_OUTPUT"
  
  # Execute the command synchronously (wait for completion)
  eval "$command" >> "$TEMP_OUTPUT" 2>&1
  
  # Stop spinner
  kill -9 $SPIN_PID 2>/dev/null
  wait $SPIN_PID 2>/dev/null
  trap - EXIT
  
  # Show completed status
  printf "\r%-40s [ Step %d of %d ] ✓\n" "$step_name" "$CURRENT_STEP" "$TOTAL_STEPS"
}

# Run each audit step sequentially
run_step "Checking FileVault and system status" \
  "fdesetup status && echo -e '\nSystem Info:' && sw_vers"

run_step "Checking for SEP panic and pink screen issues" \
  "if grep -E 'SEP Panic|pink|AppleHPMLibRTUpdater|restore.log.*Permission denied|Failed to unlink.*restore.log|softwareupdated.*Could not open log file' /var/log/system.log* /Library/Logs/DiagnosticReports/*.panic /private/var/db/diagnostics/Special/* 2>/dev/null; then
     echo 'SEP-related issues detected. Will collect system diagnostics.'
     ISSUE_DETECTED=true
   else
     echo 'None found in log files'
   fi"

run_step "Scanning for power and firmware issues" \
  "grep -E 'CPU wakes|firmware|power.*fail' /var/log/system.log* /Library/Logs/DiagnosticReports/* 2>/dev/null | head -n 15 || echo 'None found in standard log files'"

run_step "Checking for update volume errors" \
  "grep -E 'softwareupdated.*restore.log|Failed to unlink|Permission denied' /var/log/system.log* 2>/dev/null || echo 'None found in standard log files'"

# Add a specific check for the pink screen SEP issue
run_step "Checking for SEP pink screen issue" \
  "grep -E 'SEP Panic|AppleHPMLibRTUpdater|restore.log.*Permission denied' /var/log/system.log* /Library/Logs/DiagnosticReports/*.panic 2>/dev/null || echo 'None found in standard log files'"

# Print completion message and generate final report
echo ""
echo "✅ All checks complete. Generating report..."

# Copy the temporary file to the final destination
cp "$TEMP_OUTPUT" "$OUTPUT"

# Clean up
rm "$TEMP_OUTPUT"

echo "Report saved to: $OUTPUT"
echo "Searched system logs for the past $DAYS day(s)"

# If SEP issues were detected, collect a sysdiagnose
if [ "$ISSUE_DETECTED" = true ]; then
  echo ""
  echo "⚠️ SEP-related issues were detected. Collecting system diagnostics..."
  echo "This may take a few minutes and require admin privileges."
  
  # Collect sysdiagnose with progress indicator
  SYSDIAG_PATH=~/Desktop/SEP_issue_sysdiagnose_$(date +"%Y%m%d_%H%M%S")
  echo "Collecting system diagnostics to: $SYSDIAG_PATH"
  
  # Start spinner
  spin &
  SPIN_PID=$!
  trap "kill -9 $SPIN_PID 2>/dev/null" EXIT
  
  # Run sysdiagnose with admin privileges
  sudo sysdiagnose -f "$SYSDIAG_PATH" &>/dev/null
  
  # Stop spinner
  kill -9 $SPIN_PID 2>/dev/null
  wait $SPIN_PID 2>/dev/null
  trap - EXIT
  
  echo "✅ System diagnostics collection complete."
  echo "Full diagnostics saved to: $SYSDIAG_PATH"
  echo ""
  echo "Please provide these files to Apple Support for further analysis of the SEP pink screen issue."
fi
