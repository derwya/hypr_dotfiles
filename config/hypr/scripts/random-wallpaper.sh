#!/usr/bin/env bash
set -euo pipefail

DIR="${WALLPAPERS_DIR:-$HOME/Pictures/wallpapers/tokyonight-wallpapers}"
WP="$(find "$DIR" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) | shuf -n 1)"
[[ -n "${WP:-}" ]] || exit 0
WP="$(readlink -f "$WP")"

hyprctl hyprpaper wallpaper ", $WP, cover"
