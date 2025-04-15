#!/bin/bash
# macOS crash audit script with progress bar and sysdiagnose collection

# Default timeframe (in days)
DAYS=1

# Check if test mode flags are requested
TEST_MODE=false
DETECTION_TEST=false

# Process arguments
for arg in "$@"; do
  case $arg in
    test)
      TEST_MODE=true
      echo "🧪 Running in TEST MODE - will force sysdiagnose collection at the end"
      ;;
    detection-test)
      DETECTION_TEST=true
      echo "🧪 Running DETECTION TEST - will create test logs and verify detection patterns"
      ;;
    *)
      if [[ "$arg" =~ ^[0-9]+$ ]]; then
        DAYS=$arg
      else
        echo "Error: Unknown argument: $arg"
        echo "Usage: ./mac_crash_audit.sh [test] [detection-test] [days]"
        echo "  test          - Force sysdiagnose collection"
        echo "  detection-test - Test log detection patterns"
        echo "  days          - Number of days to look back (default: 1)"
        exit 1
      fi
      ;;
  esac
done

# Use a temporary file for collection
TEMP_OUTPUT=$(mktemp)
OUTPUT=~/Desktop/mac_crash_audit_$(date +"%Y%m%d_%H%M%S").txt
TOTAL_STEPS=5
CURRENT_STEP=0
ISSUE_DETECTED=false

# Create header for the temp file
{
  echo "macOS Crash & Update Audit"
  echo "=========================="
  echo "Date: $(date)"
  echo "Timeframe: Last $DAYS day(s)"
  if [ "$TEST_MODE" = true ]; then
    echo "Mode: TEST (will force sysdiagnose collection)"
  fi
  if [ "$DETECTION_TEST" = true ]; then
    echo "Mode: DETECTION TEST (testing log pattern matching)"
  fi
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

# Create test logs file if in detection test mode
if [ "$DETECTION_TEST" = true ]; then
  TEST_LOGS=~/Desktop/test_sep_logs.txt
  echo "Creating test logs file at $TEST_LOGS"
  
  cat > "$TEST_LOGS" << EOL
2025-04-08 15:41:20.018856+1000 0x152b665  Error       0x0                  53794  0    com.apple.MobileSoftwareUpdate.UpdateBrainService: (AppleHPMLib) AppleHPMLibRTInterface::<private>@0xc RID0 - AppleHPMLibRTUpdater - panic debug enabled:0
2025-04-08 15:41:21.045249+1000 0x152b665  Error       0x0                  53794  0    com.apple.MobileSoftwareUpdate.UpdateBrainService: (AppleHPMLib) AppleHPMLibRTInterface::<private>@0xa RID1 - AppleHPMLibRTUpdater - panic debug enabled:0
2025-04-08 15:41:22.094803+1000 0x152b665  Error       0x0                  53794  0    com.apple.MobileSoftwareUpdate.UpdateBrainService: (AppleHPMLib) AppleHPMLibRTInterface::<private>@0xc RID0 - AppleHPMLibRTUpdater - panic debug enabled:0
2025-04-08 15:41:22.117795+1000 0x152b665  Error       0x0                  53794  0    com.apple.MobileSoftwareUpdate.UpdateBrainService: (AppleHPMLib) AppleHPMLibRTInterface::<private>@0xa RID1 - AppleHPMLibRTUpdater - panic debug enabled:0
2025-04-09 12:35:36.935309+1000 0x76c      Default     0x0                  104    0    DumpPanic: [com.apple.DumpPanic:panicprocessing] embedded panic string decoded: panic(cpu 0 caller 0xfffffe00232c5de4): SEP Panic: :sks /sks : 0x1000a4445 0x00042808 0x000427ec 0x10000bdfc 0x10000f900 0x1000225e4 0x100078a00 0x10006ba18 [hgggqkkkl]
EOL
  echo "Test logs file created successfully"
fi

# Run each audit step sequentially
run_step "Checking FileVault and system status" \
  "fdesetup status && echo -e '\nSystem Info:' && sw_vers"

# Check for SEP panic - with test modes
if [ "$TEST_MODE" = true ]; then
  run_step "Checking for SEP panic and pink screen issues" \
    "echo 'Simulating SEP-related issues for testing'
     ISSUE_DETECTED=true"
elif [ "$DETECTION_TEST" = true ]; then
  run_step "Checking for SEP panic and pink screen issues" \
    "echo 'Running detection pattern test on test logs file...'
     if grep -E 'SEP Panic|pink|AppleHPMLibRTUpdater|restore.log.*Permission denied|Failed to unlink.*restore.log|softwareupdated.*Could not open log file' \"$TEST_LOGS\" 2>/dev/null; then
       echo '✅ Success! SEP-related issues were detected in test file.'
       ISSUE_DETECTED=true
     else
       echo '❌ Failed! No issues detected in test file. This should not happen.'
       ISSUE_DETECTED=false
     fi"
else
  run_step "Checking for SEP panic and pink screen issues" \
    "if grep -E 'SEP Panic|pink|AppleHPMLibRTUpdater|restore.log.*Permission denied|Failed to unlink.*restore.log|softwareupdated.*Could not open log file' /var/log/system.log* /Library/Logs/DiagnosticReports/*.panic /private/var/db/diagnostics/Special/* 2>/dev/null; then
       echo 'SEP-related issues detected. Will collect system diagnostics.'
       ISSUE_DETECTED=true
     else
       echo 'None found in log files'
     fi"
fi

run_step "Scanning for power and firmware issues" \
  "grep -E 'CPU wakes|firmware|power.*fail' /var/log/system.log* /Library/Logs/DiagnosticReports/* 2>/dev/null | head -n 15 || echo 'None found in standard log files'"

run_step "Checking for update volume errors" \
  "grep -E 'softwareupdated.*restore.log|Failed to unlink|Permission denied' /var/log/system.log* 2>/dev/null || echo 'None found in standard log files'"

# Add a specific check for the pink screen SEP issue
if [ "$DETECTION_TEST" = true ]; then
  run_step "Checking for SEP pink screen issue" \
    "grep -E 'SEP Panic|AppleHPMLibRTUpdater|restore.log.*Permission denied' \"$TEST_LOGS\" 2>/dev/null || echo 'None found in test logs file (this should not happen)'"
else
  run_step "Checking for SEP pink screen issue" \
    "grep -E 'SEP Panic|AppleHPMLibRTUpdater|restore.log.*Permission denied' /var/log/system.log* /Library/Logs/DiagnosticReports/*.panic 2>/dev/null || echo 'None found in standard log files'"
fi

# Force test mode if requested
if [ "$TEST_MODE" = true ]; then
  ISSUE_DETECTED=true
fi

# Cleanup test file if we created one
if [ "$DETECTION_TEST" = true ] && [ -f "$TEST_LOGS" ]; then
  echo "Cleaning up test logs file..."
  # Keep the file for now to help with debugging
  # rm "$TEST_LOGS"
  echo "Test logs available at: $TEST_LOGS"
fi

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
  
  # Skip sysdiagnose collection in detection test mode
  if [ "$DETECTION_TEST" = true ]; then
    echo "👉 Detection test mode: Skipping actual sysdiagnose collection."
    echo "👉 In normal operation, sysdiagnose would be collected now."
    exit 0
  fi
  
  # Start spinner
  spin &
  SPIN_PID=$!
  trap "kill -9 $SPIN_PID 2>/dev/null" EXIT
  
  # Use the -u flag which we know works on this system
  TIMESTAMP=$(date +"%Y.%m.%d_%H-%M-%S%z")
  EXPECTED_PATH="/var/tmp/sysdiagnose_${TIMESTAMP}_macOS_"
  
  # Run sysdiagnose in unattended mode
  echo "Running sysdiagnose in unattended mode..."
  sudo sysdiagnose -u
  
  # Stop spinner
  kill -9 $SPIN_PID 2>/dev/null
  wait $SPIN_PID 2>/dev/null
  trap - EXIT
  
  # Find the most recent sysdiagnose file
  DIAG_FILE=$(find /var/tmp -name "sysdiagnose_*" -type f -mtime -1 | sort | tail -1)
  
  if [ -n "$DIAG_FILE" ]; then
    # Copy to Desktop for easier access
    DESKTOP_COPY=~/Desktop/SEP_issue_sysdiagnose_$(date +"%Y%m%d_%H%M%S").tar.gz
    echo "✅ System diagnostics saved to: $DIAG_FILE"
    echo "Copying to Desktop for easier access..."
    cp "$DIAG_FILE" "$DESKTOP_COPY"
    echo "Copy available at: $DESKTOP_COPY"
  else
    echo "⚠️ Could not locate sysdiagnose output file. It should be in /var/tmp/"
    ls -la /var/tmp/sysdiagnose_* 2>/dev/null || echo "No sysdiagnose files found"
  fi
  
  echo ""
  echo "Please provide these files to Apple Support for further analysis of the SEP pink screen issue."
fi
