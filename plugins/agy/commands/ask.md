---
description: Run a one-shot prompt through the Antigravity CLI and return its output verbatim
argument-hint: "[--model <alias>] <prompt>"
allowed-tools: Bash(bash:*)
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
`pro`, `sonnet`, `opus`, `gpt-oss`. Each alias resolves at call time to the
newest matching model listed by `agy models`. Any model name or id from that
list (e.g. `"Gemini 3.8 Flash (High)"`) is also accepted. Run `/agy:help` for
the current table.

Notes:

- If the wrapper reports `agy is not installed` or `not authenticated`, stop
  and tell the user to run `/agy:setup`.
- If the user's request is empty, ask what they want to ask Antigravity.
- For multi-step or long-running work, suggest `/agy:delegate`, which routes
  through the `agy:runner` subagent and supports `--background`.
