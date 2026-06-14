#!/usr/bin/env bash
set -euo pipefail

INTERVAL="${1:-1}"

hide_cursor() {
  printf '\033[?25l'
}

show_cursor() {
  printf '\033[?25h'
}

clear_line() {
  printf '\033[2K\r'
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
  local cpu_model_name cpu_usage cpu_cur cpu_max
  local mem_usage mem_used mem_total mem_model
  local disk_model disk_usage disk_used disk_total disk_fs disk_source
  local net_iface net_rx1 net_tx1 net_rx2 net_tx2 net_rx_rate net_tx_rate
  local cpu_t1 cpu_i1 cpu_t2 cpu_i2 net_before net_after

  cpu_model_name="$(cpu_model)"
  cpu_cur="$(cpu_current_ghz)"
  cpu_max="$(cpu_max_ghz)"

  IFS='|' read -r mem_usage mem_used mem_total mem_model < <(mem_usage_info)
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

  clear_line
  printf '[CPU] %s %s%% (%s GHz / %s GHz)\n' "${cpu_model_name:-Unknown}" "$(format_percent "$cpu_usage")" "$cpu_cur" "$cpu_max"
  clear_line
  printf '[Memory] %s %s%% (%s GB / %sGB)\n' "${mem_model:-Unknown}" "$(format_percent "$mem_usage")" "$(bytes_to_gb "$mem_used")" "$(bytes_to_gb "$mem_total")"
  clear_line
  printf '[SSD] %s %s%% (%sGB / %sGB)\n' "${disk_model:-Unknown}" "$(format_int_percent "$disk_usage")" "$(bytes_to_gb "$disk_used")" "$(bytes_to_gb_whole "$disk_total")"
  clear_line
  printf '[Nework] %s rx (%s B/S), tx (%s B/s)\n' "${net_iface:-Unknown}" "$(bytes_to_b "$net_rx_rate")" "$(bytes_to_b "$net_tx_rate")"
}

trap 'show_cursor; printf "\n"' INT TERM EXIT

hide_cursor

while true; do
  printf '\033[H'
  render_once
done
