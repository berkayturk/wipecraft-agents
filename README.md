# Wipecraft for Claude Code

A Claude Code plugin for [Wipecraft](https://wipecraft.app/), the Mac app that finds the session histories, worktrees,
VM images and caches that Claude Code, Codex, Cursor and Claude Desktop leave on disk.

The plugin calls the `wipecraft` command-line tool that ships inside the app. It does not scan or clean anything by
itself.

## Requirements

- Wipecraft 1.2 or later, on macOS 14 or later.
- The `wipecraft` command on your PATH. In Wipecraft, Settings > General > Command-line tool shows the one line that
  links it.
- Scanning is free. Cleaning needs a Wipecraft license.

## Install

Inside Claude Code:

```text
/plugin marketplace add berkayturk/wipecraft-claude-code
/plugin install wipecraft@wipecraft
```

## What it adds

- `/wipecraft:status` runs `wipecraft scan --json` and summarizes what can be freed. Scanning only reads.
- `/wipecraft:tidy` shows the dry run of `wipecraft clean --all-safe` first, and runs it with `--apply` only after you
  say yes in the chat. Items it cleans go to Quarantine and can be put back for 7 days.
- At session start, when more than 1 GB can be freed, one line with the total. The line comes from a summary saved at
  the last refresh, so a session never waits for a scan.
- At session end inside a linked worktree, one line with that worktree's state. Tidying it after the session is a
  switch in Wipecraft, Settings > Agents, off by default.
- The `wipecraft mcp` server, so Claude can read scan results through MCP. Cleaning through MCP is off until you turn
  it on in Settings > Agents.

## Privacy

Wipecraft sends nothing. The plugin passes results to Claude Code on your Mac: `/wipecraft:status` gives Claude the scan
output, including folder paths, and the session-start line gives it one line with sizes, so Claude's provider receives
what you see in that session. The session-start summary is cached in `~/Library/Caches/wipecraft/`. Details:
[wipecraft.app/privacy](https://wipecraft.app/privacy/).

## Support

support@blitzcortex.com

## License

MIT. See [LICENSE](LICENSE). Wipecraft itself is a paid app and is not covered by this license.
