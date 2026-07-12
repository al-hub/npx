#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATE_DIR="$ROOT_DIR/scripts/templates"
CONFIG_DIR="${HOME}/.config/opencode"

PROFILE="personal"
DRY_RUN=0

usage() {
  cat <<'EOF'
Usage: npx github:al-hub/npx setup-opencode [options]

Options:
  --profile personal|work    Profile to apply (default: personal)
  --dry-run                  Show what would be changed without writing
  -h, --help                 Show this help
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --profile)
      PROFILE="${2:-personal}"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [ "$PROFILE" != "personal" ] && [ "$PROFILE" != "work" ]; then
  echo "Error: profile must be 'personal' or 'work'" >&2
  exit 1
fi

OPENCODE_CONFIG="${CONFIG_DIR}/opencode.jsonc"
TUI_CONFIG="${CONFIG_DIR}/tui.jsonc"

OPENCODE_TEMPLATE="${TEMPLATE_DIR}/opencode.${PROFILE}.jsonc"
TUI_TEMPLATE="${TEMPLATE_DIR}/tui.${PROFILE}.jsonc"

if [ ! -f "$OPENCODE_TEMPLATE" ] || [ ! -f "$TUI_TEMPLATE" ]; then
  echo "Error: templates not found for profile '$PROFILE'" >&2
  exit 1
fi

backup_file() {
  local file="$1"
  if [ -f "$file" ]; then
    local backup="${file}.bak.$(date +%Y%m%d_%H%M%S)"
    if [ "$DRY_RUN" -eq 0 ]; then
      cp "$file" "$backup"
      echo "[setup-opencode] backed up $file -> $backup"
    else
      echo "[setup-opencode] would backup $file -> $backup"
    fi
  fi
}

install_config() {
  local src="$1"
  local dst="$2"
  local name="$3"

  if [ "$DRY_RUN" -eq 0 ]; then
    mkdir -p "$(dirname "$dst")"
    cp "$src" "$dst"
    echo "[setup-opencode] installed $name -> $dst"
  else
    echo "[setup-opencode] would install $name -> $dst"
    echo "--- diff ---"
    diff -u "$dst" "$src" 2>/dev/null || true
    echo "--- end diff ---"
  fi
}

check_opencode_cli() {
  if command -v opencode >/dev/null 2>&1; then
    echo "[setup-opencode] opencode CLI found: $(opencode --version 2>/dev/null || echo 'version unknown')"
  else
    echo "[setup-opencode] WARNING: opencode CLI not found in PATH"
    echo "  Install with: curl -fsSL https://opencode.ai/install | bash"
    echo "  Or: npm install -g opencode-ai"
  fi
}

echo "[setup-opencode] profile: $PROFILE"
echo "[setup-opencode] config dir: $CONFIG_DIR"
echo ""

check_opencode_cli
echo ""

backup_file "$OPENCODE_CONFIG"
backup_file "$TUI_CONFIG"

install_config "$OPENCODE_TEMPLATE" "$OPENCODE_CONFIG" "opencode.jsonc"
install_config "$TUI_TEMPLATE" "$TUI_CONFIG" "tui.jsonc"

if [ "$DRY_RUN" -eq 0 ]; then
  echo ""
  echo "[setup-opencode] done. Restart opencode to apply changes."
fi