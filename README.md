# ShopStream - Capstone Build Sprint

Multi-tenant e-commerce backend: **PostgreSQL** (core, RLS, audit) + **Redis** (cart/cache) + **MongoDB** (events).

## Deliverables map
| Deliverable | Where |
|-------------|-------|
| Requirements summary | `docs/01_requirements.md` |
| ER diagram | `docs/er_diagram.dbml` (dbdiagram.io), `docs/er_diagram.mmd` (Mermaid) |
| Design review notes | `docs/02_design_review.md` |
| Versioned migrations V1-V5 | `db/migration/` |
| NoSQL layer + justification | `nosql/`, `app/`, `docs/03_nosql_justification.md` |
| Query optimization evidence | `optimization/` (run script generates `optimization_report.md`) |
| Backup & security artifacts | `scripts/`, `security/checklist.md`, `tests/` |
| Presentation | `docs/04_presentation.md` |

## Quick start
```bash
cp .env.example .env          # edit passwords
docker compose up -d          # postgres, redis, mongo
set -a; source .env; set +a

flyway -configFiles=flyway.conf clean migrate     # or: make migrate-docker
./scripts/setup_roles.sh                          # passwords for app roles

pip install -r requirements.txt
python -m app.demo                                # cart -> checkout -> events -> RLS proof
./scripts/verify_security.sh                      # run BEFORE bulk data

./optimization/run_optimization.sh                # loads 300k orders, writes the report
./scripts/backup.sh && ./scripts/restore_test.sh  # backup + proven restore
```

## Day-by-day checklist
- [ ] Day 1: export ER diagram PNG to `docs/`, get feedback, fill `docs/02_design_review.md`
- [ ] Day 2: `flyway clean migrate` succeeds from empty DB (screenshot it)
- [ ] Day 3: `python -m app.demo` output saved
- [ ] Day 4: `optimization/optimization_report.md` generated from YOUR machine
- [ ] Day 5: `verify_security.sh` all PASS, restore test pasted into `security/checklist.md`, present

## Important notes
- **Not yet executed.** The files were written without a database available, so run the quick start once and fix anything that differs on your machine before submitting. The optimization numbers can only come from your own run.
- Flyway 9+ blocks `clean` unless `cleanDisabled=false` (set in `flyway.conf`). Only use on a dev DB.
- Run `verify_security.sh` on the seed data; the demo checkout adds rows but checks stay valid.
