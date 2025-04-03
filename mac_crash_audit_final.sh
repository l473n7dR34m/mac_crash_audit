#!/bin/bash

# Full-featured macOS crash audit with accurate progress bar and step-by-step output

OUTPUT=~/Desktop/mac_crash_audit_$(date +"%Y%m%d_%H%M%S").txt
TOTAL_STEPS=7
CURRENT_STEP=0

echo "macOS Crash & Update Audit" > "$OUTPUT"
echo "==========================" >> "$OUTPUT"
echo "Date: $(date)" >> "$OUTPUT"
echo "" >> "$OUTPUT"

print_progress() {
  local progress=$((CURRENT_STEP * 100 / TOTAL_STEPS))
  local done=$((progress / 2))
  local left=$((50 - done))
  local bar=$(printf "%-${done}s" "#" | tr ' ' '#')
  local space=$(printf "%-${left}s" "-" | tr ' ' '-')
  printf "\r[%s%s] %3d%% - %s" "$bar" "$space" "$progress" "$1"
}

run_step() {
  STEP_LABEL="$1"
  STEP_COMMAND="$2"

  CURRENT_STEP=$((CURRENT_STEP + 1))
  print_progress "$STEP_LABEL"
  echo -e "\n\n## $STEP_LABEL" >> "$OUTPUT"

  eval "$STEP_COMMAND" >> "$OUTPUT" 2>&1

  sleep 0.5
}

# -----------------------------
# Step-by-step audit
# -----------------------------

run_step "Checking FileVault status" \
  "fdesetup status"

run_step "Checking recent shutdown causes" \
  "log show --predicate 'eventMessage CONTAINS \"shutdown cause\"' --last 3d --info | grep 'shutdown cause' || echo 'None found'"

run_step "Scanning for kernel panics" \
  "log show --predicate 'eventMessage CONTAINS \"panic\" OR eventMessage CONTAINS \"kernel trap\"' --last 3d --info || echo 'None found'"

run_step "Checking CPU wake violations" \
  "log show --predicate 'eventMessage CONTAINS[c] \"CPU wakes\" OR eventMessage CONTAINS[c] \"violating a CPU wakes limit\"' --last 3d --info || echo 'None found'"

run_step "Looking for firmware or ANE warnings" \
  "log show --predicate 'eventMessage CONTAINS \"ANE\" OR eventMessage CONTAINS \"firmware\" OR eventMessage CONTAINS \"BridgeOS\"' --last 3d --info || echo 'None found'"

run_step "Checking update/install process logs" \
  "log show --predicate 'process == \"softwareupdated\" OR process == \"osinstallersetupd\"' --last 3d --info | grep -iE 'fail|error|exit code|snapshot|seal' || echo 'None found'"

run_step "Listing active MDM/security agents" \
  "launchctl list | grep -iE 'intune|zscaler|globalprotect|mdm' || echo 'None found'"

# -----------------------------
# Complete
# -----------------------------

print_progress "Audit complete"
printf "\n\n✅ Audit complete. Report saved to: %s\n\n" "$OUTPUT"
