#!/usr/bin/env bash
# One line "artist — title" for the lock screen; empty when nothing plays.
playerctl metadata --format '󰎆  {{ artist }} — {{ title }}' 2>/dev/null | cut -c1-70
