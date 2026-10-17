#!/usr/bin/env bash
# agy-run.sh — Claude Code wrapper around Google Antigravity CLI (`agy`).
# Subcommands: check | ask | review | image | help.
# `--model` (on ask) overrides the model for one call via locked
# settings.json patching, restored on exit.

set -euo pipefail

AGY_SETTINGS_FILE="${HOME}/.gemini/antigravity-cli/settings.json"
AGY_SETTINGS_LOCKDIR="${HOME}/.gemini/antigravity-cli/.agy-plugin.lock"
AGY_SETTINGS_BACKUP="${HOME}/.gemini/antigravity-cli/settings.json.agy-plugin.bak"
AGY_SETTINGS_SENTINEL="${HOME}/.gemini/antigravity-cli/.agy-plugin.patched"

find_agy() {
  if command -v agy >/dev/null 2>&1; then
    command -v agy
    return 0
  fi
  for candidate in \
      "$HOME/.local/bin/agy" \
      "/opt/antigravity/bin/agy" \
      "/usr/local/bin/agy"; do
    if [ -x "$candidate" ]; then
      echo "$candidate"
      return 0
    fi
  done
  return 1
}

auth_status() {
  if [ -n "${ANTIGRAVITY_API_KEY:-}" ]; then
    echo "api-key"
  elif [ -d "$HOME/.config/antigravity" ] || [ -d "$HOME/.gemini/antigravity-cli" ]; then
    echo "oauth"
  else
    echo "missing"
  fi
}

j_esc() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/\\r}"
  s="${s//$'\t'/\\t}"
  printf '%s' "$s"
}

cmd_check() {
  if ! path="$(find_agy | head -n1)"; then
    cat <<JSON
{ "installed": false, "path": "", "version": "", "auth": "unknown",
  "error": "agy binary not found; install with: curl -fsSL https://antigravity.google/cli/install.sh | bash" }
JSON
    return 0
  fi
  version="$("$path" --version 2>/dev/null | head -n1 || echo unknown)"
  auth="$(auth_status)"
  printf '{ "installed": true, "path": "%s", "version": "%s", "auth": "%s", "error": "" }\n' \
    "$(j_esc "$path")" "$(j_esc "$version")" "$(j_esc "$auth")"
}

require_ready() {
  if ! path="$(find_agy)"; then
    echo "error: agy is not installed." >&2
    echo "       install: curl -fsSL https://antigravity.google/cli/install.sh | bash" >&2
    exit 127
  fi
  if [ "$(auth_status)" = "missing" ]; then
    echo "error: agy is not authenticated." >&2
    echo "       run \`agy\` once interactively, or export ANTIGRAVITY_API_KEY" >&2
    exit 1
  fi
  echo "$path"
}

# fd arg lets cmd_help reuse the same table on stdout.
print_model_table() {
  local fd="${1:-2}"
  {
    echo "Aliases (case-insensitive):"
    echo "  flash-low | flash-medium (flash-med) | flash-high   -> Gemini 3.8 Flash (Low|Medium|High)"
    echo "  flash                                              -> Gemini 3.8 Flash (High)"
    echo "  argon-low | argon-medium | argon-high              -> Gemini 4 Argon (Low|Medium|High)"
    echo "  argon                                              -> Gemini 4 Argon (Medium)"
    echo "  opus-low | opus-medium | opus-high                 -> Claude Opus 5.5 (Low|Medium|High)"
    echo "  opus, claude-opus                                  -> Claude Opus 5.5 (Medium)"
    echo "  sonnet-low | sonnet-medium | sonnet-high           -> Claude Sonnet 5.5 (Low|Medium|High)"
    echo "  sonnet, claude-sonnet                              -> Claude Sonnet 5.5 (Medium)"
    echo "  gpt-oss, gpt-oss-120b                              -> GPT-OSS 120B (Medium)"
    echo
    echo "Canonical strings (also accepted verbatim, case-sensitive):"
    echo "  Gemini 3.8 Flash (Low|Medium|High)"
    echo "  Gemini 4 Argon (Low|Medium|High)"
    echo "  Claude Opus 5.5 (Low|Medium|High)"
    echo "  Claude Sonnet 5.5 (Low|Medium|High)"
    echo "  GPT-OSS 120B (Medium)"
  } >&"$fd"
}

_current_default_model() {
  [ -f "$AGY_SETTINGS_FILE" ] || return 1
  grep -oE '"model"[[:space:]]*:[[:space:]]*"[^"]*"' "$AGY_SETTINGS_FILE" 2>/dev/null \
    | sed -E 's/.*"model"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/' \
    | head -n1
}

resolve_model_alias() {
  local input="${1:-}"
  if [ -z "$input" ]; then
    echo "error: --model requires a non-empty value (e.g. --model flash)" >&2
    print_model_table 2
    local current; current="$(_current_default_model 2>/dev/null || true)"
    if [ -n "$current" ]; then
      echo >&2
      echo "Tip: omit --model to use your current default (\"$current\")." >&2
    fi
    exit 64
  fi
  case "$input" in
    "Gemini 3.8 Flash (Low)"|"Gemini 3.8 Flash (Medium)"|"Gemini 3.8 Flash (High)"|\
    "Gemini 4 Argon (Low)"|"Gemini 4 Argon (Medium)"|"Gemini 4 Argon (High)"|\
    "Claude Opus 5.5 (Low)"|"Claude Opus 5.5 (Medium)"|"Claude Opus 5.5 (High)"|\
    "Claude Sonnet 5.5 (Low)"|"Claude Sonnet 5.5 (Medium)"|"Claude Sonnet 5.5 (High)"|\
    "GPT-OSS 120B (Medium)")
      printf '%s' "$input"
      return 0 ;;
  esac

  # bash 3.2 (macOS /bin/bash) lacks ${var,,}, hence tr.
  local lc; lc="$(printf '%s' "$input" | tr '[:upper:]' '[:lower:]')"
  case "$lc" in
    flash-low)                  printf '%s' "Gemini 3.8 Flash (Low)" ;;
    flash-medium|flash-med)     printf '%s' "Gemini 3.8 Flash (Medium)" ;;
    flash|flash-high)           printf '%s' "Gemini 3.8 Flash (High)" ;;
    argon-low)                  printf '%s' "Gemini 4 Argon (Low)" ;;
    argon|argon-medium)         printf '%s' "Gemini 4 Argon (Medium)" ;;
    argon-high)                 printf '%s' "Gemini 4 Argon (High)" ;;
    opus-low)                   printf '%s' "Claude Opus 5.5 (Low)" ;;
    opus|opus-medium|claude-opus) printf '%s' "Claude Opus 5.5 (Medium)" ;;
    opus-high)                  printf '%s' "Claude Opus 5.5 (High)" ;;
    sonnet-low)                 printf '%s' "Claude Sonnet 5.5 (Low)" ;;
    sonnet|sonnet-medium|claude-sonnet) printf '%s' "Claude Sonnet 5.5 (Medium)" ;;
    sonnet-high)                printf '%s' "Claude Sonnet 5.5 (High)" ;;
    gpt-oss|gpt-oss-120b)       printf '%s' "GPT-OSS 120B (Medium)" ;;
    *)
      echo "error: unknown model alias '$input'" >&2
      print_model_table 2
      exit 64 ;;
  esac
}

validate_settings_file() {
  if [ ! -f "$AGY_SETTINGS_FILE" ]; then
    echo "error: $AGY_SETTINGS_FILE not found." >&2
    echo "       run \`agy\` once interactively to create it." >&2
    exit 1
  fi
  if [ ! -s "$AGY_SETTINGS_FILE" ]; then
    echo "error: $AGY_SETTINGS_FILE is empty." >&2
    exit 1
  fi
  if command -v python3 >/dev/null 2>&1; then
    if ! python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$AGY_SETTINGS_FILE" 2>/dev/null; then
      echo "error: $AGY_SETTINGS_FILE is not valid JSON." >&2
      exit 1
    fi
  fi
  if ! grep -q '"model"' "$AGY_SETTINGS_FILE"; then
    echo "error: $AGY_SETTINGS_FILE has no \"model\" field." >&2
    echo "       open \`agy\` and pick a model with /model first." >&2
    exit 1
  fi
}

restore_orphaned_backup() {
  [ -f "$AGY_SETTINGS_SENTINEL" ] || {
    if [ -f "$AGY_SETTINGS_BACKUP" ]; then
      echo "[wrapper] note: stale backup with no sentinel; removing $AGY_SETTINGS_BACKUP" >&2
      rm -f "$AGY_SETTINGS_BACKUP"
    fi
    return 0
  }
  local pid; pid="$(head -n1 "$AGY_SETTINGS_SENTINEL" 2>/dev/null || true)"
  if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
    return 0
  fi
  if [ -f "$AGY_SETTINGS_BACKUP" ]; then
    mv "$AGY_SETTINGS_BACKUP" "$AGY_SETTINGS_FILE"
    echo "[wrapper] recovered orphaned settings backup from PID ${pid:-unknown}" >&2
  fi
  rm -f "$AGY_SETTINGS_SENTINEL"
}

# mkdir-based lock; macOS has no flock(1). Dead-holder detection avoids
# SIGKILL deadlocks.
with_settings_lock() {
  local fn="$1"; shift
  local attempt=0
  local max_wait="${AGY_LOCK_WAIT_SECONDS:-600}"
  while ! mkdir "$AGY_SETTINGS_LOCKDIR" 2>/dev/null; do
    local holder_pid_file="${AGY_SETTINGS_LOCKDIR}/pid"
    if [ -f "$holder_pid_file" ]; then
      local holder_pid; holder_pid="$(cat "$holder_pid_file" 2>/dev/null || true)"
      if [ -n "$holder_pid" ] && ! kill -0 "$holder_pid" 2>/dev/null; then
        rm -rf "$AGY_SETTINGS_LOCKDIR"
        continue
      fi
    fi
    attempt=$((attempt + 1))
    if [ "$attempt" -gt "$max_wait" ]; then
      echo "error: could not acquire settings lock after ${max_wait}s" >&2
      exit 1
    fi
    sleep 1
  done
  echo "$$" > "${AGY_SETTINGS_LOCKDIR}/pid"
  local rc=0
  "$fn" "$@" || rc=$?
  rm -rf "$AGY_SETTINGS_LOCKDIR"
  return "$rc"
}

# python3 preferred for correctness; sed fallback only matches single-line
# "model": "..." (the format agy itself writes).
_patch_model_field() {
  local canonical="$1"
  local tmp; tmp="$(mktemp "${AGY_SETTINGS_FILE}.tmp.XXXXXX")"
  if command -v python3 >/dev/null 2>&1; then
    python3 - "$AGY_SETTINGS_FILE" "$canonical" "$tmp" <<'PY'
import json, sys
src, model, dst = sys.argv[1], sys.argv[2], sys.argv[3]
with open(src) as f:
    data = json.load(f)
data["model"] = model
with open(dst, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
PY
  else
    local esc; esc="$(printf '%s' "$canonical" | sed -e 's/[\/&]/\\&/g')"
    sed -E "s/^([[:space:]]*\"model\"[[:space:]]*:[[:space:]]*\")[^\"]*(\".*)$/\1${esc}\2/" \
        "$AGY_SETTINGS_FILE" > "$tmp"
    echo "[wrapper] note: python3 missing, used sed fallback to patch settings.json" >&2
  fi
  mv "$tmp" "$AGY_SETTINGS_FILE"
}

_restore_settings() {
  if [ -f "$AGY_SETTINGS_BACKUP" ]; then
    mv "$AGY_SETTINGS_BACKUP" "$AGY_SETTINGS_FILE"
  fi
  rm -f "$AGY_SETTINGS_SENTINEL"
}

_do_patched_run() {
  local canonical="$1"; shift
  cp -p "$AGY_SETTINGS_FILE" "$AGY_SETTINGS_BACKUP"
  printf '%s\n%s\n' "$$" "$canonical" > "$AGY_SETTINGS_SENTINEL"
  trap '_restore_settings' EXIT INT TERM HUP
  _patch_model_field "$canonical"
  local rc=0
  "$@" || rc=$?
  _restore_settings
  trap - EXIT INT TERM HUP
  return "$rc"
}

# `--` separator guards against canonical names that start with `-`.
with_model_override() {
  local canonical="$1"; shift
  if [ "${1:-}" != "--" ]; then
    echo "internal: with_model_override expects '--' after canonical name" >&2
    exit 70
  fi
  shift
  validate_settings_file
  with_settings_lock _do_patched_run "$canonical" "$@"
}

cmd_ask() {
  local model_alias=""
  local model_flag_seen=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --model)
        model_flag_seen=1
        # `shift 2` on a one-arg list would `set -e`-exit silently; handle
        # the empty case so resolve_model_alias prints the real error.
        if [ $# -ge 2 ]; then
          model_alias="$2"; shift 2
        else
          shift
        fi ;;
      --model=*)
        model_flag_seen=1
        model_alias="${1#--model=}"
        shift ;;
      --)        shift; break ;;
      *)         break ;;
    esac
  done
  # Resolve model before prompt check so empty --model gets the right error.
  local canonical=""
  if [ "$model_flag_seen" -eq 1 ]; then
    canonical="$(resolve_model_alias "$model_alias")"
  fi
  local prompt="${1:-}"
  shift || true
  if [ -z "$prompt" ]; then
    echo "error: ask requires a prompt argument" >&2
    exit 64
  fi
  local path
  path="$(require_ready)"
  if [ -n "$canonical" ]; then
    with_model_override "$canonical" -- "$path" -p "$prompt" "$@"
  else
    "$path" -p "$prompt" "$@"
  fi
}

cmd_review() {
  local focus="${1:-Please review the following diff for correctness, edge cases, security issues, and style.}"
  local path
  path="$(require_ready)"
  local repo_dir="${CLAUDE_PROJECT_DIR:-$PWD}"
  local diff
  diff="$(git -C "$repo_dir" diff HEAD 2>/dev/null || true)"
  if [ -z "$diff" ]; then
    diff="$(git -C "$repo_dir" diff 2>/dev/null || true)"
  fi
  if [ -z "$diff" ]; then
    echo "error: no git diff found in $repo_dir. Stage or make changes first." >&2
    exit 1
  fi
  local full
  full=$(printf '%s\n\nDiff:\n```diff\n%s\n```\n' "$focus" "$diff")
  "$path" -p "$full"
}

cmd_image() {
  local description=""
  local name=""
  local output=""
  local positional=()
  while [ $# -gt 0 ]; do
    case "$1" in
      --name)
        if [ $# -ge 2 ]; then
          name="$2"; shift 2
        else
          echo "error: --name requires a value (e.g. --name coffee_cup)" >&2
          exit 64
        fi ;;
      --name=*)
        name="${1#--name=}"
        if [ -z "$name" ]; then
          echo "error: --name= requires a non-empty value" >&2
          exit 64
        fi
        shift ;;
      --output)
        if [ $# -ge 2 ]; then
          output="$2"; shift 2
        else
          echo "error: --output requires a path (e.g. --output /tmp/out.png)" >&2
          exit 64
        fi ;;
      --output=*)
        output="${1#--output=}"
        if [ -z "$output" ]; then
          echo "error: --output= requires a non-empty path" >&2
          exit 64
        fi
        shift ;;
      --)        shift; positional+=("$@"); break ;;
      *)         positional+=("$1"); shift ;;
    esac
  done
  description="${positional[*]}"
  if [ -z "$description" ]; then
    echo "error: image requires a description" >&2
    exit 64
  fi
  local agy_path
  agy_path="$(require_ready)"

  local name_clause=""
  if [ -n "$name" ]; then
    name_clause=" Save the image with name \"${name}\"."
  fi
  local prompt
  prompt="Use your built-in generate_image tool to create the following image. Description: ${description}.${name_clause}

After the tool returns, you MUST end your reply with a single line in this exact format (no quotes, no markdown, nothing after it):
IMAGE_PATH: <absolute filesystem path to the saved image>

The IMAGE_PATH line is required — the calling wrapper parses it to locate the file."

  local response rc
  response="$("$agy_path" -p "$prompt" 2>&1)" || rc=$?
  rc="${rc:-0}"
  printf '%s\n' "$response"

  local src
  src="$(printf '%s' "$response" \
    | sed -n 's/^[[:space:]]*IMAGE_PATH:[[:space:]]*//p' \
    | tail -n1)"

  # Fallback when the model skips the marker line.
  if [ -z "$src" ] || [ ! -f "$src" ]; then
    src="$(printf '%s' "$response" \
      | grep -oE '/[^[:space:]]+\.(png|jpg|jpeg|webp)' \
      | head -n1)"
  fi

  if [ -n "$src" ] && [ -f "$src" ]; then
    echo
    echo "[wrapper] generated: $src"
    if [ -n "$output" ]; then
      cp "$src" "$output"
      echo "[wrapper] copied to: $output"
    fi
  else
    echo
    echo "[wrapper] warning: agy did not include an IMAGE_PATH line and no image path was found in its reply." >&2
    echo "[wrapper]          if --output was requested, the copy was skipped." >&2
  fi
  return "$rc"
}

cmd_help() {
  cat <<'HELP'
/agy:* commands (Claude Code plugin for the Antigravity CLI)

Slash commands
  /agy:setup                            Verify agy install + auth. Offers install if missing.
  /agy:ask [--model A] <prompt>         One-shot prompt; returns agy's response verbatim.
  /agy:delegate [--background] [--model A] <task>
                                        Hand a task to the agy:runner subagent.
  /agy:research [--background] [--model A] <topic>
                                        Deep-research investigation via agy:runner.
  /agy:review [focus]                   Send current `git diff` to agy for review.
  /agy:image [--name S] [--output P] <description>
                                        Generate an image via agy's built-in tool.
  /agy:help                             This help.

Model selection (--model)
HELP
  print_model_table 1
  cat <<'HELP'

How --model works
  The plugin manages the "model" field in ~/.gemini/antigravity-cli/settings.json
  for the duration of a single call: it takes a lock, swaps in your requested
  model, invokes agy, and restores the original on exit (including SIGINT /
  SIGTERM). If your TUI is open in parallel, its selected model will flip
  for the duration of the call and revert when the call finishes.

  Unknown aliases fail with exit 64 — typo safety beats forward-compat. If
  Google ships a new model, update the plugin.

Underlying CLI
  Run `agy --help` for agy's own flags: --add-dir, -c/--continue,
  --conversation, --dangerously-skip-permissions, -i/--prompt-interactive,
  --log-file, -p/--print, --print-timeout, --sandbox.

  Subcommands: changelog, help, install, plugin/plugins, update.
HELP
}

main() {
  restore_orphaned_backup 2>/dev/null || true

  case "${1:-}" in
    check)              cmd_check ;;
    ask)     shift;     cmd_ask "$@" ;;
    review)  shift;     cmd_review "$@" ;;
    image)   shift;     cmd_image "$@" ;;
    help|-h|--help|"")  cmd_help ;;
    *)                  echo "error: unknown subcommand '$1'" >&2; cmd_help >&2; exit 64 ;;
  esac
}

# Skip dispatch when sourced (lets unit tests call functions directly).
if [ "${BASH_SOURCE[0]:-}" = "${0:-}" ]; then
  main "$@"
fi
