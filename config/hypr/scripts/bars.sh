#!/usr/bin/env bash
# (Re)launch waybar on every connected monitor.
#
#   primary monitor  : top bar (config-top) + bottom bar with media (config-bottom)
#   other monitors   : bottom bar (config-bottom-secondary)
#
# The primary is $BARS_PRIMARY (default DP-2) if connected, else the first monitor.
# Each bar gets its monitor filled in at launch, and its workspace buttons come
# from Hyprland's workspace rules (hyprland.lua), so monitors are defined in one
# place and hotplugged/unknown monitors just work.
#
# Called at login and on monitor add/remove (hyprland.lua), and by toggle-bars.sh.
# Bar mode is read from $STATE: 0 = auto-hide (default), 1 = always shown, 2 = hidden.

set -uo pipefail

PRIMARY_PREF="${BARS_PRIMARY:-DP-2}"
WAYBAR_DIR="$HOME/.config/waybar"
STYLE="$WAYBAR_DIR/style.css"
AUTOHIDE="$HOME/.config/hypr/scripts/waybar_auto_hide"
RUN_DIR="${XDG_RUNTIME_DIR:-/tmp}/bars"
STATE="${XDG_RUNTIME_DIR:-/tmp}/waybar_state"

mkdir -p "$RUN_DIR"

# Monitor hotplug sends several events at once; run one relaunch at a time and
# let the monitor layout settle first.
exec 9>"$RUN_DIR/lock"
flock 9
sleep 0.5

mode=$(cat "$STATE" 2>/dev/null || echo 0)

monitors=$(hyprctl monitors -j)
mapfile -t names < <(jq -r '.[].name' <<<"$monitors")
((${#names[@]})) || exit 0

primary=${names[0]}
for n in "${names[@]}"; do [[ $n == "$PRIMARY_PREF" ]] && primary=$n; done

# Stop old bars and their auto-hide helpers.
pkill -x waybar
pkill -f '[w]aybar_auto_hide --monitor'
for _ in {1..20}; do pgrep -x waybar >/dev/null || break; sleep 0.1; done

rules=$(hyprctl workspacerules -j)

launch() { # launch <monitor> <side> <base config>
  local mon=$1 side=$2 base=$3 cfg="$RUN_DIR/$2-$1.json" ws scale pid
  ws=$(jq -c --arg m "$mon" '[.[] | select(.monitor == $m) | .workspaceString | tonumber? ] | sort' <<<"$rules")
  jq --arg m "$mon" --argjson ws "$ws" '
      .output = $m
      | if .["hyprland/workspaces"] and ($ws | length) > 0
        then .["hyprland/workspaces"]["persistent-workspaces"] = {($m): $ws}
        else . end' "$WAYBAR_DIR/$base" >"$cfg"

  waybar -c "$cfg" -s "$STYLE" >/dev/null 2>&1 9>&- &
  pid=$!
  [[ $mode == 1 ]] && return
  scale=$(jq -r --arg m "$mon" '.[] | select(.name == $m) | .scale' <<<"$monitors")
  (
    sleep 1.5
    kill -0 "$pid" 2>/dev/null || exit 0
    args=(--monitor "$mon" --side "$side" --pid "$pid" --scaling "$scale")
    [[ $mode == 2 ]] && args+=(--always-hidden)
    exec "$AUTOHIDE" "${args[@]}"
  ) >/dev/null 2>&1 9>&- &
}

for mon in "${names[@]}"; do
  if [[ $mon == "$primary" ]]; then
    launch "$mon" top config-top
    launch "$mon" bottom config-bottom
  else
    launch "$mon" bottom config-bottom-secondary
  fi
done
