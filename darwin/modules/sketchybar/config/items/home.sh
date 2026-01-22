#!/usr/bin/env sh

# Simple home icon - opens System Settings when clicked

ICON_COLOR="0xff50FA7B" # Green for plant icon

# Handle click
if [ "$SENDER" = "mouse.clicked" ]; then
  open -a "System Preferences" 2>/dev/null || open -a "System Settings"
  exit 0
fi

# Set up the icon
sketchybar --set $NAME icon="" icon.color="$ICON_COLOR"
