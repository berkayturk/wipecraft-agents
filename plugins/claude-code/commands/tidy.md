---
description: Show what wipecraft would clean, then clean it after you confirm
allowed-tools: Bash(wipecraft clean --all-safe)
disable-model-invocation: true
---

Tidy up in two steps. Never skip the first one.

1. Dry run. Run `wipecraft clean --all-safe` with no other flag. It only shows what would be done and changes nothing.
   Show the user its output as it is: the items, their sizes and the total.
2. Ask the user whether to go ahead. Run `wipecraft clean --all-safe --apply` only after an explicit yes in the chat.
   If the answer is anything else, stop and change nothing.

After applying, report the output of the command: how many items were cleaned and how much space it freed.
Say that cleaned items sit in quarantine and can be put back with `wipecraft quarantine list` and `wipecraft quarantine restore <id>`.

If the command is not found, say that the `wipecraft` command-line tool is not on PATH and stop.
If it says cleaning needs a license, repeat that message and stop.
