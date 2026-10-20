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

# Hardware differs per machine (desktop: NVIDIA, Ryzen sensor; laptop: battery,
# backlight), so the shared bar configs are adapted at launch.
hw=$(jq -n \
  --argjson nvidia "$(nvidia-smi -L >/dev/null 2>&1 && echo true || echo false)" \
  --argjson battery "$(compgen -G '/sys/class/power_supply/BAT*' >/dev/null && echo true || echo false)" \
  --argjson backlight "$(compgen -G '/sys/class/backlight/*' >/dev/null && echo true || echo false)" \
  --argjson cpusensor "$([[ -d $(jq -r '.temperature["hwmon-path-abs"] // "/nonexistent"' "$WAYBAR_DIR/config-top") ]] && echo true || echo false)" \
  '{nvidia: $nvidia, battery: $battery, backlight: $backlight, cpusensor: $cpusensor}')

# Live workspace-button updates (one listener for all bars).
pkill -f '[w]s-events.sh'
setsid -f "$WAYBAR_DIR/scripts/ws-events.sh" >/dev/null 2>&1 9>&-

launch() { # launch <monitor> <side> <base config>
  local mon=$1 side=$2 base=$3 cfg="$RUN_DIR/$2-$1.json" ws scale pid
  ws=$(jq -c --arg m "$mon" '[.[] | select(.monitor == $m) | .workspaceString | tonumber? ] | sort' <<<"$rules")
  [[ $ws == "[]" ]] && ws="[1,2,3,4,5]"   # monitor without workspace rules (e.g. unknown screen)
  # Workspace buttons: waybar 0.15's hyprland/workspaces clicks via the old hyprctl
  # syntax (rejected by the Lua config), so the module is swapped for one clickable
  # custom button per workspace of this monitor (ws-status.sh, refreshed by ws-events.sh).
  jq --arg m "$mon" --argjson ws "$ws" --arg wsdir "$WAYBAR_DIR/scripts" --argjson hw "$hw" '
      .output = $m
      | if $hw.nvidia | not then .["modules-left"] |= (. // [] | map(select(. != "custom/gpu"))) else . end
      | if (.temperature and ($hw.cpusensor | not))
        then .temperature |= del(.["hwmon-path-abs"], .["input-filename"]) else . end
      | if ($hw.battery and (.["modules-right"] // [] | index("custom/notification")))
        then .["modules-right"] |= (map(if . == "custom/notification" then "battery", . else . end)) else . end
      | if ($hw.backlight and (.["modules-right"] // [] | index("wireplumber")))
        then .["modules-right"] |= (map(if . == "wireplumber" then "backlight", . else . end)) else . end
      | if (.["modules-left"] | index("hyprland/workspaces")) and ($ws | length) > 0 then
          .["modules-left"] |= map(if . == "hyprland/workspaces" then "group/workspaces" else . end)
          | del(.["hyprland/workspaces"])
          | .["group/workspaces"] = { orientation: "horizontal", modules: [ $ws[] | "custom/ws-\(.)" ] }
          | reduce $ws[] as $w (.;
              .["custom/ws-\($w)"] = {
                exec: "\($wsdir)/ws-status.sh \($w) \($m)",
                "return-type": "json",
                interval: "once",
                signal: 9,
                "on-click": "hyprctl dispatch \u0027hl.dsp.focus({ workspace = \($w) })\u0027"
              })
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
