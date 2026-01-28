#!/bin/bash

CONSERVATION_FILE="/sys/bus/platform/drivers/ideapad_acpi/VPC2004:00/conservation_mode"

# Check current status
CURRENT=$(cat $CONSERVATION_FILE)

if [ "$CURRENT" = "1" ]; then
  # Turn off conservation mode
  echo 0 | sudo tee $CONSERVATION_FILE >/dev/null
  notify-send "Battery Conservation" "Conservation mode disabled (charges to 100%)" -i battery-full-symbolic
else
  # Turn on conservation mode
  echo 1 | sudo tee $CONSERVATION_FILE >/dev/null
  notify-send "Battery Conservation" "Conservation mode enabled (charges to 60%)" -i battery-good-symbolic
fi
