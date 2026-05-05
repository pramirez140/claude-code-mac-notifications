#!/bin/bash
# claude-code-mac-notifications — uninstaller
# Removes the Stop hook from ~/.claude/settings.json and deletes the
# scripts/icon from ~/.claude/hooks/. Leaves terminal-notifier installed
# (you may have other tools that depend on it).

set -e

GREEN=$'\033[0;32m'
YELLOW=$'\033[0;33m'
RESET=$'\033[0m'

info()  { printf "%s==>%s %s\n" "$GREEN" "$RESET" "$*"; }
warn()  { printf "%s==>%s %s\n" "$YELLOW" "$RESET" "$*" >&2; }

HOOKS_DIR="$HOME/.claude/hooks"
SETTINGS="$HOME/.claude/settings.json"

if [ -f "$SETTINGS" ]; then
  info "Removing Stop and Notification hook entries from $SETTINGS"
  TMP=$(mktemp)
  jq '
    if .hooks.Stop then
      .hooks.Stop = [
        .hooks.Stop[] |
        select((.hooks // []) | any(.command? | tostring | contains("notify-stop.sh")) | not)
      ]
      | if (.hooks.Stop | length) == 0 then del(.hooks.Stop) else . end
    else . end
    |
    if .hooks.Notification then
      .hooks.Notification = [
        .hooks.Notification[] |
        select((.hooks // []) | any(.command? | tostring | contains("notify-input.sh")) | not)
      ]
      | if (.hooks.Notification | length) == 0 then del(.hooks.Notification) else . end
    else . end
  ' "$SETTINGS" > "$TMP" && mv "$TMP" "$SETTINGS"
fi

for f in notify-stop.sh notify-input.sh focus-terminal.sh claude-icon.png notify-stop.log notify-input.log; do
  if [ -e "$HOOKS_DIR/$f" ]; then
    info "Removing $HOOKS_DIR/$f"
    rm -f "$HOOKS_DIR/$f"
  fi
done

cat <<DONE

${GREEN}Uninstalled.${RESET}

terminal-notifier was left in place (other tools may use it).
To remove it explicitly: brew uninstall terminal-notifier

DONE
