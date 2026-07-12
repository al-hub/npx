#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

PLATFORM="opencode"
CLAUDE="no"
OPENAI="no"
GEMINI="no"
COPILOT="no"
OPENCODE_ZEN="no"
ZAI_CODING_PLAN="no"
OPENCODE_GO="no"
KIMI_FOR_CODING="no"
VERCEL_AI_GATEWAY="no"
CODEX_AUTONOMOUS="no"
SKIP_AUTH=0
DRY_RUN=0

usage() {
  cat <<'EOF'
Usage: npx github:al-hub/npx setup-opencode-omo [options]

Options:
  --platform opencode|codex|both   Target platform (default: opencode)
  --claude yes|no|max20            Claude Pro/Max subscription
  --openai yes|no                  OpenAI/ChatGPT Plus subscription
  --gemini yes|no                  Google Gemini subscription
  --copilot yes|no                 GitHub Copilot subscription
  --opencode-zen yes|no            OpenCode Zen access
  --zai-coding-plan yes|no         Z.ai Coding Plan subscription
  --opencode-go yes|no             OpenCode Go subscription
  --kimi-for-coding yes|no         Kimi for Coding subscription
  --vercel-ai-gateway yes|no       Vercel AI Gateway access
  --codex-autonomous               Configure Codex for autonomous mode
  --no-codex-autonomous            Do not configure Codex autonomous mode
  --skip-auth                      Skip provider authentication
  --dry-run                        Show what would be executed
  -h, --help                       Show this help
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --platform)
      PLATFORM="${2:-opencode}"
      shift 2
      ;;
    --platform=*)
      PLATFORM="${1#*=}"
      shift
      ;;
    --claude)
      CLAUDE="${2:-no}"
      shift 2
      ;;
    --claude=*)
      CLAUDE="${1#*=}"
      shift
      ;;
    --openai)
      OPENAI="${2:-no}"
      shift 2
      ;;
    --openai=*)
      OPENAI="${1#*=}"
      shift
      ;;
    --gemini)
      GEMINI="${2:-no}"
      shift 2
      ;;
    --gemini=*)
      GEMINI="${1#*=}"
      shift
      ;;
    --copilot)
      COPILOT="${2:-no}"
      shift 2
      ;;
    --copilot=*)
      COPILOT="${1#*=}"
      shift
      ;;
    --opencode-zen)
      OPENCODE_ZEN="${2:-no}"
      shift 2
      ;;
    --opencode-zen=*)
      OPENCODE_ZEN="${1#*=}"
      shift
      ;;
    --zai-coding-plan)
      ZAI_CODING_PLAN="${2:-no}"
      shift 2
      ;;
    --zai-coding-plan=*)
      ZAI_CODING_PLAN="${1#*=}"
      shift
      ;;
    --opencode-go)
      OPENCODE_GO="${2:-no}"
      shift 2
      ;;
    --opencode-go=*)
      OPENCODE_GO="${1#*=}"
      shift
      ;;
    --kimi-for-coding)
      KIMI_FOR_CODING="${2:-no}"
      shift 2
      ;;
    --kimi-for-coding=*)
      KIMI_FOR_CODING="${1#*=}"
      shift
      ;;
    --vercel-ai-gateway)
      VERCEL_AI_GATEWAY="${2:-no}"
      shift 2
      ;;
    --vercel-ai-gateway=*)
      VERCEL_AI_GATEWAY="${1#*=}"
      shift
      ;;
    --codex-autonomous)
      CODEX_AUTONOMOUS="yes"
      shift
      ;;
    --no-codex-autonomous)
      CODEX_AUTONOMOUS="no"
      shift
      ;;
    --skip-auth)
      SKIP_AUTH=1
      shift
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

case "$PLATFORM" in
  opencode|codex|both) ;;
  *) echo "Error: --platform must be opencode, codex, or both" >&2; exit 1 ;;
esac

if [ "$CLAUDE" != "yes" ] && [ "$CLAUDE" != "no" ] && [ "$CLAUDE" != "max20" ]; then
  echo "Error: --claude must be yes, no, or max20" >&2
  exit 1
fi

for var in OPENAI GEMINI COPILOT OPENCODE_ZEN ZAI_CODING_PLAN OPENCODE_GO KIMI_FOR_CODING VERCEL_AI_GATEWAY; do
  val="${!var}"
  if [ "$val" != "yes" ] && [ "$val" != "no" ]; then
    echo "Error: --${var,,} must be yes or no" >&2
    exit 1
  fi
done

ensure_bun() {
  if command -v bun >/dev/null 2>&1; then
    echo "[setup-opencode-omo] bun found: $(bun --version)"
    return 0
  fi

  echo "[setup-opencode-omo] bun not found, installing..."

  case "$(uname -s)" in
    Linux*|Darwin*|CYGWIN*|MINGW*|MSYS*)
      if ! command -v unzip >/dev/null 2>&1; then
        echo "[setup-opencode-omo] ERROR: 'unzip' required to install bun" >&2
        echo "  Install unzip first:" >&2
        echo "    Ubuntu/Debian: sudo apt-get install -y unzip" >&2
        echo "    Alpine: apk add unzip" >&2
        echo "    Fedora: sudo dnf install -y unzip" >&2
        echo "    macOS: brew install unzip" >&2
        return 1
      fi

      if command -v curl >/dev/null 2>&1; then
        curl -fsSL https://bun.sh/install | bash
      elif command -v wget >/dev/null 2>&1; then
        wget -qO- https://bun.sh/install | bash
      else
        echo "[setup-opencode-omo] ERROR: curl or wget required to install bun" >&2
        return 1
      fi
      ;;
    *)
      echo "[setup-opencode-omo] ERROR: unsupported OS for auto-install" >&2
      echo "  Install manually: https://bun.sh" >&2
      return 1
      ;;
  esac

  export PATH="$HOME/.bun/bin:$PATH"
  if command -v bun >/dev/null 2>&1; then
    echo "[setup-opencode-omo] bun installed: $(bun --version)"
    return 0
  else
    echo "[setup-opencode-omo] ERROR: bun installation failed" >&2
    echo "  Restart shell or run: export PATH=\"\$HOME/.bun/bin:\$PATH\"" >&2
    return 1
  fi
}

if ! ensure_bun; then
  exit 1
fi

echo "[setup-opencode-omo] oh-my-openagent installer"
echo "[setup-opencode-omo] platform: $PLATFORM"
echo "[setup-opencode-omo] claude: $CLAUDE"
echo "[setup-opencode-omo] openai: $OPENAI"
echo "[setup-opencode-omo] gemini: $GEMINI"
echo "[setup-opencode-omo] copilot: $COPILOT"
echo "[setup-opencode-omo] opencode-zen: $OPENCODE_ZEN"
echo "[setup-opencode-omo] zai-coding-plan: $ZAI_CODING_PLAN"
echo "[setup-opencode-omo] opencode-go: $OPENCODE_GO"
echo "[setup-opencode-omo] kimi-for-coding: $KIMI_FOR_CODING"
echo "[setup-opencode-omo] vercel-ai-gateway: $VERCEL_AI_GATEWAY"
echo "[setup-opencode-omo] codex-autonomous: $CODEX_AUTONOMOUS"
echo "[setup-opencode-omo] skip-auth: $SKIP_AUTH"
echo ""

if [ "$DRY_RUN" -eq 1 ]; then
  echo "[setup-opencode-omo] DRY RUN - would execute:"
  echo "  bunx oh-my-openagent install --no-tui \\"
  echo "    --platform=$PLATFORM \\"
  [ "$CLAUDE" != "no" ] && echo "    --claude=$CLAUDE \\"
  [ "$OPENAI" = "yes" ] && echo "    --openai=yes \\"
  [ "$GEMINI" = "yes" ] && echo "    --gemini=yes \\"
  [ "$COPILOT" = "yes" ] && echo "    --copilot=yes \\"
  [ "$OPENCODE_ZEN" = "yes" ] && echo "    --opencode-zen=yes \\"
  [ "$ZAI_CODING_PLAN" = "yes" ] && echo "    --zai-coding-plan=yes \\"
  [ "$OPENCODE_GO" = "yes" ] && echo "    --opencode-go=yes \\"
  [ "$KIMI_FOR_CODING" = "yes" ] && echo "    --kimi-for-coding=yes \\"
  [ "$VERCEL_AI_GATEWAY" = "yes" ] && echo "    --vercel-ai-gateway=yes \\"
  [ "$CODEX_AUTONOMOUS" = "yes" ] && echo "    --codex-autonomous \\"
  [ "$CODEX_AUTONOMOUS" = "no" ] && echo "    --no-codex-autonomous \\"
  [ "$SKIP_AUTH" -eq 1 ] && echo "    --skip-auth \\"
  exit 0
fi

echo "[setup-opencode-omo] running installer..."

ARGS=(
  "oh-my-openagent" "install" "--no-tui"
  "--platform=$PLATFORM"
)

[ "$CLAUDE" != "no" ] && ARGS+=("--claude=$CLAUDE")
[ "$OPENAI" = "yes" ] && ARGS+=("--openai=yes")
[ "$GEMINI" = "yes" ] && ARGS+=("--gemini=yes")
[ "$COPILOT" = "yes" ] && ARGS+=("--copilot=yes")
[ "$OPENCODE_ZEN" = "yes" ] && ARGS+=("--opencode-zen=yes")
[ "$ZAI_CODING_PLAN" = "yes" ] && ARGS+=("--zai-coding-plan=yes")
[ "$OPENCODE_GO" = "yes" ] && ARGS+=("--opencode-go=yes")
[ "$KIMI_FOR_CODING" = "yes" ] && ARGS+=("--kimi-for-coding=yes")
[ "$VERCEL_AI_GATEWAY" = "yes" ] && ARGS+=("--vercel-ai-gateway=yes")
[ "$CODEX_AUTONOMOUS" = "yes" ] && ARGS+=("--codex-autonomous")
[ "$CODEX_AUTONOMOUS" = "no" ] && ARGS+=("--no-codex-autonomous")
[ "$SKIP_AUTH" -eq 1 ] && ARGS+=("--skip-auth")

bunx "${ARGS[@]}"

echo "[setup-opencode-omo] done. Verify with: bunx oh-my-openagent doctor"