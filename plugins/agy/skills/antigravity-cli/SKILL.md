---
name: antigravity-cli
description: Internal runtime contract for invoking the Antigravity CLI (`agy`) from the `agy` subagent. Not user-invocable.
user-invocable: false
---

# Antigravity CLI runtime

Use this skill only inside the `agy` subagent.

## Primary helper

```
bash "${CLAUDE_PLUGIN_ROOT}/scripts/agy-run.sh" ask "<prompt>" [agy-flags...]
```

The wrapper:

- Locates `agy` in `PATH`, `~/.local/bin`, `/opt/antigravity/bin`, or
  `/usr/local/bin`.
- Verifies auth (system keyring OAuth or `ANTIGRAVITY_API_KEY`).
- Runs `agy -p "<prompt>"` non-interactively.
- Forwards any additional arguments straight to `agy` after the prompt — so
  `… ask "<prompt>" -m claude-sonnet` becomes `agy -p "<prompt>" -m claude-sonnet`.

## Rules of engagement

One wrapper call per task. The subagent is a forwarder, not an orchestrator —
keep the user's task text intact and let `agy` do the work.

Strip flags that belong to the parent slash command (`--background`, our own
`--model`) before forwarding. Pass `agy`-native flags through directly.

Common `agy`-native flags worth knowing:

- `-m <model>` — pick a model (`gemini-3.1-pro`, `claude-sonnet`,
  `gpt-oss-120b`, …). Append after the prompt argument.
- `--output-format json` — structured response; only use when the parent
  explicitly asked for JSON.
- `--sandbox` — extra-restrictive execution; only when the user asked for it.

## What this skill does NOT do

- Does not install or authenticate `agy`. That is `/antigravity:setup`'s job.
- Does not retry, summarize, or post-process `agy`'s output.
- Does not read files, run `git`, or make HTTP calls outside the wrapper.

## Error handling

If the wrapper exits non-zero, return its stderr verbatim. Standard exit
codes:

- `127` — `agy` binary not found.
- `1` — not authenticated, or no diff found (`review` subcommand).
- `64` — bad CLI usage of the wrapper itself; report as a plugin bug.
