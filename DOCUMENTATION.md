# Totonou Health Hub — Project Documentation

Living document. Architecture, decisions, roadmap, and ticket index.
Last updated: 2026-07-06.

**Naming note:** the project was renamed from "Health Hub" to "Totonou Health Hub" on
2026-07-06. "Totonou" (整う) is Japanese for reaching a state of perfect physical/mental
balance — the word wellness/sauna culture uses for full-body equilibrium, which fits a
system optimizing your whole health picture. Internal directory names (`health-hub/`,
`com.healthhub` Java package) were kept as-is to avoid a disruptive rename mid-scaffold;
only user-facing names (app display name, README, docs) changed.

---

## 1. Architecture

```
                        ┌──────────────────────────────┐
                        │   Garmin watch / VeSync scale │
                        └──────────────┬───────────────┘
                                       │ python-garminconnect / pyvesync
                              ┌────────▼────────┐
                              │   ingestion/    │  Python worker (scheduled sync)
                              └────────┬────────┘
                                       │ REST push (contract designed by OWNER)
┌───────────────┐  REST   ┌────────────▼─────────────┐   JDBC   ┌──────────────┐
│    mobile/    ├────────►│          api/            ├─────────►│ PostgreSQL 16 │
│  Expo RN app  │◄────────┤  Spring Boot 3 (Java 21) │          └──────────────┘
└───────┬───────┘         └────────────┬─────────────┘
        │ photo upload                 │ REST (contract designed by OWNER)
        │                    ┌─────────▼─────────┐        ┌──────────────────┐
        └───────────────────►│    ml-service/    ├───────►│ GCS bucket        │
                             │  FastAPI + PyTorch │        │ (local: fake-gcs) │
                             └───────────────────┘        └──────────────────┘
```

### Service responsibilities
- **api/** — source of truth. Users, health metrics, meals, insights persistence. OWNER
  builds entities/services/security; Claude builds integration glue + CRUD boilerplate later.
- **ml-service/** — computer vision (calorie estimation, body-fat, acne) + insight engine.
  OWNER builds all model logic; Claude scaffolds deployment and tests.
- **ingestion/** — pulls Garmin/VeSync data on a schedule and pushes normalized payloads to
  the api. Claude territory (integration glue).
- **mobile/** — dashboard, camera capture, meal library UI. Claude territory.

### Port map (local dev)
| Service | Port |
|---|---|
| Spring Boot api | 8080 |
| FastAPI ml-service | 8000 |
| Expo Metro bundler | 8081 |
| PostgreSQL | 5432 |
| fake-gcs-server (GCS emulator) | 4443 |

---

## 2. Decision log

| Date | Decision | Rationale |
|---|---|---|
| 2026-07-05 | Cloud storage = **GCP Cloud Storage**; local dev uses `fake-gcs-server` | Owner wants GCP experience; emulator lets the same `google-cloud-storage` client run locally and in prod. See `docs/gcp-storage.md`. |
| 2026-07-05 | Garmin/VeSync ingestion = **Python worker** with `python-garminconnect` + `pyvesync` | Official Garmin API needs developer-program approval (slow, may reject personal use). Community libs work with the owner's own login today. Owner may rewrite one integration in Java later as a Phase 2 learning exercise. |
| 2026-07-05 | Build tool = **Gradle (Groovy DSL)** | Spring Initializr default; most tutorial coverage for learning. |
| 2026-07-05 | CV calorie model = **pretrained scaffold first** (timm/HF Food-101-class models), owner wires + fine-tunes; commercial API only as optional benchmark | Preserves the learning mandate; avoids paying for an API before knowing the accuracy bar. See `docs/cv-approach.md`. |
| 2026-07-05 | iOS distribution = **Expo prebuild → Xcode**, signing decision deferred | Free Apple ID = 7-day resign cycle; $99/yr = 1-year signing + TestFlight. See `docs/ios-install.md`. |
| 2026-07-05 | Comment policy | Only `Example:` (teaching) and `TODO:` (owner work) comments allowed in code. |

---

## 3. File structure

```
health-hub/
├── CLAUDE.md              # rules of engagement (owner vs Claude territory)
├── README.md              # overview + quickstart
├── DOCUMENTATION.md       # this file
├── .github/workflows/     # CI: api.yml, mobile.yml, python.yml
├── api/                   # Spring Boot 3 main API
│   └── src/main/java/com/healthhub/
│       ├── entity/        # OWNER ONLY — JPA entities
│       ├── repository/    # owner fills (Spring Data interfaces)
│       ├── service/       # OWNER ONLY — business logic
│       ├── security/      # OWNER ONLY — Spring Security + JWT
│       ├── integration/   # Claude — receives ingestion pushes (Phase 2)
│       └── controller/    # owner fills; Claude adds CRUD boilerplate later
├── ml-service/            # FastAPI CV/insights service
│   ├── app/               # endpoints (Claude scaffolded /health; owner adds the rest)
│   ├── models/            # OWNER ONLY — training, weights, inference
│   └── notebooks/         # OWNER ONLY — EDA + experiments
├── ingestion/             # Python sync worker (Claude)
│   └── worker/            # garmin.py, vesync.py, config.py
├── mobile/                # Expo React Native app (Claude)
│   └── src/screens/       # Dashboard, Food, Meals, Settings
├── infra/                 # docker-compose.yml, .env.example
├── docs/                  # ios-install.md, cv-approach.md, gcp-storage.md
└── _scratch/              # Claude teaching drafts — never imported by real code
```

---

## 4. Phase roadmap

1. **Foundation** — data model, Spring core, auth (Owner). Repo/CI/RN shell/infra (Claude). ← *current*
2. **Integrations** — ingestion workers (Claude); owner designs ingestion→API contract, rewrites one integration to learn.
3. **ML/DS** — calorie CV, body-fat, acne, insight engine (Owner). Test scaffolds + deploy (Claude).
4. **Frontend** — dashboard charts, camera flows (Claude).
5. **Meal engine** — recommendation logic (Owner); CRUD + UI (Claude).
6. **Polish** — CI/CD hardening, monitoring, docs (Claude).

---

## 5. Ticket index

All tickets live in Notion: [Health Hub — Tickets](https://app.notion.com/p/ab4ea652b6484df3a0bd1eea1e516d4b)
(database under the ⌚ Garmin Connect UI project page). Ticket IDs follow `P<phase>-<number>`;
each has Status, Phase, Assignee (Owner/Claude), Priority (P0–P2), and Area.

| Phase | Tickets |
|---|---|
| 1 - Foundation | P1-01 repo scaffolding · P1-02 docker compose · P1-03 CI · P1-04 Spring skeleton · P1-05 OWNER Application.java · P1-06 OWNER entities · P1-07 OWNER security/JWT · P1-08 Expo shell · P1-09 iOS/Xcode |
| 2 - Integrations | P2-01 Garmin worker · P2-02 VeSync worker · P2-03 OWNER ingestion→API contract · P2-04 GCS bucket |
| 3 - ML/DS | P3-01 OWNER calorie CV · P3-02 OWNER body-fat/acne · P3-03 FastAPI scaffold |
| 4 - Frontend | P4-01 dashboard charts + camera |
| 5 - Meal Engine | P5-01 OWNER recommendation algorithm · P5-02 CRUD + UI |
| 6 - Polish | P6-01 branch protection + PR flow |

---

## 6. Who builds what (recap from CLAUDE.md)

Claude never writes: JPA entities, service-layer logic, Spring Security/JWT, ML
model/training/inference code, the Spring↔Python contract, or the meal recommendation
algorithm. For those areas Claude may only: explain concepts, review owner code, and drop
first-draft teaching examples in `_scratch/` for the owner to rewrite.
