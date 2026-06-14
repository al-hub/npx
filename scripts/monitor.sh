#!/usr/bin/env bash
set -euo pipefail

INTERVAL="${1:-1}"

hide_cursor() {
  printf '\033[?25l'
}

show_cursor() {
  printf '\033[?25h'
}

bytes_to_gb() {
  awk -v bytes="${1:-0}" 'BEGIN { printf "%.1f", bytes / 1024 / 1024 / 1024 }'
}

bytes_to_gb_whole() {
  awk -v bytes="${1:-0}" 'BEGIN { printf "%.0f", bytes / 1024 / 1024 / 1024 }'
}

bytes_to_b() {
  awk -v bytes="${1:-0}" 'BEGIN { printf "%.1f", bytes + 0 }'
}

join_nonempty() {
  local out=""
  local part
  for part in "$@"; do
    if [ -n "$part" ]; then
      if [ -n "$out" ]; then
        out="$out $part"
      else
        out="$part"
      fi
    fi
  done
  printf '%s\n' "$out"
}

format_percent() {
  awk -v value="${1:-0}" 'BEGIN { printf "%.1f", value + 0 }'
}

format_int_percent() {
  awk -v value="${1:-0}" 'BEGIN { printf "%d", (value + 0) }'
}

cpu_model() {
  lscpu 2>/dev/null | awk -F: '/Model name/ {gsub(/^[ \t]+/, "", $2); print $2; exit}'
}

cpu_current_ghz() {
  local khz mhz bogomips

  if [ -r /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq ]; then
    khz="$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq)"
    awk -v value="$khz" 'BEGIN { printf "%.1f", value / 1000000 }'
    return
  fi

  mhz="$(lscpu 2>/dev/null | awk -F: '/CPU MHz/ {gsub(/^[ \t]+/, "", $2); print $2; exit}')"
  if [ -n "${mhz:-}" ]; then
    awk -v value="$mhz" 'BEGIN { printf "%.1f", value / 1000 }'
    return
  fi

  mhz="$(awk -F: '/cpu MHz/ {gsub(/^[ \t]+/, "", $2); print $2; exit}' /proc/cpuinfo 2>/dev/null)"
  if [ -n "${mhz:-}" ]; then
    awk -v value="$mhz" 'BEGIN { printf "%.1f", value / 1000 }'
    return
  fi

  bogomips="$(awk -F: '/BogoMIPS/ {gsub(/^[ \t]+/, "", $2); print $2; exit}' /proc/cpuinfo 2>/dev/null)"
  if [ -z "${bogomips:-}" ]; then
    bogomips="$(lscpu 2>/dev/null | awk -F: '/BogoMIPS/ {gsub(/^[ \t]+/, "", $2); print $2; exit}')"
  fi
  if [ -n "${bogomips:-}" ]; then
    awk -v value="$bogomips" 'BEGIN { printf "%.1f", value / 10 }'
    return
  fi

  echo "0.0"
}

cpu_max_ghz() {
  local khz mhz bogomips

  if [ -r /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq ]; then
    khz="$(cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq)"
    awk -v value="$khz" 'BEGIN { printf "%.1f", value / 1000000 }'
    return
  fi

  mhz="$(lscpu 2>/dev/null | awk -F: '/CPU max MHz/ {gsub(/^[ \t]+/, "", $2); print $2; exit}')"
  if [ -n "${mhz:-}" ]; then
    awk -v value="$mhz" 'BEGIN { printf "%.1f", value / 1000 }'
    return
  fi

  bogomips="$(awk -F: '/BogoMIPS/ {gsub(/^[ \t]+/, "", $2); print $2; exit}' /proc/cpuinfo 2>/dev/null)"
  if [ -z "${bogomips:-}" ]; then
    bogomips="$(lscpu 2>/dev/null | awk -F: '/BogoMIPS/ {gsub(/^[ \t]+/, "", $2); print $2; exit}')"
  fi
  if [ -n "${bogomips:-}" ]; then
    awk -v value="$bogomips" 'BEGIN { printf "%.1f", value / 10 }'
    return
  fi

  echo "0.0"
}

cpu_core_count() {
  lscpu 2>/dev/null | awk -F: '/^Core\(s\) per socket:/ {gsub(/^[ \t]+/, "", $2); print $2; exit}'
}

cpu_thread_count() {
  lscpu 2>/dev/null | awk -F: '/^CPU\(s\):/ {gsub(/^[ \t]+/, "", $2); print $2; exit}'
}

mem_usage_info() {
  local total available used usage
  total="$(awk '/MemTotal:/ {print $2 * 1024; exit}' /proc/meminfo)"
  available="$(awk '/MemAvailable:/ {print $2 * 1024; exit}' /proc/meminfo)"
  used=$((total - available))
  usage="$(awk -v used="$used" -v total="$total" 'BEGIN {
    if (total <= 0) {
      printf "0.0"
    } else {
      printf "%.1f", (100 * used / total)
    }
  }')"
  printf '%s|%s|%s|%s\n' "$usage" "$used" "$total" "Unknown"
}

system_vendor() {
  cat /sys/devices/virtual/dmi/id/sys_vendor 2>/dev/null || echo "Unknown"
}

system_product() {
  cat /sys/devices/virtual/dmi/id/product_name 2>/dev/null || echo "Unknown"
}

board_vendor() {
  cat /sys/devices/virtual/dmi/id/board_vendor 2>/dev/null || echo "Unknown"
}

board_name() {
  cat /sys/devices/virtual/dmi/id/board_name 2>/dev/null || echo "Unknown"
}

root_disk_info() {
  local source fs_type size used avail usep model root_source
  source="$(df -P / 2>/dev/null | awk 'NR == 2 {print $1; exit}')"
  fs_type="$(df -PT / 2>/dev/null | awk 'NR == 2 {print $2; exit}')"
  size="$(df -PB1 / 2>/dev/null | awk 'NR == 2 {print $2; exit}')"
  used="$(df -PB1 / 2>/dev/null | awk 'NR == 2 {print $3; exit}')"
  avail="$(df -PB1 / 2>/dev/null | awk 'NR == 2 {print $4; exit}')"
  usep="$(df -P / 2>/dev/null | awk 'NR == 2 {gsub(/%/, "", $5); print $5; exit}')"

  if [[ "$source" == /dev/* ]] && command -v lsblk >/dev/null 2>&1; then
    model="$(lsblk -dn -o MODEL "$source" 2>/dev/null | awk 'NR == 1 {print; exit}' || true)"
  else
    model=""
  fi

  printf '%s|%s|%s|%s|%s|%s\n' "${model:-Unknown}" "${usep:-0}" "${used:-0}" "${size:-0}" "${fs_type:-unknown}" "${source:-unknown}"
}

gpu_info() {
  if command -v nvidia-smi >/dev/null 2>&1; then
    nvidia-smi --query-gpu=name,memory.used,memory.total --format=csv,noheader,nounits 2>/dev/null | awk -F', ' 'NR == 1 {
      used = $2 + 0
      total = $3 + 0
      usage = (total > 0) ? (100 * used / total) : 0
      printf "%s|%.1f|%s|%s\n", $1, usage, used, total
      exit
    }'
    return
  fi

  printf 'Unknown|0.0|0|0\n'
}

net_info() {
  local iface rx1 tx1
  iface="$(ip route show default 2>/dev/null | awk '/default/ {print $5; exit}' || true)"
  if [ -z "${iface:-}" ]; then
    iface="$(ip -o link show 2>/dev/null | awk -F': ' '$2 != "lo" {print $2; exit}' || true)"
  fi
  if [ -z "${iface:-}" ] && [ -r /proc/net/route ]; then
    iface="$(awk '$2 == "00000000" {print $1; exit}' /proc/net/route)"
  fi
  if [ -z "${iface:-}" ] && [ -r /proc/net/dev ]; then
    iface="$(awk -F'[: ]+' 'NR > 2 && $1 != "lo" {print $1; exit}' /proc/net/dev)"
  fi
  if [ -z "${iface:-}" ]; then
    printf 'Unknown|0|0\n'
    return
  fi

  rx1="$(awk -v iface="$iface" '$1 ~ iface":" {gsub(/:/, "", $1); print $2; exit}' /proc/net/dev)"
  tx1="$(awk -v iface="$iface" '$1 ~ iface":" {gsub(/:/, "", $1); print $10; exit}' /proc/net/dev)"
  printf '%s|%s|%s\n' "$iface" "${rx1:-0}" "${tx1:-0}"
}

cpu_sample() {
  local cpu user nice system idle iowait irq softirq steal guest guest_nice total idle_all
  read -r cpu user nice system idle iowait irq softirq steal guest guest_nice < /proc/stat
  total=$((user + nice + system + idle + iowait + irq + softirq + steal + guest + guest_nice))
  idle_all=$((idle + iowait))
  printf '%s|%s\n' "$total" "$idle_all"
}

render_once() {
  local system_name board_name_value cpu_model_name cpu_usage cpu_cur cpu_max cpu_cores cpu_threads
  local mem_usage mem_used mem_total mem_model
  local gpu_model_name gpu_usage gpu_used gpu_total
  local disk_model disk_usage disk_used disk_total disk_fs disk_source
  local net_iface net_rx1 net_tx1 net_rx2 net_tx2 net_rx_rate net_tx_rate
  local cpu_t1 cpu_i1 cpu_t2 cpu_i2 net_before net_after

  system_name="$(join_nonempty "$(system_vendor)" "$(system_product)")"
  board_name_value="$(join_nonempty "$(board_vendor)" "$(board_name)")"
  cpu_model_name="$(cpu_model)"
  cpu_cur="$(cpu_current_ghz)"
  cpu_max="$(cpu_max_ghz)"
  cpu_cores="$(cpu_core_count)"
  cpu_threads="$(cpu_thread_count)"

  IFS='|' read -r mem_usage mem_used mem_total mem_model < <(mem_usage_info)
  IFS='|' read -r gpu_model_name gpu_usage gpu_used gpu_total < <(gpu_info)
  IFS='|' read -r disk_model disk_usage disk_used disk_total disk_fs disk_source < <(root_disk_info)
  IFS='|' read -r cpu_t1 cpu_i1 < <(cpu_sample)
  IFS='|' read -r net_iface net_rx1 net_tx1 < <(net_info)
  sleep "$INTERVAL"
  IFS='|' read -r cpu_t2 cpu_i2 < <(cpu_sample)
  IFS='|' read -r _ net_rx2 net_tx2 < <(net_info)

  cpu_usage="$(awk -v t1="$cpu_t1" -v i1="$cpu_i1" -v t2="$cpu_t2" -v i2="$cpu_i2" 'BEGIN {
    delta = t2 - t1
    if (delta <= 0) {
      printf "0.0"
    } else {
      printf "%.1f", (100 * (delta - (i2 - i1)) / delta)
    }
  }')"

  net_rx_rate=$((net_rx2 - net_rx1))
  net_tx_rate=$((net_tx2 - net_tx1))
  if [ "$net_rx_rate" -lt 0 ]; then
    net_rx_rate=0
  fi
  if [ "$net_tx_rate" -lt 0 ]; then
    net_tx_rate=0
  fi

  printf '[System] %s / %s\n' "${system_name:-Unknown}" "${board_name_value:-Unknown}"
  printf '[CPU] %s %5.1f%% (%3.1f GHz / %3.1f GHz)\n' "${cpu_model_name:-Unknown}" "$(format_percent "$cpu_usage")" "$cpu_cur" "$cpu_max"
  printf '[CPU-Cores] %sC / %sT\n' "${cpu_cores:-0}" "${cpu_threads:-0}"
  printf '[Memory] %s %5.1f%% (%3.1f GB / %3.1fGB)\n' "${mem_model:-Unknown}" "$(format_percent "$mem_usage")" "$(bytes_to_gb "$mem_used")" "$(bytes_to_gb "$mem_total")"
  if [ "${gpu_total:-0}" -gt 0 ]; then
    printf '[GPU] %s %5.1f%% (VRAM %s MiB / %s MiB)\n' "${gpu_model_name:-Unknown}" "$(format_percent "$gpu_usage")" "${gpu_used:-0}" "${gpu_total:-0}"
  else
    printf '[GPU] %s VRAM unavailable\n' "${gpu_model_name:-Unknown}"
  fi
  printf '[SSD] %s %3d%% (%3.1fGB / %4.0fGB)\n' "${disk_model:-Unknown}" "$(format_int_percent "$disk_usage")" "$(bytes_to_gb "$disk_used")" "$(bytes_to_gb_whole "$disk_total")"
  printf '[Nework] %s rx (%5.1f B/S), tx (%5.1f B/s)\n' "${net_iface:-Unknown}" "$(bytes_to_b "$net_rx_rate")" "$(bytes_to_b "$net_tx_rate")"
}

trap 'show_cursor; printf "\n"' INT TERM EXIT

printf '\033[2J\033[H'
hide_cursor

while true; do
  printf '\033[H'
  render_once
done
