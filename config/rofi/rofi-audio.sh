#!/bin/bash
# Enhanced Audio Selector for Rofi + Wireplumber

get_current_sink() {
  wpctl status | grep -A 20 "Sinks:" | grep "\*" | sed 's/^[ │]*\*//;s/^[ │]*//' | awk '{print $1}' | sed 's/\.//'
}

get_current_source() {
  wpctl status | grep -A 20 "Sources:" | grep "\*" | sed 's/^[ │]*\*//;s/^[ │]*//' | awk '{print $1}' | sed 's/\.//'
}

# Get current devices
CURRENT_SINK=$(get_current_sink)
CURRENT_SOURCE=$(get_current_source)

# Get list of sinks (outputs) with indicators
sinks=$(wpctl status | grep -A 20 "Sinks:" | grep -E '^[ │\*]+[0-9]+\.' | while read line; do
  # Remove leading characters and extract ID
  clean_line=$(echo "$line" | sed 's/^[ │\*]*//')
  id=$(echo "$clean_line" | awk '{print $1}' | sed 's/\.//')
  name=$(echo "$clean_line" | awk '{$1=""; print $0}' | sed 's/^ //')

  # Add indicator if current device
  if [ "$id" = "$CURRENT_SINK" ]; then
    echo "󰓃 [ACTIVE] $id. $name"
  else
    echo "󰓃 $id. $name"
  fi
done)

# Get list of sources (inputs) with indicators
sources=$(wpctl status | grep -A 20 "Sources:" | grep -E '^[ │\*]+[0-9]+\.' | while read line; do
  clean_line=$(echo "$line" | sed 's/^[ │\*]*//')
  id=$(echo "$clean_line" | awk '{print $1}' | sed 's/\.//')
  name=$(echo "$clean_line" | awk '{$1=""; print $0}' | sed 's/^ //')

  # Skip monitor sources
  if echo "$name" | grep -qi "monitor"; then
    continue
  fi

  # Add indicator if current device
  if [ "$id" = "$CURRENT_SOURCE" ]; then
    echo "󰍬 [ACTIVE] $id. $name"
  else
    echo "󰍬 $id. $name"
  fi
done)

# Get current volume
current_volume=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{print int($2*100)}')

# Build menu
MENU="--- OUTPUT DEVICES ---
$sinks

--- INPUT DEVICES ---
$sources

--- VOLUME CONTROLS ---
󰝝 Volume: $current_volume%
󰝞 Increase Volume (+5%)
󰝟 Decrease Volume (-5%)
󰖁 Mute/Unmute Output
󰍭 Mute/Unmute Input

--- SETTINGS ---
󰒓 Open Pavucontrol"

# Show rofi menu
selected=$(echo -e "$MENU" | rofi -dmenu -p "Audio" -i "$@")

# Handle selection
if [ -z "$selected" ]; then
  exit 0
fi

case "$selected" in
*"[ACTIVE]"* | "󰓃 "* | "󰍬 "*)
  # Extract ID and set as default
  id=$(echo "$selected" | grep -oP '\d+(?=\.)' | head -1)
  if [ -n "$id" ]; then
    # Determine if it's a sink or source based on icon
    if echo "$selected" | grep -q "󰓃"; then
      wpctl set-default "$id"
      notify-send "Audio" "Output device changed" -i audio-headphones-symbolic
    elif echo "$selected" | grep -q "󰍬"; then
      wpctl set-default "$id"
      notify-send "Audio" "Input device changed" -i audio-input-microphone-symbolic
    fi
  fi
  ;;
*"Increase Volume"*)
  wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+
  new_vol=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{print int($2*100)}')
  notify-send "Volume" "Increased to ${new_vol}%" -i audio-volume-high-symbolic
  ;;
*"Decrease Volume"*)
  wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
  new_vol=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{print int($2*100)}')
  notify-send "Volume" "Decreased to ${new_vol}%" -i audio-volume-low-symbolic
  ;;
*"Mute/Unmute Output"*)
  wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
  is_muted=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ | grep -o "MUTED")
  if [ -n "$is_muted" ]; then
    notify-send "Audio" "Output muted" -i audio-volume-muted-symbolic
  else
    notify-send "Audio" "Output unmuted" -i audio-volume-high-symbolic
  fi
  ;;
*"Mute/Unmute Input"*)
  wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle
  is_muted=$(wpctl get-volume @DEFAULT_AUDIO_SOURCE@ | grep -o "MUTED")
  if [ -n "$is_muted" ]; then
    notify-send "Audio" "Microphone muted" -i microphone-sensitivity-muted-symbolic
  else
    notify-send "Audio" "Microphone unmuted" -i audio-input-microphone-symbolic
  fi
  ;;
*"Pavucontrol"*)
  pavucontrol &
  ;;
esac
