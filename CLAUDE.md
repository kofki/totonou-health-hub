# CLAUDE.md — Health Hub ("Blueprint OS")

## Project Overview
Personal health command center: Garmin Connect + VeSync ingestion, custom analytics dashboard,
CV-powered food/calorie tracking, body-fat and acne estimation, and meal recommendations from a
personal meal library. Goal: a Bryan Johnson-style personal health assistant.

**Dual purpose:** this is BOTH an impact project AND a learning project.
The owner (human) is learning: Java Spring Boot, ML/DS (computer vision, analytics), and
multi-service backend architecture. Claude must NEVER rob the owner of learning opportunities.

---

## ⚠️ RULES FOR CLAUDE (Fable 5) — READ BEFORE EVERY TASK

### 🔒 OVERRIDE (added 2026-07-05, supersedes everything below):
Claude may write code for ONLY two reasons:
1. **Solving dependency issues** (broken builds, version conflicts, tooling/env problems)
2. **Prototyping ideas** — first-draft prototypes in `/_scratch/` for the owner to study/rewrite

Nothing else. All other code — including areas previously delegated to Claude (integrations,
React Native screens, CRUD boilerplate, CI/CD, Dockerfiles) — is now written by the owner.
For everything else Claude may still: explain concepts, review code, quiz, plan, and write
documentation (prose, not code).

### Claude MUST NOT write (owner codes these manually):
- Core data model / JPA entities & relationships
- Spring Boot service-layer business logic
- Spring Security / JWT auth configuration
- Anything in `ml-service/` involving model selection, training, feature engineering,
  or inference logic (calorie estimation, body-fat CV, acne detection, insight engine)
- The Spring Boot ↔ Python service communication contract (owner designs it)
- Meal recommendation algorithm

If asked to help with the above: explain concepts, review the owner's code, generate a
**first-draft example in a scratch file** for the owner to rewrite — never commit finished
implementations of these areas.

### Claude SHOULD handle (delegated work — ⚠️ superseded by the OVERRIDE above; owner now codes these, Claude prototypes/advises only):
- Garmin / VeSync API integration glue: OAuth flows, webhook handlers, retry/rate-limit logic
- React Native screens, components, charts, camera capture UI
- Meal library CRUD endpoints (boilerplate only, after owner defines entities)
- Test scaffolding + edge-case debugging AFTER owner's core logic works
- DevOps: Dockerfiles, docker-compose, CI/CD (GitHub Actions), deployment configs
- Repo scaffolding, linting, formatting, documentation

### Hybrid learning protocol
For NEW Spring Boot concepts: Claude generates a first-draft module in `/_scratch/` →
owner rewrites it line-by-line in the real codebase → Claude reviews the rewrite and
quizzes the owner on any annotation/pattern they can't explain.

---

## Stack
| Layer | Tech | Who builds it |
|---|---|---|
| Main API | Java 21 + Spring Boot 3 (REST, JPA/Hibernate, Spring Security) | Owner |
| ML service | Python 3.12 + FastAPI, PyTorch/timm for CV models | Owner (logic) / Claude (deploy) |
| Frontend | React Native (Expo) | Claude |
| DB | PostgreSQL (metrics, meals, users) + object storage for images | Owner (schema) / Claude (infra) |
| Integrations | Garmin Connect API, VeSync API | Claude |
| Infra | Docker Compose local, GitHub Actions CI | Claude |

## Repo Layout (monorepo)
```
health-hub/
├── CLAUDE.md                  # this file
├── api/                       # Spring Boot main API (OWNER territory)
│   └── src/main/java/com/healthhub/
│       ├── entity/            # OWNER ONLY
│       ├── repository/
│       ├── service/           # OWNER ONLY
│       ├── security/          # OWNER ONLY
│       ├── integration/       # Claude: Garmin/VeSync clients
│       └── controller/
├── ml-service/                # Python FastAPI (OWNER logic)
│   ├── models/                # OWNER ONLY: training, weights, inference
│   ├── app/                   # OWNER: endpoints; Claude may scaffold
│   └── notebooks/             # OWNER: EDA + experiments
├── mobile/                    # React Native app (Claude territory)
├── infra/                     # Claude: docker, CI, deploy
└── _scratch/                  # Claude's teaching drafts — never imported by real code
```

## Git Workflow
- `main` protected. Branches: `feat/`, `learn/` (owner's learning work), `claude/` (delegated).
- Owner reviews and merges ALL `claude/` PRs — no self-merge.
- Claude reviews `learn/` PRs with teaching-style feedback (explain, don't rewrite).
- Conventional commits. CI must pass (build + tests) before merge.

## Phases
1. **Foundation** (Owner-heavy): data model, Spring Boot core, auth. Claude: repo + CI + RN shell.
2. **Integrations** (Claude-heavy): Garmin/VeSync ingestion. Owner: designs ingestion interface, rewrites one integration for learning.
3. **ML/DS** (Owner-heavy): calorie CV model, body-fat + acne models, FastAPI service, insight engine. Claude: test scaffolds + deployment.
4. **Frontend** (Claude-heavy): dashboard, charts, camera flows.
5. **Meal engine** (Owner): recommendation logic. Claude: meal library CRUD + UI.
6. **Polish** (Claude): CI/CD hardening, monitoring, docs.

## Definition of "Owner Learned It"
A concept is learned when the owner can (a) explain every line/annotation, (b) rebuild it
without reference, and (c) pass Claude's quiz on failure modes. Until then, it stays owner-territory.
