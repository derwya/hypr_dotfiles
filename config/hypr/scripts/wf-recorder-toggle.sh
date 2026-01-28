#!/usr/bin/env bash
set -euo pipefail

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/wf-recorder"
LAST_FILE="$STATE_DIR/last_file"
mkdir -p "$STATE_DIR" "$HOME/Videos"

# STOP if already recording
if pgrep -x wf-recorder >/dev/null; then
  pkill -INT -x wf-recorder
  # wait a moment for wf-recorder to finalize the file
  for _ in $(seq 1 30); do
    pgrep -x wf-recorder >/dev/null || break
    sleep 0.1
  done

  if [[ -f "$LAST_FILE" ]]; then
    notify-send "Screen recording stopped" "Saved to: $(cat "$LAST_FILE")"
  else
    notify-send "Screen recording stopped"
  fi
  exit 0
fi

# Pick region (cancel-safe)
if ! GEOM="$(slurp)"; then
  notify-send "Screen recording" "Cancelled"
  exit 0
fi

OUT="$HOME/Videos/recording_$(date +%F_%H-%M-%S).mp4"
echo "$OUT" >"$LAST_FILE"

# Auto-select desktop (sink monitor) source
DEFAULT_SINK="$(pactl get-default-sink 2>/dev/null || true)" # returns default sink name [web:318]
MONITOR_SRC="${DEFAULT_SINK}.monitor"

if ! pactl list short sources 2>/dev/null | awk '{print $2}' | grep -Fxq "$MONITOR_SRC"; then
  # fallback: first available monitor source
  MONITOR_SRC="$(pactl list short sources 2>/dev/null | awk '$2 ~ /\.monitor$/ {print $2; exit}')"
fi

if [[ -z "${MONITOR_SRC:-}" ]]; then
  notify-send -u critical "wf-recorder" "No monitor (desktop-output) audio source found"
  exit 1
fi

notify-send "Screen recording started" "Desktop audio: $MONITOR_SRC\nFile: $OUT"

# Record with desktop audio source [web:278]
wf-recorder --audio="$MONITOR_SRC" -g "$GEOM" -f "$OUT"
