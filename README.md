# agy — Antigravity CLI plugin for Claude Code

Use Google's [Antigravity CLI (`agy`)](https://antigravity.google/) from
inside Claude Code. Delegate tasks to the `agy:runner` subagent, run quick
prompts, or get a second-opinion code review — without leaving your editor.

This plugin is for Claude Code users who already use (or want to start using)
Antigravity and want a smooth way to call it from the workflow they already
have. Intentionally small: no Node runtime, no broker, no review-gate hook —
just Bash and `agy`.

## What you get

- **`/agy:setup`** — verify `agy` is installed and authenticated; can install
  it for you if it is missing.
- **`/agy:ask [--model <alias>] <prompt>`** — one-shot prompt through `agy -p`;
  returns the raw response.
- **`/agy:delegate [--background] [--model <alias>] <task>`** — hand an
  execution task to `agy`; Claude briefs it, checks the result and reports
  back. `--background` for long jobs.
- **`/agy:research [--background] [--model <alias>] <topic>`** — delegate a
  deep-research investigation; wraps the topic in a structured prompt and
  returns agy's report.
- **`/agy:image <description>`** — generate an image with `agy`'s built-in
  `generate_image` tool (Imagen under the hood). Optional `--name` and
  `--output`.
- **`/agy:review [focus]`** — ask Antigravity to review your current
  `git diff`.
- **`/agy:help`** — show all commands, supported `--model` aliases, and
  canonical model names.
- **`agy:runner` subagent** — thin forwarding wrapper around the Antigravity
  CLI; available as `subagent_type: "agy:runner"` for programmatic
  delegation.

## Requirements

- **Claude Code** with plugin-marketplace support
  (`/plugin marketplace add …`).
- **Antigravity CLI (`agy`)** installed locally. `/agy:setup` can install it
  on first run.
- **Auth** for `agy`: either OAuth cached in the system keyring (after one
  interactive run of `agy`) or `ANTIGRAVITY_API_KEY` exported in your shell.
- **Bash** and **git** in `PATH`. macOS, Linux, or WSL.

## Install

In Claude Code, run these three slash commands in order:

```text
/plugin marketplace add simplybychris/antigravity-plugin-cc
/plugin install agy@antigravity-cc
/reload-plugins
```

Then verify everything is wired up:

```text
/agy:setup
```

If `agy` is missing, `/agy:setup` offers to install it via the official
installer:

```bash
curl -fsSL https://antigravity.google/cli/install.sh | bash
```

If `agy` is installed but not logged in, run `agy` once interactively in your
terminal to complete OAuth — or export `ANTIGRAVITY_API_KEY`.

## Usage

### Ask a quick question

```text
/agy:ask explain the difference between Go channels and Rust async in one paragraph
```

Returns Antigravity's response verbatim.

### Delegate a task

```text
/agy:delegate refactor the SQL queries in src/db/queries.go to use prepared statements
```

For long tasks, run in the background and let Claude Code notify you when it
finishes:

```text
/agy:delegate --background investigate why integration tests are flaky in CI
```

You can also delegate by talking to Claude:

```text
Ask agy to look at this file and suggest a simpler design.
```

`/agy:delegate` calls the wrapper directly (no subagent hop). Claude stays
the orchestrator: it asks agy for a short report (files changed, commands
run, results) instead of a long write-up, reads it in full, checks the diff
and tests, and tells you what happened in a few lines rather than pasting
agy's output back. Talking to Claude ("ask agy to…") may also route through
the `agy:runner` subagent.

### Review the current diff

Stage or make some changes, then:

```text
/agy:review
/agy:review focus on error handling and concurrency safety
```

### Pick a specific model

```text
/agy:delegate --model sonnet fix the off-by-one in pagination
/agy:delegate --model pro write a high-coverage test for the cache layer
/agy:ask --model opus "explain Go's escape analysis"
```

Supported aliases: `flash-low`, `flash-medium`, `flash`, `pro-low`, `pro`,
`sonnet`, `opus`, `gpt-oss`. The canonical TUI strings (e.g.
`"Claude Opus 4.6 (Thinking)"`) are also accepted. Run `/agy:help` for the
full table.

If no `--model` is given, the wrapper uses whatever the TUI is currently set
to — stored in `~/.gemini/antigravity-cli/settings.json`. Project-local
`AGENTS.md` and `GEMINI.md` files are read directly by `agy` and unaffected
by this plugin.

### Delegate a deep research investigation

```text
/agy:research what's the current state of WebGPU support across browsers in 2026?
/agy:research --background --model opus survey post-quantum signature schemes used in TLS
```

The command wraps your topic in a research-oriented preamble (background,
key findings, caveats, sources) and returns agy's report verbatim. Long
investigations work well in `--background`.

### Generate an image

```text
/agy:image a minimalist dark-mode login mockup, blue accent color
/agy:image --name hero --output ./assets/hero.png isometric illustration of a developer at a desk
```

Triggers `agy`'s built-in `generate_image` tool. The image is written to
the Antigravity artifacts dir (e.g.
`~/.gemini/antigravity-cli/brain/<uuid>/<name>.png`). Pass `--output` if
you want the wrapper to copy it next to your project.

## How it works

Under the hood, the plugin is a thin wrapper around your local `agy` install:

```
Claude Code  →  /agy:*  →  agy-run.sh  →  agy -p "..."
Claude Code  →  agy:runner subagent (programmatic delegation)  →  agy-run.sh  →  agy -p "..."
```

- The plugin does **not** ship its own Antigravity runtime — it uses your
  local `agy` binary, your local auth, and your local config.
- The wrapper script
  ([`plugins/agy/scripts/agy-run.sh`](./plugins/agy/scripts/agy-run.sh))
  handles binary discovery, auth detection, and exit codes.
- Slash commands call the wrapper directly with Bash (background-capable via
  `run_in_background`). The `agy:runner` subagent (Haiku) is a *forwarder*
  for programmatic delegation: it invokes the wrapper exactly once per
  request and returns Antigravity's output verbatim.

## Configuration

`agy` stores its preferences (selected model, theme, telemetry, trusted
workspaces) in `~/.gemini/antigravity-cli/settings.json`. Project-local
`AGENTS.md` / `GEMINI.md` files are read directly by `agy`. This plugin
doesn't override or shadow any of that — drop config files where `agy`
expects them and they'll be picked up.

The `--model <alias>` flag on `/agy:ask`, `/agy:delegate`, and `/agy:research`
swaps in your requested model for the duration of a single call (under a
lockfile, with automatic restore on exit) and leaves the TUI's selected
model intact for subsequent runs.

## FAQ

### Do I need an Antigravity subscription?

You need whatever account `agy` accepts: Google AI Pro, Ultra, Code Assist
Standard/Enterprise, or an enterprise GCP project. See the
[Antigravity docs](https://antigravity.google/docs/cli-overview) for details.

### Does this plugin send data anywhere other than what `agy` sends?

No. The plugin runs `agy` locally over a Bash wrapper. The wrapper only reads
filesystem paths and your shell environment. Your prompts go directly to
Google through `agy`'s normal channels.

### Can I keep using Antigravity outside this plugin?

Yes — the plugin uses your local install. Running `agy` directly in a
terminal keeps working exactly as before.

### Why do the slash commands skip the subagent?

Speed. A subagent hop adds a model start-up plus a second full re-typing of
agy's output, often 10+ seconds per delegation. Claude Code's Bash tool can
already run in the background and notify on completion, so `/agy:delegate`
and `/agy:research` call the wrapper directly. `agy:runner` remains for
programmatic delegation and runs on Haiku to keep that hop cheap.

## Inspiration

Inspired by
[`openai/codex-plugin-cc`](https://github.com/openai/codex-plugin-cc), which
does the same thing for Codex. This plugin is intentionally smaller.

## License

[MIT](./LICENSE).
