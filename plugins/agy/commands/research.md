---
description: Delegate a thorough research investigation to Antigravity (`agy`)
argument-hint: "[--background] [--model <alias>] <topic or question>"
allowed-tools: Bash(bash:*), AskUserQuestion
---

Hand a deep-research task to Antigravity through the wrapper script.

Wrap the user's topic in a research-oriented preamble so `agy` treats it as
a structured investigation rather than a quick Q&A.

Raw user request:
$ARGUMENTS

## How to forward

Build the research prompt as:

```
Conduct a thorough research investigation on the following topic. Look up
authoritative sources, summarize the current state of knowledge, surface
disagreements or open questions, and structure the response with clear
sections (Background, Key findings, Caveats, Sources).

Topic: <stripped user request here>
```

(Strip any routing flags — `--background`, `--model <alias>` — from the
topic text before injecting it.)

Then run it directly with the `Bash` tool (no subagent hop), passing the
prompt as one shell-safe argument:

```
bash "${CLAUDE_PLUGIN_ROOT}/scripts/agy-run.sh" ask [--model <alias>] "<research prompt>"
```

## Routing rules

- If the request contains `--background`, set `run_in_background: true` on
  the Bash call. Research is often long-running — prefer background unless
  the user explicitly asked for foreground; in the foreground use
  `timeout: 600000`.
- If the request contains `--model <alias>`, put it **before** the prompt
  argument. If no model is given, leave the choice to
  whatever the TUI is currently set to (a reasoning-strong model like
  `pro` or `opus` works well for research).

Aliases: `flash-low`, `flash-medium`, `flash`, `pro-low`, `pro`, `sonnet`,
`opus`, `gpt-oss`. Canonical TUI strings (e.g. `"Claude Opus 4.6 (Thinking)"`)
are also accepted. Run `/agy:help` for the full table.

## Permission requests

If the output ends with an `[agy-permission-request]` block, follow
the "Permission requests from agy" section of `/agy:delegate`: ask the user
with `AskUserQuestion` (Allow once / Always allow / Deny) and resume the same
conversation with `--resume <conversation_id>` plus `--allow-once` /
`--allow-always` for the approved commands.

## Response style

The research report is the deliverable: return agy's output verbatim — no
extra commentary before or after.

If the user did not supply a topic, ask what they want researched.
