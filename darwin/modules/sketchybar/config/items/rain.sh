#!/bin/bash

# --- Configuration ---
GRAPH_BAR_WIDTH=4
# "Substantial" means rain >= 0.1mm. Anything less is considered "spitting".
THRESHOLD_LIGHT=0.1
THRESHOLD_HEAVY=0.8
URGENT_COLOR=0xff08F7FE
URGENT_FILL="0x4D${URGENT_COLOR:4}"

source "$HOME/.config/sketchybar/colorpresets/custom-theme.sh"

echo "----------------------------------------------------"
echo "Rain Script Started: $(date)"

# 1. Location Fetching
IP_INFO=$(curl -s https://ipapi.co/json/)
if [ -z "$IP_INFO" ] || echo "$IP_INFO" | jq -e '.error' >/dev/null; then
  echo "Error fetching IP info."
  exit 1
fi
LAT=$(echo "$IP_INFO" | jq -r '.latitude')
LON=$(echo "$IP_INFO" | jq -r '.longitude')
CITY=$(echo "$IP_INFO" | jq -r '.city')
REGION=$(echo "$IP_INFO" | jq -r '.region')

echo "Location Deduced: $CITY, $REGION (Lat: $LAT, Lon: $LON)"

# 2. Fetch Data
API_URL="https://api.open-meteo.com/v1/forecast?latitude=$LAT&longitude=$LON&minutely_15=precipitation&hourly=precipitation&forecast_days=2&timezone=auto"
echo "Curl Request URL: $API_URL"

WEATHER_JSON=$(curl -s "$API_URL")
if [ -z "$WEATHER_JSON" ] || echo "$WEATHER_JSON" | jq -e '.error' >/dev/null; then
  echo "Error: Weather API returned no data or error."
  exit 1
fi

# 3. Time Indexing
H=$(date +%H)
M=$(date +%M)
M_ROUND=$((M - (M % 15)))
TIME_STRING=$(date +"%Y-%m-%dT$H"):$(printf "%02d" $M_ROUND)
echo "Targeting Time Interval: $TIME_STRING"

CURRENT_INDEX=$(echo "$WEATHER_JSON" | jq ".minutely_15.time | index(\"$TIME_STRING\")")
if [ "$CURRENT_INDEX" == "null" ] || [ -z "$CURRENT_INDEX" ]; then
  CURRENT_INDEX=0
fi

# 4. Extract Data
PRECIP_DATA=$(echo "$WEATHER_JSON" | jq -r ".minutely_15.precipitation[$CURRENT_INDEX:$((CURRENT_INDEX + 32))] | .[]")
TIME_DATA=$(echo "$WEATHER_JSON" | jq -r ".minutely_15.time[$CURRENT_INDEX:$((CURRENT_INDEX + 32))] | .[]")

PRECIP_ARRAY=()
while read -r line; do PRECIP_ARRAY+=("$line"); done <<<"$PRECIP_DATA"
TIME_ARRAY=()
while read -r line; do TIME_ARRAY+=("$line"); done <<<"$TIME_DATA"

# 5. Process Data
GRAPH_POINTS=""
NEXT_RAIN_TIME=""
IS_RAINING_NOW=false

echo "--- Rain Data Dump (Next 8h) ---"
for ((i = 0; i < 32; i++)); do
  val="${PRECIP_ARRAY[$i]}"
  time_val="${TIME_ARRAY[$i]}"
  echo "$time_val - $val"

  # Check "Now" (Index 0) - Only counts if substantial
  if [ $i -eq 0 ]; then
    if (($(echo "$val >= $THRESHOLD_LIGHT" | bc -l))); then
      IS_RAINING_NOW=true
    fi
  fi

  # Find next SUBSTANTIAL rain time
  if [ -z "$NEXT_RAIN_TIME" ] && (($(echo "$val >= $THRESHOLD_LIGHT" | bc -l))); then
    NEXT_RAIN_TIME=$(echo "$time_val" | cut -d'T' -f2)
  fi

  # Graph Logic (Visuals)
  if (($(echo "$val == 0" | bc -l))); then
    level="0.00"
  elif (($(echo "$val < 0.1" | bc -l))); then
    level="0.10"
  elif (($(echo "$val < 0.3" | bc -l))); then
    level="0.25"
  elif (($(echo "$val < 0.8" | bc -l))); then
    level="0.50"
  else level="0.80"; fi

  block=""
  for ((k = 0; k < GRAPH_BAR_WIDTH; k++)); do block="$block $level"; done
  GRAPH_POINTS="$GRAPH_POINTS$block"
done
echo "--------------------------------"

# 6. Styling Logic (UPDATED)
MAX_RAIN=$(echo "${PRECIP_ARRAY[@]}" | tr ' ' '\n' | sort -nr | head -n1)
if [ -z "$MAX_RAIN" ]; then MAX_RAIN=0; fi

# Determine Color Intensity
if (($(echo "$MAX_RAIN > $THRESHOLD_HEAVY" | bc -l))); then
  RAIN_COLOR=$PINK
elif (($(echo "$MAX_RAIN > 0.3" | bc -l))); then
  RAIN_COLOR=$LAVENDER
elif (($(echo "$MAX_RAIN >= $THRESHOLD_LIGHT" | bc -l))); then
  RAIN_COLOR=$SAGE
else
  RAIN_COLOR=$YELLOW
fi

# Determine Icon & State
# STRICT CHECK: Max Rain must be >= THRESHOLD_LIGHT (0.1) to trigger Rain Mode
if (($(echo "$MAX_RAIN >= $THRESHOLD_LIGHT" | bc -l))); then

  if $IS_RAINING_NOW; then
    echo "State: Raining Now (Substantial) -> High Vis, No Label"
    sketchybar --set "$NAME" \
      icon=󰖗 \
      icon.color="$RAIN_COLOR" \
      graph.color="$RAIN_COLOR" \
      label.drawing=off

  elif [ -n "$NEXT_RAIN_TIME" ]; then
    echo "State: Substantial Rain Incoming ($NEXT_RAIN_TIME) -> High Vis + Label"
    sketchybar --set "$NAME" \
      icon=󰖗 \
      icon.color="$URGENT_COLOR" \
      graph.color="$URGENT_COLOR" \
      graph.fill_color="$URGENT_FILL" \
      label="($NEXT_RAIN_TIME)" \
      label.color="$URGENT_COLOR" \
      label.drawing=on \
      label.font.size=9.0 \
      label.y_offset=1
  fi

else
  # State: Dry OR merely "spitting" (trace amounts < 0.1)
  echo "State: Dry/Spitting -> Sun Icon, Yellow"
  sketchybar --set "$NAME" \
    icon=󰖙 \
    icon.color=0xffFFD700 \
    graph.color=0xffFFD700 \
    label.drawing=off
fi

echo "--- Raw Graph Output ---"
echo "$GRAPH_POINTS"
echo "--------------------------------"

sketchybar --push "$NAME" $GRAPH_POINTS
