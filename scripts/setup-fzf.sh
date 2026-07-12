#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "[setup-fzf] fzf 공식 설치(git clone + install)"

if dpkg -l | grep -q '^ii.*fzf'; then
  echo "[setup-fzf] apt 패키지 fzf 제거 중..."
  sudo apt remove -y fzf
  echo "[setup-fzf] apt 패키지 제거 완료"
fi

if [ ! -d "$HOME/.fzf" ]; then
  echo "[setup-fzf] git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf"
  git clone --depth 1 https://github.com/junegunn/fzf.git "$HOME/.fzf"
else
  echo "[setup-fzf] ~/.fzf 이미 존재, 업데이트 중..."
  git -C "$HOME/.fzf" pull --depth 1
fi

echo "[setup-fzf] ~/.fzf/install --all 실행 중..."
"$HOME/.fzf/install" --all --no-bash --no-zsh --no-fish

for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
  if [ -f "$rc" ]; then
    if ! grep -q '\.fzf\.' "$rc"; then
      echo "[setup-fzf] $rc에 fzf 연동 추가"
      echo '[ -f ~/.fzf.bash ] && source ~/.fzf.bash' >> "$rc"
      echo '[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh' >> "$rc"
    fi
  fi
done

if command -v fzf >/dev/null 2>&1; then
  echo "[setup-fzf] 완료: $(fzf --version)"
else
  echo "[setup-fzf] 경고: fzf가 PATH에 없습니다. 쉘을 재시작하거나 'source ~/.bashrc' 실행하세요."
  exit 1
fi