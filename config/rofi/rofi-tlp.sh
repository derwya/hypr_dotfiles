#!/bin/bash

CONSERVATION_FILE="/sys/bus/platform/drivers/ideapad_acpi/VPC2004:00/conservation_mode"

# Check TLP status
if systemctl is-active --quiet tlp.service; then
  TLP_STATUS="enabled"
  TLP_ACTION="Disable"
else
  TLP_STATUS="disabled"
  TLP_ACTION="Enable"
fi

# Check conservation mode status
if [ -f "$CONSERVATION_FILE" ]; then
  CONSERVATION=$(cat $CONSERVATION_FILE)
  if [ "$CONSERVATION" = "1" ]; then
    CONS_STATUS="ON (60%)"
    CONS_ACTION="Disable"
    CONS_ICON="󱐋"
  else
    CONS_STATUS="OFF (100%)"
    CONS_ACTION="Enable"
    CONS_ICON="󱐌"
  fi
else
  CONS_STATUS="Not Available"
  CONS_ACTION="N/A"
  CONS_ICON="󰂑"
fi

# Build menu
MENU="󱐋 $TLP_ACTION TLP (Currently: $TLP_STATUS)
$CONS_ICON $CONS_ACTION Battery Conservation (Currently: $CONS_STATUS)
󰑓 TLP Status"

# Show rofi menu
CHOICE=$(echo -e "$MENU" | rofi -dmenu -p "Power Management" -i "$@")

case "$CHOICE" in
*"$TLP_ACTION TLP"*)
  if [ "$TLP_STATUS" = "enabled" ]; then
    systemctl stop tlp.service &&
      notify-send "TLP" "Power management disabled" -i battery-full-symbolic
  else
    systemctl start tlp.service &&
      notify-send "TLP" "Power management enabled" -i battery-full-charging-symbolic
  fi
  ;;
*"$CONS_ACTION Battery Conservation"*)
  if [ "$CONSERVATION" = "1" ]; then
    echo 0 | sudo tee $CONSERVATION_FILE >/dev/null &&
      notify-send "Battery Conservation" "Conservation mode disabled" -i battery-full-symbolic
  else
    echo 1 | sudo tee $CONSERVATION_FILE >/dev/null &&
      notify-send "Battery Conservation" "Conservation mode enabled" -i battery-good-symbolic
  fi
  ;;
*"TLP Status")
  kitty --class tui-popup -e sh -c "tlp-stat -s 2>/dev/null || echo 'TLP not available'; echo -e '\nPress Enter to close'; read"
  ;;
esac
