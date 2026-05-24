# antigravity (Claude Code plugin payload)

This directory is the actual Claude Code plugin. For install instructions and full
usage, see the [repo-level README](../../README.md).

## Layout

- `commands/` — slash commands (`/antigravity:setup`, `/antigravity:ask`, `/antigravity:delegate`, `/antigravity:review`)
- `agents/agy.md` — the `agy` subagent (thin forwarder around the Antigravity CLI)
- `skills/antigravity-cli/` — internal runtime skill, used only inside the `agy` subagent
- `scripts/agy-run.sh` — bash wrapper that locates `agy`, checks auth, and invokes `agy -p`

## Why this layout

This plugin mirrors the conventions used by [`openai/codex-plugin-cc`](https://github.com/openai/codex-plugin-cc),
but intentionally trims the heavy bits: no Node runtime, no broker, no review-gate
hook. Everything is plain Bash plus a single subagent.
