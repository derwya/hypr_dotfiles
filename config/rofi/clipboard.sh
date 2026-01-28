#!/bin/bash
cliphist list | rofi -dmenu -p "Clipboard" -theme ~/.config/rofi/tokyo-night.rasi | cliphist decode | wl-copy
