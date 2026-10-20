#!/bin/bash
# GPU monitor for waybar.
#   NVIDIA (desktop): "usage% temp°" from nvidia-smi, with a detailed tooltip.
#   Intel  (laptop) : "usage%" from the i915 RC6 (idle) counter in sysfs - no root needed.
# class: warning/critical when hot (>= WARN_TEMP / CRIT_TEMP °C) or busy (>= 90%).

WARN_TEMP=75
CRIT_TEMP=85

# Intel iGPU: busy% = 100 - share of time spent in RC6 (idle) since the previous call.
intel_gpu() {
  local card rc6 now prev_rc6 prev_now state="${XDG_RUNTIME_DIR:-/tmp}/waybar-gpu-rc6"
  for card in /sys/class/drm/card[0-9]; do
    [[ $(<"$card/device/vendor") == 0x8086 ]] || continue
    for rc6 in "$card/gt/gt0/rc6_residency_ms" "$card/power/rc6_residency_ms"; do
      [[ -r $rc6 ]] && break 2
    done
  done
  [[ -r $rc6 ]] || return 1

  [[ -r $state ]] && read -r prev_rc6 prev_now <"$state"
  if [[ -z $prev_now ]]; then # first run: take a short sample
    prev_rc6=$(<"$rc6") prev_now=$(date +%s%3N)
    sleep 0.5
  fi
  local idle=$(<"$rc6")
  now=$(date +%s%3N)
  echo "$idle $now" >"$state"

  local util=0 dt=$((now - prev_now))
  ((dt > 0)) && util=$((100 - (idle - prev_rc6) * 100 / dt))
  ((util < 0)) && util=0
  ((util > 100)) && util=100

  local name freq max
  # "00:02.0 VGA compatible controller: Intel Corporation CometLake-U GT2 [UHD Graphics] (rev 02)"
  #   -> "Intel CometLake-U GT2 [UHD Graphics]"
  name=$(lspci -s "$(basename "$(readlink -f "$card/device")")" 2>/dev/null |
    cut -d: -f3- | sed 's/^ *//; s/ Corporation//; s/ (rev [0-9a-f]*)$//')
  freq=$(<"$card/gt_act_freq_mhz") max=$(<"$card/gt_RP0_freq_mhz")

  jq -nc \
    --arg text "${util}%" \
    --arg tooltip "$(printf '%s\nUsage   %s%%\nClock   %s / %s MHz' "${name:-Intel GPU}" "$util" "$freq" "$max")" \
    --arg class "$( ((util >= 90)) && echo warning || echo gpu)" \
    --argjson pct "$util" \
    '{text: $text, tooltip: $tooltip, class: $class, percentage: $pct}'
}

IFS=',' read -r name util temp mem_used mem_total power power_limit clock fan < <(
  nvidia-smi --query-gpu=name,utilization.gpu,temperature.gpu,memory.used,memory.total,power.draw,power.limit,clocks.gr,fan.speed \
    --format=csv,noheader,nounits 2>/dev/null | head -n1 | sed 's/, */,/g')

if [[ -z $util ]]; then
  intel_gpu && exit 0
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
