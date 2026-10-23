"""Permission relay helpers for agy-run.sh.

Headless `agy -p` cannot prompt for permissions, so it auto-denies them.
These helpers let the wrapper hand the decision back to Claude Code:

  grant  <settings.json> <rule>...   add exact allow rules; print the ones added
  revoke <settings.json> <rule>...   remove those rules again
  report <stdout-file> <stderr-file> <rc>
                                     print agy's response; if agy denied
                                     commands, append a permission-request
                                     block and exit 75
"""

import fcntl
import json
import os
import sys
import tempfile
from contextlib import contextmanager

EXIT_PERMISSION_REQUEST = 75
BRAIN_DIR = os.path.expanduser("~/.gemini/antigravity-cli/brain")


@contextmanager
def _locked(settings_path):
    with open(settings_path + ".agy-plugin.flock", "w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        try:
            yield
        finally:
            fcntl.flock(lock, fcntl.LOCK_UN)


def _rewrite_allow(settings_path, mutate):
    with _locked(settings_path):
        with open(settings_path) as f:
            data = json.load(f)
        allow = data.setdefault("permissions", {}).setdefault("allow", [])
        changed = mutate(allow)
        if not allow:
            del data["permissions"]["allow"]
            if not data["permissions"]:
                del data["permissions"]
        fd, tmp = tempfile.mkstemp(dir=os.path.dirname(settings_path))
        with os.fdopen(fd, "w") as f:
            json.dump(data, f, indent=2)
            f.write("\n")
        os.chmod(tmp, os.stat(settings_path).st_mode & 0o777)
        os.replace(tmp, settings_path)
        return changed


def grant(settings_path, rules):
    def mutate(allow):
        added = [r for r in dict.fromkeys(rules) if r not in allow]
        allow.extend(added)
        return added

    for rule in _rewrite_allow(settings_path, mutate):
        print(rule)


def revoke(settings_path, rules):
    def mutate(allow):
        allow[:] = [r for r in allow if r not in rules]

    _rewrite_allow(settings_path, mutate)


def _parse_json_output(text):
    for line in reversed(text.strip().splitlines()):
        line = line.strip()
        if line.startswith("{"):
            try:
                return json.loads(line)
            except ValueError:
                continue
    return None


def _denied_from_transcript(conversation_id):
    """Exact tool calls denied in the latest turn of the conversation."""
    path = os.path.join(BRAIN_DIR, conversation_id, ".system_generated", "logs",
                        "transcript_full.jsonl")
    commands, others = [], []
    try:
        lines = open(path).read().splitlines()
    except OSError:
        return commands, others
    last_calls = []
    for line in lines:
        try:
            step = json.loads(line)
        except ValueError:
            continue
        if step.get("type") == "USER_INPUT":
            commands, others = [], []
        if step.get("tool_calls"):
            last_calls = step["tool_calls"]
        error = step.get("error") or ""
        if step.get("status") != "ERROR" or "denied permission" not in error:
            continue
        for call in last_calls:
            args = call.get("args") or {}
            if call.get("name") == "run_command" and args.get("CommandLine"):
                if args["CommandLine"] not in commands:
                    commands.append(args["CommandLine"])
            else:
                target = args.get("Path") or args.get("AbsolutePath") or args.get("Url") or ""
                entry = "%s %s" % (call.get("name"), target)
                if entry.strip() and entry not in others:
                    others.append(entry.strip())
    return commands, others


def report(stdout_path, stderr_path, rc):
    out = open(stdout_path).read()
    err = open(stderr_path).read()
    result = _parse_json_output(out)
    if result is None:
        sys.stdout.write(out)
        sys.stderr.write(err)
        sys.exit(int(rc) or 1)

    response = result.get("response") or ""
    if response:
        print(response.rstrip())

    denied = result.get("denied_actions") or []
    if not denied:
        if result.get("status") != "SUCCESS":
            sys.stderr.write(err)
            sys.exit(int(rc) or 1)
        return

    conversation_id = result.get("conversation_id", "")
    commands, others = _denied_from_transcript(conversation_id)
    if not commands and not others:
        others = sorted({d.get("action", "?") for d in denied})
    print()
    print("[agy-permission-request]")
    print("conversation_id: %s" % conversation_id)
    for command in commands:
        print("command: %s" % command)
    for other in others:
        print("other: %s" % other)
    print("[/agy-permission-request]")
    sys.exit(EXIT_PERMISSION_REQUEST)


def main(argv):
    if len(argv) < 2:
        sys.exit(__doc__)
    cmd, args = argv[1], argv[2:]
    if cmd == "grant":
        grant(args[0], args[1:])
    elif cmd == "revoke":
        revoke(args[0], args[1:])
    elif cmd == "report":
        report(*args[:3])
    else:
        sys.exit("unknown subcommand: %s" % cmd)


if __name__ == "__main__":
    main(sys.argv)
