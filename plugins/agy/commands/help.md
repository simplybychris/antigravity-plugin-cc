---
description: Show all /agy:* commands, supported --model aliases, and the models agy currently offers
allowed-tools: Bash(bash:*)
---

Run the wrapper's help branch, then print its stdout verbatim as a fenced
code block in your text response. Do not paraphrase, reorder, or summarize —
the wrapper is the authoritative source for the command list, model aliases,
and the models listed by `agy models`. The output MUST appear as readable
text in the reply, not just as a collapsed tool result.

```
bash "${CLAUDE_PLUGIN_ROOT}/scripts/agy-run.sh" help
```

After the Bash call completes, copy the full stdout into your response inside
a ``` code block.
