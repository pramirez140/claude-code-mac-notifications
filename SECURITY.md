# Security Policy

## Supported versions

This project follows [Semantic Versioning](https://semver.org/). Only the latest minor release on `main` is supported with security fixes.

| Version | Supported          |
|---------|--------------------|
| 0.2.x   | :white_check_mark: |
| < 0.2   | :x:                |

## Reporting a vulnerability

**Please do not open a public GitHub issue for security problems.**

Instead, use GitHub's private vulnerability reporting:

> **Repository → Security → Report a vulnerability**
> ([direct link](https://github.com/pramirez140/claude-code-mac-notifications/security/advisories/new))

Include:

- A description of the issue and its impact
- Reproduction steps
- macOS version, terminal, Claude Code version
- Whether you installed via `install.sh` or the plugin marketplace

I'll acknowledge within **5 business days** and aim to ship a fix within **30 days** for confirmed issues.

## Threat model — what this project actually does

To help you assess risk, here's the surface area:

### What runs on your machine

- **Two bash scripts as Claude Code hooks** (`notify-stop.sh`, `notify-input.sh`). They read JSON on stdin (provided by Claude Code), parse the transcript path, and shell out to `jq`, `claude`, `osascript`, and `terminal-notifier`.
- **One AppleScript helper** (`focus-terminal.sh`) invoked at notification *click* time via `terminal-notifier -execute`. It uses AppleScript to focus a Terminal/iTerm window matching the captured TTY.

### What could go wrong

- **Transcript content is treated as text, not code.** The summary path passes the assistant's last message as stdin to `claude -p` — never `eval`'d.
- **The TTY captured at hook-fire time** is passed as a command-line argument to `focus-terminal.sh` via `-execute`. This is escaped with single quotes in the parent shell. TTY paths come from `ps -p <ancestor> -o tty=` and look like `ttys012` — safe characters.
- **No network calls** other than what `claude -p --model haiku` does (which is the same network surface as your normal Claude Code usage).
- **The installer patches `~/.claude/settings.json` via `jq`.** It validates the resulting JSON before clobbering the original. If validation fails, the original is preserved.

### What this project does NOT do

- Read or transmit secrets from the transcript.
- Persist message content beyond what `claude -p` already does (and `--no-session-persistence` skips that).
- Modify any file outside `~/.claude/hooks/` and `~/.claude/settings.json`.

If you find something that contradicts the above, please report it through the channel at the top of this file.
