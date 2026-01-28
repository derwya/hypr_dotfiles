#!/bin/bash

killall -q waybar

while pgrep -x waybar >/dev/null; do sleep 0.1; done

waybar -c ~/.config/waybar/config-top -s ~/.config/waybar/style.css &

sleep 0.2

waybar -c ~/.config/waybar/config-bottom -s ~/.config/waybar/style.css &
