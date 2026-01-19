#!/usr/bin/env sh

# 1. Check if SwitchAudioSource is installed
if ! command -v SwitchAudioSource &> /dev/null; then
  sketchybar --set $NAME icon="󰖁" label="Err"
  exit 1
fi

# 2. Get the Current Output Device
DEVICE=$(SwitchAudioSource -c -t output)

if [ "$DEVICE" == "External Headphones" ]; then
  DEVICE="Aux"
fi

# 3. Handle the Volume Variable
# If $INFO is empty (e.g., manual run), fetch current volume via osascript
if [ -z "$INFO" ]; then
  VOLUME=$(osascript -e "output volume of (get volume settings)")
else
  VOLUME=$INFO
fi

# 4. Update the Bar
if [ "$VOLUME" -eq 0 ]; then
  sketchybar --set $NAME icon="" label="$DEVICE"
else
  sketchybar --set $NAME icon="" label="$DEVICE"
fi
