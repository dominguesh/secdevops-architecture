# Security and engineering controls matrix

This matrix maps **controls** in this repository to **mechanisms** and **locations**. It supports portfolio review (solutions architecture / security engineering) and operational onboarding.

---

## 1. Configuration management and secrets

| ID | Control | Implementation | Evidence |
|----|---------|------------------|----------|
| CM-1 | No production secrets in Git | `.gitignore` excludes `.env`, `.env.*` (with `.env.example` exception pattern) | Root `.gitignore` |
| CM-2 | Template for local configuration | `.env.example` documents variables without real values | `.env.example` |
| CM-3 | Runtime secrets from environment | Backend uses `process.env` (`DATABASE_URL`, `PORT`); Compose passes dev defaults only for local use | `backend/app.js`, `docker-compose.dev.yml` |

---

## 2. Automated policy (editor / agent)

| ID | Control | Implementation | Evidence |
|----|---------|------------------|----------|
| POL-1 | Block / gate obvious hardcoded secret patterns in shell activity | `beforeShellExecution` → `scan-secrets.sh` (`failClosed: true`) | `.cursor/hooks.json` |
| POL-2 | Block **Write** payloads matching secret heuristics | `preToolUse` + matcher `Write` → `scan-secrets-pre-write.sh` | `.cursor/hooks.json`, `scan_secrets_pre_write.py` |
| POL-3 | Audit after file edit (warning path) | `afterFileEdit` + matcher `Write` → `scan-secrets-after-edit.sh` (`failClosed: false`) | `.cursor/hooks.json` |
| POL-4 | Repeatable health verification (not enforcement) | Skill `env-health` | `.cursor/skills/env-health/SKILL.md` |

**Note:** Hooks are **heuristic**; they complement — not replace — code review, threat modeling, and production secret stores (e.g. Vault, cloud SM).

---

## 3. Network exposure (development)

| ID | Control | Implementation | Evidence |
|----|---------|------------------|----------|
| NET-1 | Database not bound to host by default | No `ports` on `db` in base `docker-compose.dev.yml` | `docker-compose.dev.yml` |
| NET-2 | Optional explicit DB exposure for GUI tools | Overlay `docker-compose.dev.db-host.yml` publishes `5432` only when merged | `docker-compose.dev.db-host.yml` |
| NET-3 | Internal service discovery | Services on `webapp1_network`; DNS names `frontend`, `backend`, `db` | Compose files |

---

## 4. Availability and ordering (development)

| ID | Control | Implementation | Evidence |
|----|---------|------------------|----------|
| AV-1 | Postgres readiness before dependent services | `db` healthcheck; `backend` `depends_on` with `condition: service_healthy` | `docker-compose.dev.yml` |

---

## 5. Production image hardening (summary)

| ID | Control | Implementation | Evidence |
|----|---------|------------------|----------|
| IMG-1 | Non-root API process | `USER node`, Alpine base | `backend/Dockerfile.prod` |
| IMG-2 | Reproducible dependency install | `npm ci --omit=dev` with lockfile | `backend/Dockerfile.prod` |
| IMG-3 | Multi-stage frontend; static runtime | Build stage → `nginxinc/nginx-unprivileged`, non-root nginx, port 8080 | `frontend/Dockerfile.prod`, `frontend/nginx.prod.conf` |
| IMG-4 | Smaller build contexts | `.dockerignore` at root and under apps | Various `.dockerignore` |

---

## 6. Documentation and traceability

| ID | Control | Implementation | Evidence |
|----|---------|------------------|----------|
| DOC-1 | Architecture and operational narrative | `docs/ARCHITECTURE.md` | Repo |
| DOC-2 | Controls matrix (this file) | `docs/CONTROLS.md` | Repo |
| DOC-3 | Stack and security rules for agents | `.cursor/rules/*.mdc` | Repo |

---

## 7. Runtime access edge (self-hosted portfolio)

| ID | Control | Implementation | Evidence |
|----|---------|----------------|----------|
| EDGE-1 | Self-hosted deployment narrative (control and auditability) | Documented preference for **self-hosted** operations vs cloud PaaS as the default portfolio story | [docs/ARCHITECTURE.md](ARCHITECTURE.md) §1.1 |
| EDGE-2 | Identity-aware / tunneled reverse proxy (Pangolin) | **Pangolin** as access and publication layer; deny-by-default publication model per vendor docs | [docs/ARCHITECTURE.md](ARCHITECTURE.md) §1.1; [Pangolin documentation](https://docs.pangolin.net/) |
| EDGE-3 | Zero-trust access principles | Explicit identity/policy-driven access; complements policy-as-code in `.cursor/` | [docs/ARCHITECTURE.md](ARCHITECTURE.md) §1.1 |

---

## 8. Planned (not yet implemented here)

| ID | Planned control | Notes |
|----|-----------------|-------|
| PL-1 | CI: image vulnerability scan, Hadolint, `npm audit` | Add GitHub Actions or equivalent |
| PL-2 | Multi-tenant / multi-app DB isolation strategy | Document per-app DB vs schema vs RLS; implement per product needs |
| PL-3 | Centralized secrets in prod (no Compose defaults) | Map to target platform |

---

*Update this matrix when controls or files change.*
