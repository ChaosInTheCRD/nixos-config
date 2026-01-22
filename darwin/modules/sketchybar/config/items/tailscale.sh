#!/usr/bin/env sh

source "$HOME/.config/sketchybar/colorpresets/custom-theme.sh"

TAILSCALE_CMD="/Applications/Tailscale.app/Contents/MacOS/Tailscale"

# Colors for each state
COLOR_TAILSCALE="0xff08F7FE"      # Cyan for tailscale.com
COLOR_PERSONAL="0xffD83F87"       # Pink for personal
COLOR_OFF="0xffA4B3B6"            # Grey for off

# Tailnet names (for detection via .CurrentTailnet.Name)
TAILNET_WORK="tailscale.com"
TAILNET_PERSONAL="tpmeadows1@gmail.com"

# Profile IDs (for tailscale switch command - from `tailscale switch --list`)
PROFILE_WORK="92fe"
PROFILE_PERSONAL="19a0"

# Icon
ICON="󰸳"

# Theme colors for popup
THEME_SAGE="0xffA4B3B6"
THEME_LAVENDER="0xffE98074"

# Handle mouse events for hover popup
if [ "$SENDER" = "mouse.entered" ]; then
  sketchybar --set $NAME popup.drawing=on
  exit 0
fi

if [ "$SENDER" = "mouse.exited" ]; then
  sketchybar --set $NAME popup.drawing=off
  exit 0
fi

# Get current tailnet from Tailscale (for initial state)
get_current_tailnet() {
  if [ -x "$TAILSCALE_CMD" ]; then
    STATUS=$("$TAILSCALE_CMD" status --json 2>/dev/null)
    if [ $? -eq 0 ] && [ -n "$STATUS" ]; then
      BACKEND_STATE=$(echo "$STATUS" | jq -r '.BackendState // empty')
      if [ "$BACKEND_STATE" = "Running" ]; then
        echo "$STATUS" | jq -r '.CurrentTailnet.Name // empty'
      else
        echo "off"
      fi
    else
      echo "off"
    fi
  else
    echo "off"
  fi
}

# Get Tailscale IP
get_tailscale_ip() {
  if [ -x "$TAILSCALE_CMD" ]; then
    "$TAILSCALE_CMD" ip -4 2>/dev/null
  fi
}

# Update the bar icon color based on state
update_display() {
  local STATE=$1

  case "$STATE" in
    "$TAILNET_WORK")
      sketchybar --set $NAME icon="$ICON" icon.color="$COLOR_TAILSCALE"
      ;;
    "$TAILNET_PERSONAL")
      sketchybar --set $NAME icon="$ICON" icon.color="$COLOR_PERSONAL"
      ;;
    *)
      sketchybar --set $NAME icon="$ICON" icon.color="$COLOR_OFF"
      ;;
  esac
}

# Update popup
update_popup() {
  local STATE=$1
  local TS_IP=$2

  sketchybar --set "$NAME" popup.align=center

  # Line 1: Status
  if [ "$STATE" = "off" ]; then
    STATUS_LABEL="Status: Off"
  else
    STATUS_LABEL="Status: Connected"
  fi
  sketchybar --set "$NAME".status label="$STATUS_LABEL" 2>/dev/null || \
    sketchybar --add item "$NAME".status popup."$NAME" \
      --set "$NAME".status label="$STATUS_LABEL" \
        label.font="Iosevka Nerd Font:Regular:13.0" label.color="$THEME_SAGE"

  # Line 2: Tailnet
  if [ "$STATE" != "off" ]; then
    sketchybar --set "$NAME".tailnet label="Tailnet: $STATE" drawing=on 2>/dev/null || \
      sketchybar --add item "$NAME".tailnet popup."$NAME" \
        --set "$NAME".tailnet label="Tailnet: $STATE" \
          label.font="Iosevka Nerd Font:Regular:13.0" label.color="$THEME_SAGE"

    # Line 3: IP
    if [ -n "$TS_IP" ]; then
      sketchybar --set "$NAME".ip label="IP: $TS_IP" drawing=on 2>/dev/null || \
        sketchybar --add item "$NAME".ip popup."$NAME" \
          --set "$NAME".ip label="IP: $TS_IP" \
            label.font="Iosevka Nerd Font:Regular:13.0" label.color="$THEME_LAVENDER"
    else
      # No IP available, hide the item
      sketchybar --set "$NAME".ip drawing=off 2>/dev/null
    fi
  else
    # Off state - hide tailnet and IP items
    sketchybar --set "$NAME".tailnet drawing=off 2>/dev/null
    sketchybar --set "$NAME".ip drawing=off 2>/dev/null
  fi
}

# Update popup with transitional state (for click feedback)
update_popup_transitional() {
  local NEXT_STATE=$1

  sketchybar --set "$NAME" popup.align=center

  if [ "$NEXT_STATE" = "off" ]; then
    # Disconnecting
    sketchybar --set "$NAME".status label="Status: Disconnecting..." 2>/dev/null || \
      sketchybar --add item "$NAME".status popup."$NAME" \
        --set "$NAME".status label="Status: Disconnecting..." \
          label.font="Iosevka Nerd Font:Regular:13.0" label.color="$THEME_SAGE"
    sketchybar --set "$NAME".tailnet drawing=off 2>/dev/null
    sketchybar --set "$NAME".ip drawing=off 2>/dev/null
  else
    # Connecting to a tailnet
    sketchybar --set "$NAME".status label="Status: Connecting..." 2>/dev/null || \
      sketchybar --add item "$NAME".status popup."$NAME" \
        --set "$NAME".status label="Status: Connecting..." \
          label.font="Iosevka Nerd Font:Regular:13.0" label.color="$THEME_SAGE"
    sketchybar --set "$NAME".tailnet label="Tailnet: $NEXT_STATE" drawing=on 2>/dev/null || \
      sketchybar --add item "$NAME".tailnet popup."$NAME" \
        --set "$NAME".tailnet label="Tailnet: $NEXT_STATE" \
          label.font="Iosevka Nerd Font:Regular:13.0" label.color="$THEME_SAGE"
    sketchybar --set "$NAME".ip label="IP: ..." drawing=on 2>/dev/null || \
      sketchybar --add item "$NAME".ip popup."$NAME" \
        --set "$NAME".ip label="IP: ..." \
          label.font="Iosevka Nerd Font:Regular:13.0" label.color="$THEME_LAVENDER"
  fi
}

# Handle click - cycle through states
if [ "$SENDER" = "mouse.clicked" ]; then
  # Get current state
  CURRENT=$(get_current_tailnet)

  # Determine next state (tailnet name for display) and profile ID (for switch command)
  case "$CURRENT" in
    "$TAILNET_WORK")
      NEXT="$TAILNET_PERSONAL"
      NEXT_PROFILE="$PROFILE_PERSONAL"
      ;;
    "$TAILNET_PERSONAL")
      NEXT="off"
      NEXT_PROFILE=""
      ;;
    *)
      NEXT="$TAILNET_WORK"
      NEXT_PROFILE="$PROFILE_WORK"
      ;;
  esac

  # Update display and popup IMMEDIATELY (before the actual switch)
  update_display "$NEXT"
  update_popup_transitional "$NEXT"

  # Run the actual switch in background, then trigger updates
  (
    if [ "$NEXT" = "off" ]; then
      "$TAILSCALE_CMD" down 2>/dev/null
      sleep 1
    else
      "$TAILSCALE_CMD" switch "$NEXT_PROFILE" 2>/dev/null
      sleep 1
      # If not running after switch, bring it up
      STATE=$("$TAILSCALE_CMD" status --json 2>/dev/null | jq -r '.BackendState // empty')
      if [ "$STATE" != "Running" ]; then
        "$TAILSCALE_CMD" up 2>/dev/null
      fi
      # Poll until BackendState is Running (max 10 seconds)
      for i in 1 2 3 4 5 6 7 8 9 10; do
        sleep 1
        STATE=$("$TAILSCALE_CMD" status --json 2>/dev/null | jq -r '.BackendState // empty')
        if [ "$STATE" = "Running" ]; then
          break
        fi
      done
    fi
    # Update the display with actual state
    ACTUAL=$("$TAILSCALE_CMD" status --json 2>/dev/null)
    BACKEND=$(echo "$ACTUAL" | jq -r '.BackendState // empty')
    if [ "$BACKEND" = "Running" ]; then
      TAILNET=$(echo "$ACTUAL" | jq -r '.CurrentTailnet.Name // empty')
      IP=$("$TAILSCALE_CMD" ip -4 2>/dev/null)
      # Update icon color
      case "$TAILNET" in
        "tailscale.com")
          sketchybar --set tailscale icon.color="0xff08F7FE"
          ;;
        "tpmeadows1@gmail.com")
          sketchybar --set tailscale icon.color="0xffD83F87"
          ;;
        *)
          sketchybar --set tailscale icon.color="0xffA4B3B6"
          ;;
      esac
      # Update popup
      sketchybar --set tailscale.status label="Status: Connected" 2>/dev/null
      sketchybar --set tailscale.tailnet label="Tailnet: $TAILNET" drawing=on 2>/dev/null
      sketchybar --set tailscale.ip label="IP: $IP" drawing=on 2>/dev/null
    else
      sketchybar --set tailscale icon.color="0xffA4B3B6"
      sketchybar --set tailscale.status label="Status: Off" 2>/dev/null
      sketchybar --set tailscale.tailnet drawing=off 2>/dev/null
      sketchybar --set tailscale.ip drawing=off 2>/dev/null
    fi
  ) &

  exit 0
fi

# Normal update - get actual current state
CURRENT=$(get_current_tailnet)
TS_IP=$(get_tailscale_ip)
update_display "$CURRENT"
update_popup "$CURRENT" "$TS_IP"
