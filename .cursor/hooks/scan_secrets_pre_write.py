"""preToolUse Write: deny if tool_input strings match hardcoded-secret heuristics."""

import json
import re
import sys

_PATTERN = re.compile(
    r"(api_key|secret_key|password)\s*=\s*['\"][a-zA-Z0-9]{8,}['\"]",
    re.IGNORECASE,
)


def _collect_strings(obj: object, out: list[str]) -> None:
    if isinstance(obj, str):
        out.append(obj)
    elif isinstance(obj, dict):
        for v in obj.values():
            _collect_strings(v, out)
    elif isinstance(obj, list):
        for v in obj:
            _collect_strings(v, out)


def main() -> None:
    raw = sys.stdin.read()
    try:
        payload = json.loads(raw)
    except json.JSONDecodeError:
        print('{"permission":"allow"}')
        return

    if payload.get("tool_name") != "Write":
        print('{"permission":"allow"}')
        return

    inp = payload.get("tool_input") or {}
    strings: list[str] = []
    _collect_strings(inp, strings)

    msg = (
        "Write blocked: payload matches a hardcoded secret pattern. "
        "Use environment variables or secret storage instead."
    )

    for s in strings:
        if _PATTERN.search(s):
            print(json.dumps({"permission": "deny", "user_message": msg}))
            sys.exit(2)

    print('{"permission":"allow"}')


if __name__ == "__main__":
    main()
