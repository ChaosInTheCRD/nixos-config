#!/usr/bin/env sh

# Check if SwitchAudioSource CLI is installed
if ! command -v SwitchAudioSource &> /dev/null; then
    sketchybar --set $NAME icon="󰖁" label="Err" --set '/audio.*/' drawing=on
    exit 1
fi

# Get the number of notifications
DEVICE=$(SwitchAudioSource -c -t output)

if [ "$VOLUME" -eq 0 ]; then
  sketchybar --set $NAME icon="" label="$DEVICE" --set '/audio.*/' drawing=on
else
  sketchybar --set $NAME icon="" label="$DEVICE" --set '/audio.*/' drawing=on
fi
