# Wipecraft for coding agents

Plugins for [Wipecraft](https://wipecraft.app/), the Mac app that finds the session histories, worktrees, VM images and
caches that Claude Code, Codex, Cursor and Claude Desktop leave on disk. This repository has one native plugin for each
of these agents:

| Agent | Folder | Install with |
| --- | --- | --- |
| Claude Code | [`plugins/claude-code`](plugins/claude-code) | `/plugin marketplace add` |
| Codex | [`plugins/codex`](plugins/codex) | `codex plugin marketplace add` |
| Cursor | [`plugins/cursor`](plugins/cursor) | a local plugin folder |
| Antigravity | [`plugins/antigravity`](plugins/antigravity) | `agy plugin install` |

Every plugin calls the `wipecraft` command-line tool that ships inside the app. No plugin scans or cleans anything by
itself, and none sends anything over the network.

## Requirements

- Wipecraft 1.2 or later, on macOS 14 or later.
- The `wipecraft` command on your PATH. In Wipecraft, Settings > General > Command-line tool shows the one line that
  links it to `/usr/local/bin/wipecraft`. Check it in Terminal:

  ```sh
  wipecraft --version
  ```

- Scanning is free. Cleaning needs a Wipecraft license.
- The session-end hooks (Claude Code, Codex, Cursor) also need `jq` or `python3`. macOS has `python3` once the
  Command Line Tools are installed.

## What each plugin adds

| | Claude Code | Codex | Cursor | Antigravity |
| --- | --- | --- | --- | --- |
| Status: what can be freed (reads only) | `/wipecraft:status` | `$wipecraft-status` | `/wipecraft-status` | `/wipecraft-status` |
| Tidy: dry run first, `--apply` after your yes | `/wipecraft:tidy` | `$wipecraft-tidy` | `/wipecraft-tidy` | `/wipecraft-tidy` |
| Session start: one line above 1 GB | yes | yes | yes | no |
| Session end: state of the linked worktree | yes | yes | yes | no |
| `wipecraft mcp` server | yes | yes | yes | yes |

- **Status** runs `wipecraft scan --json` and summarizes the total, the three largest sources and any locked items.
  Nothing is changed.
- **Tidy** runs `wipecraft clean --all-safe` first, which only shows what would be cleaned. It runs the same command
  with `--apply` only after you confirm in the chat. Items it cleans go to Quarantine and can be put back for 7 days
  (`wipecraft quarantine list`, `wipecraft quarantine restore <id>`). In Codex and Cursor the agent never picks Tidy on
  its own; you call it by name. In Claude Code it runs only when you type the command. In every agent, `--apply`
  waits for your yes in the chat.
- **Session start** adds one line with the total, taken from a summary saved at the last refresh. A session never
  waits for a scan. The first session after install is silent while the summary is built.
- **Session end** checks whether the session ran inside a linked git worktree and reports its state. Tidying that
  worktree after the session is a switch in Wipecraft, Settings > Agents, off by default.
- **MCP** lets the agent read scan results through the tools `scan_summary`, `list_items`, `explain_item`,
  `quarantine_status` and `clean_items`. `clean_items` with `apply: true` is refused until you turn on "Allow agents
  to clean through MCP" in Settings > Agents.

Antigravity has no session-end event, so its plugin has the two skills and the MCP server, and no hooks.

## Claude Code

Inside Claude Code:

```text
/plugin marketplace add berkayturk/wipecraft-agents
/plugin install wipecraft@wipecraft
```

Start a new session, or run `/reload-plugins`. `/plugin` lists Wipecraft under Installed, and `/mcp` lists the
`wipecraft` server.

Use it:

```text
/wipecraft:status
/wipecraft:tidy
```

Update: `/plugin marketplace update wipecraft`. Remove: `/plugin uninstall wipecraft@wipecraft`, then
`/plugin marketplace remove wipecraft`.

MCP only, without the plugin:

```sh
claude mcp add wipecraft -- wipecraft mcp
```

## Codex

In Terminal:

```sh
codex plugin marketplace add berkayturk/wipecraft-agents
codex plugin add wipecraft@wipecraft
```

Start a new session after installing.

1. **Trust the hooks.** Codex does not run plugin hooks until you review them. In a session, run `/hooks`, review the
   two Wipecraft entries (SessionStart and SessionEnd) and trust them. Without this step the skills and the MCP server
   still work; only the session lines are missing. OpenAI documents plugin hooks for the Codex desktop app first, so
   the CLI may need a newer Codex for them.
2. **Use the skills.** Type `$wipecraft-status` or `$wipecraft-tidy`. Codex may also use Status when you ask how much
   space can be freed. It never picks Tidy on its own.
3. **Sandbox.** Wipecraft reads folders outside your project, such as `~/.claude` and `~/.codex`. If the sandbox
   blocks the command, Codex asks you to approve running it outside the sandbox. Approve the scan. Approve
   `wipecraft clean --all-safe --apply` only when you mean to clean, and do not add it to an always-allow rule.

Update: `codex plugin marketplace upgrade wipecraft`. Remove: `codex plugin remove wipecraft@wipecraft`, then
`codex plugin marketplace remove wipecraft`.

MCP only, without the plugin:

```sh
codex mcp add wipecraft -- wipecraft mcp
```

or in `~/.codex/config.toml`:

```toml
[mcp_servers.wipecraft]
command = "wipecraft"
args = ["mcp"]
```

## Cursor

Cursor loads local plugins from `~/.cursor/plugins/local/`. In Terminal:

```sh
git clone https://github.com/berkayturk/wipecraft-agents.git ~/wipecraft-agents
mkdir -p ~/.cursor/plugins/local
ln -s ~/wipecraft-agents/plugins/cursor ~/.cursor/plugins/local/wipecraft
```

Then run "Developer: Reload Window" from the Command Palette. Cursor picks up the plugin's skills, hooks and the
`wipecraft` MCP server. If the MCP server shows as off, turn it on in Cursor Settings > MCP.

Use it in the Agent chat:

```text
/wipecraft-status
/wipecraft-tidy
```

- The agent may also use Status when you ask about disk space. Tidy runs only when you call it.
- The session-start line reaches the agent as context. The session-end hook runs in the background, and Cursor does
  not show its output.
- The Cursor CLI can load the same folder for one run:
  `cursor-agent --plugin-dir ~/wipecraft-agents/plugins/cursor`.
- Team admins can import this repository as a team marketplace; it has a `.cursor-plugin/marketplace.json`.

Update: `git -C ~/wipecraft-agents pull`, then reload the window. Remove: `rm ~/.cursor/plugins/local/wipecraft`,
then reload the window.

MCP only, without the plugin: open this link in your browser,

```text
cursor://anysphere.cursor-deeplink/mcp/install?name=wipecraft&config=eyJjb21tYW5kIjoid2lwZWNyYWZ0IiwiYXJncyI6WyJtY3AiXX0%3D
```

or add this to `~/.cursor/mcp.json`:

```json
{
  "mcpServers": {
    "wipecraft": {
      "command": "wipecraft",
      "args": ["mcp"]
    }
  }
}
```

## Antigravity

With the `agy` command, in Terminal:

```sh
git clone https://github.com/berkayturk/wipecraft-agents.git ~/wipecraft-agents
agy plugin install ~/wipecraft-agents/plugins/antigravity
agy plugin list
```

The install checks that `wipecraft` is on your PATH before it adds the MCP server. Start a new conversation after
installing.

Use it:

```text
/wipecraft-status
/wipecraft-tidy
```

Antigravity asks before it runs a terminal command you have not allowed. Keep `wipecraft clean --all-safe --apply` out
of any allow list, so every clean waits for your yes.

Update: `git -C ~/wipecraft-agents pull`, then `agy plugin uninstall wipecraft` and install again. Remove:
`agy plugin uninstall wipecraft`.

MCP only, without the plugin: add the server to `~/.gemini/config/mcp_config.json`:

```json
{
  "mcpServers": {
    "wipecraft": {
      "command": "wipecraft",
      "args": ["mcp"]
    }
  }
}
```

## Other MCP clients

Any client that starts stdio MCP servers can run `wipecraft mcp`. The server opens no port; it speaks over stdin and
stdout only.

## Troubleshooting

- **"wipecraft: command not found", or the MCP server does not start.** Link the command in Wipecraft, Settings >
  General > Command-line tool, then restart the agent. If the agent still cannot find it, use the full path
  `/usr/local/bin/wipecraft` as the MCP `command`.
- **No session-start line.** It appears only when more than 1 GB can be freed, and not in the first session after
  install. In Codex, check that the hooks are trusted in `/hooks`.
- **Cleaning says a license is needed.** Activate Wipecraft in the app once. The command-line tool reads the same
  license.
- **The agent asks to run outside its sandbox.** Wipecraft reads folders outside the project, so a scan needs this.
  Approve cleaning only when you mean it.

## Privacy

Wipecraft sends nothing. The plugins pass results to your agent on your Mac: Status gives the agent the scan output,
including folder paths, and the session-start line gives it one line with sizes. The agent's model provider receives
what you see in that session. The session-start summary is cached in `~/Library/Caches/wipecraft/`. Details:
[wipecraft.app/privacy](https://wipecraft.app/privacy/).

## Support

support@blitzcortex.com

## License

MIT. See [LICENSE](LICENSE). Wipecraft itself is a paid app and is not covered by this license.
