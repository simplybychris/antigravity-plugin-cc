---
description: Delegate a task to the Antigravity (`agy`) runner subagent; supports background execution and model selection
argument-hint: "[--background] [--model <name>] <task description>"
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
- If the request contains `--model <name>`, forward it to the subagent so it
  can be appended as `-m <name>` to the `agy` call. Strip it from the task
  text.
- If no model is given, let `agy` pick its own default (configured in
  `~/.config/antigravity/config.toml` or the global default).

## Response style

The subagent is a thin wrapper around `agy`. Return its output verbatim — no
extra commentary before or after.

If the user did not supply a task, ask what they would like Antigravity to do.
