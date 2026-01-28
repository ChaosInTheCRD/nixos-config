#!/bin/sh

# Update with compact day and time format (e.g., "Fri 24 18:30")
sketchybar --set $NAME label="$(date '+%a %-d %H:%M' | tr '[:upper:]' '[:lower:]')"
