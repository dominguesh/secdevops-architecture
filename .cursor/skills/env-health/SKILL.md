---
name: env-health
description: Verifies local Docker Compose dev stack health and basic repo security hygiene for this webapp-1 reference project. Use when the user asks for an environment health check, pre-flight, dev sanity check, secure setup verification, or before deploy/feature work; also when validating that frontend, backend, and db match docs/ARCHITECTURE.md.
---

# Environment health and security (local dev)

## Separation of concerns

- **Secrets enforcement** is handled by **Cursor hooks** (`.cursor/hooks.json`): `scan-secrets.sh` before shell execution, `scan-secrets-pre-write.sh` / `scan-secrets-after-edit.sh` on Write — do not duplicate blocking logic here.
- This skill instructs **verification and reporting**: run checks, summarize pass/fail, and point to fixes or documentation.

## Preconditions

- Shell at the **repository root** (where `docker-compose.dev.yml` lives).
- **Docker** daemon available (Docker Desktop or equivalent).

## Health checks (execute and report)

Run these unless the user has already provided equivalent output:

1. **Compose services**
   - `docker compose -f docker-compose.dev.yml ps`
   - Expect **frontend**, **backend**, **db** Up when using the default dev stack.
   - If the user enabled **tools**: `docker compose -f docker-compose.dev.yml --profile tools ps` — **dev-workstation** appears only with that profile.

2. **HTTP endpoints**
   - Frontend (Vite): `curl -sf -o /dev/null -w "%{http_code}" http://127.0.0.1:5173/` → expect **200**.
   - Backend (Express): `curl -sf http://127.0.0.1:3000/` → expect body indicating API is alive (e.g. current root handler).

3. **Database readiness** (from host)
   - Preferred: `docker compose -f docker-compose.dev.yml exec -T db pg_isready -U webapp1 -d webapp1` → exit **0**.
   - If **db** is not running, note it before other DB checks.

4. **Optional Postgres on host**
   - Default compose **does not** publish **5432**. If the user uses **`docker-compose.dev.db-host.yml`**, localhost DB access is expected; otherwise connecting only via **`db:5432`** inside the network is normal — do not flag as failure.

5. **Architecture alignment**
   - Compare results to [docs/ARCHITECTURE.md](../../../docs/ARCHITECTURE.md) (services, ports, profiles, overlays).

## Security hygiene (verify, do not replace hooks)

1. **Git / env files**
   - Confirm `.env` is not tracked: e.g. `git check-ignore -v .env 2>/dev/null` or `git status --ignored` as appropriate; `.gitignore` should list `.env`.
   - Remind: copy from `.env.example` for local overrides; inject secrets with **1Password** (`op`) per project standards — never commit real secrets.

2. **Compose secrets**
   - Dev credentials in `docker-compose.dev.yml` are **local-only** defaults; warn if the user plans to reuse them outside local Docker.

3. **Hooks**
   - If a check touches `frontend/` or `backend/` source, hooks may run — if something is blocked, explain it references **hardcoded secret patterns** and remediation (environment variables), without bypassing policy.

## Output format

Produce a short report:

```markdown
## Environment health

| Check | Result | Notes |
|-------|--------|--------|
| ... | Pass/Fail | ... |

## Security hygiene

| Item | Result | Notes |
|------|--------|--------|

## Follow-ups
- ...
```

Keep notes actionable (exact command or file). If anything is unclear, ask one focused question.

## When checks cannot run

If Docker or `curl` is unavailable in the environment, state that limitation and fall back to **read-only** review of `docker-compose.dev.yml`, `docs/ARCHITECTURE.md`, and `.gitignore` / `.env.example`.
