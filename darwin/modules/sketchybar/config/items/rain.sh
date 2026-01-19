#!/bin/bash

# 1. Location Fetching
IP_INFO=$(curl -s https://ipapi.co/json/)
LAT=$(echo "$IP_INFO" | jq -r '.latitude')
LON=$(echo "$IP_INFO" | jq -r '.longitude')

# 2. Fetch data
API_URL="https://api.open-meteo.com/v1/forecast?latitude=$LAT&longitude=$LON&minutely_15=precipitation,rain,showers&hourly=precipitation&forecast_days=1"
WEATHER_JSON=$(curl -s "$API_URL")

# 3. Time Indexing
NOW_EPOCH=$(date +%s)
ROUNDED_EPOCH=$(((NOW_EPOCH / 900) * 900))
if date --version >/dev/null 2>&1; then
  CURRENT_TIME=$(date -d "@$ROUNDED_EPOCH" +"%Y-%m-%dT%H:%M")
else
  CURRENT_TIME=$(date -r "$ROUNDED_EPOCH" +"%Y-%m-%dT%H:%M")
fi

# 4. Extracting Current 15-Min Data
SEARCH_INDEX=$(echo "$WEATHER_JSON" | jq ".minutely_15.time | index(\"$CURRENT_TIME\")")
if [ "$SEARCH_INDEX" == "null" ] || [ -z "$SEARCH_INDEX" ]; then SEARCH_INDEX=0; fi
RAW_VALUES=$(echo "$WEATHER_JSON" | jq -r ".minutely_15.precipitation[$SEARCH_INDEX:$((SEARCH_INDEX + 4))] | .[]")

# 5. Normalization & Icon Selection
SCALED_POINTS=""
TOTAL_RAIN=0
for val in $RAW_VALUES; do
  TOTAL_RAIN=$(echo "$TOTAL_RAIN + $val" | bc)
  if (($(echo "$val == 0" | bc -l))); then
    level="0.00"
  elif (($(echo "$val < 0.1" | bc -l))); then
    level="0.15"
  elif (($(echo "$val < 0.3" | bc -l))); then
    level="0.35"
  elif (($(echo "$val < 0.8" | bc -l))); then
    level="0.65"
  else level="0.92"; fi

  block=$(printf "%.2f %.2f %.2f %.2f %.2f %.2f %.2f %.2f %.2f %.2f %.2f %.2f %.2f %.2f %.2f %.2f %.2f %.2f %.2f %.2f " \
    $level $level $level $level $level $level $level $level $level $level $level $level $level $level $level $level $level $level $level $level)
  SCALED_POINTS="$SCALED_POINTS$block"
done

# 6. Styling: Rain vs. Sun
if (($(echo "$TOTAL_RAIN > 0.01" | bc -l))); then
  # RAINING: Cloud with Rain icon + Blue Border
  sketchybar --set "$NAME" icon=󰖗 \
    icon.color=0xff00FBFF \
    background.border_width=1 \
    background.border_color=0xff5DADE2
else
  # DRY: Sun icon + No Border
  sketchybar --set "$NAME" icon=󰖙 \
    icon.color=0xffFFD700 \
    background.border_width=0
fi

sketchybar --push "$NAME" $SCALED_POINTS
