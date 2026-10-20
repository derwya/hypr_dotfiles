#!/usr/bin/env bash
# One workspace button for waybar: ws-status.sh <workspace-id> <monitor>
# Prints {"text","class","tooltip"}; class is "ws" plus active / occupied / empty.
# Refreshed by ws-events.sh (SIGRTMIN+9) whenever workspaces or windows change.
# (Custom buttons because waybar 0.15's hyprland/workspaces still clicks via the
# old hyprctl syntax, which Hyprland's Lua config rejects.)
ws=$1 mon=$2
read -r active windows < <(
  { hyprctl monitors -j; hyprctl workspaces -j; } | jq -rs --argjson ws "$ws" --arg mon "$mon" '
    (.[0][] | select(.name == $mon) | .activeWorkspace.id) as $act
    | ([.[1][] | select(.id == $ws) | .windows] | first // 0) as $win
    | "\($act == $ws) \($win)"')
if [[ $active == true ]]; then state=active
elif ((windows > 0)); then state=occupied
else state=empty; fi
printf '{"text":"%s","class":["ws","%s"],"tooltip":"Workspace %s · %s window%s"}\n' \
  "$ws" "$state" "$ws" "$windows" "$([[ $windows == 1 ]] || echo s)"
