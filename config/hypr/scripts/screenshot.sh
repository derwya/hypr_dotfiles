#!/usr/bin/env bash
# Screenshot to ~/Pictures/Screenshots + clipboard, with a notification preview.
#
#   screenshot.sh region   select an area (Print)
#   screenshot.sh window   the focused window (SUPER+Print)
#   screenshot.sh screen   the focused monitor (SHIFT+Print)

set -uo pipefail

DIR="${SCREENSHOT_DIR:-$HOME/Pictures/Screenshots}"
mkdir -p "$DIR"
file="$DIR/$(date +%Y-%m-%d_%H-%M-%S).png"

case "${1:-region}" in
  region)
    geom=$(slurp -d -b '#1a1b2699' -c '#7aa2f7ff' -s '#7aa2f722' -w 2) || exit 0
    grim -g "$geom" "$file"
    ;;
  window)
    geom=$(hyprctl activewindow -j | jq -r 'if .at then "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])" else empty end')
    [[ -n $geom ]] || exit 0
    grim -g "$geom" "$file"
    ;;
  screen)
    grim -o "$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name')" "$file"
    ;;
  *)
    echo "usage: $0 region|window|screen" >&2
    exit 2
    ;;
esac || { notify-send -a screenshot -u critical "Screenshot failed"; exit 1; }

wl-copy --type image/png <"$file"
notify-send -a screenshot -i "$file" -t 3000 "Screenshot saved" "Copied to clipboard · ${file/#$HOME/\~}"
