#!/bin/bash
query=$(echo "" | rofi -dmenu -p "Search" -theme ~/.config/rofi/tokyo-night.rasi)
if [ -n "$query" ]; then
    xdg-open "https://www.google.com/search?q=$query"
fi
