#!/bin/sh

# Target date: April 15th, 2029, 00:00:00 (midnight)
TARGET_DATE_STR="2029-04-15 00:00:00"

# Reference start date: Set this to the BEGINNING of your desired progress period
START_DATE_STR="2025-04-15 00:00:00"

# Get current Unix timestamp
CURRENT_TIMESTAMP=$(date +%s)

# --- Robust method to get target Unix timestamp ---
TARGET_TIMESTAMP=""
START_TIMESTAMP=""

# Try with GNU date (if installed via Homebrew on macOS, 'gdate')
if command -v gdate >/dev/null 2>&1; then
  TARGET_TIMESTAMP=$(gdate -d "$TARGET_DATE_STR" +%s 2>/dev/null)
  START_TIMESTAMP=$(gdate -d "$START_DATE_STR" +%s 2>/dev/null)
fi

# Fallback to macOS's native date command if gdate isn't found or fails
if [ -z "$TARGET_TIMESTAMP" ] || [ -z "$START_TIMESTAMP" ]; then
  TARGET_TIMESTAMP=$(date -j -f "%Y-%m-%d %H:%M:%S" "$TARGET_DATE_STR" +%s 2>/dev/null)
  START_TIMESTAMP=$(date -j -f "%Y-%m-%d %H:%M:%S" "$START_DATE_STR" +%s 2>/dev/null)
fi

# Final check: if timestamps are still empty, something is wrong
if [ -z "$TARGET_TIMESTAMP" ] || [ -z "$START_TIMESTAMP" ]; then
  sketchybar --set "$NAME" label="Date Error" icon=""
  exit 1
fi

# Calculate total duration of the period (Start to Target)
TOTAL_DURATION_SECONDS=$((TARGET_TIMESTAMP - START_TIMESTAMP))

# Calculate time elapsed since the start date (Start to Current)
ELAPSED_SECONDS=$((CURRENT_TIMESTAMP - START_TIMESTAMP))

# Handle cases where current time is outside the defined range
if [ "$TOTAL_DURATION_SECONDS" -le 0 ]; then
  sketchybar --set "$NAME" label="Invalid Dates" icon=""
  exit 1
fi

# If current time is before the start date
if [ "$ELAPSED_SECONDS" -lt 0 ]; then
  # Calculate days until start
  DAYS_UNTIL_START=$(((START_TIMESTAMP - CURRENT_TIMESTAMP) / (60 * 60 * 24)))
  sketchybar --set "$NAME" label="Starts ${DAYS_UNTIL_START}d" icon="" # Shows days until it starts
  exit 0
elif [ "$ELAPSED_SECONDS" -ge "$TOTAL_DURATION_SECONDS" ]; then
  sketchybar --set "$NAME" label="Completed! 🥳" icon="" # Green checkmark icon
  exit 0
fi

# Calculate percentage complete (using bc for floating point arithmetic)
PERCENTAGE=$(echo "scale=2; ($ELAPSED_SECONDS * 100) / $TOTAL_DURATION_SECONDS" | bc -l)

# Round to nearest integer for bar representation
PERCENTAGE_INT=$(printf "%.0f\n" "$PERCENTAGE")

# Define progress bar characters and length
BAR_LENGTH=16 # Changed to 20 for more granularity (each bar is 5%)
FILLED_CHAR="█"
EMPTY_CHAR="░"

# Calculate number of filled and empty characters
FILLED_CHARS=$((PERCENTAGE_INT * BAR_LENGTH / 100))
EMPTY_CHARS=$((BAR_LENGTH - FILLED_CHARS))

# Build the progress bar string
PROGRESS_BAR=""
for i in $(seq 1 $FILLED_CHARS); do
  PROGRESS_BAR="${PROGRESS_BAR}${FILLED_CHAR}"
done
for i in $(seq 1 $EMPTY_CHARS); do
  PROGRESS_BAR="${PROGRESS_BAR}${EMPTY_CHAR}"
done

# Format the output label
LABEL_TEXT="${PROGRESS_BAR} ${PERCENTAGE_INT}%"

# Set a generic icon (optional, you can remove if the bar is enough)
ICON="󱄾"

# Update the sketchybar item
sketchybar --set "$NAME" icon="$ICON" label="$LABEL_TEXT"
