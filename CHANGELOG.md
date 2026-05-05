# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.0] — 2026-05-05

### Added

- **Notification hook** (`hooks/notify-input.sh`) that fires when Claude Code is waiting on user input — permission prompts, `AskUserQuestion`, idle timeouts. Body reads "Needs your input", plays a system sound, and uses the same click-to-focus mechanism as the Stop hook. Instant fire (~40ms — no LLM call).
- Same `claude-stop` notification group so a fresh "needs input" displaces a stale "done" cleanly.
- Plugin manifest declares both `Stop` and `Notification` events.
- Installer + uninstaller handle both hooks idempotently.

### Changed

- README features list and "What you'll see" install message now describe both events.

## [0.1.0] — 2026-05-05

### Added

- Initial release.
- **Stop hook** (`hooks/notify-stop.sh`) fires after every Claude Code turn with a 3-to-4 word AI summary produced by `claude -p --model haiku --strict-mcp-config --no-session-persistence`. Falls back to first-N-words on LLM failure.
- **Click-to-focus** (`hooks/focus-terminal.sh`) — captures the Claude session's TTY at hook-fire time, then matches it via AppleScript on click. Targets the exact window/tab for **Apple Terminal** and **iTerm2**; other terminals fall back to whole-app activation.
- **Project-scoped title** — `Claude · <basename of cwd>`.
- **Claude-branded thumbnail** via `terminal-notifier -contentImage` (since `-appIcon` is silently dropped on macOS Tahoe).
- **Idempotent installer** (`install.sh`) — verifies macOS + jq + Claude CLI, brew-installs `terminal-notifier` if missing, copies hook scripts and icon into `~/.claude/hooks/`, and patches `~/.claude/settings.json` via `jq` (replaces any prior entry pointing at the same script).
- **Clean uninstall** (`uninstall.sh`) — surgical removal of just our entries; leaves `terminal-notifier` and any unrelated settings alone.
- **Two install paths** — Claude Code plugin marketplace and a manual `install.sh`.

[Unreleased]: https://github.com/pramirez140/claude-code-mac-notifications/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/pramirez140/claude-code-mac-notifications/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/pramirez140/claude-code-mac-notifications/releases/tag/v0.1.0
