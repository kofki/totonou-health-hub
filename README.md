# Health Hub ("Blueprint OS")

Personal health command center: Garmin Connect + VeSync ingestion, custom analytics
dashboard, CV-powered food/calorie tracking, body-fat and acne estimation, and meal
recommendations from a personal meal library.

> Dual purpose: impact project AND learning project (Java Spring Boot, ML/DS, multi-service
> backend architecture). See `CLAUDE.md` for the owner/Claude division of labor and
> `DOCUMENTATION.md` for architecture, decisions, and the ticket index.

## Services

| Directory | What | Stack | Port (local) |
|---|---|---|---|
| `api/` | Main API | Java 21, Spring Boot 3, Gradle | 8080 |
| `ml-service/` | CV + analytics | Python 3.12, FastAPI | 8000 |
| `ingestion/` | Garmin/VeSync sync worker | Python 3.12 | — |
| `mobile/` | iOS/Android app | React Native (Expo, TypeScript) | 8081 (Metro) |
| `infra/` | Local dev stack | Docker Compose (Postgres 16, fake-gcs-server) | 5432 / 4443 |

## Quickstart

```bash
# 1. Infra (Postgres + GCS emulator)
cp infra/.env.example infra/.env
docker compose -f infra/docker-compose.yml up -d

# 2. API (after the owner writes Application.java — see _scratch/)
cd api && ./gradlew bootRun

# 3. ML service
cd ml-service && pip install -e ".[dev]" && uvicorn app.main:app --reload

# 4. Ingestion worker
cd ingestion && pip install -e ".[dev]" && python -m worker

# 5. Mobile
cd mobile && npm install && npx expo start
```

Install on your iPhone via Xcode: see `docs/ios-install.md`.

## Repo rules
- `main` is protected. Branches: `feat/`, `learn/` (owner learning work), `claude/` (delegated).
- Conventional commits. CI must pass before merge.
- Owner-only territory is marked with a `README.md` inside each directory — Claude never
  implements those areas (entities, service logic, security, ML models, meal algorithm).
