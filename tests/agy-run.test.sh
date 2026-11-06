#!/usr/bin/env bash
# Tests for plugins/agy/scripts/agy-run.sh, run against a stub `agy` binary.
# Usage: bash tests/agy-run.test.sh

set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WRAPPER="$ROOT/plugins/agy/scripts/agy-run.sh"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

mkdir -p "$WORK/bin"
cat > "$WORK/bin/agy" <<'STUB'
#!/usr/bin/env bash
case "${1:-}" in
  --version) echo "${STUB_VERSION:-agy 1.4.10}"; exit 0 ;;
  models)
    echo "Fetching available models..." >&2
    if [ -n "${STUB_MODELS_FAIL:-}" ]; then
      echo "error: unknown command \"models\"" >&2
      exit 2
    fi
    cat "$STUB_MODELS_FILE"
    exit 0 ;;
esac
printf '%s\n' "$@" > "$STUB_ARGS_FILE"
echo "stub-response"
STUB
chmod +x "$WORK/bin/agy"

MODELS_NAMES="$WORK/models-names.txt"
cat > "$MODELS_NAMES" <<'EOF'
Gemini 3.8 Flash (High)
Gemini 3.8 Flash (Medium)
Gemini 3.8 Flash (Low)
Gemini 3.7 Flash (High)
Gemini 3.7 Flash (Medium)
Gemini 3.7 Flash (Low)
Gemini 3.6 Flash (High)
Gemini 3.6 Flash (Medium)
Gemini 3.6 Flash (Low)
Gemini 3.1 Pro (High)
Gemini 3.1 Pro (Low)
Claude Sonnet 4.6 (Thinking)
Claude Opus 4.6 (Thinking)
GPT-OSS 120B (Medium)
EOF

MODELS_IDS="$WORK/models-ids.txt"
printf '%s\t%s\n' \
  "gemini-3.8-flash-high" "Gemini 3.8 Flash (High)" \
  "gemini-3.8-flash-medium" "Gemini 3.8 Flash (Medium)" \
  "gemini-3.8-flash-low" "Gemini 3.8 Flash (Low)" \
  "claude-sonnet-4-6" "Claude Sonnet 4.6 (Thinking)" \
  "claude-opus-4-6-thinking" "Claude Opus 4.6 (Thinking)" \
  "gpt-oss-120b-medium" "GPT-OSS 120B (Medium)" > "$MODELS_IDS"

MODELS_CRLF="$WORK/models-crlf.txt"
sed 's/$/\r/' "$MODELS_IDS" > "$MODELS_CRLF"

MODELS_TIES="$WORK/models-ties.txt"
cat > "$MODELS_TIES" <<'EOF'
Claude Opus 4.6
Claude Opus 4.6 (Thinking)
GPT-OSS 120B (Low)
GPT-OSS 120B (Medium)
EOF

MODELS_NEWER="$WORK/models-newer.txt"
cat > "$MODELS_NEWER" <<'EOF'
Gemini 3.9 Flash (High)
Gemini 3.10 Flash (High)
Gemini 3.2 Pro (High)
Gemini 3.1 Pro (High)
Claude Opus 4.6 (Thinking)
Claude Opus 5 (Thinking)
EOF

PASS=0
FAIL=0
OUT=""
ERR=""
RC=0

run_wrapper() {
  local home="$WORK/home"
  rm -rf "$home" "$WORK/args"
  mkdir -p "$home/.gemini/antigravity-cli"
  printf '{\n  "model": "Gemini 3.8 Flash (Medium)"\n}\n' > "$home/.gemini/antigravity-cli/settings.json"
  [ -z "${SETUP_HOME:-}" ] || "$SETUP_HOME" "$home/.gemini/antigravity-cli"
  RC=0
  OUT="$(env HOME="$home" PATH="$WORK/bin:$PATH" ANTIGRAVITY_API_KEY=test \
    STUB_ARGS_FILE="$WORK/args" STUB_MODELS_FILE="${MODELS_FILE:-$MODELS_NAMES}" \
    STUB_VERSION="${AGY_VERSION:-agy 1.4.10}" STUB_MODELS_FAIL="${MODELS_FAIL:-}" \
    bash "$WRAPPER" "$@" 2>"$WORK/stderr")" || RC=$?
  ERR="$(cat "$WORK/stderr")"
}

passed_args() {
  [ -f "$WORK/args" ] && cat "$WORK/args"
}

check() {
  local name="$1"; shift
  if "$@"; then
    PASS=$((PASS + 1))
    echo "ok   - $name"
  else
    FAIL=$((FAIL + 1))
    echo "FAIL - $name"
    echo "       rc=$RC"
    echo "       stdout: $(printf '%s' "$OUT" | head -n 5 | tr '\n' '|')"
    echo "       stderr: $(printf '%s' "$ERR" | head -n 5 | tr '\n' '|')"
    echo "       agy args: $(passed_args | tr '\n' '|')"
  fi
}

called_with_model() {
  local expected="$1"
  [ "$RC" -eq 0 ] || return 1
  [ "$(passed_args)" = "$(printf '%s\n' --model "$expected" -p "hello")" ]
}

not_called() {
  [ ! -f "$WORK/args" ]
}

exited() {
  [ "$RC" -eq "$1" ]
}

stderr_has() {
  case "$ERR" in *"$1"*) return 0 ;; esac
  return 1
}

stdout_has() {
  case "$OUT" in *"$1"*) return 0 ;; esac
  return 1
}

stdout_lacks() {
  case "$OUT" in *"$1"*) return 1 ;; esac
  return 0
}

test_flash_resolves_to_newest_listed_version() {
  run_wrapper ask --model flash hello
  called_with_model "Gemini 3.8 Flash (High)"
}

test_flash_tiers_resolve() {
  run_wrapper ask --model flash-low hello
  called_with_model "Gemini 3.8 Flash (Low)" || return 1
  run_wrapper ask --model FLASH-MED hello
  called_with_model "Gemini 3.8 Flash (Medium)"
}

test_tab_separated_listing_passes_id() {
  MODELS_FILE="$MODELS_IDS" run_wrapper ask --model opus hello
  called_with_model "claude-opus-4-6-thinking"
}

test_crlf_listing() {
  MODELS_FILE="$MODELS_CRLF" run_wrapper ask --model sonnet hello
  called_with_model "claude-sonnet-4-6"
}

test_ties_prefer_thinking_and_medium() {
  MODELS_FILE="$MODELS_TIES" run_wrapper ask --model opus hello
  called_with_model "Claude Opus 4.6 (Thinking)" || return 1
  MODELS_FILE="$MODELS_TIES" run_wrapper ask --model gpt-oss hello
  called_with_model "GPT-OSS 120B (Medium)"
}

test_versions_compare_numerically() {
  MODELS_FILE="$MODELS_NEWER" run_wrapper ask --model flash hello
  called_with_model "Gemini 3.10 Flash (High)" || return 1
  MODELS_FILE="$MODELS_NEWER" run_wrapper ask --model pro hello
  called_with_model "Gemini 3.2 Pro (High)" || return 1
  MODELS_FILE="$MODELS_NEWER" run_wrapper ask --model opus hello
  called_with_model "Claude Opus 5 (Thinking)"
}

test_display_name_passes_through() {
  run_wrapper ask --model "Gemini 3.7 Flash (Low)" hello
  called_with_model "Gemini 3.7 Flash (Low)"
}

test_display_name_is_case_insensitive() {
  run_wrapper ask --model "claude opus 4.6 (thinking)" hello
  called_with_model "Claude Opus 4.6 (Thinking)"
}

test_model_id_passes_through() {
  MODELS_FILE="$MODELS_IDS" run_wrapper ask --model GEMINI-3.8-FLASH-HIGH hello
  called_with_model "gemini-3.8-flash-high"
}

test_display_name_maps_to_id() {
  MODELS_FILE="$MODELS_IDS" run_wrapper ask --model "Gemini 3.8 Flash (Low)" hello
  called_with_model "gemini-3.8-flash-low"
}

test_backslash_escapes_are_literal() {
  run_wrapper ask --model 'Gemini 3.8 Flash \050High\051' hello
  exited 64 && not_called
}

test_equals_form() {
  run_wrapper ask --model=pro-low hello
  called_with_model "Gemini 3.1 Pro (Low)"
}

test_retired_model_is_rejected() {
  run_wrapper ask --model "Gemini 3.5 Flash (High)" hello
  exited 64 && not_called && stderr_has "Gemini 3.8 Flash (High)"
}

test_unknown_alias_is_rejected() {
  run_wrapper ask --model flsh hello
  exited 64 && not_called && stderr_has "flsh"
}

test_alias_list_is_not_an_alias() {
  run_wrapper ask --model flash,flash-high hello
  exited 64 && not_called
}

test_alias_without_listed_model_is_rejected() {
  MODELS_FILE="$MODELS_IDS" run_wrapper ask --model pro hello
  exited 64 && not_called && stderr_has "pro"
}

test_empty_model_value_is_rejected() {
  run_wrapper ask --model= hello
  exited 64 && not_called && stderr_has "non-empty" || return 1
  run_wrapper ask --model
  exited 64 && not_called && stderr_has "non-empty"
}

test_no_model_flag_calls_agy_plainly() {
  run_wrapper ask hello
  exited 0 && [ "$(passed_args)" = "$(printf '%s\n' -p hello)" ]
}

test_extra_args_follow_prompt() {
  run_wrapper ask --model flash hello --sandbox
  exited 0 && [ "$(passed_args)" = "$(printf '%s\n' --model "Gemini 3.8 Flash (High)" -p hello --sandbox)" ]
}

test_settings_file_is_not_modified() {
  run_wrapper ask --model opus hello
  exited 0 || return 1
  [ "$(cat "$WORK/home/.gemini/antigravity-cli/settings.json")" = "$(printf '{\n  "model": "Gemini 3.8 Flash (Medium)"\n}')" ] \
    && [ ! -e "$WORK/home/.gemini/antigravity-cli/settings.json.agy-plugin.bak" ]
}

test_agy_older_than_1_2_is_rejected() {
  AGY_VERSION="1.1.9" run_wrapper ask --model flash hello
  exited 1 && not_called && stderr_has "agy update" && stderr_has "1.1.9"
}

test_agy_1_2_and_newer_are_accepted() {
  AGY_VERSION="1.2.0" run_wrapper ask --model flash hello
  called_with_model "Gemini 3.8 Flash (High)" || return 1
  AGY_VERSION="agy version 1.10.0 (build abc)" run_wrapper ask --model flash hello
  called_with_model "Gemini 3.8 Flash (High)"
}

test_unparseable_version_is_not_blocking() {
  AGY_VERSION="dev" run_wrapper ask --model flash hello
  called_with_model "Gemini 3.8 Flash (High)"
}

test_listing_failure_rejects_alias() {
  MODELS_FAIL=1 run_wrapper ask --model flash hello
  exited 1 && not_called && stderr_has "agy models"
}

test_listing_failure_passes_full_name_through() {
  MODELS_FAIL=1 run_wrapper ask --model "Gemini 3.9 Flash (High)" hello
  called_with_model "Gemini 3.9 Flash (High)"
}

test_help_shows_live_resolution() {
  MODELS_FILE="$MODELS_IDS" run_wrapper help
  exited 0 \
    && stdout_has "Gemini 3.8 Flash (High)" \
    && stdout_has "gemini-3.8-flash-high" \
    && stdout_lacks "3.5 Flash" \
    && stdout_lacks "settings.json"
}

leave_dead_patch() {
  cp "$1/settings.json" "$1/settings.json.agy-plugin.bak"
  printf '{\n  "model": "Claude Opus 4.6 (Thinking)"\n}\n' > "$1/settings.json"
  printf '%s\n%s\n' 2147483646 "Claude Opus 4.6 (Thinking)" > "$1/.agy-plugin.patched"
  mkdir -p "$1/.agy-plugin.lock"
}

leave_live_patch() {
  leave_dead_patch "$1"
  printf '%s\n%s\n' "$$" "Claude Opus 4.6 (Thinking)" > "$1/.agy-plugin.patched"
}

leave_backup_only() {
  printf 'stale\n' > "$1/settings.json.agy-plugin.bak"
}

settings_model_is() {
  grep -q "\"model\": \"$1\"" "$WORK/home/.gemini/antigravity-cli/settings.json"
}

test_recovers_settings_from_killed_0_4_run() {
  local dir="$WORK/home/.gemini/antigravity-cli"
  SETUP_HOME=leave_dead_patch run_wrapper ask hello
  exited 0 && settings_model_is "Gemini 3.8 Flash (Medium)" \
    && [ ! -e "$dir/settings.json.agy-plugin.bak" ] \
    && [ ! -e "$dir/.agy-plugin.patched" ] \
    && [ ! -e "$dir/.agy-plugin.lock" ]
}

test_leaves_settings_of_running_0_4_call() {
  local dir="$WORK/home/.gemini/antigravity-cli"
  SETUP_HOME=leave_live_patch run_wrapper ask hello
  exited 0 && settings_model_is "Claude Opus 4.6 (Thinking)" \
    && [ -e "$dir/settings.json.agy-plugin.bak" ] \
    && [ -e "$dir/.agy-plugin.patched" ]
}

test_removes_backup_without_sentinel() {
  SETUP_HOME=leave_backup_only run_wrapper ask hello
  exited 0 && settings_model_is "Gemini 3.8 Flash (Medium)" \
    && [ ! -e "$WORK/home/.gemini/antigravity-cli/settings.json.agy-plugin.bak" ]
}

test_help_without_listing() {
  MODELS_FAIL=1 run_wrapper help
  exited 0 && stdout_has "flash" && stdout_has "agy models" && stdout_lacks "3.5 Flash"
}

for t in $(declare -F | awk '{print $3}' | grep '^test_'); do
  check "${t#test_}" "$t"
done

echo
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
