#!/bin/bash
# claude-code-mac-notifications — Notification hook
# Fires when Claude is waiting on user input (permission prompt, AskUserQuestion).
# No LLM summary needed — just a fixed "Needs your input" banner with a sound.
# Click → activates the originating terminal window/tab (same focus-terminal.sh
# mechanism as the Stop hook). Logs to ~/.claude/hooks/notify-input.log.

set -u

# Resolve companion paths in either context: plugin or manual install.
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
LOG="$LOG_DIR/notify-input.log"
exec 2>>"$LOG"

INPUT=$(cat)

CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)

PROJECT_NAME=$(basename "${CWD:-claude}")
{ [ "$PROJECT_NAME" = "/" ] || [ -z "$PROJECT_NAME" ]; } && PROJECT_NAME="claude"

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

NOTIFIER=$(command -v terminal-notifier || true)
if [ -z "$NOTIFIER" ]; then
  for p in /opt/homebrew/bin/terminal-notifier /usr/local/bin/terminal-notifier; do
    [ -x "$p" ] && NOTIFIER="$p" && break
  done
fi
if [ -z "$NOTIFIER" ]; then
  echo "$(date) terminal-notifier not found" >&2
  exit 0
fi

# Walk the ancestry to find a real TTY (same as notify-stop.sh).
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

# Same group as notify-stop so a fresh "needs input" displaces a stale "done"
# (and vice versa). -sound makes this one slightly more attention-grabbing
# than the Stop banner, since it's a call-to-action.
nohup "$NOTIFIER" \
  -title "Claude · $PROJECT_NAME" \
  -message "Needs your input" \
  -contentImage "$ICON" \
  -execute "bash '$FOCUS' '$PARENT_TTY' '${TERM_PROGRAM:-}' '$TERM_BUNDLE'" \
  -group "claude-stop" \
  -sound "default" \
  </dev/null >/dev/null 2>&1 &
disown

echo "$(date) input fired: project='$PROJECT_NAME' tty='$PARENT_TTY'" >&2
exit 0
