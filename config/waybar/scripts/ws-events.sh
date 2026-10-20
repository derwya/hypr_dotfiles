#!/usr/bin/env bash
# Refresh waybar workspace buttons (signal 9) on Hyprland workspace/window events.
# Started by bars.sh; exits when Hyprland's event socket closes.
sock="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"
socat -U - "UNIX-CONNECT:$sock" | while read -r line; do
  case $line in
    workspace\>\>*|focusedmon\>\>*|openwindow\>\>*|closewindow\>\>*|movewindow\>\>*|createworkspace\>\>*|destroyworkspace\>\>*|moveworkspace\>\>*)
      pkill -RTMIN+9 -x waybar ;;
  esac
done
