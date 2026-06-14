#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEFAULT_CODEX_HOME="${HOME:-$ROOT_DIR/.local-home}/.codex"

find_latest_state_db() {
  local db

  if [ -n "${CCUSAGE_STATE_DB:-}" ] && [ -r "${CCUSAGE_STATE_DB}" ]; then
    printf '%s\n' "${CCUSAGE_STATE_DB}"
    return
  fi

  if [ -d "$DEFAULT_CODEX_HOME" ]; then
    db="$(ls -1t "$DEFAULT_CODEX_HOME"/state_*.sqlite 2>/dev/null | head -n1 || true)"
    if [ -n "$db" ] && [ -r "$db" ]; then
      printf '%s\n' "$db"
      return
    fi
  fi

  if [ -r "$DEFAULT_CODEX_HOME/state_5.sqlite" ]; then
    printf '%s\n' "$DEFAULT_CODEX_HOME/state_5.sqlite"
    return
  fi

  printf '%s\n' ""
}

show_help() {
  cat <<'EOF'
ccusage-style session usage summary

Usage:
  npx github:al-hub/npx ccusage
  npx github:al-hub/npx ccusage --watch
  npx github:al-hub/npx ccusage --all
  npx github:al-hub/npx tokens

Options:
  -d, --db FILE         codex state sqlite file
  -c, --cwd PATH        scope to a workspace path
  -a, --all             show all sessions
  -i, --interval SEC    refresh interval for watch mode
  -w, --watch           live refresh
  --price-file FILE     optional TSV price file: model <tab> usd_per_million_tokens
EOF
}

WATCH=0
SHOW_ALL=0
INTERVAL="${CCUSAGE_INTERVAL:-1}"
TARGET_CWD="${CCUSAGE_CWD:-$PWD}"
STATE_DB="${CCUSAGE_STATE_DB:-$(find_latest_state_db)}"
PRICE_FILE="${CCUSAGE_PRICE_FILE:-${DEFAULT_CODEX_HOME}/ccusage-prices.tsv}"

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      -h|--help|help)
        show_help
        exit 0
        ;;
      -w|--watch|watch)
        WATCH=1
        ;;
      -a|--all)
        SHOW_ALL=1
        ;;
      -d|--db|--state-db)
        STATE_DB="${2:-}"
        shift
        ;;
      --db=*|--state-db=*)
        STATE_DB="${1#*=}"
        ;;
      -c|--cwd)
        TARGET_CWD="${2:-}"
        shift
        ;;
      --cwd=*)
        TARGET_CWD="${1#*=}"
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
        break
        ;;
      -*)
        echo "Unknown option: $1" >&2
        exit 1
        ;;
      *)
        if [ -z "${STATE_DB:-}" ] && [ -r "$1" ]; then
          STATE_DB="$1"
        elif [ -z "${TARGET_CWD:-}" ]; then
          TARGET_CWD="$1"
        fi
        ;;
    esac
    shift
  done
}

render_once() {
  if [ -z "${STATE_DB:-}" ] || [ ! -r "$STATE_DB" ]; then
    cat <<EOF
[ccusage] ${STATE_DB:-unknown}
[Status] no Codex state database found
[Hint] set CCUSAGE_STATE_DB or place a state_*.sqlite file under ~/.codex
EOF
    return
  fi

  python3 - "$STATE_DB" "$TARGET_CWD" "$PRICE_FILE" "$SHOW_ALL" <<'PY'
import datetime as dt
import os
import sqlite3
import sys

db_path = sys.argv[1]
target_cwd = sys.argv[2]
price_file = sys.argv[3]
show_all = sys.argv[4] == "1"

def load_prices(path):
    prices = {}
    if not path or not os.path.isfile(path):
        return prices
    with open(path, "r", encoding="utf-8", errors="replace") as handle:
      for raw in handle:
        line = raw.strip()
        if not line or line.startswith("#"):
          continue
        parts = line.split()
        if len(parts) < 2:
          continue
        model = parts[0].strip().lower()
        rate = None
        for token in parts[1:]:
          try:
            rate = float(token)
            break
          except ValueError:
            continue
        if rate is not None:
          prices[model] = rate
    return prices

def fmt_tokens(value):
    value = int(value or 0)
    if value >= 1_000_000:
        return f"{value / 1_000_000:.1f}M"
    if value >= 1_000:
        return f"{value / 1_000:.1f}K"
    return str(value)

def fmt_cost(value, known):
    if not known:
        return "n/a"
    return f"${value:.2f}"

def fmt_ts(value):
    if not value:
        return "-"
    return dt.datetime.fromtimestamp(int(value)).strftime("%Y-%m-%d %H:%M")

def clean(text, width):
    if text is None:
        text = ""
    text = " ".join(str(text).split())
    if len(text) <= width:
        return text
    if width <= 1:
        return text[:width]
    return text[: width - 1] + "…"

prices = load_prices(price_file)
con = sqlite3.connect(db_path)
con.row_factory = sqlite3.Row
cur = con.cursor()

base_sql = """
SELECT id, created_at, updated_at, source, cwd, title, model, reasoning_effort, tokens_used
FROM threads
"""

rows = []
scope = "all"
if not show_all and target_cwd:
    rows = cur.execute(base_sql + " WHERE cwd = ? ORDER BY updated_at DESC", (target_cwd,)).fetchall()
    scope = f"cwd={target_cwd}"
if not rows:
    rows = cur.execute(base_sql + " ORDER BY updated_at DESC").fetchall()
    scope = "all"

total_tokens = 0
total_cost = 0.0
known_cost = False

print(f"[ccusage] {db_path}")
print(f"[Scope] {scope}")
print(f"[Rows] {len(rows)}")

if not rows:
    print("[Status] no sessions found")
    raise SystemExit(0)

session_w = 18
model_w = 12
tokens_w = 12
cost_w = 12
updated_w = 16
title_w = 46

print(f"{'Session':{session_w}} {'Model':{model_w}} {'Tokens':>{tokens_w}} {'Cost':>{cost_w}} {'Updated':{updated_w}} Title")
print(f"{'-' * session_w} {'-' * model_w} {'-' * tokens_w} {'-' * cost_w} {'-' * updated_w} {'-' * title_w}")

for row in rows:
    session_id = clean(row["id"], session_w)
    model = clean(row["model"] or "Unknown", model_w)
    tokens = int(row["tokens_used"] or 0)
    total_tokens += tokens
    updated = fmt_ts(row["updated_at"])
    title = clean(row["title"] or "", title_w)
    rate = prices.get((row["model"] or "").lower())
    if rate is not None:
        cost = tokens * rate / 1_000_000.0
        total_cost += cost
        known_cost = True
    else:
        cost = None
    print(f"{session_id:{session_w}} {model:{model_w}} {fmt_tokens(tokens):>{tokens_w}} {fmt_cost(cost, rate is not None):>{cost_w}} {updated:{updated_w}} {title}")

print(f"{'TOTAL':{session_w}} {str(len(rows)) + ' sessions':{model_w}} {fmt_tokens(total_tokens):>{tokens_w}} {fmt_cost(total_cost, known_cost):>{cost_w}} {'-':{updated_w}} {'-'}")
PY
}

parse_args "$@"

if [ "$WATCH" -eq 1 ]; then
  trap 'printf "\033[?25h"; printf "\n"' INT TERM EXIT
  printf '\033[2J\033[H'
  printf '\033[?25l'
  while true; do
    printf '\033[H'
    render_once
    sleep "$INTERVAL"
  done
else
  render_once
fi
