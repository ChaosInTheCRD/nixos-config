#!/bin/sh

PERCENTAGE=$(pmset -g batt | grep -Eo "\d+%" | cut -d% -f1)
CHARGING=$(pmset -g batt | grep 'AC Power')

if [ "$PERCENTAGE" = "" ]; then
  exit 0
fi

# Get wattage if charging
WATTAGE=""
if [[ "$CHARGING" != "" ]]; then
  # Try to get wattage directly
  WATTAGE=$(system_profiler SPPowerDataType 2>/dev/null | grep "Wattage (W):" | awk '{print $NF}' | tr -d '\n')

  # If direct wattage is not found, try to calculate from Voltage and Amperage
  if [ -z "$WATTAGE" ]; then
    AMPERAGE_MA=$(system_profiler SPPowerDataType 2>/dev/null | grep "Amperage (mA):" | awk '{print $NF}' | tr -d '\n')
    VOLTAGE_MV=$(system_profiler SPPowerDataType 2>/dev/null | grep "Voltage (mV):" | awk '{print $NF}' | tr -d '\n')

    if [ -n "$AMPERAGE_MA" ] && [ -n "$VOLTAGE_MV" ]; then
      # Calculate wattage: (mA * mV) / 1,000,000 = Watts
      WATTAGE=$(echo "scale=0; ($AMPERAGE_MA * $VOLTAGE_MV) / 1000000" | bc 2>/dev/null)
    fi
  fi
fi

case "${PERCENTAGE}" in
9[0-9] | 100)
  ICON=""
  ;;
[6-8][0-9])
  ICON=""
  ;;
[3-5][0-9])
  ICON=""
  ;;
[1-2][0-9])
  ICON=""
  ;;
*) ICON="" ;;
esac

LABEL_TEXT="${PERCENTAGE}%"

if [[ "$CHARGING" != "" ]]; then
  ICON=""
  if [ -n "$WATTAGE" ]; then
    LABEL_TEXT="${PERCENTAGE}% (${WATTAGE}W)"
  fi
fi

# The item invoking this script (name $NAME) will get its icon and label
# updated with the current battery status
sketchybar --set "$NAME" icon="$ICON" label="$LABEL_TEXT"
