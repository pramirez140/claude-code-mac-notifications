# Contributing

Thanks for considering a contribution. This project is small and pragmatic — we'd love help making it more robust, especially around terminal compatibility.

## Quick start

```bash
git clone https://github.com/pramirez140/claude-code-mac-notifications.git
cd claude-code-mac-notifications
./install.sh                  # local install for testing
```

After making changes, re-run `./install.sh` to refresh your local install (it's idempotent), then trigger a Claude Code Stop or Notification event to see the result.

Tail the logs while iterating:

```bash
tail -f ~/.claude/hooks/notify-stop.log ~/.claude/hooks/notify-input.log
```

## How to test changes manually

Synthesize a Stop event and pipe it to the hook:

```bash
TRANSCRIPT=$(ls -t ~/.claude/projects/*/*.jsonl | head -1)
PAYLOAD="{\"session_id\":\"test\",\"transcript_path\":\"$TRANSCRIPT\",\"cwd\":\"$HOME\",\"hook_event_name\":\"Stop\"}"
printf '%s' "$PAYLOAD" | bash hooks/notify-stop.sh
```

For the Notification hook (no transcript needed):

```bash
echo '{"cwd":"'$HOME'","hook_event_name":"Notification"}' | bash hooks/notify-input.sh
```

## Style

- **Bash, no externalisms beyond `jq`, `perl`, `osascript`, and `terminal-notifier`.** All of those exist on stock macOS or are installed by `install.sh`. Don't introduce new dependencies without a strong reason.
- **`set -u`** at the top of every script.
- **Keep scripts under ~150 lines.** If you need more, split or factor out — don't grow a god-script.
- **Comment the *why*, not the *what*.** Good comments explain a non-obvious constraint (e.g. *"`-appIcon` is silently dropped on macOS Tahoe; use `-contentImage` instead"*); bad comments narrate the code.
- **One commit per logical change.** Squash WIP commits before opening a PR.

## Adding support for a new terminal

We want to support more terminals via TTY-based per-window targeting. Two paths:

1. **AppleScript-supporting terminal** — extend `hooks/focus-terminal.sh` with a new `case "$TERM_PROG" in` arm. Mirror the Apple Terminal block: loop windows/tabs/sessions, match `tty`, set selected/frontmost.
2. **No AppleScript / opaque terminal** — fall through to the default arm, which activates the bundle. Add the bundle ID to the lookup table in `hooks/notify-stop.sh` and `hooks/notify-input.sh`.

Either way:
- Test that `tty` is exposed at the right level in the AppleScript dictionary (use Script Editor's Library to check).
- Handle the case where the original window/tab has been closed by the time the user clicks — fall back to app activation.

PRs that just add a new bundle ID to the lookup tables are welcome.

## What we won't merge

- Replacing `claude -p --model haiku` with a different summary backend by default. Custom prompts are great as a config knob, but the default should keep working out of the box on a fresh Claude Code install with no extra setup.
- Anything that requires Claude.app to be authorized for notifications. We deliberately route under `terminal-notifier`'s own bundle for portability.
- Force-replacing the user's existing Stop or Notification hooks with no opt-out. The installer's `jq` merge only touches entries pointing at our specific scripts.

## Reporting a bug

Open an issue using the [Bug report template](https://github.com/pramirez140/claude-code-mac-notifications/issues/new?template=bug_report.yml). Please include:

- macOS version (`sw_vers`)
- Terminal app + version
- Output of `tail -50 ~/.claude/hooks/notify-stop.log` and `notify-input.log`
- Whether you installed via `install.sh` or the plugin marketplace

## Reporting a security issue

Don't open a public issue — see [SECURITY.md](SECURITY.md).

## License

By contributing, you agree your contributions will be licensed under the [MIT License](LICENSE).
