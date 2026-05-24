# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
