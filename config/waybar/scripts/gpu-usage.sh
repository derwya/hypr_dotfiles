#!/bin/bash
# NVIDIA GPU monitor for waybar: "usage% temp°" with a detailed tooltip.
# class: warning/critical when hot (>= WARN_TEMP / CRIT_TEMP °C) or busy (>= 90%).

WARN_TEMP=75
CRIT_TEMP=85

IFS=',' read -r name util temp mem_used mem_total power power_limit clock fan < <(
  nvidia-smi --query-gpu=name,utilization.gpu,temperature.gpu,memory.used,memory.total,power.draw,power.limit,clocks.gr,fan.speed \
    --format=csv,noheader,nounits 2>/dev/null | head -n1 | sed 's/, */,/g')

if [[ -z $util ]]; then
  echo '{"text":"N/A","tooltip":"GPU not detected","class":"gpu-error"}'
  exit 0
fi

class=gpu
if ((temp >= CRIT_TEMP)); then
  class=critical
elif ((temp >= WARN_TEMP || util >= 90)); then
  class=warning
fi

jq -nc \
  --arg text "${util}% <span alpha='65%'>${temp}°</span>" \
  --arg tooltip "$(printf '%s\nUsage   %s%%\nTemp    %s°C\nVRAM    %.1f / %.1f GB\nPower   %.0f / %.0f W\nClock   %s MHz\nFan     %s%%' \
    "$name" "$util" "$temp" "$(awk "BEGIN{print $mem_used/1024}")" "$(awk "BEGIN{print $mem_total/1024}")" \
    "$power" "$power_limit" "$clock" "${fan//[^0-9]/}")" \
  --arg class "$class" \
  --argjson pct "$util" \
  '{text: $text, tooltip: $tooltip, class: $class, percentage: $pct}'
