#!/bin/bash
# Usage: ./launch_bar.sh [top|bottom] scaling

SIDE=$1
SCALING=$2
CONFIG="$HOME/.config/waybar/config-$SIDE"
STYLE="$HOME/.config/waybar/style.css"
# Update path if your binary name is different
AUTOHIDE="$HOME/.config/hypr/scripts/waybar_auto_hide"

# 1. Kill old instances for this specific config
pkill -f "waybar -c $CONFIG"

# 2. Start Waybar
waybar -c "$CONFIG" -s "$STYLE" &

# 3. Get the PID of the Waybar we just started
WAYBAR_PID=$!

# 4. Start the auto-hide utility pointing to that specific PID
$AUTOHIDE --side "$SIDE" --pid "$WAYBAR_PID" --scaling "$SCALING"
