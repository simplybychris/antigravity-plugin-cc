---
description: Delegate a thorough research investigation to the agy:runner subagent
argument-hint: "[--background] [--model <alias>] <topic or question>"
allowed-tools: Agent
---

Hand a deep-research task to the `agy:runner` subagent
(`subagent_type: "agy:runner"`).

Wrap the user's topic in a research-oriented preamble so `agy` treats it as
a structured investigation rather than a quick Q&A.

Raw user request:
$ARGUMENTS

## How to forward

Build the research prompt for the subagent as:

```
Conduct a thorough research investigation on the following topic. Look up
authoritative sources, summarize the current state of knowledge, surface
disagreements or open questions, and structure the response with clear
sections (Background, Key findings, Caveats, Sources).

Topic: <stripped user request here>
```

(Strip any routing flags — `--background`, `--model <alias>` — from the
topic text before injecting it.)

Then invoke the `agy:runner` subagent with that prompt as
`subagent_type: "agy:runner"`.

## Routing rules

- If the request contains `--background`, launch the subagent with
  `run_in_background: true`. Research is often long-running — prefer
  background unless the user explicitly asked for foreground.
- If the request contains `--model <alias>`, forward it to the subagent so
  it can be appended to the wrapper call as `--model <alias>` (placed
  **before** the prompt argument). If no model is given, leave the choice to
  whatever the TUI is currently set to (a reasoning-strong model like
  `pro` or `opus` works well for research).

Aliases: `flash-low`, `flash-medium`, `flash`, `pro-low`, `pro`, `sonnet`,
`opus`, `gpt-oss`. Each alias resolves at call time to the newest matching
model listed by `agy models`. Any model name or id from that list (e.g.
`"Gemini 3.8 Flash (High)"`) is also accepted. Run `/agy:help` for the
current table.

## Response style

Return the subagent's output verbatim — no extra commentary before or
after.

If the user did not supply a topic, ask what they want researched.
