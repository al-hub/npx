#!/usr/bin/env bash
set -euo pipefail

INTERVAL="${1:-1}"

cpu_model() {
  local model
  model="$(lscpu 2>/dev/null | awk -F: '/Model name/ {gsub(/^[ \t]+/, "", $2); print $2; exit}')"
  if [ -n "${model:-}" ]; then
    printf '%s\n' "$model"
    return
  fi

  awk -F: '/model name/ {gsub(/^[ \t]+/, "", $2); print $2; exit}' /proc/cpuinfo 2>/dev/null || true
}

cpu_sample() {
  local cpu user nice system idle iowait irq softirq steal guest guest_nice total idle_all
  read -r cpu user nice system idle iowait irq softirq steal guest guest_nice < /proc/stat
  total=$((user + nice + system + idle + iowait + irq + softirq + steal + guest + guest_nice))
  idle_all=$((idle + iowait))
  printf '%s %s\n' "$total" "$idle_all"
}

mem_total_bytes() {
  awk '/MemTotal:/ {print $2 * 1024; exit}' /proc/meminfo
}

mem_available_bytes() {
  awk '/MemAvailable:/ {print $2 * 1024; exit}' /proc/meminfo
}

gpu_model() {
  if command -v nvidia-smi >/dev/null 2>&1; then
    nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -n 1
    return
  fi

  if command -v lspci >/dev/null 2>&1; then
    lspci 2>/dev/null | awk -F': ' '/VGA compatible controller|3D controller|Display controller/ {print $2; exit}'
    return
  fi

  echo "unknown"
}

gpu_vram_usage() {
  if command -v nvidia-smi >/dev/null 2>&1; then
    nvidia-smi --query-gpu=memory.used,memory.total --format=csv,noheader,nounits 2>/dev/null | head -n 1 | awk -F', ' '{printf "%s MiB / %s MiB\n", $1, $2}'
    return
  fi

  echo "unavailable"
}

disk_inventory() {
  lsblk -dn -P -o NAME,MODEL,SIZE,TYPE 2>/dev/null | while IFS= read -r line; do
    eval "$line"
    if [ "${TYPE:-}" = "disk" ]; then
      printf "%s|%s|%s\n" "${NAME:-unknown}" "${MODEL:-unknown}" "${SIZE:-unknown}"
    fi
  done
}

net_sample() {
  awk -F'[: ]+' '
    NR > 2 && $1 != "lo" {
      rx += $3
      tx += $11
    }
    END {
      printf "%s %s\n", rx + 0, tx + 0
    }
  ' /proc/net/dev
}

format_bytes() {
  awk -v bytes="${1:-0}" 'BEGIN {
    split("B KB MB GB TB PB", units, " ")
    value = bytes + 0
    unit = 1
    while (value >= 1024 && unit < 6) {
      value /= 1024
      unit++
    }
    printf "%.1f %s", value, units[unit]
  }'
}

clear_screen() {
  printf '\033[2J\033[H'
}

draw_once() {
  local cpu_total_1 cpu_idle_1 cpu_total_2 cpu_idle_2
  local cpu_usage mem_total mem_available mem_used mem_usage
  local net_rx_1 net_tx_1 net_rx_2 net_tx_2 rx_rate tx_rate

  read -r cpu_total_1 cpu_idle_1 < <(cpu_sample)
  read -r net_rx_1 net_tx_1 < <(net_sample)
  sleep "$INTERVAL"
  read -r cpu_total_2 cpu_idle_2 < <(cpu_sample)
  read -r net_rx_2 net_tx_2 < <(net_sample)

  cpu_usage="$(awk -v t1="$cpu_total_1" -v i1="$cpu_idle_1" -v t2="$cpu_total_2" -v i2="$cpu_idle_2" 'BEGIN {
    total = t2 - t1
    idle = i2 - i1
    if (total <= 0) {
      printf "0.0"
    } else {
      printf "%.1f", (100 * (total - idle) / total)
    }
  }')"

  mem_total="$(mem_total_bytes)"
  mem_available="$(mem_available_bytes)"
  mem_used=$((mem_total - mem_available))
  mem_usage="$(awk -v used="$mem_used" -v total="$mem_total" 'BEGIN {
    if (total <= 0) {
      printf "0.0"
    } else {
      printf "%.1f", (100 * used / total)
    }
  }')"

  rx_rate=$(( (net_rx_2 - net_rx_1) / INTERVAL ))
  tx_rate=$(( (net_tx_2 - net_tx_1) / INTERVAL ))

  clear_screen
  echo "al-hub system monitor"
  echo "timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
  echo "uptime: $(uptime -p 2>/dev/null || true)"
  echo ""
  printf "CPU model     : %s\n" "$(cpu_model)"
  printf "CPU usage     : %s%%\n" "$cpu_usage"
  printf "Memory total   : %s\n" "$(format_bytes "$mem_total")"
  printf "Memory usage   : %s%% (%s / %s)\n" "$mem_usage" "$(format_bytes "$mem_used")" "$(format_bytes "$mem_total")"
  printf "GPU model     : %s\n" "$(gpu_model)"
  printf "GPU VRAM      : %s\n" "$(gpu_vram_usage)"
  echo ""
  echo "[Disk]"
  while IFS='|' read -r name model size; do
    printf "  %s  model=%s  size=%s\n" "$name" "$model" "$size"
  done < <(disk_inventory)
  df -hT -x tmpfs -x devtmpfs 2>/dev/null | awk '
    NR == 1 || $1 ~ "^/dev/" {
      print "  " $0
    }
  '
  echo ""
  echo "[Network]"
  printf "  rx: %s/s\n" "$(format_bytes "$rx_rate")"
  printf "  tx: %s/s\n" "$(format_bytes "$tx_rate")"
  ip -s link show 2>/dev/null | awk '
    /^[0-9]+: / {
      iface = $2
      sub(/:$/, "", iface)
      if (iface != "lo") {
        print "  iface: " iface
      }
    }
  '
  echo ""
  echo "Ctrl-C to exit"
}

trap 'printf "\n"; exit 0' INT TERM

while true; do
  draw_once
done
