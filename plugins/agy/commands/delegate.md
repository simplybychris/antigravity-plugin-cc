---
description: Delegate a task to the Antigravity (`agy`) runner subagent; supports background execution and model selection
argument-hint: "[--background] [--model <alias>] <task description>"
allowed-tools: Agent, AskUserQuestion
---

Hand the user's task to the `agy:runner` subagent
(`subagent_type: "agy:runner"`).

Raw user request:
$ARGUMENTS

## Routing rules

- If the request contains `--background`, launch the subagent with
  `run_in_background: true`. Strip the flag from the forwarded task text.
- Otherwise run the subagent in the foreground.
- If the request contains `--model <alias>`, forward it to the subagent so
  it can be appended to the wrapper call as `--model <alias>` (placed
  **before** the prompt argument). Strip it from the task text.
- If no model is given, the wrapper uses whatever the TUI is currently set
  to (stored in `~/.gemini/antigravity-cli/settings.json`).

Aliases for `<alias>`: `flash-low`, `flash-medium`, `flash`, `pro-low`,
`pro`, `sonnet`, `opus`, `gpt-oss`. Canonical TUI strings (e.g.
`"Claude Opus 4.6 (Thinking)"`) are also accepted. Run `/agy:help` for the
full table.

## Permission requests from agy

`agy` runs headless with `--mode accept-edits`: edits inside the workspace go
through, but anything it would normally ask about (shell commands, writes
outside the workspace) is denied and relayed back. The wrapper then exits
with code **75** and ends its output with:

```
[agy-permission-request]
conversation_id: <id>
command: <exact command agy wanted to run>
other: <non-command tool and target, if any>
[/agy-permission-request]
```

When you see that block, do **not** approve anything yourself. Show the user
any response text above the block, then use `AskUserQuestion` with one
question per `command:` line (at most 4; batch the rest in a follow-up),
quoting the exact command, with these options:

- `Allow once` — run it this time only.
- `Always allow` — add a permanent exact-match rule to agy's settings.
- `Deny` — do not run it.

Then resume the same conversation through the `agy:runner` subagent again
(keep the same `--model` if one was used). Tell it to put these wrapper flags
before the prompt, so it runs:

```
bash "${CLAUDE_PLUGIN_ROOT}/scripts/agy-run.sh" ask [--model <alias>] --resume <conversation_id> \
  [--allow-once "<cmd>"]... [--allow-always "<cmd>"]... \
  "The user approved: <cmds>. The user denied: <cmds> (do not run or work around those). Continue the task."
```

Repeat until the output has no `[agy-permission-request]` block. `other:`
lines can't be granted from here: tell the user what agy wanted and suggest
running from that folder or passing `--add-dir <path>` after the prompt.

For `--background` delegations, the request arrives when the subagent
finishes; ask the user then and resume in the foreground.

## Response style

The subagent is a thin wrapper around `agy`. Return its output verbatim — no
extra commentary before or after.

If the user did not supply a task, ask what they would like Antigravity to do.
