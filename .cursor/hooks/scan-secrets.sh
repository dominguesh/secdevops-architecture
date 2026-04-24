#!/usr/bin/env bash
# beforeShellExecution: scan backend/frontend on disk only when the shell command is likely relevant.
# Cursor sends JSON on stdin (includes hook_event_name, cwd, command). See https://cursor.com/docs/hooks

set -euo pipefail

readonly SECRET_PATTERN='(api_key|secret_key|password)[[:space:]]*=.*['\''"][a-zA-Z0-9]{8,}['\''"]'

# Directories and lockfiles to skip (large trees + noisy false positives)
readonly GREP_IGNORE=(--exclude-dir=node_modules --exclude-dir=dist --exclude-dir=build
  --exclude-dir=.git --exclude-dir=coverage --exclude-dir=.next --exclude-dir=out
  --exclude=package-lock.json --exclude=yarn.lock --exclude=pnpm-lock.yaml)

input="$(cat)"

python_json() {
  printf '%s' "$1" | python3 -c "$2"
}

cwd="$(python_json "$input" 'import sys,json; d=json.load(sys.stdin); print(d.get("cwd") or "")')" || cwd=""
command="$(python_json "$input" 'import sys,json; d=json.load(sys.stdin); print(d.get("command") or "")')" || command=""
wsroot="$(python_json "$input" 'import sys,json; d=json.load(sys.stdin); w=d.get("workspace_roots") or []; print(w[0] if w else "")')" || wsroot=""
[[ -z "${cwd}" ]] && cwd="${PWD}"

deny_json() {
  echo '{"permission":"deny","user_message":"Action blocked: Hardcoded secret detected in your code. Please move it to an environment variable."}'
  exit 2
}

allow_json() {
  echo '{"permission":"allow"}'
  exit 0
}

# Read-only / diagnostic commands: skip full tree scan (cheap allow)
fast_allow_shell() {
  local cmd="$1"
  [[ -z "${cmd}" ]] && return 0
  if [[ "${cmd}" =~ ^(ls|pwd|which|where|type|echo|dirname|basename|uname|whoami|printenv|env)([[:space:]]|$) ]]; then return 0; fi
  if [[ "${cmd}" =~ ^git[[:space:]]+(status|diff|log|branch|show|rev-parse|remote|grep)([[:space:]]|$) ]]; then return 0; fi
  if [[ "${cmd}" =~ ^docker[[:space:]]+(ps|images?|compose[[:space:]]+(ps|ls|top)|version|info)([[:space:]]|$) ]]; then return 0; fi
  return 1
}

# When false, we still allow — we only skip the expensive recursive grep
should_run_tree_scan() {
  local cmd="$1" wd="$2"
  fast_allow_shell "${cmd}" && return 1
  # Terminal cwd already inside app sources → edits likely matter
  if [[ "${wd}" =~ /(frontend|backend)(/|$) ]]; then return 0; fi
  # Command explicitly references app trees
  if [[ "${cmd}" =~ (^|[[:space:];|&])(\./)?(frontend|backend)(/|$|[[:space:]]) ]]; then return 0; fi
  if [[ "${cmd}" =~ (npm|pnpm|yarn|npx|node[[:space:]]|vite|eslint|tsc|docker compose|docker build|docker run|curl|wget|bash|sh |zsh ) ]]; then return 0; fi
  # Default: avoid scanning on every obscure command; rely on preToolUse(Write) + afterFileEdit safety net
  return 1
}

if ! should_run_tree_scan "${command}" "${cwd}"; then
  allow_json
fi

root=""
if [[ -n "${wsroot}" ]] && { [[ -d "${wsroot}/backend" ]] || [[ -d "${wsroot}/frontend" ]]; }; then
  root="${wsroot}"
fi
if [[ -z "${root}" ]]; then
  root="${cwd}"
  case "${cwd}" in
  */frontend|*/frontend/*)
    root="${cwd%%/frontend*}"
    ;;
  */backend|*/backend/*)
    root="${cwd%%/backend*}"
    ;;
  esac
fi

check_dirs=()
[[ -d "${root}/backend" ]] && check_dirs+=("${root}/backend")
[[ -d "${root}/frontend" ]] && check_dirs+=("${root}/frontend")

if ((${#check_dirs[@]})); then
  if grep -rEi "${SECRET_PATTERN}" "${GREP_IGNORE[@]}" "${check_dirs[@]}" 2>/dev/null; then
    deny_json
  fi
fi

allow_json
