---
description: Delegate an execution task to Antigravity (`agy`) while Claude orchestrates and verifies; supports background execution and model selection
argument-hint: "[--background] [--model <alias>] <task description>"
allowed-tools: Bash(bash:*), AskUserQuestion
---

Hand the user's task to Antigravity and stay the orchestrator: `agy` does
the hands-on work, you brief it, read its full report, check the result and
tell the user what happened.

Raw user request:
$ARGUMENTS

## How to run it

Call the wrapper directly with the `Bash` tool (no subagent hop — it only
adds latency and re-types agy's output):

```
bash "${CLAUDE_PLUGIN_ROOT}/scripts/agy-run.sh" ask [--model <alias>] "<brief>"
```

- `--model <alias>` goes **before** the prompt. Strip it and `--background`
  from the task text.
- With `--background`, set `run_in_background: true` on the Bash call and
  carry on; you are notified when it finishes. Otherwise run it in the
  foreground with `timeout: 600000`.
- If no model is given, the wrapper uses whatever the TUI is currently set
  to (stored in `~/.gemini/antigravity-cli/settings.json`).
- Pass the brief as one shell-safe argument (single quotes, or a quoted
  heredoc for multi-line text) so `"`, `$`, `;`, `\` and backticks can't
  break out.

Aliases for `<alias>`: `flash-low`, `flash-medium`, `flash`, `pro-low`,
`pro`, `sonnet`, `opus`, `gpt-oss`. Canonical TUI strings (e.g.
`"Claude Opus 4.6 (Thinking)"`) are also accepted. Run `/agy:help` for the
full table.

## The brief

Pass the user's task through intact, adding only the context agy needs that
you already know (relevant files, constraints, how to check the work). End
it with this report request; agy's output tokens are the slowest part of a
delegation, so keep them for the work, not for prose:

```
When you finish, reply only with a short report: files created or changed,
commands you ran and their results, and anything left undone or failing.
Do not explain or paste the code.
```

## After agy finishes

You have agy's full report in the Bash result. Do not paste it back
verbatim. Instead:

1. Check the work where it is cheap to do so: look at `git status` /
   `git diff` for the files it touched, and re-run the check it ran (tests,
   build) if it reported one.
2. Tell the user in a few lines what agy did, what you verified, and
   anything that failed or is left. Fix small issues yourself, or resume agy
   (`--resume <conversation_id>`) for larger follow-ups.

## Permission requests from agy

`agy` runs headless with `--mode accept-edits`: edits inside the workspace go
through, but anything it would normally ask about (shell commands, writes
outside the workspace) is denied and relayed back. The wrapper then exits
with code **75** and ends its output with:

```
[agy-permission-request]
conversation_id: <id>
command: <exact command agy wanted to run>
other: <non-command tool and target, if any>
[/agy-permission-request]
```

When you see that block, do **not** approve anything yourself. Use
`AskUserQuestion` with one question per `command:` line (at most 4; batch the
rest in a follow-up), quoting the exact command, with these options:

- `Allow once` — run it this time only.
- `Always allow` — add a permanent exact-match rule to agy's settings
  (saves a round trip next time; good for test and build commands).
- `Deny` — do not run it.

Then resume the same conversation (keep the same `--model` if one was used):

```
bash "${CLAUDE_PLUGIN_ROOT}/scripts/agy-run.sh" ask [--model <alias>] --resume <conversation_id> \
  [--allow-once "<cmd>"]... [--allow-always "<cmd>"]... \
  "The user approved: <cmds>. The user denied: <cmds> (do not run or work around those). Continue the task."
```

Repeat until the output has no `[agy-permission-request]` block. `other:`
lines can't be granted from here: tell the user what agy wanted and suggest
running from that folder or passing `--add-dir <path>` after the prompt.

For `--background` delegations, the request arrives when the background
command finishes; ask the user then and resume in the foreground.

If the user did not supply a task, ask what they would like Antigravity to do.
