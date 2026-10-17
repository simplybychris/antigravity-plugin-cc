---
description: Delegate a task to the Antigravity (`agy`) runner subagent; supports background execution and model selection
argument-hint: "[--background] [--model <alias>] <task description>"
allowed-tools: Agent
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

Aliases for `<alias>`: `flash[-low|-medium|-high]`, `argon[-low|-medium|-high]`,
`opus[-low|-medium|-high]`, `sonnet[-low|-medium|-high]`, `gpt-oss`. Canonical TUI strings (e.g.
`"Claude Opus 5.5 (High)"`) are also accepted. Run `/agy:help` for the
full table.

## Response style

The subagent is a thin wrapper around `agy`. Return its output verbatim — no
extra commentary before or after.

If the user did not supply a task, ask what they would like Antigravity to do.
