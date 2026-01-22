#!/usr/bin/env sh

source "$HOME/.config/sketchybar/colorpresets/custom-theme.sh"

# Handle mouse events for hover popup
if [ "$SENDER" = "mouse.entered" ]; then
  sketchybar --set $NAME popup.drawing=on
  exit 0
fi

if [ "$SENDER" = "mouse.exited" ]; then
  sketchybar --set $NAME popup.drawing=off
  exit 0
fi

# Handle click to toggle mute
if [ "$SENDER" = "mouse.clicked" ]; then
  osascript -e "set volume output muted not (output muted of (get volume settings))"
  # Trigger refresh
  sleep 0.1
fi

# 1. Check if SwitchAudioSource is installed
if ! command -v SwitchAudioSource &> /dev/null; then
  sketchybar --set $NAME icon="󰖁" label=""
  exit 1
fi

# 2. Get the Current Output Device
DEVICE=$(SwitchAudioSource -c -t output)

# 3. Get volume and mute status
VOLUME=$(osascript -e "output volume of (get volume settings)")
MUTED=$(osascript -e "output muted of (get volume settings)")

# 4. Choose icon based on device type
if [ "$MUTED" = "true" ] || [ "$VOLUME" -eq 0 ]; then
  ICON="󰖁"  # Muted
  ICON_COLOR="0xff08F7FE"  # Cyan blue
elif [[ "$DEVICE" == *"AirPods"* ]]; then
  ICON="󱡏"  # Earbuds
  ICON_COLOR="$PINK"
elif [[ "$DEVICE" == "External Headphones" ]]; then
  ICON="󰋋"  # Headphones
  ICON_COLOR="$PINK"
elif [[ "$DEVICE" == *"MacBook"* ]] || [[ "$DEVICE" == *"Speakers"* ]]; then
  ICON="󰓃"  # Built-in speakers
  ICON_COLOR="$PINK"
else
  ICON=""  # Generic speaker
  ICON_COLOR="$PINK"
fi

# 5. Update the bar - show volume number, no device text
sketchybar --set $NAME icon="$ICON" icon.color="$ICON_COLOR" label="${VOLUME}%"

# 6. Update popup
THEME_SAGE="0xffA4B3B6"
THEME_LAVENDER="0xffE98074"

# Friendly device name for popup
FRIENDLY_DEVICE="$DEVICE"

sketchybar --set "$NAME" popup.align=center

# Line 1: Device
sketchybar --set "$NAME".device label="Device: $FRIENDLY_DEVICE" 2>/dev/null || \
  sketchybar --add item "$NAME".device popup."$NAME" \
    --set "$NAME".device label="Device: $FRIENDLY_DEVICE" \
      label.font="Iosevka Nerd Font:Regular:13.0" label.color="$THEME_SAGE"

# Line 2: Volume
sketchybar --set "$NAME".volume label="Volume: ${VOLUME}%" 2>/dev/null || \
  sketchybar --add item "$NAME".volume popup."$NAME" \
    --set "$NAME".volume label="Volume: ${VOLUME}%" \
      label.font="Iosevka Nerd Font:Regular:13.0" label.color="$THEME_SAGE"

# AirPods battery info (only if AirPods are connected)
if [[ "$DEVICE" == *"AirPods"* ]]; then
  # Get Bluetooth info
  BT_INFO=$(system_profiler SPBluetoothDataType 2>/dev/null)

  # Extract battery levels - look for the AirPods section and get battery info
  # Parse battery levels (format: "Battery Level (Left): XX%")
  LEFT_BATTERY=$(echo "$BT_INFO" | grep -A 20 "$DEVICE" | grep "Left" | head -1 | grep -oE '[0-9]+%' | head -1)
  RIGHT_BATTERY=$(echo "$BT_INFO" | grep -A 20 "$DEVICE" | grep "Right" | head -1 | grep -oE '[0-9]+%' | head -1)
  CASE_BATTERY=$(echo "$BT_INFO" | grep -A 20 "$DEVICE" | grep "Case" | head -1 | grep -oE '[0-9]+%' | head -1)

  # Build battery string
  BATTERY_INFO=""
  [ -n "$LEFT_BATTERY" ] && BATTERY_INFO="L: $LEFT_BATTERY"
  [ -n "$RIGHT_BATTERY" ] && BATTERY_INFO="$BATTERY_INFO  R: $RIGHT_BATTERY"
  [ -n "$CASE_BATTERY" ] && BATTERY_INFO="$BATTERY_INFO  C: $CASE_BATTERY"

  if [ -n "$BATTERY_INFO" ]; then
    sketchybar --set "$NAME".battery label="Battery: $BATTERY_INFO" 2>/dev/null || \
      sketchybar --add item "$NAME".battery popup."$NAME" \
        --set "$NAME".battery label="Battery: $BATTERY_INFO" \
          label.font="Iosevka Nerd Font:Regular:13.0" label.color="$THEME_LAVENDER"
  fi
fi

