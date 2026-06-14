#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

DEFAULT_TOKEN_LOG="${HOME:-$ROOT_DIR/.local-home}/.al/token-usage.log"
DEFAULT_PRICE_FILE="${HOME:-$ROOT_DIR/.local-home}/.al/ccusage-prices.tsv"

TOKEN_LOG_FILE="${TOKEN_LOG_FILE:-$DEFAULT_TOKEN_LOG}"
PRICE_FILE="${CCUSAGE_PRICE_FILE:-$DEFAULT_PRICE_FILE}"
INTERVAL="${TOKEN_INTERVAL:-1}"
WATCH=0

show_help() {
  cat <<'EOF'
ccusage-style session usage summary

Usage:
  npx github:al-hub/npx ccusage
  npx github:al-hub/npx ccusage --watch
  npx github:al-hub/npx tokens

Options:
  -f, --file FILE       usage log file
  -i, --interval SEC    refresh interval for watch mode
  -w, --watch           live refresh
  --price-file FILE     optional model price table
EOF
}

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

format_cost() {
  awk -v value="${1:-0}" -v known="${2:-0}" 'BEGIN {
    if (known + 0 == 0) {
      printf "n/a"
      exit
    }
    value += 0
    if (value < 0) {
      printf "n/a"
      exit
    }
    printf "$%.2f", value
  }'
}

load_price_table() {
  awk -v price_file="$PRICE_FILE" '
    function trim(value) {
      sub(/^[ \t]+/, "", value)
      sub(/[ \t]+$/, "", value)
      return value
    }

    function extract_string(line, key,    pattern, value) {
      pattern = "\"" key "\"[[:space:]]*:[[:space:]]*\"[^\"]*\""
      if (match(line, pattern)) {
        value = substr(line, RSTART, RLENGTH)
        sub(/^.*:[[:space:]]*"/, "", value)
        sub(/"$/, "", value)
        return value
      }
      return ""
    }

    BEGIN {
      if (price_file != "" && (getline line < price_file) >= 0) {
        do {
          if (line ~ /^[[:space:]]*$/ || line ~ /^[[:space:]]*#/) {
            continue
          }
          split(line, parts, /\t/)
          if (length(parts[1]) > 0 && length(parts[2]) > 0 && length(parts[3]) > 0) {
            key = tolower(trim(parts[1]))
            price_in[key] = parts[2] + 0
            price_out[key] = parts[3] + 0
          }
        } while ((getline line < price_file) > 0)
        close(price_file)
      }
    }

    function extract_number(line, key,    pattern, value) {
      pattern = "\"" key "\"[[:space:]]*:[[:space:]]*(-?[0-9]+([.][0-9]+)?)"
      if (match(line, pattern)) {
        value = substr(line, RSTART, RLENGTH)
        sub(/^.*:[[:space:]]*/, "", value)
        return value + 0
      }
      return -1
    }

    function choose_string(line, keys,    i, n, value) {
      n = split(keys, arr, /\|/)
      for (i = 1; i <= n; i++) {
        value = extract_string(line, arr[i])
        if (value != "") {
          return value
        }
      }
      return ""
    }

    function choose_number(line, keys,    i, n, value) {
      n = split(keys, arr, /\|/)
      for (i = 1; i <= n; i++) {
        value = extract_number(line, arr[i])
        if (value >= 0) {
          return value
        }
      }
      return -1
    }

    function maybe_cost(model, input, output,    key) {
      key = tolower(model)
      if (key in price_in && key in price_out) {
        return (input * price_in[key] + output * price_out[key]) / 1000000.0
      }
      return -1
    }

    {
      seq += 1

      session = choose_string($0, "session_id|sessionId|chat_session_id|chatSessionId|conversation_id|conversationId|run_id|thread_id")
      if (session == "") {
        session = "default"
      }

      model = choose_string($0, "model|model_name|modelName|engine")
      if (model == "") {
        model = "Unknown"
      }

      ts = choose_string($0, "created_at|createdAt|timestamp|time|date|ts")
      if (ts == "") {
        ts = "-"
      }

      input = choose_number($0, "input_tokens|prompt_tokens|inputTokens|promptTokens")
      output = choose_number($0, "output_tokens|completion_tokens|outputTokens|completionTokens")
      total = choose_number($0, "total_tokens|tokens|totalTokens")
      cost = choose_number($0, "cost_usd|usd|cost")

      if (input >= 0) {
        sum_input[session] += input
      }

      if (output >= 0) {
        sum_output[session] += output
      }

      if (total >= 0) {
        sum_total[session] += total
      } else if (input >= 0 || output >= 0) {
        sum_total[session] += (input > 0 ? input : 0) + (output > 0 ? output : 0)
      }

      if (cost >= 0) {
        sum_cost[session] += cost
        seen_cost[session] = 1
      } else {
        estimate = maybe_cost(model, (input > 0 ? input : 0), (output > 0 ? output : 0))
        if (estimate >= 0) {
          sum_cost[session] += estimate
          seen_cost[session] = 1
        }
      }

      entries[session] += 1
      if (!(session in first_seq)) {
        first_seq[session] = seq
        first_ts[session] = ts
        first_model[session] = model
      }
      last_seq[session] = seq
      last_ts[session] = ts
      last_model[session] = model

      if (!(session in session_index)) {
        session_index[session] = ++session_count
      }
    }

    END {
      for (session in session_index) {
        order = last_seq[session]
        printf "%d|%s|%s|%d|%d|%d|%.6f|%d|%s|%s|%d|%s\n",
          order,
          session,
          last_model[session],
          sum_input[session] + 0,
          sum_output[session] + 0,
          sum_total[session] + 0,
          sum_cost[session] + 0,
          entries[session] + 0,
          first_ts[session],
          last_ts[session],
          seen_cost[session] + 0,
          first_model[session]
      }
    }
  ' "$TOKEN_LOG_FILE" | sort -t'|' -k1,1nr -k2,2
}

render_summary() {
  local rows footer total_sessions total_input total_output total_tokens total_cost

  if [ ! -r "$TOKEN_LOG_FILE" ]; then
    printf '[ccusage] %s\n' "$TOKEN_LOG_FILE"
    printf '[Status] waiting for log file\n'
    printf '[Hint] JSONL lines should include session_id, token counts, and optional cost_usd\n'
    return
  fi

  rows="$(load_price_table)"
  if [ -z "$rows" ]; then
    printf '[ccusage] %s\n' "$TOKEN_LOG_FILE"
    printf '[Status] no usage rows found\n'
    return
  fi

  footer="$(printf '%s\n' "$rows" | awk -F'|' '
    {
      sessions += 1
      input += $4
      output += $5
      total += $6
      cost += $7
      if ($11 > 0) {
        seen_cost += 1
      }
    }
    END {
      printf "%d|%d|%d|%d|%.6f|%d\n", sessions + 0, input + 0, output + 0, total + 0, cost + 0, seen_cost + 0
    }
  ')"

  IFS='|' read -r total_sessions total_input total_output total_tokens total_cost _seen_cost <<< "$footer"

  printf '[ccusage] %s\n' "$TOKEN_LOG_FILE"
  printf '%-18s %-18s %9s %9s %9s %12s %19s %19s\n' "Session" "Model" "Input" "Output" "Total" "Cost" "First" "Last"
  printf '%-18s %-18s %9s %9s %9s %12s %19s %19s\n' "------------------" "------------------" "---------" "---------" "---------" "------------" "-------------------" "-------------------"

  while IFS='|' read -r _order session model input output total cost entries first_ts last_ts seen_cost first_model; do
    [ -n "$session" ] || continue
    printf '%-18.18s %-18.18s %9s %9s %9s %12s %19.19s %19.19s\n' \
      "$session" \
      "$model" \
      "$(format_count "$input")" \
      "$(format_count "$output")" \
      "$(format_count "$total")" \
      "$(format_cost "$cost" "$seen_cost")" \
      "$first_ts" \
      "$last_ts"
  done <<< "$rows"

  printf '%-18s %-18s %9s %9s %9s %12s %19s %19s\n' \
    "TOTAL" \
    "$total_sessions sessions" \
    "$(format_count "$total_input")" \
    "$(format_count "$total_output")" \
    "$(format_count "$total_tokens")" \
    "$(format_cost "$total_cost" "${_seen_cost:-0}")" \
    "-" \
    "-"
}

render_watch() {
  trap 'show_cursor; printf "\n"' INT TERM EXIT
  printf '\033[2J\033[H'
  hide_cursor

  while true; do
    printf '\033[H'
    render_summary
    sleep "$INTERVAL"
  done
}

parse_args() {
  local positional=()

  while [ "$#" -gt 0 ]; do
    case "$1" in
      -h|--help|help)
        show_help
        exit 0
        ;;
      -w|--watch|watch)
        WATCH=1
        ;;
      -f|--file)
        TOKEN_LOG_FILE="${2:-}"
        shift
        ;;
      --file=*)
        TOKEN_LOG_FILE="${1#*=}"
        ;;
      -i|--interval)
        INTERVAL="${2:-1}"
        shift
        ;;
      --interval=*)
        INTERVAL="${1#*=}"
        ;;
      --price-file)
        PRICE_FILE="${2:-}"
        shift
        ;;
      --price-file=*)
        PRICE_FILE="${1#*=}"
        ;;
      --)
        shift
        while [ "$#" -gt 0 ]; do
          positional+=("$1")
          shift
        done
        break
        ;;
      -*)
        echo "Unknown option: $1" >&2
        exit 1
        ;;
      *)
        positional+=("$1")
        ;;
    esac
    shift
  done

  if [ "${#positional[@]}" -ge 1 ] && [ -n "${positional[0]:-}" ]; then
    TOKEN_LOG_FILE="${positional[0]}"
  fi
  if [ "${#positional[@]}" -ge 2 ] && [ -n "${positional[1]:-}" ]; then
    INTERVAL="${positional[1]}"
  fi
}

parse_args "$@"

if [ "$WATCH" -eq 1 ]; then
  render_watch
else
  render_summary
fi
