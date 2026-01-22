#!/bin/sh

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

# Get local IP (prefer en0 for WiFi, fallback to other interfaces)
LOCAL_IP=$(ipconfig getifaddr en0 2>/dev/null)
[ -z "$LOCAL_IP" ] && LOCAL_IP=$(ipconfig getifaddr en1 2>/dev/null)
[ -z "$LOCAL_IP" ] && LOCAL_IP=$(scutil --nwi | grep address | sed 's/.*://' | tr -d ' ' | head -1)

# Check for VPN (utun interfaces) - exclude Tailscale
# Only flag as VPN if there's a utun AND Tailscale is not responsible for it
IS_VPN=""
UTUN_EXISTS=$(scutil --nwi | grep -m1 'utun' | awk '{ print $1 }')
if [ -n "$UTUN_EXISTS" ]; then
  # Check if Tailscale is running - if so, don't count as generic VPN
  TAILSCALE_CMD="/Applications/Tailscale.app/Contents/MacOS/Tailscale"
  if [ -x "$TAILSCALE_CMD" ]; then
    TS_STATE=$("$TAILSCALE_CMD" status --json 2>/dev/null | jq -r '.BackendState // empty')
    if [ "$TS_STATE" != "Running" ]; then
      IS_VPN="$UTUN_EXISTS"
    fi
  else
    IS_VPN="$UTUN_EXISTS"
  fi
fi

# Check for iPhone hotspot (SSID contains iPhone or iPad)
WIFI_SSID=$(networksetup -getairportnetwork en0 2>/dev/null | awk -F': ' '{print $2}')
[ -z "$WIFI_SSID" ] && WIFI_SSID=$(system_profiler SPAirPortDataType 2>/dev/null | awk '/Current Network Information:/{getline; gsub(/^[[:space:]]+|:[[:space:]]*$/, ""); print; exit}')
IS_HOTSPOT=""
if [[ "$WIFI_SSID" == *"iPhone"* ]] || [[ "$WIFI_SSID" == *"iPad"* ]] || [[ "$WIFI_SSID" == *"Hotspot"* ]]; then
  IS_HOTSPOT="yes"
fi

# Determine icon and color based on connection type
# Hotspot takes priority
HOTSPOT_GREEN="0xff50FA7B"

if [ -n "$IS_HOTSPOT" ]; then
  # Hotspot connected - phone icon takes priority
  if [ -n "$IS_VPN" ]; then
    ICON="󰄜 󰌆"  # Phone + shield icons
  else
    ICON="󰄜"  # Phone icon only
  fi
  ICON_COLOR="$HOTSPOT_GREEN"
elif [ -n "$IS_VPN" ]; then
  ICON="󰌆"  # Shield icon for VPN
  ICON_COLOR="$LAVENDER"
elif [ -n "$LOCAL_IP" ]; then
  ICON="󰖩"  # WiFi/network icon
  ICON_COLOR="$PINK"
else
  ICON="󰖪"  # Disconnected
  ICON_COLOR="$SAGE"
  LOCAL_IP="No Connection"
fi

# Update bar - show local IP
sketchybar --set $NAME icon="$ICON" icon.color="$ICON_COLOR" label="$LOCAL_IP"

# --- Update Popup ---
THEME_SAGE="0xffA4B3B6"
THEME_LAVENDER="0xffE98074"

sketchybar --set "$NAME" popup.align=center

# Line 1: Network name (SSID)
if [ -n "$WIFI_SSID" ]; then
  sketchybar --set "$NAME".ssid label="Network: $WIFI_SSID" 2>/dev/null || \
    sketchybar --add item "$NAME".ssid popup."$NAME" \
      --set "$NAME".ssid label="Network: $WIFI_SSID" \
        label.font="Iosevka Nerd Font:Regular:13.0" label.color="$THEME_SAGE"
fi

# Line 2: Local IP
sketchybar --set "$NAME".localip label="Local: $LOCAL_IP" 2>/dev/null || \
  sketchybar --add item "$NAME".localip popup."$NAME" \
    --set "$NAME".localip label="Local: $LOCAL_IP" \
      label.font="Iosevka Nerd Font:Regular:13.0" label.color="$THEME_SAGE"

# Line 3: VPN Status (non-Tailscale)
if [ -n "$IS_VPN" ]; then
  sketchybar --set "$NAME".vpn label="VPN: Active" drawing=on 2>/dev/null || \
    sketchybar --add item "$NAME".vpn popup."$NAME" \
      --set "$NAME".vpn label="VPN: Active" \
        label.font="Iosevka Nerd Font:Regular:13.0" label.color="$THEME_LAVENDER"
else
  # Hide VPN status if not active
  sketchybar --set "$NAME".vpn drawing=off 2>/dev/null
fi
