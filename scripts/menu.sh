#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

show_help() {
  cat <<'EOF'
al-hub npx launcher

Usage:
  npx github:al-hub/npx
  npx github:al-hub/npx doctor
  npx github:al-hub/npx setup
  npx github:al-hub/npx monitor
  npx github:al-hub/npx ccusage
  npx github:al-hub/npx tokens

Commands:
  doctor   환경 점검
  setup    기본 개발 폴더 생성
  monitor  시스템 모니터링
  ccusage  세션별 토큰/비용 표
  tokens   현재 세션 토큰 실시간 모니터
EOF
}

run_menu() {
  echo "al-hub npx launcher"
  echo ""
  echo "1) doctor   환경 점검"
  echo "2) setup    기본 개발 폴더 생성"
  echo "3) monitor  시스템 모니터링"
  echo "4) ccusage  세션별 토큰/비용 표"
  echo "5) tokens   현재 세션 토큰 실시간"
  echo "6) exit"
  echo ""

  read -rp "선택하세요: " choice

  case "$choice" in
    1) bash "$ROOT_DIR/scripts/doctor.sh" ;;
    2) bash "$ROOT_DIR/scripts/setup.sh" ;;
    3) bash "$ROOT_DIR/scripts/monitor.sh" ;;
    4) bash "$ROOT_DIR/scripts/ccusage.sh" ;;
    5) bash "$ROOT_DIR/scripts/tokens.sh" ;;
    6) exit 0 ;;
    *) echo "잘못된 선택입니다."; exit 1 ;;
  esac
}

cmd="${1:-}"
args=("${@:2}")

case "$cmd" in
  "")
    run_menu
    ;;
  help|-h|--help)
    show_help
    ;;
  doctor)
    bash "$ROOT_DIR/scripts/doctor.sh" "${args[@]}"
    ;;
  setup)
    bash "$ROOT_DIR/scripts/setup.sh" "${args[@]}"
    ;;
  monitor)
    bash "$ROOT_DIR/scripts/monitor.sh" "${args[@]}"
    ;;
  ccusage)
    bash "$ROOT_DIR/scripts/ccusage.sh" "${args[@]}"
    ;;
  tokens)
    bash "$ROOT_DIR/scripts/tokens.sh" "${args[@]}"
    ;;
  *)
    echo "Unknown command: $cmd"
    echo ""
    show_help
    exit 1
    ;;
esac
