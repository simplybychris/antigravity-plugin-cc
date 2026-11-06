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
- If no model is given, `agy` uses the default model selected in its TUI.

Aliases for `<alias>`: `flash-low`, `flash-medium`, `flash`, `pro-low`,
`pro`, `sonnet`, `opus`, `gpt-oss`. Each alias resolves at call time to the
newest matching model listed by `agy models`. Any model name or id from that
list (e.g. `"Gemini 3.8 Flash (High)"`) is also accepted. Run `/agy:help` for
the current table.

## Response style

The subagent is a thin wrapper around `agy`. Return its output verbatim — no
extra commentary before or after.

If the user did not supply a task, ask what they would like Antigravity to do.
