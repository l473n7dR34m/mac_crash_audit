#!/bin/bash
# macOS crash audit script with progress bar and sysdiagnose collection
# Enhanced version with comprehensive error detection
# Now writes outputs to the invoking user's Desktop with sane ownership and permissions.

set -euo pipefail

# Default timeframe (in days)
DAYS=1

# Check if test mode flags are requested
TEST_MODE=false
DETECTION_TEST=false

# Resolve the real caller (handles sudo)
CALLER_USER="${SUDO_USER:-$USER}"
CALLER_HOME="$(eval echo "~${CALLER_USER}")"
DESKTOP_DIR="${CALLER_HOME}/Desktop"
mkdir -p "$DESKTOP_DIR"

# Process arguments
for arg in "${@:-}"; do
  case $arg in
    test)
      TEST_MODE=true
      echo "[TEST] Running in TEST MODE - will force sysdiagnose collection at the end"
      ;;
    detection-test)
      DETECTION_TEST=true
      echo "[TEST] Running DETECTION TEST - will create test logs and verify detection patterns"
      ;;
    *)
      if [[ "$arg" =~ ^[0-9]+$ ]]; then
        DAYS=$arg
      else
        echo "Error: Unknown argument: $arg"
        echo "Usage: ./mac_crash_audit.sh [test] [detection-test] [days]"
        echo "  test           - Force sysdiagnose collection"
        echo "  detection-test - Test log detection patterns"
        echo "  days           - Number of days to look back (default: 1)"
        exit 1
      fi
      ;;
  esac
done

# Use a temporary file for collection
TEMP_OUTPUT="$(mktemp)"
OUTPUT="${DESKTOP_DIR}/mac_crash_audit_$(date +"%Y%m%d_%H%M%S").txt"
TOTAL_STEPS=13  # Updated from 5 to include new checks
CURRENT_STEP=0
ISSUE_DETECTED=false

# Check for recent panic immediately
LATEST_PANIC=$(find /Library/Logs/DiagnosticReports -name '*.panic' -mtime -7 2>/dev/null | sort -n | tail -1 || true)

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
  if [ -n "${LATEST_PANIC:-}" ]; then
    echo ""
    echo "ALERT: Recent panic found at: $LATEST_PANIC"
    echo "Panic summary:"
    grep -A5 "panic(" "$LATEST_PANIC" 2>/dev/null | head -n 10 || echo "Could not extract panic details"
  fi
  echo ""
} > "$TEMP_OUTPUT"

# Simpler spinner animation
spin() {
  local spinstr='|/-\'
  local i=0
  while :; do
    i=$(( (i+1) % 4 ))
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
  printf "\r%-50s [ Step %d of %d ] " "$step_name" "$CURRENT_STEP" "$TOTAL_STEPS"

  # Start spinner
  spin &
  local SPIN_PID=$!
  # Make sure spinner process is terminated on exit
  trap "kill -9 $SPIN_PID 2>/dev/null || true" EXIT

  # Add header to output file
  echo -e "\n## $step_name" >> "$TEMP_OUTPUT"

  # Execute the command synchronously (wait for completion)
  # shellcheck disable=SC2086
  eval "$command" >> "$TEMP_OUTPUT" 2>&1

  # Stop spinner
  kill -9 $SPIN_PID 2>/dev/null || true
  wait $SPIN_PID 2>/dev/null || true
  trap - EXIT

  # Show completed status
  printf "\r%-50s [ Step %d of %d ] done\n" "$step_name" "$CURRENT_STEP" "$TOTAL_STEPS"
}

# Create test logs file if in detection test mode
if [ "$DETECTION_TEST" = true ]; then
  TEST_LOGS="${DESKTOP_DIR}/test_crash_logs.txt"
  echo "Creating test logs file at $TEST_LOGS"

  cat > "$TEST_LOGS" << 'EOL'
2025-04-08 15:41:20.018856+1000 0x152b665  Error       0x0                  53794  0    com.apple.MobileSoftwareUpdate.UpdateBrainService: (AppleHPMLib) AppleHPMLibRTInterface::<private>@0xc RID0 - AppleHPMLibRTUpdater - panic debug enabled:0
2025-04-08 15:41:21.045249+1000 0x152b665  Error       0x0                  53794  0    com.apple.MobileSoftwareUpdate.UpdateBrainService: (AppleHPMLib) AppleHPMLibRTInterface::<private>@0xa RID1 - AppleHPMLibRTUpdater - panic debug enabled:0
2025-04-09 12:35:36.935309+1000 0x76c      Default     0x0                  104    0    DumpPanic: [com.apple.DumpPanic:panicprocessing] embedded panic string decoded: panic(cpu 0 caller 0xfffffe00232c5de4): SEP Panic: :sks /sks : 0x1000a4445 0x00042808 0x000427ec 0x10000bdfc 0x10000f900 0x1000225e4 0x100078a00 0x10006ba18 [hgggqkkkl]
2025-04-09 14:22:15.123456+1000 0x123      Default     0x0                  999    0    kernel: panic(cpu 2 caller 0xffffff8012345678): Kernel trap at 0xffffff8012345678
2025-04-09 14:23:45.234567+1000 0x456      Error       0x0                  888    0    WindowServer: GPU reset occurred
2025-04-09 14:24:12.345678+1000 0x789      Error       0x0                  777    0    kernel: disk0s1: I/O error
2025-04-09 14:25:33.456789+1000 0xabc      Default     0x0                  666    0    kernel: Previous shutdown cause: 3
2025-04-09 14:26:44.567890+1000 0xdef      Error       0x0                  555    0    kernel: SMC error: communication failed
2025-04-09 14:27:55.678901+1000 0x012      Default     0x0                  444    0    kernel: thermal pressure level 2
2025-04-09 14:28:06.789012+1000 0x345      Error       0x0                  333    0    kernel: watchdog timeout: no checkins from watchdogd
EOL
  echo "Test logs file created successfully"
fi

# Run each audit step sequentially

# Original checks
run_step "Checking FileVault and system status" \
  "fdesetup status && echo -e '\nSystem Info:' && sw_vers"

# Enhanced SEP panic check with more patterns
if [ "$TEST_MODE" = true ]; then
  run_step "Checking for SEP panic and critical errors" \
    "echo 'Simulating critical errors for testing'; ISSUE_DETECTED=true"
elif [ "$DETECTION_TEST" = true ]; then
  run_step "Checking for SEP panic and critical errors" \
    "echo 'Running detection pattern test on test logs file...';
     if grep -E 'SEP Panic|pink|AppleHPMLibRTUpdater|restore.log.*Permission denied|Failed to unlink.*restore.log|softwareupdated.*Could not open log file|panic.*cpu.*caller|Sleep.*Wake failure|Previous shutdown cause|kernel trap|Machine check|Double fault|General protection fault' \"$TEST_LOGS\" 2>/dev/null; then
       echo 'Critical issues detected in test file.'
       ISSUE_DETECTED=true
     else
       echo 'Failure: No issues detected in test file. This should not happen.'
       ISSUE_DETECTED=false
     fi"
else
  run_step "Checking for SEP panic and critical errors" \
    "if grep -E 'SEP Panic|pink|AppleHPMLibRTUpdater|restore.log.*Permission denied|Failed to unlink.*restore.log|softwareupdated.*Could not open log file|panic.*cpu.*caller|Sleep.*Wake failure|Previous shutdown cause|kernel trap|Machine check|Double fault|General protection fault' /var/log/system.log* /Library/Logs/DiagnosticReports/*.panic /private/var/db/diagnostics/Special/* 2>/dev/null; then
       echo 'Critical issues detected. Will collect system diagnostics.'
       ISSUE_DETECTED=true
     else
       echo 'None found in log files'
     fi"
fi

# New comprehensive error checks
run_step "Checking for kernel panics" \
  "find /Library/Logs/DiagnosticReports -name '*.panic' -mtime -$DAYS -exec echo 'Found panic: {}' \; -exec head -n 50 {} \; 2>/dev/null || echo 'No panic logs found'"

run_step "Checking for hardware errors" \
  "grep -E 'I/O error|disk.*error|memory.*error|ATA.*error|NVMe.*error|SMC.*error|T2.*error' /var/log/system.log* 2>/dev/null | tail -n 20 || echo 'No hardware errors found'"

run_step "Checking for GPU issues" \
  "grep -E 'GPU.*reset|GPU.*hang|WindowServer.*crash|graphics.*error|AMD.*error|Intel.*Graphics' /var/log/system.log* /Library/Logs/DiagnosticReports/* 2>/dev/null | tail -n 20 || echo 'No GPU errors found'"

run_step "Checking for watchdog timeouts" \
  "grep -E 'watchdog.*timeout|spin.*detected|hang.*detected|unresponsive' /var/log/system.log* 2>/dev/null | tail -n 20 || echo 'No watchdog timeouts found'"

run_step "Checking for thermal issues" \
  "grep -E 'thermal|temperature|fan.*speed|CPU.*throttl|overheat' /var/log/system.log* 2>/dev/null | tail -n 20 || echo 'No thermal issues found'"

run_step "Listing non-Apple kernel extensions" \
  "kextstat | grep -v com.apple | head -n 20 || echo 'No third-party kexts loaded'"

run_step "Listing recent crash reports" \
  "find /Library/Logs/DiagnosticReports -name '*.crash' -mtime -$DAYS -exec basename {} \; 2>/dev/null | sort | uniq -c | sort -nr | head -n 20 || echo 'No recent crashes found'"

run_step "Checking last shutdown cause" \
  "log show --predicate 'eventMessage contains \"Previous shutdown cause\"' --last ${DAYS}d 2>/dev/null | tail -n 10 || echo 'Could not retrieve shutdown cause'"

run_step "Checking for repeated crashes" \
  "log show --predicate 'eventMessage contains \"crashed\" OR eventMessage contains \"panic\"' --style syslog --last ${DAYS}d 2>/dev/null | grep -v 'com.apple' | tail -n 30 || echo 'No repeated crashes found'"

# Original checks continue
run_step "Scanning for power and firmware issues" \
  "grep -E 'CPU wakes|firmware|power.*fail' /var/log/system.log* /Library/Logs/DiagnosticReports/* 2>/dev/null | head -n 15 || echo 'None found in standard log files'"

run_step "Checking for update volume errors" \
  "grep -E 'softwareupdated.*restore.log|Failed to unlink|Permission denied' /var/log/system.log* 2>/dev/null || echo 'None found in standard log files'"

# Force test mode if requested
if [ "$TEST_MODE" = true ]; then
  ISSUE_DETECTED=true
fi

# Check if any panic was found
if [ -n "${LATEST_PANIC:-}" ]; then
  ISSUE_DETECTED=true
fi

# Leave test logs in place for debugging

# Print completion message and generate final report
echo ""
echo "All checks complete. Generating report..."

# Copy the temporary file to the final destination
cp "$TEMP_OUTPUT" "$OUTPUT"

# Ensure the report is readable by the caller, regardless of sudo
chown "${CALLER_USER}":staff "$OUTPUT" 2>/dev/null || true
chmod 0644 "$OUTPUT" 2>/dev/null || true

# Clean up
rm -f "$TEMP_OUTPUT"

echo "Report saved to: $OUTPUT"
echo "Searched system logs for the past $DAYS day(s)"

# If issues were detected, collect a sysdiagnose
if [ "$ISSUE_DETECTED" = true ]; then
  echo ""
  echo "Critical issues were detected. Collecting system diagnostics..."
  echo "This may take a few minutes and may require admin privileges."

  # Skip sysdiagnose collection in detection test mode
  if [ "$DETECTION_TEST" = true ]; then
    echo "Detection test mode: Skipping actual sysdiagnose collection."
    echo "In normal operation, sysdiagnose would be collected now."
    exit 0
  fi

  # Start spinner
  spin &
  SPIN_PID=$!
  trap "kill -9 $SPIN_PID 2>/dev/null || true" EXIT

  # Run sysdiagnose in unattended mode
  echo "Running sysdiagnose in unattended mode..."
  if command -v sudo >/dev/null 2>&1; then
    sudo sysdiagnose -u || true
  else
    sysdiagnose -u || true
  fi

  # Stop spinner
  kill -9 $SPIN_PID 2>/dev/null || true
  wait $SPIN_PID 2>/dev/null || true
  trap - EXIT

  # Find the most recent sysdiagnose file
  DIAG_FILE="$(find /var/tmp -name 'sysdiagnose_*' -type f -mtime -1 2>/dev/null | sort | tail -1 || true)"

  if [ -n "${DIAG_FILE:-}" ]; then
    # Copy to Desktop for easier access
    DESKTOP_COPY="${DESKTOP_DIR}/crash_issue_sysdiagnose_$(date +"%Y%m%d_%H%M%S").tar.gz"
    echo "System diagnostics saved to: $DIAG_FILE"
    echo "Copying to Desktop for easier access..."
    cp "$DIAG_FILE" "$DESKTOP_COPY" 2>/dev/null || true
    chown "${CALLER_USER}":staff "$DESKTOP_COPY" 2>/dev/null || true
    chmod 0644 "$DESKTOP_COPY" 2>/dev/null || true
    echo "Copy available at: $DESKTOP_COPY"
  else
    echo "Could not locate sysdiagnose output file. It should be in /var/tmp/"
    ls -la /var/tmp/sysdiagnose_* 2>/dev/null || echo "No sysdiagnose files found"
  fi

  echo ""
  echo "Please provide these files to Apple Support for further analysis of the system crash issues."
fi
