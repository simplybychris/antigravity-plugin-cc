#!/usr/bin/env bash
# agy-run.sh — Claude Code wrapper around Google Antigravity CLI (`agy`).
# Subcommands: check | ask | review | image | help.
# `--model` (on ask) resolves an alias against `agy models` and passes the
# result to agy's own --model flag for that call only.

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
  version="$("$path" --version </dev/null 2>/dev/null | head -n1 || echo unknown)"
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

# Each row: comma-separated aliases | ERE matched against the lowercased
# display name from `agy models` | ERE that wins a version tie (may be
# empty) | description shown when no listing is available. Aliases pick the
# newest version in their family.
MODEL_ALIASES='flash-low|^gemini [0-9.]+ flash [(]low[)]$||newest Gemini Flash (Low)
flash-medium,flash-med|^gemini [0-9.]+ flash [(]medium[)]$||newest Gemini Flash (Medium)
flash,flash-high|^gemini [0-9.]+ flash [(]high[)]$||newest Gemini Flash (High)
pro-low|^gemini [0-9.]+ pro [(]low[)]$||newest Gemini Pro (Low)
pro,pro-high|^gemini [0-9.]+ pro [(]high[)]$||newest Gemini Pro (High)
sonnet,claude-sonnet|^claude sonnet [0-9.]+( [(].*[)])?$|[(]thinking[)]$|newest Claude Sonnet
opus,claude-opus|^claude opus [0-9.]+( [(].*[)])?$|[(]thinking[)]$|newest Claude Opus
gpt-oss,gpt-oss-120b|^gpt-oss 120b( [(].*[)])?$|[(]medium[)]$|GPT-OSS 120B'

# Older agy builds lack --model, ignore it in -p runs, or hang in
# `agy models` on an open stdin.
MIN_AGY_VERSION="1.2.0"

TAB="$(printf '\t')"

AWK_VERSION_NEWER='
function newer(a, b,    x, y, na, nb, n, i) {
  na = split(a, x, "."); nb = split(b, y, ".")
  n = na > nb ? na : nb
  for (i = 1; i <= n; i++) {
    if (x[i] + 0 > y[i] + 0) return 1
    if (x[i] + 0 < y[i] + 0) return 0
  }
  return 0
}'

require_model_support() {
  local path="$1" raw version
  raw="$("$path" --version </dev/null 2>/dev/null || true)"
  version="$(printf '%s\n' "$raw" | grep -oE '[0-9]+[.][0-9]+([.][0-9]+)?' | head -n1 || true)"
  if [ -z "$version" ]; then
    echo "[wrapper] note: could not read the agy version; assuming --model works" >&2
    return 0
  fi
  if [ "$(awk -v a="$MIN_AGY_VERSION" -v b="$version" "$AWK_VERSION_NEWER"'
      BEGIN { print newer(a, b) }')" = 1 ]; then
    echo "error: agy $version is too old for --model (needs $MIN_AGY_VERSION or newer)." >&2
    echo "       update it with \`agy update\`." >&2
    exit 1
  fi
}

# Prints "id<TAB>display name" per model. Some agy builds print names only,
# in which case the id column is empty.
list_models() {
  local path="$1" raw
  raw="$("$path" models </dev/null 2>/dev/null)" || return 1
  printf '%s\n' "$raw" | awk '
    { sub(/\r$/, "") }
    /^[[:space:]]*$/ || /:[[:space:]]*$/ || /^Fetching / { next }
    {
      tab = index($0, "\t")
      if (tab > 0) { id = substr($0, 1, tab - 1); name = substr($0, tab + 1) }
      else { id = ""; name = $0 }
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", id)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", name)
      if (name != "") print id "\t" name
    }'
}

# Line of $1 (list_models output) whose name matches ERE $2 and has the
# newest version. On a version tie, a name matching ERE $3 wins.
_newest_match() {
  printf '%s\n' "$1" | PATTERN="$2" PREFER="${3:-}" awk -F '\t' "$AWK_VERSION_NEWER"'
    NF >= 2 && tolower($2) ~ ENVIRON["PATTERN"] {
      version = ""
      count = split(tolower($2), word, " ")
      for (i = 1; i <= count; i++) if (word[i] ~ /^[0-9]+([.][0-9]+)*$/) { version = word[i]; break }
      preferred = ENVIRON["PREFER"] != "" && tolower($2) ~ ENVIRON["PREFER"]
      if (best == "" || newer(version, best_version) ||
          (!newer(best_version, version) && preferred && !best_preferred)) {
        best = $0; best_version = version; best_preferred = preferred
      }
    }
    END { if (best != "") print best }'
}

# Line of $1 whose id or name equals $2, ignoring case.
_exact_match() {
  printf '%s\n' "$1" | WANT="$2" awk -F '\t' '
    NF >= 2 && (tolower($1) == tolower(ENVIRON["WANT"]) || tolower($2) == tolower(ENVIRON["WANT"])) { print; exit }'
}

_model_name() {
  printf '%s' "${1#*"$TAB"}"
}

# The id when the listing has one, otherwise the display name.
_model_arg() {
  local id="${1%%"$TAB"*}"
  if [ -n "$id" ]; then
    printf '%s' "$id"
  else
    _model_name "$1"
  fi
}

# Prints "pattern|prefer|description" for alias $1 (already lowercased).
_alias_row() {
  local want="$1" aliases pattern prefer description
  case "$want" in ""|*,*) return 1 ;; esac
  while IFS='|' read -r aliases pattern prefer description; do
    case ",$aliases," in
      *",$want,"*) printf '%s|%s|%s' "$pattern" "$prefer" "$description"; return 0 ;;
    esac
  done <<<"$MODEL_ALIASES"
  return 1
}

# $1 = output fd, $2 = list_models output (may be empty).
print_model_table() {
  local fd="${1:-2}" models="${2:-}"
  {
    if [ -n "$models" ]; then
      echo "Aliases (case-insensitive), resolved against \`agy models\`:"
    else
      echo "Aliases (case-insensitive). \`agy models\` could not be read, so they are shown unresolved:"
    fi
    local aliases pattern prefer description match target
    while IFS='|' read -r aliases pattern prefer description; do
      target="$description"
      if [ -n "$models" ]; then
        match="$(_newest_match "$models" "$pattern" "$prefer")"
        if [ -n "$match" ]; then
          target="$(_model_name "$match")"
        else
          target="(not available: $description)"
        fi
      fi
      printf '  %-28s  -> %s\n' "$(printf '%s' "$aliases" | sed 's/,/, /g')" "$target"
    done <<<"$MODEL_ALIASES"
    if [ -n "$models" ]; then
      echo
      echo "Available models (names and ids are accepted verbatim, case-insensitive):"
      printf '%s\n' "$models" | awk -F '\t' '{ if ($1 != "") printf "  %-32s  %s\n", $2, $1; else printf "  %s\n", $2 }'
    fi
  } >&"$fd"
}

_current_default_model() {
  [ -f "$AGY_SETTINGS_FILE" ] || return 1
  grep -oE '"model"[[:space:]]*:[[:space:]]*"[^"]*"' "$AGY_SETTINGS_FILE" 2>/dev/null \
    | sed -E 's/.*"model"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/' \
    | head -n1
}

model_value_error() {
  echo "error: --model requires a non-empty value (e.g. --model pro)" >&2
  local path models=""
  if path="$(find_agy)"; then
    models="$(list_models "$path" || true)"
  fi
  print_model_table 2 "$models"
  local current; current="$(_current_default_model 2>/dev/null || true)"
  if [ -n "$current" ]; then
    echo >&2
    echo "Tip: omit --model to use your current default (\"$current\")." >&2
  fi
  exit 64
}

# Prints the value for `agy --model`: the id when `agy models` lists one,
# otherwise the display name.
resolve_model() {
  local path="$1" input="$2"
  local lc; lc="$(printf '%s' "$input" | tr '[:upper:]' '[:lower:]')"
  local row=""; row="$(_alias_row "$lc" || true)"
  local models
  if ! models="$(list_models "$path")" || [ -z "$models" ]; then
    if [ -n "$row" ]; then
      echo "error: could not list models with \`agy models\` (run it directly to see why)." >&2
      echo "       aliases need that list; pass the full model name instead." >&2
      exit 1
    fi
    echo "[wrapper] note: could not list models; passing '$input' to agy unchecked" >&2
    printf '%s' "$input"
    return 0
  fi
  local match pattern prefer description
  match="$(_exact_match "$models" "$input")"
  if [ -z "$match" ] && [ -n "$row" ]; then
    IFS='|' read -r pattern prefer description <<<"$row"
    match="$(_newest_match "$models" "$pattern" "$prefer")"
    [ -n "$match" ] || echo "error: alias '$input' has no matching model in \`agy models\` (expected: $description)" >&2
  elif [ -z "$match" ]; then
    echo "error: unknown model '$input' (not an alias and not listed by \`agy models\`)" >&2
  fi
  if [ -n "$match" ]; then
    _model_arg "$match"
    return 0
  fi
  print_model_table 2 "$models"
  exit 64
}

# Recovers settings.json left patched by a killed 0.4.x run, which swapped
# the model in place instead of passing --model.
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
  rm -rf "$AGY_SETTINGS_LOCKDIR"
}

cmd_ask() {
  local model_alias=""
  local model_flag_seen=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --model)
        model_flag_seen=1
        # `shift 2` on a one-arg list would `set -e`-exit silently; handle
        # the empty case so model_value_error prints the real error.
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
  # Check the value before the prompt so `ask --model` reports the flag.
  if [ "$model_flag_seen" -eq 1 ] && [ -z "$model_alias" ]; then
    model_value_error
  fi
  local prompt="${1:-}"
  shift || true
  if [ -z "$prompt" ]; then
    echo "error: ask requires a prompt argument" >&2
    exit 64
  fi
  local path
  path="$(require_ready)"
  if [ "$model_flag_seen" -eq 1 ]; then
    require_model_support "$path"
    local model
    model="$(resolve_model "$path" "$model_alias")"
    "$path" --model "$model" -p "$prompt" "$@"
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
  local path models=""
  if path="$(find_agy)"; then
    models="$(list_models "$path" || true)"
  fi
  print_model_table 1 "$models"
  cat <<'HELP'

How --model works
  The wrapper reads the model list from `agy models` at call time, resolves
  the alias to the newest matching version, and passes it to agy as
  `--model <id>` (or the display name when the list has no ids) for that
  call only. The default model you picked in the agy TUI is left untouched.

  Names or ids that `agy models` does not list fail with exit 64, and so do
  aliases whose model family your account does not offer. When Google
  rotates model versions, aliases follow without a plugin update.

  Requires agy 1.2.0 or newer.

Underlying CLI
  Run `agy --help` for agy's own flags and `agy models` for the models
  available to your account.
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
