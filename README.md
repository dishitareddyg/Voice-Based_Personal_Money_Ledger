# Voice-Enabled Personal Financial Ledger on Raspberry Pi

A DBMS project that turns spoken financial entries into a secure, server-authoritative
ledger. A Flutter Android app captures speech, parses the confirmed text locally with
deterministic rules, and sends structured JSON over HTTPS to a FastAPI service running
on a Raspberry Pi 4B. The Pi stores financial data in MySQL 8.x and keeps audit,
NLP metadata and exchange-rate cache documents in MongoDB.

Raw audio never leaves the phone. Only the text the user confirms is uploaded, and the
server is the only component allowed to validate balances, mutate loans or convert
currency.

## Components

| Component | Stack | Responsibility |
| --- | --- | --- |
| Mobile app (`mobile_app/`) | Flutter, Dart, Material 3, Riverpod, go_router, Dio | Speech capture, on-device parsing, review UI, HTTPS client |
| API server (`rpi_server/`) | Python 3.11+, FastAPI, SQLAlchemy 2, Alembic, Uvicorn | Auth, financial rules, ledger, loans, reports, admin |
| Relational store | MySQL 8.x (InnoDB) | Users, persons, categories, interest schemes, loans, transactions, repayments |
| Document store | MongoDB 6/7 | Voice metadata, audit logs, application events, FX rate cache |
| Edge | Nginx + systemd | TLS termination, reverse proxy, service supervision |

```
Android phone
  microphone -> SpeechRecognizer -> editable transcript
             -> rule-based Dart parser -> review screen
             -> HTTPS JSON (confirmed text only)
                        |
                        v
                  Nginx (TLS)
                        |
                        v
                FastAPI / Uvicorn
                   |         |
                   |         +--> MongoDB (voice, audit, events, FX cache)
                   +------------> MySQL 8.x (authoritative ledger)
                                        |
                                        +--> exchange-rate provider (HTTPS)
```

## Features

- Voice entry for income, expense, savings, lending, borrowing and repayment.
- On-device NLP only: amounts, dates, intents, people and categories, with a
  confidence score; no LLM and no audio upload.
- Review-before-save flow so the user edits the transcript and confirms the
  structured command.
- One intent-based voice contract (`POST /commands`) mapped on the Pi to the same
  authoritative ledger service as manual entries; failed writes are audited.
- Server-enforced financial rules: non-negative amounts, sufficient balance,
  loan lifecycle, repayment limits, live currency conversion.
- Idempotent writes (`Idempotency-Key` + `request_id`) so network retries never
  duplicate a transaction.
- Dashboard summary, month calendar, paged transaction history, people and
  category directories.
- Role-based admin console limited to whitelisted maintenance commands; no raw
  SQL endpoint.
- Argon2id passwords, JWT access tokens, HTTPS-only deployment.
- Reference schema, views, seed data and 12 report queries for the DBMS report.

## Repository layout

```
dbms_el/
  mobile_app/                 Flutter client (see mobile_app/README.md)
  rpi_server/                 FastAPI service (see rpi_server/README.md)
    app/
      api/                    routes, dependencies, error handlers
      business_rules/         pure financial validation
      core/                   config, enums, security, time, errors
      database/               MySQL session + MongoDB client
      models/                 SQLAlchemy ORM
      repositories/           user-scoped SQL queries
      schemas/                Pydantic v2 request/response models
      services/               transactions, ledger, dashboard, admin
      scripts/                demo seed, password hash, Mongo init
    alembic/                  migrations 0001_initial, 0002_dbms_layer
    deployment/               Nginx, systemd, Pi checklist
    sql/                      schema, views, seed, 12 demo queries
    tests/                    unit, HTTP contract, optional integration
  docs/                       database, architecture, API, deployment, report
  integrations/               API collection, currency checker, Pi smoke script
```

## Quick start

### 1. Raspberry Pi server

```bash
cd rpi_server
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements-dev.txt
cp .env.example .env          # set MySQL, MongoDB, JWT secret
alembic upgrade head
python -m app.scripts.seed_demo
python -m app.scripts.init_mongo   # create collections and indexes
uvicorn app.main:app --host 127.0.0.1 --port 8000
```

OpenAPI docs: `http://127.0.0.1:8000/docs`. Health: `/health` and `/health/ready`.
Production installation with Nginx and systemd is documented in
`rpi_server/deployment/README.md`.

### 2. Flutter app

```bash
cd mobile_app
flutter pub get
flutter run \
  --dart-define=API_BASE_URL=https://192.168.1.42/api/v1 \
  --dart-define=APP_ENV=development
```

Run on a physical Android device and grant microphone permission. Use the Pi's
LAN IP because `.local` mDNS is not always reachable from Android.

Release APK:

```bash
flutter build apk --release \
  --dart-define=API_BASE_URL=https://ledger.example.com/api/v1
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

The current release artifact is
`mobile_app/build/app/outputs/flutter-apk/app-release.apk` (55.2 MB). It is
signed with a local evaluation key; use your own keystore for distribution, as
documented in `rpi_server/deployment/README.md`.

### Demo accounts

`python -m app.scripts.seed_demo` creates the demo ledger and this account:

| Email | Password | Role |
| --- | --- | --- |
| `demo@voiceledger.in` | `Demo@12345` | user |

For an administrator, either set `ADMIN_EMAIL` and `ADMIN_PASSWORD` in `.env` before
starting the API (the bootstrap creates or promotes that account), or run
`rpi_server/sql/seed/001_seed.sql`, which inserts
`admin@voiceledger.in / Admin@12345`. Delete or rotate these accounts before
exposing the server.

## DBMS demonstration on Raspberry Pi

Run the reference DDL and seed on a fresh MySQL database, then inspect the ledger:

```bash
mysql -u root -p < rpi_server/sql/schema/001_schema.sql
mysql -u root -p voice_ledger < rpi_server/sql/schema/002_views.sql
mysql -u root -p voice_ledger < rpi_server/sql/seed/001_seed.sql

mysql -u root -p voice_ledger
```

Useful demonstration commands inside the MySQL shell:

```sql
SHOW TABLES;
SHOW CREATE TABLE transactions\G
SHOW INDEX FROM transactions;
SELECT * FROM v_user_balances;
SELECT * FROM v_open_loans ORDER BY due_date;

SOURCE rpi_server/sql/demo_queries/03_balance.sql;
SOURCE rpi_server/sql/demo_queries/07_lending.sql;
SOURCE rpi_server/sql/demo_queries/11_calendar_transactions.sql;
EXPLAIN ANALYZE
SELECT * FROM transactions
WHERE user_id = 2 AND transaction_date >= CURDATE() - INTERVAL 30 DAY
ORDER BY transaction_date DESC, id DESC
LIMIT 20;
```

The 12 files in `rpi_server/sql/demo_queries/` cover:

| File | Demonstration |
| --- | --- |
| `01_users.sql` | projection, filtering, ordered results |
| `02_transactions.sql` | joins, date ranges, pagination |
| `03_balance.sql` | conditional aggregation and the balance view |
| `04_expense_summary.sql` | monthly grouping, `CASE`, `HAVING` |
| `05_income_summary.sql` | running totals and window functions |
| `06_category_analysis.sql` | category share, ranking, CTEs |
| `07_lending.sql` | lent loans and repayment progress |
| `08_borrowing.sql` | liabilities and per-person net position |
| `09_repayments.sql` | four-table repayment audit trail |
| `10_outstanding_loans.sql` | urgency view, `EXISTS`, correlated subqueries |
| `11_calendar_transactions.sql` | daily/monthly calendar aggregates |
| `12_join_demonstrations.sql` | outer joins, subqueries, `UNION ALL` |

Schema design, normalization arguments, constraints and the query map are in
`docs/database/README.md` and `docs/database-design.md`.

## Financial model

The ledger is an append-only set of completed transactions; balances are derived,
never stored on the user row.

```
available = income + borrowing + repayment(received)
          - expense - savings - lending - repayment(paid)
```

- Amounts are INR, stored as `DECIMAL(15,2)`; non-INR input stores the original
  amount, currency and the exchange rate used.
- Lending/borrowing create a loan with `outstanding = principal`.
- A repayment reduces the matching loan and closes it at zero; overpayment is
  rejected.
- `transaction_date` is a separate `DATE` that preserves user intent; all audit
  timestamps are UTC and rendered as ISO-8601 with `Z`.
- Writes lock the user row (`SELECT ... FOR UPDATE`) and rely on
  `UNIQUE (user_id, request_id)` for idempotency.

Full rules and constraints: `docs/database-design.md` and
`rpi_server/app/business_rules/financial_rules.py`.

## Verification

```bash
# Server
cd rpi_server
.venv/Scripts/ruff check app tests alembic    # Windows; use .venv/bin on Linux
.venv/Scripts/python -m pytest -q
.venv/Scripts/python -m compileall -q app tests alembic

# Mobile
cd mobile_app
flutter analyze
flutter test
```

Latest verification: server `62 passed` against live MySQL 8.0.46 and MongoDB
7.0.37, including the canonical `/commands` success, replay, rejection and audit
path, cross-user isolation, admin password checks, database constraints and live
USD-to-INR conversion; Flutter `57 passed`, analyzers clean, and a signed release
APK builds successfully. The live services also passed
`integrations/pi_smoke_test.sh` end to end. Earlier DBMS validation applied and
rolled back both Alembic migrations, loaded both seed paths independently, and
executed all 12 demo queries. SQLite is deliberately not supported because the
project targets MySQL semantics. The physical Raspberry Pi/Android smoke test
remains deployment-specific.

## Documentation

- `docs/database/README.md` - DBMS quick reference, ER model, constraints, query map.
- `docs/database-design.md` - detailed tables, keys, indexes, normalization,
  concurrency, views and MongoDB usage.
- `docs/architecture/README.md` - component and request-flow summary.
- `docs/architecture.md` - detailed system architecture and security model.
- `docs/api/README.md` - endpoint and error-envelope quick reference.
- `docs/api-contract.md` - complete payloads, status codes and examples.
- `docs/deployment/README.md` - Raspberry Pi deployment and verification checklist.
- `docs/dbms-report.md` - report-ready objectives, design, SQL features and results.
- `integrations/README.md` - runnable HTTP requests and Pi smoke test.

## Scope and limitations

- The mobile parser is English/India oriented and rule-based; unusual phrasing may
  require editing before confirmation.
- Speech recognition depends on the device's Android SpeechRecognizer and network
  availability; the app does not bundle an offline speech model.
- Exchange rates require internet access. If the provider is unreachable the API
  returns `EXCHANGE_RATE_UNAVAILABLE` instead of inventing a rate.
- The system targets a single household/user dataset per deployment; no multi-tenant
  isolation beyond `user_id` scoping is claimed.
