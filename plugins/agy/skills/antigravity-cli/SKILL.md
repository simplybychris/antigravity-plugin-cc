---
name: antigravity-cli
description: Internal runtime contract for invoking the Antigravity CLI (`agy`) from the `agy` subagent. Not user-invocable.
user-invocable: false
---

# Antigravity CLI runtime

Use this skill only inside the `agy` subagent.

## Primary helper

```
bash "${CLAUDE_PLUGIN_ROOT}/scripts/agy-run.sh" ask [--model <alias>] "<prompt>" [agy-flags...]
```

The wrapper:

- Locates `agy` in `PATH`, `~/.local/bin`, `/opt/antigravity/bin`, or
  `/usr/local/bin`.
- Verifies auth (system keyring OAuth or `ANTIGRAVITY_API_KEY`).
- Runs `agy -p "<prompt>"` non-interactively.
- If `--model <alias>` is supplied **before** the prompt, resolves the
  alias against `agy models` and runs `agy --model <id> -p "<prompt>"`
  (the display name instead of the id when the list has no ids).
  The user's default model in agy's settings is not touched.
- Forwards any extra arguments **after** the prompt straight to `agy` — so
  `… ask "<prompt>" --sandbox` becomes `agy -p "<prompt>" --sandbox`.

## Rules of engagement

One wrapper call per task. The subagent is a forwarder, not an orchestrator —
keep the user's task text intact and let `agy` do the work.

Strip flags that belong to the parent slash command (`--background`) before
forwarding. Pass `--model <alias>` to the wrapper (not to agy directly).
Pass agy-native flags through after the prompt argument.

## Model aliases (consumed by the wrapper)

`flash-low`, `flash-medium` (`flash-med`), `flash` (`flash-high`),
`pro-low`, `pro` (`pro-high`), `sonnet` (`claude-sonnet`),
`opus` (`claude-opus`), `gpt-oss` (`gpt-oss-120b`). Each alias picks the
newest matching model from `agy models` at call time. Model names and ids
from that list are also accepted verbatim (e.g. `"Gemini 3.8 Flash (High)"`).

Run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/agy-run.sh" help` for the
authoritative list.

## agy-native flags worth knowing

Run `agy --help` for the full list. Useful ones that go **after** the
prompt argument:

- `--sandbox` — extra-restrictive execution; only when the user asked for it.
- `--print-timeout 10m` — stop print mode after a time limit (by default
  it waits until the turn completes).
- `--add-dir <path>` — add a directory to the workspace (repeatable).

## What this skill does NOT do

- Does not install or authenticate `agy`. That is `/agy:setup`'s job.
- Does not retry, summarize, or post-process `agy`'s output.
- Does not read files, run `git`, or make HTTP calls outside the wrapper.

## Error handling

If the wrapper exits non-zero, return its stderr verbatim. Standard exit
codes:

- `127` — `agy` binary not found.
- `1` — not authenticated, no diff found (`review` subcommand), `agy`
  older than 1.2.0 when `--model` is used, or `agy models` unavailable when
  an alias was requested.
- `64` — bad CLI usage of the wrapper itself, a `--model` value that is
  neither an alias nor listed by `agy models`, or an alias whose model
  family `agy models` does not offer (e.g. `pro` on an account without a
  Gemini Pro model).
