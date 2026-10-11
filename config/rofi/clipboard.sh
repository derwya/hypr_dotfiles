#!/bin/bash
# Clipboard history (SUPER+V). Shows entries without cliphist's numeric IDs;
# Shift+Delete removes the highlighted entry.

sel=$(cliphist list | rofi -dmenu -i -p "󰅍  Clipboard" -display-columns 2 \
  -kb-delete-entry "" -kb-custom-1 "shift+Delete" -mesg "Enter: copy · Shift+Del: remove")
code=$?

[[ -n $sel ]] || exit 0
if ((code == 10)); then
  cliphist delete <<<"$sel"
  exec "$0"
fi
cliphist decode <<<"$sel" | wl-copy
