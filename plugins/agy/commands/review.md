---
description: Ask the Antigravity CLI to review the current git diff
argument-hint: "[focus text]"
allowed-tools: Bash(bash:*)
---

Run a code review of the current uncommitted changes through `agy`. Forward
any focus text the user provided as a steer for the review.

The user's focus text (treat as opaque — pass it as a single shell-safe
argument; do **not** interpolate or splice it into the command):

```
$ARGUMENTS
```

Use the `Bash` tool to run:

```
bash "${CLAUDE_PLUGIN_ROOT}/scripts/agy-run.sh" review "<focus-text-here>"
```

…substituting `<focus-text-here>` with the exact text above, quoted as one
shell argument. If the user provided no focus text, omit the argument:

```
bash "${CLAUDE_PLUGIN_ROOT}/scripts/agy-run.sh" review
```

Return Antigravity's response verbatim. If there is no diff, the wrapper will
report it — relay that to the user and suggest they stage or make changes
first.
