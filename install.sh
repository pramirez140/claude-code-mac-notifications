#!/bin/bash
# claude-code-mac-notifications — installer
# Idempotent: safe to run multiple times.
#
# What this does:
#   1. Verifies macOS + jq + Claude Code CLI
#   2. Installs terminal-notifier via Homebrew if missing
#   3. Copies hook scripts and icon into ~/.claude/hooks/
#   4. Patches ~/.claude/settings.json to register the Stop hook
#
# Re-run after an update to refresh the scripts. Uninstall with ./uninstall.sh.

set -e

GREEN=$'\033[0;32m'
YELLOW=$'\033[0;33m'
RED=$'\033[0;31m'
RESET=$'\033[0m'

info()  { printf "%s==>%s %s\n" "$GREEN" "$RESET" "$*"; }
warn()  { printf "%s==>%s %s\n" "$YELLOW" "$RESET" "$*" >&2; }
error() { printf "%serror:%s %s\n" "$RED" "$RESET" "$*" >&2; exit 1; }

# 1. Platform & dependency checks
[ "$(uname -s)" = "Darwin" ] || error "macOS required (got $(uname -s))."

command -v jq >/dev/null 2>&1 || error "jq is required. Install via 'brew install jq'."

if ! command -v claude >/dev/null 2>&1; then
  warn "Claude Code CLI not on PATH — the LLM-summary path will fall back to first-N-words."
fi

# 2. terminal-notifier
if ! command -v terminal-notifier >/dev/null 2>&1; then
  if command -v brew >/dev/null 2>&1; then
    info "Installing terminal-notifier via Homebrew..."
    brew install terminal-notifier
  else
    error "Homebrew not found. Install from https://brew.sh, then re-run."
  fi
else
  info "terminal-notifier already installed."
fi

# 3. Copy hooks and icon
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOKS_DIR="$HOME/.claude/hooks"

mkdir -p "$HOOKS_DIR"

info "Copying scripts to $HOOKS_DIR/"
cp "$SCRIPT_DIR/hooks/notify-stop.sh"    "$HOOKS_DIR/notify-stop.sh"
cp "$SCRIPT_DIR/hooks/notify-input.sh"   "$HOOKS_DIR/notify-input.sh"
cp "$SCRIPT_DIR/hooks/focus-terminal.sh" "$HOOKS_DIR/focus-terminal.sh"
chmod +x "$HOOKS_DIR/notify-stop.sh" "$HOOKS_DIR/notify-input.sh" "$HOOKS_DIR/focus-terminal.sh"

info "Copying icon to $HOOKS_DIR/claude-icon.png"
cp "$SCRIPT_DIR/assets/claude-icon.png" "$HOOKS_DIR/claude-icon.png"

# 4. Patch ~/.claude/settings.json
SETTINGS="$HOME/.claude/settings.json"
mkdir -p "$(dirname "$SETTINGS")"
[ -f "$SETTINGS" ] || echo '{}' > "$SETTINGS"

info "Patching $SETTINGS"

STOP_HOOK=$(cat <<JSON
{
  "type": "command",
  "command": "bash \"$HOOKS_DIR/notify-stop.sh\"",
  "async": true,
  "timeout": 60
}
JSON
)

INPUT_HOOK=$(cat <<JSON
{
  "type": "command",
  "command": "bash \"$HOOKS_DIR/notify-input.sh\"",
  "async": true,
  "timeout": 10
}
JSON
)

# jq merge: replace any prior entries pointing at our scripts; append fresh ones.
TMP=$(mktemp)
jq --argjson stop "$STOP_HOOK" --argjson input "$INPUT_HOOK" '
  .hooks = (.hooks // {}) |
  # Stop hook
  .hooks.Stop = (
    [ (.hooks.Stop // [])[] |
      select((.hooks // []) | any(.command? | tostring | contains("notify-stop.sh")) | not)
    ]
    + [ { hooks: [ $stop ] } ]
  ) |
  # Notification hook
  .hooks.Notification = (
    [ (.hooks.Notification // [])[] |
      select((.hooks // []) | any(.command? | tostring | contains("notify-input.sh")) | not)
    ]
    + [ { hooks: [ $input ] } ]
  )
' "$SETTINGS" > "$TMP"

# Sanity-check resulting JSON before clobbering original
if jq -e . "$TMP" >/dev/null 2>&1; then
  mv "$TMP" "$SETTINGS"
else
  rm -f "$TMP"
  error "Refused to write — produced JSON is invalid. Original $SETTINGS unchanged."
fi

cat <<DONE

${GREEN}Installed.${RESET}

Restart Claude Code (or open '/hooks' once) so the new hooks are picked up.

What you'll see:
  - On every Claude turn end → "Claude · <project>" with a 3-4 word AI summary
  - On every input prompt    → "Claude · <project>" / "Needs your input" + sound
  - Click either → jumps back to the exact terminal window/tab Claude was in

Files:
  stop hook     $HOOKS_DIR/notify-stop.sh
  input hook    $HOOKS_DIR/notify-input.sh
  focus helper  $HOOKS_DIR/focus-terminal.sh
  icon          $HOOKS_DIR/claude-icon.png
  logs          $HOOKS_DIR/notify-stop.log
                $HOOKS_DIR/notify-input.log
  settings      $SETTINGS

Uninstall: ./uninstall.sh

DONE
