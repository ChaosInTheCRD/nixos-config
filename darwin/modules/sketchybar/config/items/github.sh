#!/usr/bin/env sh

# Check if GitHub CLI is installed
if ! command -v gh &> /dev/null; then
		sketchybar --set $NAME label=" 0" --set '/github.*/' drawing=on
    exit 1
fi

# Authenticate if not already authenticated
if ! gh auth status &> /dev/null; then
		sketchybar --set $NAME label=" 0" --set '/github.*/' drawing=on
    exit 1
fi

# Get the number of notifications
NOT=$(gh api notifications --jq 'length')

sketchybar --set $NAME icon="" label="$NOT" --set '/github.*/' drawing=on
