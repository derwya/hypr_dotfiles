#!/usr/bin/env bash
# Cycle bar mode: auto-hide -> always shown -> always hidden -> auto-hide.
STATE="${XDG_RUNTIME_DIR:-/tmp}/waybar_state"

case "$(cat "$STATE" 2>/dev/null || echo 0)" in
  0) next=1 msg="Bars locked visible" ;;
  1) next=2 msg="Bars locked hidden" ;;
  *) next=0 msg="Bars auto-hide" ;;
esac

echo "$next" >"$STATE"
notify-send -a waybar -t 1200 "Waybar" "$msg"
exec ~/.config/hypr/scripts/bars.sh
