#!/bin/bash
# Activate the specific terminal window/tab where Claude Code was running.
# Args:
#   $1 = TTY device path (e.g. /dev/ttys012)
#   $2 = TERM_PROGRAM (e.g. Apple_Terminal, iTerm.app, ghostty)
#   $3 = fallback bundle ID (e.g. com.apple.Terminal)
# Apple Terminal & iTerm2 expose per-tab TTY via AppleScript so we can target
# the exact session. Other terminals fall back to whole-app activation.

TTY_PATH="$1"
TERM_PROG="$2"
FALLBACK_BUNDLE="$3"

case "$TERM_PROG" in
  Apple_Terminal)
    osascript <<APPLESCRIPT 2>/dev/null
      tell application "Terminal"
        activate
        try
          repeat with w in (every window)
            repeat with t in (every tab of w)
              try
                if tty of t is "$TTY_PATH" then
                  set selected of t to true
                  set frontmost of w to true
                  return "ok"
                end if
              end try
            end repeat
          end repeat
        end try
      end tell
APPLESCRIPT
    ;;

  iTerm.app)
    osascript <<APPLESCRIPT 2>/dev/null
      tell application "iTerm"
        activate
        try
          repeat with w in windows
            repeat with t in tabs of w
              repeat with s in sessions of t
                try
                  if tty of s is "$TTY_PATH" then
                    tell w to select
                    tell t to select
                    return "ok"
                  end if
                end try
              end repeat
            end repeat
          end repeat
        end try
      end tell
APPLESCRIPT
    ;;

  *)
    # Ghostty / WezTerm / VSCode / Cursor / Hyper / Alacritty / Warp / Kitty / Tabby
    # AppleScript window-targeting support is uneven; fall back to activating the app.
    if [ -n "$FALLBACK_BUNDLE" ]; then
      osascript -e "tell application id \"$FALLBACK_BUNDLE\" to activate" 2>/dev/null
    fi
    ;;
esac
