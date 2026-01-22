#!/bin/bash

source "$HOME/.config/sketchybar/colorpresets/custom-theme.sh"

# Icon and colors
ICON="󰓅"  # Speedometer icon
ICON_COLOR="0xffFFB86C"      # Warm amber/orange for the icon
COLOR_GOOD="0xffA4B3B6"      # Sage - normal speed
COLOR_POOR="0xffFF6B6B"      # Bright red - poor speed (<10 Mbps)
SPEED_THRESHOLD=10           # Mbps threshold for "poor" speed

# Helper: Get label color based on speed
get_speed_color() {
  local SPEED=$1
  if [ -z "$SPEED" ] || [ "$SPEED" = "--" ] || [ "$SPEED" = "—" ]; then
    echo "$COLOR_GOOD"
  elif [ "$SPEED" -lt "$SPEED_THRESHOLD" ] 2>/dev/null; then
    echo "$COLOR_POOR"
  else
    echo "$COLOR_GOOD"
  fi
}

# Handle mouse events for hover popup
if [ "$SENDER" = "mouse.entered" ]; then
  sketchybar --set $NAME popup.drawing=on
  exit 0
fi

if [ "$SENDER" = "mouse.exited" ]; then
  sketchybar --set $NAME popup.drawing=off
  exit 0
fi

# --- Configuration ---
STATE_FILE="/tmp/sketchybar_netspeed_state"
LAST_TEST_FILE="/tmp/sketchybar_netspeed_last_test"
ERROR_FILE="/tmp/sketchybar_netspeed_error"
LOCK_FILE="/tmp/sketchybar_netspeed.lock"
TEST_CMD="networkQuality"
SIGNAL_THRESHOLD=15
MIN_TEST_INTERVAL=300      # Minimum seconds between signal-triggered tests
NETWORK_CHANGE_INTERVAL=30 # Shorter interval for network changes (always want fresh data on new network)
STALE_DATA_INTERVAL=1800   # Refresh if no test in 30 minutes
ERROR_RETRY_INTERVAL=60    # Retry every 60 seconds when in error state
MAX_RETRIES=3              # Max retries before giving up until next trigger

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

# --- Helper: Clear error state ---
clear_error() {
  rm -f "$ERROR_FILE"
}

# --- Helper: Set error state with message ---
set_error() {
  local ERROR_MSG=$1
  local RETRY_COUNT=${2:-0}
  echo "${ERROR_MSG}|${RETRY_COUNT}|$(date +%s)" >"$ERROR_FILE"
}

# --- Helper: Update popup with current status ---
update_popup() {
  local STATUS=$1
  local SSID=$2
  local SPEED=$3
  local RSSI=$4
  local LAST_TEST_TIME=$5

  # Format the last test time
  if [ -n "$LAST_TEST_TIME" ] && [ "$LAST_TEST_TIME" != "0" ]; then
    FORMATTED_TIME=$(date -r "$LAST_TEST_TIME" "+%H:%M:%S" 2>/dev/null || echo "Unknown")
  else
    FORMATTED_TIME="Never"
  fi

  # Theme colors (matching custom-theme.sh)
  THEME_SAGE="0xffA4B3B6"
  THEME_LAVENDER="0xffE98074"
  THEME_PINK="0xffD83F87"

  # Create or update popup items
  sketchybar --set "$NAME" popup.align=center

  # Line 1: Network
  sketchybar --set "$NAME".network label="Network: $SSID" 2>/dev/null || \
    sketchybar --add item "$NAME".network popup."$NAME" \
      --set "$NAME".network label="Network: $SSID" \
        label.font="Iosevka Nerd Font:Regular:13.0" label.color="$THEME_SAGE"

  # Line 3: Speed
  sketchybar --set "$NAME".speed label="Speed: ${SPEED} Mbps" 2>/dev/null || \
    sketchybar --add item "$NAME".speed popup."$NAME" \
      --set "$NAME".speed label="Speed: ${SPEED} Mbps" \
        label.font="Iosevka Nerd Font:Regular:13.0" label.color="$THEME_SAGE"

  # Line 4: Signal (only for WiFi)
  if [ "$SSID" != "Wired" ] && [ -n "$RSSI" ] && [ "$RSSI" != "0" ]; then
    sketchybar --set "$NAME".signal label="Signal: ${RSSI} dBm" 2>/dev/null || \
      sketchybar --add item "$NAME".signal popup."$NAME" \
        --set "$NAME".signal label="Signal: ${RSSI} dBm" \
          label.font="Iosevka Nerd Font:Regular:13.0" label.color="$THEME_SAGE"
  fi

  # Line 5: Last tested
  sketchybar --set "$NAME".time label="Tested: $FORMATTED_TIME" 2>/dev/null || \
    sketchybar --add item "$NAME".time popup."$NAME" \
      --set "$NAME".time label="Tested: $FORMATTED_TIME" \
        label.font="Iosevka Nerd Font:Regular:13.0" label.color="$THEME_LAVENDER"
}

# --- Helper: Check if in error state and should retry ---
should_retry_error() {
  if [ ! -f "$ERROR_FILE" ]; then
    return 1
  fi

  IFS='|' read -r ERR_MSG ERR_RETRIES ERR_TIME <"$ERROR_FILE"
  NOW=$(date +%s)
  ELAPSED=$((NOW - ERR_TIME))

  # Check if enough time has passed and we haven't exceeded max retries
  if [ "$ELAPSED" -ge "$ERROR_RETRY_INTERVAL" ] && [ "$ERR_RETRIES" -lt "$MAX_RETRIES" ]; then
    return 0
  fi
  return 1
}

# --- Helper: Get current retry count ---
get_retry_count() {
  if [ ! -f "$ERROR_FILE" ]; then
    echo "0"
    return
  fi
  IFS='|' read -r _ ERR_RETRIES _ <"$ERROR_FILE"
  echo "${ERR_RETRIES:-0}"
}

# --- Helper: Run Speed Test ---
run_speed_test() {
  REASON=$1
  RETRY_COUNT=$(get_retry_count)
  echo "--- STARTING SPEED TEST (Reason: $REASON, Retry: $RETRY_COUNT) ---"

  sketchybar --set "$NAME" icon="$ICON" label="..." icon.color=0xffE98074 label.color="$COLOR_GOOD"

  echo "Executing: $TEST_CMD"
  RESULT=$($TEST_CMD 2>&1)
  EXIT_CODE=$?
  echo "Raw Result: $RESULT"
  echo "Exit Code: $EXIT_CODE"

  # Check for command failure
  if [ "$EXIT_CODE" -ne 0 ]; then
    echo "Error: networkQuality command failed with exit code $EXIT_CODE"
    NEW_RETRY=$((RETRY_COUNT + 1))
    set_error "networkQuality failed (exit $EXIT_CODE)" "$NEW_RETRY"
    sketchybar --set "$NAME" icon="$ICON" label="Err" icon.color=0xffE98074 label.color="$COLOR_POOR"
    LAST_TEST=$(cat "$LAST_TEST_FILE" 2>/dev/null || echo "0")
    update_popup "error" "$CURRENT_SSID" "—" "$CURRENT_RSSI" "$LAST_TEST"
    echo "--- TEST FAILED (will retry $NEW_RETRY/$MAX_RETRIES) ---"
    return 1
  fi

  DL_SPEED=$(echo "$RESULT" | grep "Downlink capacity" | awk '{printf "%.0f", $3}')

  if [ -z "$DL_SPEED" ]; then
    echo "Error: Could not parse download speed."
    NEW_RETRY=$((RETRY_COUNT + 1))
    set_error "Failed to parse speed result" "$NEW_RETRY"
    sketchybar --set "$NAME" icon="$ICON" label="Err" icon.color=0xffE98074 label.color="$COLOR_POOR"
    LAST_TEST=$(cat "$LAST_TEST_FILE" 2>/dev/null || echo "0")
    update_popup "error" "$CURRENT_SSID" "—" "$CURRENT_RSSI" "$LAST_TEST"
    echo "--- TEST FAILED (will retry $NEW_RETRY/$MAX_RETRIES) ---"
    return 1
  fi

  echo "Parsed Download Speed: $DL_SPEED Mbps"

  # Success - clear any error state
  clear_error

  echo "${CURRENT_SSID}|${DL_SPEED}|${CURRENT_RSSI}" >"$STATE_FILE"
  date +%s >"$LAST_TEST_FILE"
  SPEED_COLOR=$(get_speed_color "$DL_SPEED")
  sketchybar --set "$NAME" icon="$ICON" label="${DL_SPEED} Mbps" icon.color="$ICON_COLOR" label.color="$SPEED_COLOR"
  update_popup "ok" "$CURRENT_SSID" "$DL_SPEED" "$CURRENT_RSSI" "$(date +%s)"
  echo "--- TEST COMPLETE ---"
  return 0
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
  # Reset retry count on manual click
  rm -f "$ERROR_FILE"
  run_speed_test "User Clicked"
  exit 0
fi

# 3. Error Retry Check
if should_retry_error; then
  echo "In error state, attempting retry..."
  run_speed_test "Error Retry"
  exit 0
fi

# 4. State Reconciliation
if [ ! -f "$STATE_FILE" ]; then
  if can_auto_test; then
    run_speed_test "First Run / No State File"
  else
    echo "First run but rate-limited. Setting placeholder."
    sketchybar --set "$NAME" icon="$ICON" label="--" icon.color="$ICON_COLOR" label.color="$COLOR_GOOD"
    update_popup "ok" "$CURRENT_SSID" "--" "$CURRENT_RSSI" "0"
  fi
  exit 0
fi

# Parse state file (use | as delimiter to handle SSIDs with spaces)
IFS='|' read -r LAST_SSID LAST_SPEED LAST_RSSI <"$STATE_FILE"
echo "Previous State: SSID=$LAST_SSID, Speed=$LAST_SPEED, RSSI=$LAST_RSSI"

# CHECK A: Network Change? (use shorter interval - we always want fresh data on new network)
if [ "$CURRENT_SSID" != "$LAST_SSID" ]; then
  echo "Network Changed ($LAST_SSID -> $CURRENT_SSID)."
  clear_error  # Clear error on network change
  if can_test_with_interval "$NETWORK_CHANGE_INTERVAL"; then
    run_speed_test "Network Change"
  else
    echo "Rate-limited (network change). Updating SSID, keeping old speed."
    echo "${CURRENT_SSID}|${LAST_SPEED}|${CURRENT_RSSI}" >"$STATE_FILE"
    SPEED_COLOR=$(get_speed_color "$LAST_SPEED")
    sketchybar --set "$NAME" icon="$ICON" label="${LAST_SPEED} Mbps" icon.color="$ICON_COLOR" label.color="$SPEED_COLOR"
    LAST_TEST=$(cat "$LAST_TEST_FILE" 2>/dev/null || echo "0")
    update_popup "ok" "$CURRENT_SSID" "$LAST_SPEED" "$CURRENT_RSSI" "$LAST_TEST"
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

# 5. No Changes? Maintain Display
echo "No significant changes detected. Maintaining display."
echo "${CURRENT_SSID}|${LAST_SPEED}|${CURRENT_RSSI}" >"$STATE_FILE"
SPEED_COLOR=$(get_speed_color "$LAST_SPEED")
sketchybar --set "$NAME" icon="$ICON" label="${LAST_SPEED} Mbps" icon.color="$ICON_COLOR" label.color="$SPEED_COLOR"

# Update popup with current state
LAST_TEST=$(cat "$LAST_TEST_FILE" 2>/dev/null || echo "0")
if [ -f "$ERROR_FILE" ]; then
  update_popup "error" "$CURRENT_SSID" "$LAST_SPEED" "$CURRENT_RSSI" "$LAST_TEST"
else
  update_popup "ok" "$CURRENT_SSID" "$LAST_SPEED" "$CURRENT_RSSI" "$LAST_TEST"
fi
