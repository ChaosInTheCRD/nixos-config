#!/usr/bin/env sh
RUNNING=$(osascript -e 'if application "Spotify" is running then return 0')
if [ "$RUNNING" == "" ]; then
	RUNNING=1
fi
NOTCH_ON=$(system_profiler SPDisplaysDataType | awk '/Main Display/ {print $3}')
TRIM=19
PLAYING=1
TRACK=""
ALBUM=""
ARTIST=""
if [ "$(osascript -e 'if application "Spotify" is running then tell application "Spotify" to get player state')" == "playing" ]; then
	PLAYING=0
	TRACK=$(osascript -e 'tell application "Spotify" to get name of current track')
	ARTIST=$(osascript -e 'tell application "Spotify" to get artist of current track')
	ALBUM=$(osascript -e 'tell application "Spotify" to get album of current track')
fi
if [ $RUNNING -eq 0 ] && [ $PLAYING -eq 0 ]; then
	if [ "$(echo " $TRACK - $ARTIST" | wc -c)" -gt $TRIM ] && [ $NOTCH_ON == "Yes" ]; then
		LESS=$(echo " $TRACK - $ARTIST" | cut -c 1-$TRIM)
		LESS="$LESS..."
		sketchybar --set $NAME label="$LESS" --set '/spot.*/' drawing=on
	else
		if [ "$ARTIST" == "" ]; then
			sketchybar --set $NAME label=" $TRACK - $ALBUM" --set '/spot.*/' drawing=on
		else
			sketchybar --set $NAME label=" $TRACK - $ARTIST" --set '/spot.*/' drawing=on
		fi
	fi
else
	sketchybar --set '/spot.*/' drawing=off
fi
