#!/usr/bin/env bash
# Suspend only when running on battery (laptops). Desktops / plugged in: do nothing.
for bat in /sys/class/power_supply/BAT*; do
  [[ -r $bat/status && $(<"$bat/status") == Discharging ]] && exec systemctl suspend
done
exit 0
