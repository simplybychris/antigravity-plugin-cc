# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-05-24

### Added
- Initial plugin scaffold and Claude Code marketplace manifest.
- `/antigravity:setup` — verify `agy` install and authentication; offer to install if missing.
- `/antigravity:ask` — run a one-shot `agy -p` prompt and return its output verbatim.
- `/antigravity:delegate` — hand a task to the `agy` subagent; supports `--background` and `--model`.
- `/antigravity:review` — pipe the current `git diff` into `agy` for review.
- `agy` subagent — thin forwarding wrapper around the Antigravity CLI.
- `antigravity-cli` internal skill — runtime contract for invoking `agy` from the subagent.
- `agy-run.sh` — bash wrapper that handles binary discovery, auth detection, and exit codes.
