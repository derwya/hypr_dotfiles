#!/bin/bash
# Volume of the media app (MPRIS player) for the bottom bar.
# The top bar's wireplumber module handles the system volume; this one only ever
# touches the player's own audio stream(s), never the system sink.
#
#   app-volume.sh get        print waybar JSON (empty text = module hidden)
#   app-volume.sh up|down    change the app volume by STEP%, capped at 100%
#                            (via the player's MPRIS volume when supported)
#   app-volume.sh mute       toggle the app's mute
#
# After a change, waybar is told to refresh via SIGRTMIN+SIGNAL (matches
# "signal" in the custom/volume module config).

STEP=5
SIGNAL=8

# Pick the player that is playing, else a paused one, else the first one.
pick_player() {
  local p status fallback=""
  while read -r p; do
    [[ -z $p ]] && continue
    status=$(playerctl -p "$p" status 2>/dev/null)
    [[ $status == Playing ]] && { echo "$p"; return; }
    [[ $status == Paused && -z $fallback ]] && fallback=$p
    [[ -z $fallback ]] && fallback=$p
  done < <(playerctl -l 2>/dev/null)
  echo "$fallback"
}

# PID that owns the player's MPRIS bus name.
player_pid() {
  busctl --user call org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus \
    GetConnectionUnixProcessID s "org.mpris.MediaPlayer2.$1" 2>/dev/null | awk '{print $2}'
}

# True if $1 is $2 or one of its descendants (browsers play audio from child processes).
descends_from() {
  local pid=$1 ancestor=$2
  while [[ -n $pid && $pid -gt 1 ]]; do
    [[ $pid == "$ancestor" ]] && return 0
    pid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
  done
  return 1
}

# Sink input indices belonging to the player: by process tree, else by name.
# Fields are split on \x1f, not tabs: bash's read merges consecutive tabs, which
# shifts fields when one is empty (some streams have no application.process.id).
player_streams() {
  local player=$1 base=${1%%.*} ppid streams idx pid name
  ppid=$(player_pid "$player")
  streams=$(pactl -f json list sink-inputs 2>/dev/null | jq -r '.[] |
    "\(.index)\u001f\(.properties["application.process.id"] // "")\u001f\((.properties["application.process.binary"] // "") + " " + (.properties["application.name"] // "") | ascii_downcase)"')
  local found=()
  if [[ -n $ppid ]]; then
    while IFS=$'\x1f' read -r idx pid name; do
      [[ -n $pid ]] && descends_from "$pid" "$ppid" && found+=("$idx")
    done <<<"$streams"
  fi
  if ((${#found[@]} == 0)); then
    base=${base,,}
    while IFS=$'\x1f' read -r idx pid name; do
      [[ -n $idx && $name == *"$base"* ]] && found+=("$idx")
    done <<<"$streams"
  fi
  ((${#found[@]})) && printf '%s\n' "${found[@]}"
}

stream_info() { # prints "<volume%> <true|false>" for a sink input
  pactl -f json list sink-inputs | jq -r --argjson i "$1" \
    '.[] | select(.index == $i) | "\(.volume | to_entries[0].value.value_percent | rtrimstr("%")) \(.mute)"'
}

refresh_bar() { pkill -RTMIN+"$SIGNAL" -x waybar 2>/dev/null; }

# Player's own (MPRIS) volume as an integer percent, empty if unsupported.
# Prefer it over the stream volume: players like Spotify re-apply their internal
# volume to the stream on every track change, undoing stream-level changes.
mpris_volume() {
  local v
  v=$(playerctl -p "$1" volume 2>/dev/null) || return
  [[ $v =~ ^[0-9.]+$ ]] && awk -v v="$v" 'BEGIN { printf "%d", v * 100 + 0.5 }'
}

PLAYER=$(pick_player)
mapfile -t STREAMS < <([[ -n $PLAYER ]] && player_streams "$PLAYER")

if [[ ${1:-get} == get ]]; then
  if [[ -z $PLAYER || ${#STREAMS[@]} -eq 0 ]]; then
    echo '{"text":""}' # nothing playing: hide the module
    exit 0
  fi
  read -r vol muted < <(stream_info "${STREAMS[0]}")
  pvol=$(mpris_volume "$PLAYER")
  [[ -n $pvol ]] && vol=$pvol
  if [[ -z $vol ]]; then
    echo '{"text":""}'
    exit 0
  fi
  app=${PLAYER%%.*}
  class=$app
  [[ $muted == true ]] && class=muted
  printf '{"text":"%s","alt":"%s","class":"%s","tooltip":"%s volume: %s%%%s"}\n' \
    "$vol" "$class" "$class" "$app" "$vol" "$([[ $muted == true ]] && echo ' (muted)')"
  exit 0
fi

((${#STREAMS[@]})) || exit 0

pvol=$(mpris_volume "$PLAYER")
if [[ -n $pvol && $1 != mute ]]; then
  case "$1" in
    up) new=$((pvol + STEP)) ;;
    down) new=$((pvol - STEP)) ;;
  esac
  ((new > 100)) && new=100
  ((new < 0)) && new=0
  playerctl -p "$PLAYER" volume "$(awk -v n="$new" 'BEGIN { printf "%.2f", n / 100 }')"
  refresh_bar
  exit 0
fi

for s in "${STREAMS[@]}"; do
  case "$1" in
    up)
      read -r vol _ < <(stream_info "$s")
      new=$((vol + STEP))
      ((new > 100)) && new=100
      pactl set-sink-input-volume "$s" "${new}%"
      ;;
    down) pactl set-sink-input-volume "$s" "-${STEP}%" ;;
    mute) pactl set-sink-input-mute "$s" toggle ;;
  esac
done
refresh_bar
