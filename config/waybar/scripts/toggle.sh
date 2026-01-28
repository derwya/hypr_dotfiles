#!/bin/bash
# Usage: ./toggle.sh <process_name> [command_to_run_if_not_process_name]

PROCESS="$1"
COMMAND="${2:-$1}" # If 2nd arg is empty, use 1st arg as command

if pgrep -x "$PROCESS" >/dev/null; then
  pkill -x "$PROCESS"
else
  $COMMAND &
fi
