---
description: Summarize what can be freed on this Mac
allowed-tools: Bash(wipecraft scan --json)
---

Run `wipecraft scan --json` and summarize the result for the user. Scanning only reads; nothing is changed.

- Start with the total in `reclaimableBytes`, as one line with the size in GB.
- Then list the three sources with the most reclaimable space, with their sizes.
- Say how many items are locked and why, using `lockReason`.
- If `partial` is true, say the totals can be low.
- Use plain numbers and no adjectives. Do not suggest cleaning anything on your own.

If the command is not found, say that the `wipecraft` command-line tool is not on PATH and stop.
