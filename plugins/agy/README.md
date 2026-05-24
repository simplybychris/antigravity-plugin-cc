# agy (Claude Code plugin payload)

This directory is the actual Claude Code plugin. For install instructions and
full usage, see the [repo-level README](../../README.md).

## Layout

- `commands/` — slash commands: `/agy:setup`, `/agy:ask`, `/agy:delegate`,
  `/agy:review`.
- `agents/runner.md` — the `agy:runner` subagent (thin forwarder around the
  Antigravity CLI).
- `skills/antigravity-cli/` — internal runtime skill, used only inside the
  `agy:runner` subagent.
- `scripts/agy-run.sh` — bash wrapper that locates `agy`, checks auth, and
  invokes `agy -p`.

## Why this layout

Mirrors the conventions used by
[`openai/codex-plugin-cc`](https://github.com/openai/codex-plugin-cc), trimmed
down: no Node runtime, no broker, no review-gate hook. Plain Bash plus a
single subagent.
