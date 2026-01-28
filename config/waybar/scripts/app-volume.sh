#!/bin/bash

# Get the currently playing media player
PLAYER=$(playerctl -l 2>/dev/null | head -n1)

if [ -z "$PLAYER" ]; then
    # No player found, control system volume instead
    case "$1" in
        up)
            pactl set-sink-volume @DEFAULT_SINK@ +5%
            ;;
        down)
            pactl set-sink-volume @DEFAULT_SINK@ -5%
            ;;
    esac
    exit 0
fi

# Get the process name from playerctl player
PROCESS_NAME=$(echo "$PLAYER" | cut -d'.' -f1)

# Find the PID of the media player
case "$PROCESS_NAME" in
    spotify)
        PID=$(pgrep -x spotify)
        ;;
    firefox)
        # Firefox, Zen, and all Firefox-based browsers
        # Try multiple possible process names
        PID=$(pgrep -x "firefox" -o pgrep -x "zen-bin" -o pgrep -x ".zen-wrapped" -o pgrep -x "firefox-bin" | head -n1)
        if [ -z "$PID" ]; then
            PID=$(pgrep "firefox|zen" | head -n1)
        fi
        ;;
    chromium|chrome)
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
        # Fallback: try to find by process name
        PID=$(pgrep -x "$PROCESS_NAME" | head -n1)
        ;;
esac

# If we found a PID, control its volume
if [ -n "$PID" ]; then
    # Get all sink inputs and find the one matching our PID
    SINK_INPUT=$(pactl list sink-inputs | grep -B 20 "application.process.id = \"$PID\"" | grep "Sink Input" | head -n1 | awk '{print $3}' | tr -d '#')
    
    if [ -n "$SINK_INPUT" ]; then
        case "$1" in
            up)
                # Get current volume
                CURRENT_VOL=$(pactl list sink-inputs | grep -A 15 "Sink Input #$SINK_INPUT" | grep "Volume:" | head -n1 | grep -oP '\d+%' | head -n1 | tr -d '%')
                # Only increase if under 100%
                if [ "$CURRENT_VOL" -lt 100 ]; then
                    pactl set-sink-input-volume "$SINK_INPUT" +5%
                    # Cap at 100% if we went over
                    NEW_VOL=$(pactl list sink-inputs | grep -A 15 "Sink Input #$SINK_INPUT" | grep "Volume:" | head -n1 | grep -oP '\d+%' | head -n1 | tr -d '%')
                    if [ "$NEW_VOL" -gt 100 ]; then
                        pactl set-sink-input-volume "$SINK_INPUT" 100%
                    fi
                fi
                ;;
            down)
                pactl set-sink-input-volume "$SINK_INPUT" -5%
                ;;
        esac
    else
        # If sink input not found, fall back to system volume
        case "$1" in
            up)
                # Get current system volume
                CURRENT_VOL=$(pactl get-sink-volume @DEFAULT_SINK@ | grep -oP '\d+%' | head -n1 | tr -d '%')
                # Only increase if under 100%
                if [ "$CURRENT_VOL" -lt 100 ]; then
                    pactl set-sink-volume @DEFAULT_SINK@ +5%
                    # Cap at 100% if we went over
                    NEW_VOL=$(pactl get-sink-volume @DEFAULT_SINK@ | grep -oP '\d+%' | head -n1 | tr -d '%')
                    if [ "$NEW_VOL" -gt 100 ]; then
                        pactl set-sink-volume @DEFAULT_SINK@ 100%
                    fi
                fi
                ;;
            down)
                pactl set-sink-volume @DEFAULT_SINK@ -5%
                ;;
        esac
    fi
else
    # No PID found, control system volume
    case "$1" in
        up)
            pactl set-sink-volume @DEFAULT_SINK@ +5%
            ;;
        down)
            pactl set-sink-volume @DEFAULT_SINK@ -5%
            ;;
    esac
fi
