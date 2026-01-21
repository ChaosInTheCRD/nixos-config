#!/bin/bash

# --- Configuration ---
STATE_FILE="/tmp/sketchybar_netspeed_state"
LAST_TEST_FILE="/tmp/sketchybar_netspeed_last_test"
LOCK_FILE="/tmp/sketchybar_netspeed.lock"
TEST_CMD="networkQuality"
SIGNAL_THRESHOLD=15
MIN_TEST_INTERVAL=300      # Minimum seconds between signal-triggered tests
NETWORK_CHANGE_INTERVAL=30 # Shorter interval for network changes (always want fresh data on new network)
STALE_DATA_INTERVAL=1800   # Refresh if no test in 30 minutes

# --- Acquire Lock (prevent concurrent runs) ---
# Use mkdir for atomic lock (works on macOS)
if ! mkdir "$LOCK_FILE" 2>/dev/null; then
  # Check if lock is stale (older than 2 minutes)
  if [ -d "$LOCK_FILE" ]; then
    # Support both GNU stat (-c) and BSD stat (-f)
    LOCK_MTIME=$(stat -c %Y "$LOCK_FILE" 2>/dev/null || stat -f %m "$LOCK_FILE" 2>/dev/null)
    LOCK_AGE=$(( $(date +%s) - ${LOCK_MTIME:-0} ))
    if [ "$LOCK_AGE" -gt 120 ]; then
      echo "Removing stale lock."
      rmdir "$LOCK_FILE" 2>/dev/null
      mkdir "$LOCK_FILE" 2>/dev/null || { echo "Lock contention. Exiting."; exit 0; }
    else
      echo "Another instance is running. Exiting."
      exit 0
    fi
  fi
fi
trap 'rmdir "$LOCK_FILE" 2>/dev/null' EXIT

# --- Helper: Check if enough time has passed (with configurable interval) ---
time_since_last_test() {
  if [ ! -f "$LAST_TEST_FILE" ]; then
    echo "999999"  # No record, return large number
    return
  fi
  LAST_TEST=$(cat "$LAST_TEST_FILE")
  NOW=$(date +%s)
  echo $((NOW - LAST_TEST))
}

can_test_with_interval() {
  local INTERVAL=$1
  local ELAPSED=$(time_since_last_test)
  [ "$ELAPSED" -ge "$INTERVAL" ]
}

can_auto_test() {
  can_test_with_interval "$MIN_TEST_INTERVAL"
}

# --- Helper: Run Speed Test ---
run_speed_test() {
  REASON=$1
  echo "--- STARTING SPEED TEST (Reason: $REASON) ---"

  sketchybar --set "$NAME" label="..." icon.color=0xffE98074

  echo "Executing: $TEST_CMD"
  RESULT=$($TEST_CMD)
  echo "Raw Result: $RESULT"

  DL_SPEED=$(echo "$RESULT" | grep "Downlink capacity" | awk '{printf "%.0f", $3}')

  if [ -z "$DL_SPEED" ]; then
    echo "Error: Could not parse download speed."
    DL_SPEED="Err"
  else
    echo "Parsed Download Speed: $DL_SPEED Mbps"
  fi

  echo "${CURRENT_SSID}|${DL_SPEED}|${CURRENT_RSSI}" >"$STATE_FILE"
  date +%s >"$LAST_TEST_FILE"
  sketchybar --set "$NAME" label="${DL_SPEED} Mbps" icon.color=0xffA4B3B6
  echo "--- TEST COMPLETE ---"
}

# --- Main Logic ---

echo "Script triggered."

# 1. Get Current Network Info (using system_profiler for modern macOS compatibility)
WIFI_INFO=$(system_profiler SPAirPortDataType 2>/dev/null)

# Extract SSID from "Current Network Information:" section - the SSID is the line after it ending with ":"
CURRENT_SSID=$(echo "$WIFI_INFO" | awk '/Current Network Information:/{getline; gsub(/^[[:space:]]+|:[[:space:]]*$/, ""); print; exit}')

# Get signal strength from system_profiler (no sudo required)
CURRENT_RSSI=$(echo "$WIFI_INFO" | awk -F'[/ ]' '/Signal \/ Noise/ {for(i=1;i<=NF;i++) if($i ~ /^-[0-9]+$/) {print $i; exit}}')
[ -z "$CURRENT_RSSI" ] && CURRENT_RSSI=0

# Check if we successfully got an SSID (WiFi connected) or if it's empty (wired/disconnected)
if [ -z "$CURRENT_SSID" ] || [ "$CURRENT_SSID" = "" ]; then
  echo "No WiFi SSID found. Assuming Wired connection."
  CURRENT_SSID="Wired"
  CURRENT_RSSI=0
else
  echo "Current Network: $CURRENT_SSID (RSSI: $CURRENT_RSSI)"
fi

# 2. Click Handler
if [ "$SENDER" = "mouse.clicked" ]; then
  run_speed_test "User Clicked"
  exit 0
fi

# 3. State Reconciliation
if [ ! -f "$STATE_FILE" ]; then
  if can_auto_test; then
    run_speed_test "First Run / No State File"
  else
    echo "First run but rate-limited. Setting placeholder."
    sketchybar --set "$NAME" label="--" icon.color=0xffA4B3B6
  fi
  exit 0
fi

# Parse state file (use | as delimiter to handle SSIDs with spaces)
IFS='|' read -r LAST_SSID LAST_SPEED LAST_RSSI <"$STATE_FILE"
echo "Previous State: SSID=$LAST_SSID, Speed=$LAST_SPEED, RSSI=$LAST_RSSI"

# CHECK A: Network Change? (use shorter interval - we always want fresh data on new network)
if [ "$CURRENT_SSID" != "$LAST_SSID" ]; then
  echo "Network Changed ($LAST_SSID -> $CURRENT_SSID)."
  if can_test_with_interval "$NETWORK_CHANGE_INTERVAL"; then
    run_speed_test "Network Change"
  else
    echo "Rate-limited (network change). Updating SSID, keeping old speed."
    echo "${CURRENT_SSID}|${LAST_SPEED}|${CURRENT_RSSI}" >"$STATE_FILE"
    sketchybar --set "$NAME" label="${LAST_SPEED} Mbps"
  fi
  exit 0
fi

# CHECK B: Major Signal Shift? (WiFi Only)
if [ "$CURRENT_SSID" != "Wired" ] && [ -n "$LAST_RSSI" ] && [ "$LAST_RSSI" != "0" ]; then
  # Calculate delta
  DIFF=$((CURRENT_RSSI - LAST_RSSI))
  DIFF=${DIFF#-}

  echo "Signal Delta: $DIFF dBm (Threshold: $SIGNAL_THRESHOLD)"

  if [ "$DIFF" -gt "$SIGNAL_THRESHOLD" ]; then
    if can_auto_test; then
      run_speed_test "Signal Shift > $SIGNAL_THRESHOLD dBm"
    else
      echo "Rate-limited. Skipping signal-triggered test."
    fi
    exit 0
  fi
fi

# CHECK C: Stale data? (periodic refresh)
if can_test_with_interval "$STALE_DATA_INTERVAL"; then
  echo "Data is stale (no test in $STALE_DATA_INTERVAL seconds). Refreshing."
  run_speed_test "Periodic Refresh"
  exit 0
fi

# 4. No Changes? Maintain Display
echo "No significant changes detected. Maintaining display."
echo "${CURRENT_SSID}|${LAST_SPEED}|${CURRENT_RSSI}" >"$STATE_FILE"
sketchybar --set "$NAME" label="${LAST_SPEED} Mbps"
