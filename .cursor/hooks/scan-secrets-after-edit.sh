#!/usr/bin/env bash
# afterFileEdit: scan only the edited file (fast). Audit-only — always exit 0 so we never break
# the edit pipeline if afterFileEdit does not support deny responses in your Cursor build.

set -euo pipefail

readonly SECRET_PATTERN='(api_key|secret_key|password)[[:space:]]*=.*['\''"][a-zA-Z0-9]{8,}['\''"]'

input="$(cat)"
file_path="$(printf '%s' "$input" | python3 -c '
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get("file_path") or "")
except Exception:
    print("")
' 2>/dev/null || true)"

[[ -z "${file_path}" || ! -f "${file_path}" ]] && exit 0

case "${file_path}" in
*/backend/* | */frontend/*) ;;
*) exit 0 ;;
esac

case "${file_path}" in
*node_modules* | */dist/* | */build/* | */.git/* | *package-lock.json | *pnpm-lock.yaml | *yarn.lock)
  exit 0
  ;;
esac

if grep -qEi "${SECRET_PATTERN}" "${file_path}"; then
  echo "scan-secrets-after-edit: possible secret-like pattern in ${file_path}" >&2
fi

exit 0
