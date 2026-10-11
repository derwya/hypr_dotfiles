#!/usr/bin/env bash
# Set a random wallpaper on every connected monitor via swaybg.
#
#   random-wallpaper.sh            pick new random wallpapers (distinct per monitor)
#   random-wallpaper.sh --restore  re-apply the last chosen wallpapers
#
# Uses swaybg rather than hyprpaper: hyprpaper 0.8 / hyprtoolkit 0.6 round the
# buffer size down at fractional scales (1.67 -> 2559x1439), leaving a 2px gap
# at the right and bottom edges.
#
# A new swaybg is started before the old one is killed, so changes don't flash.
# The current selection is saved in ~/.cache/hypr/wallpapers (monitor<TAB>path).
set -uo pipefail

DIR="${WALLPAPERS_DIR:-$HOME/Pictures/wallpapers/tokyonight-wallpapers}"
MODE="${WALLPAPER_MODE:-fill}" # swaybg: stretch, fit, fill, center, tile
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/hypr"
STATE="$CACHE_DIR/wallpapers"
LOCK="${XDG_RUNTIME_DIR:-/tmp}/random-wallpaper.lock"

mkdir -p "$CACHE_DIR"

notify() {
  echo "random-wallpaper: $*" >&2
  command -v notify-send >/dev/null && notify-send -a wallpaper "Wallpaper" "$*"
}

# Ignore key-repeat / double presses while a change is in progress.
exec 9>"$LOCK"
flock -n 9 || exit 0

mapfile -t MONITORS < <(hyprctl monitors -j | jq -r '.[].name')
if ((${#MONITORS[@]} == 0)); then
  notify "No monitors reported by hyprctl"
  exit 1
fi

declare -A CHOICE=()

if [[ "${1:-}" == "--restore" && -f "$STATE" ]]; then
  while IFS=$'\t' read -r mon path; do
    [[ -n $mon && -f $path ]] && CHOICE[$mon]="$path"
  done <"$STATE"
fi

# Pick random wallpapers for every monitor that has none yet.
if ((${#CHOICE[@]} < ${#MONITORS[@]})); then
  # -xtype f follows symlinks and skips broken ones; null-delimited for odd filenames.
  mapfile -d '' -t FOUND < <(find "$DIR"/ -maxdepth 1 -xtype f \
    \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) -print0)
  if ((${#FOUND[@]} == 0)); then
    notify "No images found in $DIR"
    exit 1
  fi
  mapfile -t WALLPAPERS < <(realpath -- "${FOUND[@]}" | sort -u)

  # Avoid re-picking what is currently shown, when there are enough images.
  declare -A CURRENT=()
  if [[ -f "$STATE" ]]; then
    while IFS=$'\t' read -r _ path; do CURRENT[$path]=1; done <"$STATE"
  fi
  CANDIDATES=()
  for wp in "${WALLPAPERS[@]}"; do
    [[ -z ${CURRENT[$wp]:-} ]] && CANDIDATES+=("$wp")
  done
  ((${#CANDIDATES[@]} >= ${#MONITORS[@]})) || CANDIDATES=("${WALLPAPERS[@]}")

  mapfile -t SHUFFLED < <(printf '%s\n' "${CANDIDATES[@]}" | shuf)
  i=0
  for mon in "${MONITORS[@]}"; do
    [[ -n ${CHOICE[$mon]:-} ]] && continue
    CHOICE[$mon]="${SHUFFLED[i % ${#SHUFFLED[@]}]}"
    ((i++))
  done
fi

ARGS=()
: >"$STATE"
for mon in "${MONITORS[@]}"; do
  ARGS+=(-o "$mon" -i "${CHOICE[$mon]}" -m "$MODE")
  printf '%s\t%s\n' "$mon" "${CHOICE[$mon]}" >>"$STATE"
done

# hyprpaper was used before; make sure it doesn't sit on top of swaybg.
pkill -u "$USER" -x hyprpaper

mapfile -t OLD < <(pgrep -u "$USER" -x swaybg)

# 9>&- : don't let the long-lived daemon inherit (and hold) our lock.
swaybg "${ARGS[@]}" >/dev/null 2>&1 9>&- &
NEW=$!
disown

# Give the new instance time to draw before removing the old one.
sleep 0.5
if ! kill -0 "$NEW" 2>/dev/null; then
  notify "swaybg failed to start (run it in a terminal to see why)"
  exit 1
fi
((${#OLD[@]})) && kill "${OLD[@]}" 2>/dev/null
exit 0
