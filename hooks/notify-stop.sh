#!/bin/bash
# claude-code-mac-notifications — Stop hook
# Fires a native macOS notification with a 3-4 word AI summary of what
# Claude just did. Click → activates the originating terminal window/tab.
# Logs to ~/.claude/hooks/notify-stop.log.

set -u

# Resolve our companion paths in either context: plugin or manual install.
if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && [ -d "$CLAUDE_PLUGIN_ROOT" ]; then
  PLUGIN_ROOT="$CLAUDE_PLUGIN_ROOT"
else
  PLUGIN_ROOT="$HOME/.claude/hooks"
fi

ICON="$PLUGIN_ROOT/assets/claude-icon.png"
[ -r "$ICON" ] || ICON="$HOME/.claude/hooks/claude-icon.png"

FOCUS="$PLUGIN_ROOT/hooks/focus-terminal.sh"
[ -x "$FOCUS" ] || FOCUS="$HOME/.claude/hooks/focus-terminal.sh"

LOG_DIR="$HOME/.claude/hooks"
mkdir -p "$LOG_DIR"
LOG="$LOG_DIR/notify-stop.log"
exec 2>>"$LOG"

INPUT=$(cat)

TRANSCRIPT_PATH=$(printf '%s' "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null)
CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)

if [ -z "$TRANSCRIPT_PATH" ] || [ ! -r "$TRANSCRIPT_PATH" ]; then
  exit 0
fi

# Extract the last assistant message that contains a text block. The transcript
# is JSONL — one event per line. Some entries are tool_use, others contain text.
# We normalize newlines inside jq so an embedded \n in the message can't make
# tail -1 pick a fragment instead of the whole text.
LAST_MSG=$(grep '"role":"assistant"' "$TRANSCRIPT_PATH" \
  | jq -rc '
      select(.message?.content // .content // [] | type == "array")
      | select(any((.message.content // .content)[]?; .type == "text"))
      | [ (.message.content // .content)[] | select(.type == "text") | .text ]
      | join(" ")
      | gsub("[\\n\\r\\t]+"; " ")
    ' 2>/dev/null \
  | tail -1 \
  | sed 's/  */ /g' \
  | head -c 1500)

if [ -z "$LAST_MSG" ]; then
  SUMMARY="Done"
else
  TMPFILE=$(mktemp -t claude-summary.XXXXX)
  trap 'rm -f "$TMPFILE"' EXIT

  cat > "$TMPFILE" <<'PROMPT'
You will receive the last message from a coding assistant. Reply with a 3-to-4 word summary of what was just done. Action phrase only — no period, no quotes, no preamble, no emoji. Title-Case the words.

Examples:
- Fixed Login Bug
- Refactored Auth Module
- Added Stop Hook
- Explored Repo Structure

Message:
PROMPT
  printf '%s' "$LAST_MSG" >> "$TMPFILE"

  SUMMARY=""
  if command -v claude >/dev/null 2>&1; then
    # --strict-mcp-config skips MCP server loading (~3s saved on startup)
    # --no-session-persistence avoids polluting ~/.claude/projects/ with one-shot summary transcripts
    # perl alarm gives us a portable timeout without coreutils
    SUMMARY=$(perl -e 'alarm 45; exec @ARGV' \
        claude -p --model haiku --strict-mcp-config --no-session-persistence \
        < "$TMPFILE" 2>/dev/null \
      | tr -d '\r' \
      | grep -v '^[[:space:]]*$' \
      | head -1 \
      | sed -E 's/^[[:space:]]+|[[:space:]]+$//g; s/^["'"'"'`]+//; s/["'"'"'`]+$//; s/[.!?]+$//' \
      | head -c 60)
  fi

  if [ -z "$SUMMARY" ]; then
    SUMMARY=$(printf '%s' "$LAST_MSG" \
      | awk '{ for (i=1;i<=NF && i<=4;i++) printf "%s ", $i; print "" }' \
      | sed -E 's/[[:space:]]+$//' \
      | head -c 60)
    [ -z "$SUMMARY" ] && SUMMARY="Task Complete"
  fi
fi

# Pick the launching terminal's bundle ID. Used as a fallback if AppleScript
# can't locate the originating window/tab (e.g. user closed it).
TERM_PROGRAM_LC=$(printf '%s' "${TERM_PROGRAM:-}" | tr '[:upper:]' '[:lower:]')
case "$TERM_PROGRAM_LC" in
  apple_terminal)    TERM_BUNDLE="com.apple.Terminal" ;;
  iterm.app)         TERM_BUNDLE="com.googlecode.iterm2" ;;
  ghostty)           TERM_BUNDLE="com.mitchellh.ghostty" ;;
  wezterm)           TERM_BUNDLE="com.github.wez.wezterm" ;;
  vscode)            TERM_BUNDLE="com.microsoft.VSCode" ;;
  cursor)            TERM_BUNDLE="com.todesktop.230313mzl4w4u92" ;;
  hyper)             TERM_BUNDLE="co.zeit.hyper" ;;
  alacritty)         TERM_BUNDLE="org.alacritty" ;;
  warpterminal|warp) TERM_BUNDLE="dev.warp.Warp-Stable" ;;
  kitty)             TERM_BUNDLE="net.kovidgoyal.kitty" ;;
  tabby)             TERM_BUNDLE="org.tabby" ;;
  *)                 TERM_BUNDLE="com.apple.Terminal" ;;
esac

PROJECT_NAME=$(basename "${CWD:-claude}")
{ [ "$PROJECT_NAME" = "/" ] || [ -z "$PROJECT_NAME" ]; } && PROJECT_NAME="claude"

NOTIFIER=$(command -v terminal-notifier || true)
if [ -z "$NOTIFIER" ]; then
  for p in /opt/homebrew/bin/terminal-notifier /usr/local/bin/terminal-notifier; do
    [ -x "$p" ] && NOTIFIER="$p" && break
  done
fi
if [ -z "$NOTIFIER" ]; then
  echo "$(date) terminal-notifier not found — run install.sh or 'brew install terminal-notifier'" >&2
  exit 0
fi

# Walk the process ancestry to find the first ancestor with a real TTY.
# Normally that's Claude Code (the hook's PPID); some wrappers add a layer.
PARENT_TTY=""
P=$PPID
for _ in 1 2 3 4 5 6 7 8; do
  { [ -z "$P" ] || [ "$P" = "0" ] || [ "$P" = "1" ]; } && break
  T=$(ps -p "$P" -o tty= 2>/dev/null | tr -d ' ')
  case "$T" in
    "" | "?" | "??")
      P=$(ps -p "$P" -o ppid= 2>/dev/null | tr -d ' ')
      ;;
    *)
      PARENT_TTY="/dev/$T"
      break
      ;;
  esac
done

# Detach: terminal-notifier blocks ~37s waiting on the macOS notification.
# Fixed group dedupes — newer notifications displace older ones.
# We post under terminal-notifier's own bundle (it already has notification
# permission). The Claude logo shows as the right-hand thumbnail via
# -contentImage. -appIcon is ignored on macOS Tahoe so we skip it.
nohup "$NOTIFIER" \
  -title "Claude · $PROJECT_NAME" \
  -message "$SUMMARY" \
  -contentImage "$ICON" \
  -execute "bash '$FOCUS' '$PARENT_TTY' '${TERM_PROGRAM:-}' '$TERM_BUNDLE'" \
  -group "claude-stop" \
  </dev/null >/dev/null 2>&1 &
disown

echo "$(date) fired: title='Claude · $PROJECT_NAME' msg='$SUMMARY' term='${TERM_PROGRAM:-?}' tty='$PARENT_TTY'" >&2
exit 0
