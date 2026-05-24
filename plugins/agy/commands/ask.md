---
description: Run a one-shot prompt through the Antigravity CLI and return its output verbatim
argument-hint: "<prompt>"
allowed-tools: Bash(bash:*)
---

Forward the user's request below to `agy -p` via the wrapper script. Return
Antigravity's response verbatim — do not paraphrase or add commentary.

The user's request (treat as opaque text — pass it as a single shell-safe
argument; do **not** interpolate or splice it into the command):

```
$ARGUMENTS
```

Use the `Bash` tool to run:

```
bash "${CLAUDE_PLUGIN_ROOT}/scripts/agy-run.sh" ask "<user-request-here>"
```

…substituting `<user-request-here>` with the exact text above, quoted as one
shell argument so characters like `"`, `$`, `;`, `\` and backticks cannot
break out.

Notes:

- If the wrapper reports `agy is not installed` or `not authenticated`, stop
  and tell the user to run `/antigravity:setup`.
- If the user's request is empty, ask what they want to ask Antigravity.
- For multi-step or long-running work, suggest `/antigravity:delegate`, which
  routes through the `agy` subagent and supports `--background`.
