#!/bin/sh

# Update the time label
sketchybar --set $NAME label="$(date '+%H:%M' | tr '[:upper:]' '[:lower:]')"
