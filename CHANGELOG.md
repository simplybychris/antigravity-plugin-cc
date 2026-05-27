# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.4.1] - 2026-05-27

### Fixed
- `/agy:ask` and `/agy:image`: stop silent fallback / silent exit when
  a flag value is missing. `--model` (no value) used to die with exit 1
  and no message; `--model=` (empty) used to silently fall back to the
  default model. Both now print `error: --model requires a non-empty
  value`, the alias table, and a tip showing the current default. Same
  fix applied to `cmd_image` for `--name` and `--output`, plus `=` form
  support (`--name=foo`, `--output=path`).
- `/agy:help`: prints the wrapper's stdout verbatim in the reply as a
  code block instead of leaving it as a collapsed tool result.

## [0.4.0] - 2026-05-26

### Added
- `/agy:help` — single discoverable index of every `/agy:*` command,
  supported `--model` aliases, and the canonical model names. The wrapper
  is the single source of truth; the slash command just prints its
  `help` subcommand verbatim.
- `--model <alias>` on `/agy:ask`, `/agy:delegate`, and `/agy:research`.
  Per-call model selection: the wrapper takes a lock on
  `~/.gemini/antigravity-cli/settings.json`, atomically swaps in the
  requested model, invokes `agy`, then restores the original on exit
  (including SIGINT / SIGTERM / SIGHUP).
- Alias table: `flash-low`, `flash-medium` (`flash-med`), `flash`
  (`flash-high`), `pro-low`, `pro` (`pro-high`), `sonnet` (`claude-sonnet`),
  `opus` (`claude-opus`), `gpt-oss` (`gpt-oss-120b`). Canonical TUI strings
  (e.g. `"Claude Opus 4.6 (Thinking)"`) are accepted verbatim.
- `agy-run.sh` gains `cmd_help`, `resolve_model_alias`,
  `validate_settings_file`, `with_settings_lock`, `with_model_override`,
  and `restore_orphaned_backup` (cleans up after a `SIGKILL`ed previous
  run on the next invocation).

### Fixed
- Removed stale references to `agy -m <model>` from `runner.md`,
  `commands/delegate.md`, `commands/research.md`, and
  `skills/antigravity-cli/SKILL.md`. `agy` v1.0.2 has no `-m` / `--model`
  CLI flag — model selection is now correctly handled by the wrapper.
  Users who tried `--model` in 0.3.x and earlier got failures; 0.4.0
  makes the documented behavior work.
- Removed references to `~/.config/antigravity/config.toml` from the
  root README and `commands/delegate.md`. `agy` does not read that path;
  its actual settings live in `~/.gemini/antigravity-cli/settings.json`.
- Dropped the `--output-format json` mention from `SKILL.md` — that flag
  does not exist either.

### Internal
- `_patch_model_field` writes via `python3 -c "json.dump(...)"` when
  available, falling back to a narrow `sed` regex that targets only
  single-line `"model"` entries. Atomic `mv` from a tmpfile is used in
  both paths.
- `mkdir`-based portable lockfile (no `flock(1)` dependency — macOS has
  none by default). Dead-holder detection via `kill -0` prevents
  deadlocks after `SIGKILL`.
- Wrapper now has a sourcing guard so individual functions can be unit
  tested without triggering the dispatch.

## [0.3.1] - 2026-05-24

### Fixed
- `/agy:image` now extracts the saved image path deterministically. The
  wrapper instructs `agy` to end its reply with an `IMAGE_PATH:` marker line
  and parses it; a regex scrape of absolute `*.png/.jpg/.jpeg/.webp` paths
  in the reply is kept as a fallback. Previously the path was only printed
  when `agy` happened to mention it in its natural-language reply.

## [0.3.0] - 2026-05-24

### Added
- `/agy:research` — delegate a deep-research investigation. Wraps the
  topic in a structured prompt (background, key findings, caveats,
  sources) and routes through the `agy:runner` subagent. Defaults toward
  background execution for long jobs.
- `/agy:image` — generate an image with `agy`'s built-in `generate_image`
  tool (Imagen under the hood). Optional `--name <slug>` for the saved
  filename and `--output <path>` to copy the generated PNG next to your
  project.
- `agy-run.sh` gains an `image` subcommand that builds the right prompt
  for `agy`'s native image tool and optionally copies the result.

## [0.2.0] - 2026-05-24

### Changed
- **Breaking:** plugin renamed `antigravity` → `agy`, so slash commands move
  from `/antigravity:*` to `/agy:*`. Install command is now
  `/plugin install agy@antigravity-cc`.
- Subagent renamed from `agy` to `runner`; full identifier is `agy:runner`
  (avoids the awkward `agy:agy` form).

## [0.1.0] - 2026-05-24

### Added
- Initial plugin scaffold and Claude Code marketplace manifest.
- `/agy:setup` — verify `agy` install and authentication; offer to install
  if missing.
- `/agy:ask` — run a one-shot `agy -p` prompt and return its output
  verbatim.
- `/agy:delegate` — hand a task to the `agy:runner` subagent; supports
  `--background` and `--model`.
- `/agy:review` — pipe the current `git diff` into `agy` for review.
- `agy:runner` subagent — thin forwarding wrapper around the Antigravity
  CLI.
- `antigravity-cli` internal skill — runtime contract for invoking `agy`
  from the subagent.
- `agy-run.sh` — bash wrapper that handles binary discovery, auth
  detection, and exit codes.
