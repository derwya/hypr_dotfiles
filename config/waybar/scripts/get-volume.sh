#!/bin/bash

# Check if there's a playing media app
PLAYER=$(playerctl -l 2>/dev/null | head -n1)

if [ -n "$PLAYER" ]; then
  # Get the process name from playerctl player
  PROCESS_NAME=$(echo "$PLAYER" | cut -d'.' -f1)

  # Find the PID of the media player
  case "$PROCESS_NAME" in
  spotify)
    PID=$(pgrep -x spotify)
    ;;
  firefox)
    PID=$(pgrep -x "firefox" -o pgrep -x "zen-bin" -o pgrep -x ".zen-wrapped" -o pgrep -x "firefox-bin" | head -n1)
    if [ -z "$PID" ]; then
      PID=$(pgrep "firefox|zen" | head -n1)
    fi
    ;;
  chromium | chrome)
    PID=$(pgrep -x "chromium" -o pgrep -x "chrome" -o pgrep -x "chromium-browser" | head -n1)
    ;;
  brave)
    PID=$(pgrep -x "brave" -o pgrep -x "brave-browser" | head -n1)
    ;;
  edge)
    PID=$(pgrep -x "msedge" -o pgrep -x "microsoft-edge" | head -n1)
    ;;
  opera)
    PID=$(pgrep -x "opera" | head -n1)
    ;;
  vlc)
    PID=$(pgrep -x vlc)
    ;;
  mpv)
    PID=$(pgrep -x mpv)
    ;;
  *)
    PID=$(pgrep -x "$PROCESS_NAME" | head -n1)
    ;;
  esac

  # If we found a PID, get its volume
  if [ -n "$PID" ]; then
    SINK_INPUT=$(pactl list sink-inputs | grep -B 20 "application.process.id = \"$PID\"" | grep "Sink Input" | head -n1 | awk '{print $3}' | tr -d '#')

    if [ -n "$SINK_INPUT" ]; then
      # Get the actual volume percentage from the sink input
      VOLUME_LINE=$(pactl list sink-inputs | grep -A 15 "Sink Input #$SINK_INPUT" | grep "Volume:" | head -n1)
      # Extract percentage - works with formats like "0: 65%" or "front-left: 12345 /  65%"
      VOLUME=$(echo "$VOLUME_LINE" | grep -oP '\d+%' | head -n1 | tr -d '%')

      MUTED=$(pactl list sink-inputs | grep -A 15 "Sink Input #$SINK_INPUT" | grep "Mute:" | awk '{print $2}')

      if [ "$MUTED" = "yes" ]; then
        echo "{\"text\":\"$VOLUME\",\"class\":\"muted\",\"alt\":\"muted\"}"
      else
        echo "{\"text\":\"$VOLUME\",\"class\":\"app\",\"alt\":\"app\"}"
      fi
      exit 0
    fi
  fi
fi

# Fall back to system volume
VOLUME=$(pactl get-sink-volume @DEFAULT_SINK@ | grep -oP '\d+%' | head -n1 | tr -d '%')
MUTED=$(pactl get-sink-mute @DEFAULT_SINK@ | grep -oP '(yes|no)')

if [ "$MUTED" = "yes" ]; then
  echo "{\"text\":\"$VOLUME\",\"class\":\"muted\",\"alt\":\"muted\"}"
else
  echo "{\"text\":\"$VOLUME\",\"class\":\"system\",\"alt\":\"system\"}"
fi
