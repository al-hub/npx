#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "[setup] 기본 개발 폴더 생성"

target_home="${HOME:-}"

if [ -n "$target_home" ] && mkdir -p "$target_home/.al" "$target_home/workspace" "$target_home/.config/opencode" 2>/dev/null; then
  echo "[setup] using HOME: $target_home"
else
  target_home="$ROOT_DIR/.local-home"
  mkdir -p "$target_home/.al" "$target_home/workspace" "$target_home/.config/opencode"
  echo "[setup] HOME is not writable here; using local fallback: $target_home"
fi

echo "[setup] done"
