# Voice Ledger API (Raspberry Pi 4B)

FastAPI backend for the Voice-Enabled Personal Financial Ledger. It is the only
component allowed to write financial data, calculate balances, manage loans and
convert currencies. The Flutter client never talks to the database.

```text
Flutter app --HTTPS/JSON--> Nginx --> FastAPI (Uvicorn)
                                      |--> MySQL 8.x   the single database:
                                      |                ledger, auth, audit,
                                      |                voice metadata, events,
                                      |                FX cache
                                      +--> exchange-rate API
```

## Requirements

- Raspberry Pi 4B (2 GB is enough), Raspberry Pi OS 64-bit
- Python 3.11+
- MySQL 8.0.18+
- Nginx (TLS termination)
- Internet access for live exchange rates (optional if all amounts are INR)

## Local setup

```bash
cd rpi_server
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements-dev.txt
cp .env.example .env
# edit .env: MySQL credentials, JWT_SECRET_KEY, optional admin bootstrap
alembic upgrade head
python -m app.scripts.seed_demo
uvicorn app.main:app --reload --port 8000
```

Interactive API documentation: `http://127.0.0.1:8000/docs`.

Health endpoints are intentionally outside the API prefix:

| Endpoint | Meaning |
| --- | --- |
| `GET /health` | process is alive |
| `GET /health/ready` | MySQL reachable (503 when degraded) |

## Configuration

All settings are read from environment variables or `.env` (see
`.env.example`). Important values:

| Variable | Purpose |
| --- | --- |
| `DATABASE_URL` / `MYSQL_*` | MySQL connection (URL wins) |
| `DB_POOL_SIZE`, `DB_MAX_OVERFLOW` | per-worker connection pool (default 5 + 5) |
| `JWT_SECRET_KEY` | token signing; use 64 random bytes in production |
| `ACCESS_TOKEN_EXPIRE_MINUTES` | access-token lifetime (default 12 h) |
| `EXCHANGE_RATE_BASE_URL` | provider root; rate endpoint is `{root}/{BASE}` |
| `EXCHANGE_RATE_CACHE_MINUTES` | how long a fetched rate is trusted |
| `ADMIN_EMAIL` / `ADMIN_PASSWORD` | optional administrator bootstrap |
| `BACKUP_DIR` | destination for `CREATE_BACKUP` |

Secrets must never be committed. Review `.env` before deployment.

## API

Base path: `/api/v1` (configurable through `API_PREFIX`). Every financial
endpoint requires `Authorization: Bearer <jwt>`.

### Auth

| Method | Path | Notes |
| --- | --- | --- |
| POST | `/auth/register` | creates a user, returns token |
| POST | `/auth/login` | email + password |
| GET | `/auth/me` | current profile |
| PATCH | `/auth/me` | full name / timezone |
| POST | `/auth/change-password` | verifies the current password |
| POST | `/auth/logout` | stateless; client discards the token |

### Ledger

| Method | Path | Notes |
| --- | --- | --- |
| POST | `/commands` | confirmed voice command: `intent` + `original_amount` + `request_id` |
| POST | `/transactions` | manual/typed clients: body includes `type` + `request_id` |
| GET | `/transactions` | `page`, `page_size`, `type`, `search`, `from`, `to`, `person_id`, `category_id` |
| GET | `/transactions/{id}` | one transaction |
| GET | `/dashboard/summary` | balances, outstanding loans, recent activity |
| GET | `/calendar?month=YYYY-MM` | per-day aggregates |
| GET | `/loans` | `kind=lent|borrowed`, `status`, `person_id` |
| GET | `/repayments` | `loan_id`, `limit` |

Typed write endpoints fix the transaction type from the URL and therefore do
not accept `type` in the body:

`POST /expenses`, `/income`, `/savings`, `/lending`, `/borrowing`,
`/repayments`. Each also exposes `GET` with the same filters as
`/transactions`.

The voice client uses `POST /commands` with an uppercase `intent` such as
`CREATE_EXPENSE`, `original_amount`, `original_currency`, `category`, `person`
and the confirmed `voice_text`. The server maps it to the same transaction
service, so validation, currency conversion, idempotency and auditing are shared
with the typed endpoints.

### Directories and administration

| Method | Path |
| --- | --- |
| GET/POST | `/persons` (GET supports `search`) |
| PATCH/DELETE | `/persons/{id}` |
| GET/POST | `/categories` (GET supports `type`) |
| PATCH/DELETE | `/categories/{id}` |
| POST | `/admin/actions` |
| GET | `/admin/users` (admin only) |

`POST /admin/actions` accepts only whitelisted commands:

```json
{
  "action": "DATABASE_STATS",
  "password": "admin-password",
  "confirm": true,
  "parameters": {}
}
```

| Action | Effect |
| --- | --- |
| `DATABASE_STATS` | row counts, table sizes, MySQL version, supporting-table counts (`details.supporting_tables`) |
| `RUN_MIGRATIONS` | `alembic upgrade head` (subprocess) |
| `CREATE_BACKUP` | `mysqldump --single-transaction` into `BACKUP_DIR` |
| `OPTIMIZE_INDEXES` | `ANALYZE TABLE` for the fixed table whitelist |
| `PRUNE_RATE_CACHE` | deletes expired rows from `EXCHANGE_RATE_CACHE` |

There is deliberately no arbitrary SQL endpoint. Passwords are verified with
Argon2id and are never logged.

## Financial rules

Available balance (server authoritative, `DECIMAL(15,2)`):

```text
income + borrowing + repayment(received)
  - expense - savings - lending - repayment(paid)
```

- Only `status = 'completed'` transactions count.
- `expense`, `savings` and `lending` check the balance inside the same database
  transaction; insufficient funds return `INSUFFICIENT_BALANCE` with details.
- `lending` / `borrowing` create a loan (`open`, outstanding = principal).
- A repayment needs a direction:
  - `received` -> against a `lent` loan (they pay you back)
  - `paid` -> against a `borrowed` loan (you pay them back)
  - `loan_id` is optional only when the person has exactly one open loan in the
    matching direction; otherwise the API asks for `loan_id`.
- Repayments larger than the outstanding amount are rejected
  (`REPAYMENT_EXCEEDS_OUTSTANDING`). A zero outstanding loan closes.
- `transaction_date` is a `DATE` preserving user intent; audit timestamps are
  UTC.

### Idempotency

Clients send a UUID `request_id` in the body and the same value in the
`Idempotency-Key` header. The database enforces
`UNIQUE (user_id, request_id)`; the user row is locked (`SELECT ... FOR UPDATE`)
during writes and duplicate requests return the original transaction with
`idempotent_replay: true`. Retrying a request can never create two rows.

### Currency

Amounts are stored in INR. For non-INR input the server fetches a live rate,
stores it on the transaction (`original_amount`, `original_currency`,
`exchange_rate_to_inr`), and caches it in MySQL `EXCHANGE_RATE_CACHE` (`DECIMAL(28,12)`, one row per pair, expiring after `EXCHANGE_RATE_CACHE_MINUTES`). INR returns
rate `1` without any network call. If no rate is available the request fails
with `EXCHANGE_RATE_UNAVAILABLE` (503); the server never invents a rate.

## Database design

MySQL tables: `users`, `persons`, `categories`, `interest_schemes`, `loans`,
`transactions`, `repayments`, plus the four supporting tables below.

- `transactions` is the single ledger; all money movements are rows here.
- `income`, `expenses` and `savings` are read-only typed views over
  `transactions`, not duplicate physical tables.
- `loans` tracks principal/outstanding/status per person.
- `repayments` links a repayment transaction to its loan (1:1 via unique
  `transaction_id`).
- `loans.source_transaction_id` and `transactions.loan_id` are circular, so the
  second foreign key is added with `ALTER TABLE` after both tables exist.
- Foreign keys use `CASCADE` for user-owned data and `RESTRICT` / `SET NULL`
  where history must survive.
- CHECK constraints validate enums, positive amounts, valid rates and dates.
- Composite indexes cover the common access paths
  (`user_id + transaction_date`, `user_id + type`, `user_id + category_id`,
  `user_id + person_id`).

Supporting tables (migration `0003_support_tables`; names are upper case and
case-sensitive on Linux):

| Table | Purpose | Key constraints / indexes |
| --- | --- | --- |
| `VOICE_COMMAND` | confirmed text, parser confidence, extraction metadata (`nlp` JSON) | `UNIQUE (user_id, request_id)` for idempotency; FK `user_id` (CASCADE), `transaction_id` (SET NULL); index `(user_id, created_at)` |
| `AUDIT_LOG` | login, committed/rejected financial writes and admin audit trail (`payload` JSON) | FK `user_id` (SET NULL); indexes `(user_id, created_at)`, `request_id`, `(event_type, created_at)` |
| `APPLICATION_EVENT` | auth, lifecycle and operational events (`payload` JSON) | same shape and indexes as `AUDIT_LOG` |
| `EXCHANGE_RATE_CACHE` | short-lived FX cache | `UNIQUE (base_currency, target_currency)`; index `valid_until` for pruning |

Audio is never uploaded or stored. Audit, event and voice-command writes are
best-effort: each uses its own short session/transaction, failures are logged
and never raised, and they never roll back a committed financial transaction.
User isolation is by `user_id`.

Reference DDL: `sql/schema/001_schema.sql`, views: `sql/schema/002_views.sql`,
seed data: `sql/seed/001_seed.sql`, and 12 report queries in
`sql/demo_queries/01_users.sql` through `12_join_demonstrations.sql`.

## Error format

Every failure uses one envelope:

```json
{
  "success": false,
  "error_code": "INSUFFICIENT_BALANCE",
  "message": "Insufficient available balance for this transaction.",
  "request_id": "b4f0a3...",
  "details": {"available_balance": "100.00", "requested_amount": "250.00"}
}
```

Codes include `VALIDATION_ERROR`, `INVALID_AMOUNT`, `INVALID_CURRENCY`,
`INVALID_PERSON`, `INVALID_CATEGORY`, `INVALID_LOAN`, `LOAN_NOT_FOUND`,
`LOAN_CLOSED`, `INSUFFICIENT_BALANCE`, `REPAYMENT_EXCEEDS_OUTSTANDING`,
`INVALID_CREDENTIALS`, `UNAUTHORIZED`, `FORBIDDEN`, `EMAIL_ALREADY_EXISTS`,
`EXCHANGE_RATE_UNAVAILABLE`, `DATABASE_ERROR`, `INTERNAL_ERROR`.

Every response carries `X-Request-ID`; the same id appears in the error body and
in server logs.

## Tests

```bash
pytest                 # unit + HTTP contract tests, no database required
RUN_INTEGRATION=1 pytest -m integration
```

If the test database is not on the default `127.0.0.1:3306`, set
`TEST_DATABASE_URL` for the integration run (the database must already be
migrated with `alembic upgrade head`):

```bash
export TEST_DATABASE_URL='mysql+pymysql://test:test@127.0.0.1:3307/voice_ledger_test?charset=utf8mb4'
RUN_INTEGRATION=1 pytest -m integration
```

Unit tests cover Argon2/JWT, financial rules, Pydantic validation, the currency
service, calendar bounds, error envelopes, SQL assets and the Flutter API
contract (paths and response keys). `tests/test_support_store.py` and the
integration tests need a live MySQL 8 (SQLite is not supported); the
former skip themselves when MySQL is unreachable (`REQUIRE_MYSQL=1` makes that
an error). They cover audit persistence, voice-command idempotency, user
isolation, FX cache expiry and fallback, admin statistics, and model/migration
parity.

## Deployment

- `deployment/voice-ledger-api.service` - systemd unit
- `deployment/nginx.conf` - HTTPS reverse proxy
- `deployment/mysql/my.cnf` - MySQL tuning for a 2 GB Raspberry Pi
- `deployment/README.md` - Raspberry Pi installation checklist
- `migration/legacy_mongo/` - optional one-off import of data exported from the retired document store

Run Uvicorn bound to `127.0.0.1` behind Nginx. Do not expose MySQL or
port 8000 to the internet. Back up with `CREATE_BACKUP` (or a nightly cron job)
and store copies off the Pi.
