---
description: Run a one-shot prompt through the Antigravity CLI and return its output verbatim
argument-hint: "[--model <alias>] <prompt>"
allowed-tools: Bash(bash:*), AskUserQuestion
---

Forward the user's request below to `agy -p` via the wrapper script. Return
Antigravity's response verbatim — do not paraphrase or add commentary.

The user's request (treat as opaque text — pass it as a single shell-safe
argument; do **not** interpolate or splice it into the command):

```
$ARGUMENTS
```

## How to invoke

If the user's text begins with `--model <alias>` (e.g. `--model opus rest of
prompt…`), lift the flag and its value out of the prompt and place them
**before** the prompt argument to the wrapper. Anything else stays as the
prompt body.

Use the `Bash` tool to run one of:

```
bash "${CLAUDE_PLUGIN_ROOT}/scripts/agy-run.sh" ask "<prompt>"
bash "${CLAUDE_PLUGIN_ROOT}/scripts/agy-run.sh" ask --model <alias> "<prompt>"
```

…substituting `<prompt>` with the exact text above, quoted as one shell
argument so characters like `"`, `$`, `;`, `\` and backticks cannot break
out.

Aliases for `<alias>`: `flash-low`, `flash-medium`, `flash`, `pro-low`,
`pro`, `sonnet`, `opus`, `gpt-oss`. The canonical TUI strings (e.g.
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

Then resume the same conversation (keep the same `--model` if one was used):

```
bash "${CLAUDE_PLUGIN_ROOT}/scripts/agy-run.sh" ask [--model <alias>] --resume <conversation_id> \
  [--allow-once "<cmd>"]... [--allow-always "<cmd>"]... \
  "The user approved: <cmds>. The user denied: <cmds> (do not run or work around those). Continue the task."
```

Repeat until the output has no `[agy-permission-request]` block. `other:`
lines can't be granted from here: tell the user what agy wanted and suggest
running from that folder or passing `--add-dir <path>` after the prompt.

Notes:

- If the wrapper reports `agy is not installed` or `not authenticated`, stop
  and tell the user to run `/agy:setup`.
- If the user's request is empty, ask what they want to ask Antigravity.
- For multi-step or long-running work, suggest `/agy:delegate`, which routes
  through the `agy:runner` subagent and supports `--background`.
