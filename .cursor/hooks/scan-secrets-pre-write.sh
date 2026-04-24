#!/usr/bin/env bash
# Delegates to Python so we parse Write payloads reliably.
set -euo pipefail
exec python3 "$(dirname "$0")/scan_secrets_pre_write.py"
