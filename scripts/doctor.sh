#!/usr/bin/env bash
set -euo pipefail

echo "[doctor] 환경 점검"
echo ""

echo "[node]"
node -v || true
npm -v || true
npx -v || true

echo ""
echo "[git]"
git --version || true

echo ""
echo "[os]"
uname -a || true

echo ""
echo "[wsl]"
if grep -qi microsoft /proc/version 2>/dev/null; then
  echo "WSL: yes"
else
  echo "WSL: no or unknown"
fi

echo ""
echo "[api keys]"
for key in NVIDIA_API_KEY GEMINI_API_KEY OPENROUTER_API_KEY GROQ_API_KEY CEREBRAS_API_KEY; do
  if [ -n "${!key:-}" ]; then
    echo "$key: set"
  else
    echo "$key: missing"
  fi
done
