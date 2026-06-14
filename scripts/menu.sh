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

Commands:
  doctor   환경 점검
  setup    기본 개발 폴더 생성
EOF
}

run_menu() {
  echo "al-hub npx launcher"
  echo ""
  echo "1) doctor   환경 점검"
  echo "2) setup    기본 개발 폴더 생성"
  echo "3) exit"
  echo ""

  read -rp "선택하세요: " choice

  case "$choice" in
    1) bash "$ROOT_DIR/scripts/doctor.sh" ;;
    2) bash "$ROOT_DIR/scripts/setup.sh" ;;
    3) exit 0 ;;
    *) echo "잘못된 선택입니다."; exit 1 ;;
  esac
}

cmd="${1:-}"

case "$cmd" in
  "")
    run_menu
    ;;
  help|-h|--help)
    show_help
    ;;
  doctor)
    bash "$ROOT_DIR/scripts/doctor.sh"
    ;;
  setup)
    bash "$ROOT_DIR/scripts/setup.sh"
    ;;
  *)
    echo "Unknown command: $cmd"
    echo ""
    show_help
    exit 1
    ;;
esac
