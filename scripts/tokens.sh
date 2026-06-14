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

  printf '%s\n' ""
}

show_help() {
  cat <<'EOF'
live token monitor

Usage:
  npx github:al-hub/npx tokens
  npx github:al-hub/npx tokens --all

Options:
  -d, --db FILE         codex state sqlite file
  -c, --cwd PATH        scope to a workspace path
  -a, --all             include all workspaces
  -i, --interval SEC    refresh interval
EOF
}

STATE_DB="${CCUSAGE_STATE_DB:-$(find_latest_state_db)}"
TARGET_CWD="${CCUSAGE_CWD:-$PWD}"
INTERVAL="${CCUSAGE_INTERVAL:-1}"
SHOW_ALL=0

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      -h|--help|help)
        show_help
        exit 0
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
      -*)
        echo "Unknown option: $1" >&2
        exit 1
        ;;
      *)
        ;;
    esac
    shift
  done
}

render_once() {
  if [ -z "${STATE_DB:-}" ] || [ ! -r "$STATE_DB" ]; then
    cat <<EOF
[Tokens] no Codex state database found
[Hint] set CCUSAGE_STATE_DB or use Codex once so ~/.codex/state_*.sqlite exists
EOF
    return
  fi

  python3 - "$STATE_DB" "$TARGET_CWD" "$SHOW_ALL" <<'PY'
import datetime as dt
import sqlite3
import sys

db_path = sys.argv[1]
target_cwd = sys.argv[2]
show_all = sys.argv[3] == "1"

def fmt_tokens(value):
    value = int(value or 0)
    if value >= 1_000_000:
        return f"{value / 1_000_000:.2f}M"
    if value >= 1_000:
        return f"{value / 1_000:.1f}K"
    return str(value)

def fmt_ts(value):
    if not value:
        return "-"
    return dt.datetime.fromtimestamp(int(value)).strftime("%Y-%m-%d %H:%M:%S")

def clean(text, width):
    text = " ".join(str(text or "").split())
    if len(text) <= width:
        return text
    return text[: width - 1] + "…"

con = sqlite3.connect(db_path)
con.row_factory = sqlite3.Row
cur = con.cursor()

where = ""
params = []
scope = "all workspaces"
if not show_all and target_cwd:
    where = "WHERE cwd = ?"
    params = [target_cwd]
    scope = target_cwd

rows = cur.execute(
    f"""
    SELECT id, updated_at, cwd, title, model, tokens_used
    FROM threads
    {where}
    ORDER BY updated_at DESC
    """,
    params,
).fetchall()

if not rows and where:
    rows = cur.execute(
        """
        SELECT id, updated_at, cwd, title, model, tokens_used
        FROM threads
        ORDER BY updated_at DESC
        """
    ).fetchall()
    scope = "all workspaces"

total = sum(int(row["tokens_used"] or 0) for row in rows)
latest = rows[0] if rows else None

print("[Tokens] live Codex token monitor")
print(f"[DB] {db_path}")
print(f"[Scope] {scope}")
print(f"[Sessions] {len(rows)}")
print(f"[Total Tokens] {fmt_tokens(total)}")

if not latest:
    print("[Current] no sessions found")
    raise SystemExit(0)

print("")
print("[Current Session]")
print(f"  id      : {latest['id']}")
print(f"  model   : {latest['model'] or 'Unknown'}")
print(f"  tokens  : {fmt_tokens(latest['tokens_used'])}")
print(f"  updated : {fmt_ts(latest['updated_at'])}")
print(f"  cwd     : {latest['cwd']}")
print(f"  title   : {clean(latest['title'], 72)}")

print("")
print("Recent sessions")
print(f"{'Tokens':>10} {'Updated':19} Title")
print(f"{'-' * 10} {'-' * 19} {'-' * 48}")
for row in rows[:5]:
    print(f"{fmt_tokens(row['tokens_used']):>10} {fmt_ts(row['updated_at']):19} {clean(row['title'], 48)}")

print("")
print("[Quit] press q")
PY
}

wait_or_quit() {
  local elapsed=0
  local key
  while awk -v elapsed="$elapsed" -v interval="$INTERVAL" 'BEGIN { exit !(elapsed < interval) }'; do
    if IFS= read -rsn1 -t 0.1 key; then
      case "$key" in
        q|Q) return 1 ;;
      esac
    fi
    elapsed="$(awk -v elapsed="$elapsed" 'BEGIN { printf "%.1f", elapsed + 0.1 }')"
  done
  return 0
}

trap 'printf "\033[?25h"; printf "\n"' INT TERM EXIT

parse_args "$@"

printf '\033[2J\033[H'
printf '\033[?25l'

while true; do
  printf '\033[H'
  render_once
  wait_or_quit || break
done
