<!--
Thanks for the PR! A few quick boxes to check before review.
-->

## Summary

<!-- 1-3 sentences. What does this change, and why? -->

## Type of change

- [ ] Bug fix (non-breaking)
- [ ] New feature (non-breaking)
- [ ] Breaking change
- [ ] Docs / chore only

## Test plan

<!-- How did you verify this? Paste log lines, screenshots/GIFs of notifications, the command you ran. -->

- [ ] Ran `./install.sh` locally and triggered a Stop event — banner fires
- [ ] Ran `./install.sh` locally and triggered a Notification event (e.g. `AskUserQuestion` in a real Claude session) — banner fires with sound
- [ ] Click on the notification activates the right window/tab
- [ ] `bash -n` clean on all changed scripts
- [ ] `jq -e .` clean on all changed JSON
- [ ] If a new terminal was added: tested on the actual terminal, not just the lookup table

## Screenshots / GIFs

<!-- Optional but appreciated for UX changes. -->

## Related issues

<!-- e.g. Closes #12, Refs #34 -->
