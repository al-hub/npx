#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

DEFAULT_TOKEN_LOG="${HOME:-$ROOT_DIR/.local-home}/.al/token-usage.log"
TOKEN_LOG_FILE="${1:-${TOKEN_LOG_FILE:-$DEFAULT_TOKEN_LOG}}"
INTERVAL="${2:-${TOKEN_INTERVAL:-1}}"

hide_cursor() {
  printf '\033[?25l'
}

show_cursor() {
  printf '\033[?25h'
}

format_count() {
  awk -v value="${1:-0}" 'BEGIN {
    value += 0
    if (value < 0) {
      value = 0
    }
    if (value >= 1000000) {
      printf "%.1fM", value / 1000000
    } else if (value >= 1000) {
      printf "%.1fK", value / 1000
    } else {
      printf "%.0f", value
    }
  }'
}

file_state() {
  if [ -r "$TOKEN_LOG_FILE" ]; then
    printf 'ready\n'
  else
    printf 'missing\n'
  fi
}

scan_tokens() {
  awk '
    function extract_number(line, key,    pattern, rest) {
      pattern = "\"" key "\"[[:space:]]*:[[:space:]]*[0-9]+"
      if (match(line, pattern)) {
        rest = substr(line, RSTART, RLENGTH)
        sub(/.*:[[:space:]]*/, "", rest)
        return rest + 0
      }

      pattern = "(^|[^[:alnum:]_])" key "[[:space:]]*=[[:space:]]*[0-9]+"
      if (match(line, pattern)) {
        rest = substr(line, RSTART, RLENGTH)
        sub(/.*=[[:space:]]*/, "", rest)
        return rest + 0
      }

      return -1
    }

    {
      input = extract_number($0, "input_tokens")
      if (input < 0) {
        input = extract_number($0, "prompt_tokens")
      }

      output = extract_number($0, "output_tokens")
      if (output < 0) {
        output = extract_number($0, "completion_tokens")
      }

      total = extract_number($0, "total_tokens")
      if (total < 0) {
        total = extract_number($0, "tokens")
      }

      if (input >= 0) {
        sum_input += input
        line_has_data = 1
      }

      if (output >= 0) {
        sum_output += output
        line_has_data = 1
      }

      if (total >= 0) {
        sum_total += total
        line_has_data = 1
      } else if (input >= 0 || output >= 0) {
        sum_total += (input > 0 ? input : 0) + (output > 0 ? output : 0)
      }

      if (line_has_data) {
        entries += 1
        last_input = input
        last_output = output
        last_total = (total >= 0) ? total : ((input > 0 ? input : 0) + (output > 0 ? output : 0))
      }

      line_has_data = 0
    }

    END {
      printf "%d|%d|%d|%d|%d|%d|%d\n", entries + 0, sum_input + 0, sum_output + 0, sum_total + 0, last_input + 0, last_output + 0, last_total + 0
    }
  ' "$TOKEN_LOG_FILE"
}

render_once() {
  local state entries input_total output_total grand_total last_input last_output last_total

  state="$(file_state)"
  if [ "$state" = "missing" ]; then
    printf '[Tokens] %s\n' "$TOKEN_LOG_FILE"
    printf '[Status] waiting for log file\n'
    printf '[Hint] write JSONL entries with input_tokens / output_tokens / total_tokens\n'
    return
  fi

  IFS='|' read -r entries input_total output_total grand_total last_input last_output last_total < <(scan_tokens)

  printf '[Tokens] %s\n' "$TOKEN_LOG_FILE"
  printf '[Entries] %s\n' "${entries:-0}"
  printf '[Input] %s\n' "$(format_count "${input_total:-0}")"
  printf '[Output] %s\n' "$(format_count "${output_total:-0}")"
  printf '[Total] %s\n' "$(format_count "${grand_total:-0}")"
  printf '[Last] in %s, out %s, total %s\n' "$(format_count "${last_input:-0}")" "$(format_count "${last_output:-0}")" "$(format_count "${last_total:-0}")"
}

trap 'show_cursor; printf "\n"' INT TERM EXIT

printf '\033[2J\033[H'
hide_cursor

while true; do
  printf '\033[H'
  render_once
  sleep "$INTERVAL"
done
