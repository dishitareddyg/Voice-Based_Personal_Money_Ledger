# Voice-Enabled Personal Financial Ledger Management System Using Raspberry Pi

## Project Report

**Domain:** Database Management Systems
**Client:** Flutter (Android)
**Server:** Raspberry Pi 4B, FastAPI, MySQL 8.x
**Primary key idea:** voice input parsed on-device, with a server-authoritative,
idempotent relational ledger

---

## Abstract

Manual expense tracking fails for two reasons: entry is slow, and recorded numbers are
not trustworthy. This project builds a personal financial ledger that accepts spoken
entries while keeping a single, auditable source of truth on a low-cost Raspberry Pi.
The Android client converts speech to text locally, parses the confirmed sentence with
a deterministic rule-based engine, and sends only structured JSON over HTTPS. The
server validates the command, enforces balance and loan rules, writes the transaction
inside a MySQL transaction, and returns the recomputed balance.

Financial records are stored in a normalized MySQL 8.x schema with foreign keys,
unique and CHECK constraints, and composite indexes. Confirmed voice metadata,
audit/application events and the exchange-rate cache live in the same MySQL
database as four supporting tables (`VOICE_COMMAND`, `AUDIT_LOG`,
`APPLICATION_EVENT`, `EXCHANGE_RATE_CACHE`) that use `JSON` payloads, indexed
columns and unique keys. Idempotency keys and row-level locking prevent duplicate
transactions and lost-update anomalies during retries or concurrent writes. The
implementation is verified with unit tests, HTTP contract tests, a complete
register-to-repayment flow, and a Flutter test suite.

**Keywords:** DBMS, personal finance, voice interface, MySQL, transaction
processing, idempotency, Raspberry Pi, Flutter, FastAPI.

---

## 1. Introduction

### 1.1 Problem statement

People record expenses inconsistently. Mobile forms require many taps, spreadsheets
allow contradictory edits, and cloud apps make users trust an invisible balance.
A useful personal ledger must make entry fast, prevent invalid states (for example,
spending more cash than available), and keep history consistent when the network
retries a request.

### 1.2 Proposed solution

A voice-first Android application backed by a home-hosted Raspberry Pi:

1. The user speaks a sentence such as "spent eight hundred and fifty rupees on
   groceries".
2. On-device speech recognition produces editable text.
3. A deterministic parser extracts intent, amount, currency, date, person and
   category.
4. The user reviews the structured command.
5. The server applies financial rules and writes the ledger in MySQL.
6. The app refreshes balances from the server.

### 1.3 Objectives

- Provide hands-free creation of six transaction types.
- Keep all balances and loan states server-authoritative.
- Guarantee exactly one ledger row per client request, even under retries.
- Demonstrate relational design: normalization, keys, constraints, indexes, joins,
  aggregates, views, transactions and concurrency control.
- Demonstrate relational handling of semi-structured data: indexed columns plus
  MySQL `JSON` for events, voice metadata and the FX cache.
- Deploy on affordable hardware with HTTPS, systemd and backups.
- Preserve privacy: raw audio never leaves the phone.

### 1.4 Scope

In scope: single-user ledger accounts, persons, categories, loans, repayments,
dashboard, calendar, history, administrative maintenance, INR plus live currency
conversion.

Out of scope: bank feeds, multi-tenant organizations, investment portfolios, offline
write queues, and generative-AI language understanding.

---

## 2. Literature and Technology Review

### 2.1 Relational databases for financial records

Financial records benefit from ACID transactions and declarative constraints.
MySQL 8.x with InnoDB provides row-level locking, foreign keys, multi-statement
transactions, `DECIMAL` arithmetic and window functions. Storing money as
`DECIMAL(15,2)` avoids the rounding errors of binary floating point.

### 2.2 Semi-structured data in a relational store

Voice metadata and audit events have heterogeneous payloads (confirmed text,
parser confidence, admin parameters) and are written far more often than they are
joined. MySQL 8's native `JSON` type stores those payloads without a second
database server, while indexed relational columns (`user_id`, `event_type`,
`request_id`, `created_at`) keep the common filters fast. Uniqueness on
`(user_id, request_id)` gives voice retries the same idempotency guarantee as the
ledger, and `DECIMAL(18,8)` keeps FX rates exact. These tables are deliberately
not authoritative for money.

### 2.3 On-device speech and rule-based NLP

Android's `SpeechRecognizer` is available without a paid cloud service. A
deterministic parser over the confirmed transcript is transparent, testable and
private. It avoids the latency, cost and non-determinism of an LLM while covering the
constrained sentence patterns of personal finance.

### 2.4 Edge deployment

A Raspberry Pi 4B with 2 GB RAM can run Nginx, Uvicorn and MySQL for a single
household. systemd restarts services; Nginx terminates TLS. The MySQL buffer pool
is capped at 256 MB and `performance_schema` is disabled so the OS and API retain
memory. This demonstrates a complete deployment without cloud infrastructure or
a second database server.

---

## 3. Requirement Analysis

### 3.1 Functional requirements

| ID | Requirement |
| --- | --- |
| FR-1 | Register and log in with email and password |
| FR-2 | Capture speech, show an editable transcript, require confirmation |
| FR-3 | Parse income, expense, savings, lending, borrowing and repayment commands |
| FR-4 | Record transactions with date, amount, currency, category, person and notes |
| FR-5 | Compute the available balance on the server |
| FR-6 | Create loans for lending/borrowing and reduce them through repayments |
| FR-7 | Reject overpayment, invalid direction and insufficient balance |
| FR-8 | List transactions with pagination and filters |
| FR-9 | Show dashboard totals, category split, recent activity and upcoming repayments |
| FR-10 | Show a month calendar with per-day totals |
| FR-11 | Manage persons and categories |
| FR-12 | Convert non-INR amounts using a live provider rate |
| FR-13 | Replay duplicate requests without creating extra rows |
| FR-14 | Let administrators run only whitelisted maintenance commands |
| FR-15 | Record audit events for logins, writes and admin actions |

### 3.2 Non-functional requirements

| ID | Requirement |
| --- | --- |
| NFR-1 | Server-authoritative balances; the client never computes money |
| NFR-2 | All write endpoints idempotent per `request_id` |
| NFR-3 | Passwords stored with Argon2id; transport protected by TLS |
| NFR-4 | Raw audio never uploaded; only confirmed text in audit |
| NFR-5 | UTC timestamps; `Asia/Kolkata` default display timezone |
| NFR-6 | Foreign keys and unique constraints enforce integrity |
| NFR-7 | Paged reads indexed by `(user_id, ...)` |
| NFR-8 | No arbitrary SQL execution path |
| NFR-9 | Clear machine-readable error envelope |
| NFR-10 | Runs on Raspberry Pi 4B with 2 GB RAM |

### 3.3 Hardware and software

| Item | Choice |
| --- | --- |
| Server hardware | Raspberry Pi 4B, 2 GB+, 32 GB microSD/SSD |
| OS | Raspberry Pi OS 64-bit |
| Runtime | Python 3.11+ |
| Web framework | FastAPI + Uvicorn |
| ORM/migrations | SQLAlchemy 2.x + Alembic |
| RDBMS | MySQL 8.x (InnoDB, utf8mb4, native JSON) |
| Edge | Nginx (TLS), systemd |
| Client | Flutter/Dart, Material 3, Riverpod, go_router, Dio |
| Client storage | `flutter_secure_storage` (Android Keystore) |
| Speech | Android `SpeechRecognizer` via `speech_to_text` |
| Testing | pytest, FastAPI TestClient, flutter_test |

---

## 4. System Design

### 4.1 Architecture

```
Flutter app
  speech -> text -> rule parser -> review -> HTTPS JSON
                                              |
                                         Nginx (TLS)
                                              |
                                        FastAPI service
                                              |
                                         MySQL 8.x
                             ledger, loans, users, categories,
                             voice metadata, audit/events, FX cache
```

Layer responsibilities:

- **Presentation (Flutter):** capture, parsing, review, display.
- **API (FastAPI routes):** HTTP validation and authentication.
- **Service layer:** transaction boundaries, financial rules, loan lifecycle.
- **Repository layer:** user-scoped SQL queries.
- **Persistence:** MySQL for financial facts and for the four supporting tables
  (voice metadata, audit/events and FX cache).

### 4.2 Process design for a write

1. Authenticate JWT and load the active user.
2. Require `Idempotency-Key` equal to body `request_id`.
3. Begin a database transaction.
4. `SELECT ... FOR UPDATE` the user row.
5. Look up `(user_id, request_id)`; replay if present.
6. Resolve person/category, compute balance, validate rules.
7. Insert transaction; create/update loan and repayment rows.
8. Commit.
9. Best-effort audit/application/voice rows in MySQL through an independent
   session.
10. Return transaction plus new balance.

### 4.3 Entity-relationship model

The full ER diagram is in `docs/database-design.md`. Core relationships:

- A user owns persons, categories, loans, transactions and repayments.
- A person participates in many loans, transactions and repayments.
- A category classifies many transactions.
- A lending/borrowing transaction creates one loan.
- A repayment reduces one loan and is linked 1:1 to its transaction.

### 4.4 Schema summary

| Table | Purpose | Key constraints |
| --- | --- | --- |
| `users` | accounts | unique email |
| `persons` | counterparties | unique `(user_id, name)` |
| `categories` | labels | unique `(user_id, name, type)` |
| `interest_schemes` | reusable rates + compounding | unique `(user_id, name)` |
| `loans` | principal/outstanding lifecycle | unique `source_transaction_id` |
| `transactions` | every money movement | unique `(user_id, request_id)` |
| `repayments` | loan repayments | unique `transaction_id` |
| `VOICE_COMMAND` | confirmed voice metadata | unique `(user_id, request_id)` |
| `AUDIT_LOG` | security audit trail | indexes on user/event/request |
| `APPLICATION_EVENT` | lifecycle events | indexes on user/event/request |
| `EXCHANGE_RATE_CACHE` | FX cache | unique `(base_currency, target_currency)` |

The circular reference between `loans.source_transaction_id` and
`transactions.loan_id` is resolved by adding one foreign key with `ALTER TABLE`
after both tables exist.

### 4.5 Normalization

The design satisfies 1NF (atomic columns), 2NF (single-column keys) and 3NF
(descriptive attributes depend on the key). Two deliberate derivations are
documented:

- `loans.outstanding_amount_inr` is a lifecycle state updated atomically with each
  repayment, not independently editable data.
- Transaction FX columns preserve the historical original amount and rate so later
  rate changes cannot rewrite history.

Balances are **not** stored; they are aggregated from completed transactions.

---

## 5. Implementation

### 5.1 Repository structure

```
mobile_app/        Flutter client
rpi_server/
  app/api/         routes, dependencies, exception handlers
  app/services/    transaction, ledger, dashboard, auth, admin
  app/business_rules/financial_rules.py
  app/models/      SQLAlchemy mappings
  app/schemas/     Pydantic request/response models
  app/repositories/user-scoped queries
  alembic/         migration 0001_initial
  sql/             DDL, views, seed, 12 report queries
  tests/           unit, contract, integration (gated)
docs/              design and report
integrations/      HTTP collection and Pi smoke script
```

### 5.2 Authentication and security

- Passwords hashed with Argon2id (`argon2-cffi`).
- JWT HS256 access tokens with `sub`, `role`, `iat`, `exp`.
- `require_admin` dependency for administration.
- Admin actions re-verify the administrator password and require `confirm: true`.
- Admin commands are an enum; SQL text is never accepted from the client.
- All read/write queries are scoped by `user_id`, preventing horizontal access.
- Nginx terminates TLS; Uvicorn binds to loopback.

### 5.3 Financial rules

Implemented as pure functions in `app/business_rules/financial_rules.py` and invoked
under the write transaction:

- amount > 0 and at most 15 digits with 2 decimals,
- outflows (`expense`, `savings`, `lending`) require sufficient balance,
- lending/borrowing require a person and create a loan,
- repayment direction must match loan kind,
- repayment cannot exceed outstanding,
- a zero outstanding loan is closed,
- currency conversion uses only a live/cached provider rate.

### 5.4 Balance computation

```sql
SELECT SUM(
  CASE
    WHEN type = 'income' THEN amount_inr
    WHEN type = 'borrowing' THEN amount_inr
    WHEN type = 'repayment' AND repayment_direction = 'received' THEN amount_inr
    ELSE -amount_inr
  END
) AS available_balance
FROM transactions
WHERE user_id = ? AND status = 'completed';
```

This is the only balance formula; the mobile app displays the returned value.

### 5.5 Idempotency and concurrency

The client sends a UUID as both `request_id` (body) and `Idempotency-Key` (header).
The server:

1. locks the user row to serialize that user's writes,
2. checks `(user_id, request_id)`,
3. replays the existing transaction if found,
4. otherwise inserts; `UNIQUE(user_id, request_id)` backstops races,
5. catches `IntegrityError`, rolls back, reloads and replays.

The replay response sets `idempotent_replay: true` and `duplicate: true`.

### 5.6 Currency conversion

- INR requires no network call (rate = 1).
- Non-INR: check `EXCHANGE_RATE_CACHE` for an unexpired row; otherwise call the
  configured provider (`{base_url}/{BASE}`), read `rates["INR"]`, and upsert the
  row with `DECIMAL(18,8)` precision.
- Store `original_amount`, `original_currency` and `exchange_rate_to_inr`.
- If the provider fails, return `503 EXCHANGE_RATE_UNAVAILABLE`; never fabricate a
  rate.

### 5.7 Voice parsing on the client

The Dart parser recognizes:

- intents from verbs such as spent/paid, received/salary, saved, lent, borrowed,
  repaid;
- Indian and international amount formats, including words and lakh/crore;
- relative dates (today, yesterday), weekdays and explicit dates;
- person names introduced by "to/from";
- category keywords mapped to the user's categories.

A confidence score drives a review warning. The user can always edit the transcript
and the structured fields before saving.

### 5.8 Administrative maintenance

| Command | Implementation |
| --- | --- |
| `DATABASE_STATS` | counts, MySQL version, table sizes, supporting-table counts |
| `RUN_MIGRATIONS` | Alembic subprocess |
| `CREATE_BACKUP` | `mysqldump --single-transaction` |
| `OPTIMIZE_INDEXES` | `ANALYZE TABLE` on a fixed whitelist |
| `PRUNE_RATE_CACHE` | delete expired `EXCHANGE_RATE_CACHE` rows |

### 5.9 SQL features used

- DDL with `BIGINT`, `DECIMAL(15,2)`, `DECIMAL(18,8)`, `DATE`, `DATETIME`,
  `utf8mb4` and native `JSON`.
- Primary, foreign, unique and check-by-code constraints.
- `ON DELETE CASCADE / RESTRICT / SET NULL` chosen per relationship.
- Composite indexes for user-scoped access paths.
- Conditional aggregation (`CASE`), joins, `COALESCE`, `DATE_FORMAT`.
- Window functions (`RANK`, `LAG`, `SUM OVER`), CTEs and correlated subqueries.
- Views `v_user_balances` and `v_open_loans`, plus read-only typed views
  `income`, `expenses` and `savings` over the central ledger.
- CHECK constraints for enums, positive amounts, interest rates and valid dates.
- `EXPLAIN ANALYZE` for the history query.
- `SELECT ... FOR UPDATE` for concurrency control.

### 5.10 Mobile application

The Flutter client contains 19 screens across auth, voice, dashboard, calendar,
history, ledger entry, people, categories, profile, settings and admin. State is
managed with Riverpod; navigation uses go_router. Dio interceptors add the bearer
token, retry safe requests, map errors and attach request ids. Tokens live in the
Android Keystore. The UI never calls HTTP directly; repositories are injected through
providers.

---

## 6. Testing and Results

### 6.1 Test strategy

| Level | Tool | What is checked |
| --- | --- | --- |
| Unit | pytest | Argon2/JWT, financial rules, schemas, currency cache, calendar bounds |
| SQL assets | pytest + sqlglot | every SQL file parses; demo columns resolve against the reference schema and views |
| HTTP contract | FastAPI TestClient | health, error envelope, OpenAPI paths and response keys |
| Flow | HTTP harness | register, income, expense, lending, repayment, dashboard, calendar, admin denial |
| Mobile unit/widget | flutter_test | formatters, parser, review flow, repositories |
| Supporting storage | pytest | voice upsert idempotency, user isolation, audit/event persistence, FX cache expiry and fallback |
| Integration (gated) | pytest `RUN_INTEGRATION=1` | live MySQL flow and supporting tables |

SQLite is deliberately excluded from the test suite because the project depends on
MySQL semantics (locking, `DECIMAL`, `ANALYZE`, dump behavior).

### 6.2 Results

| Check | Result |
| --- | --- |
| `ruff check app tests alembic` | clean |
| `pytest` | `66 passed, 2 skipped` (unit/contract; live integration gated), including `/commands` and supporting-table tests |
| `flutter analyze` | no issues |
| `flutter test` | 57 passed |
| Android release APK | built and signed (`app-release.apk`, 55.2 MB) |
| SQL syntax + column resolution (sqlglot, MySQL dialect) | all 15 files parsed, all demo columns resolved |
| `python -m compileall` | clean |
| Alembic offline SQL | generated successfully, including the circular-FK `ALTER` |
| Alembic live migration | upgrade, downgrade to base and re-upgrade passed on MySQL 8.0.46 |
| Reference SQL seed | 16 transactions, balance `62250.00`, all 12 demo queries passed |
| Python demo seed | same balance, loans and 12 demo queries passed |
| Reference SQL vs Alembic schema | matching definitions: 145 columns, 43 indexes, 29 checks, 5 views |
| Live integration flow | register through repayment, `/commands`, `VOICE_COMMAND`/`AUDIT_LOG`/`APPLICATION_EVENT` writes passed |
| Release matrix | auth failures/expiry, IDOR, SQL-injection search, admin password/confirmation, FK/unique constraints, rollback, live FX/cache passed |
| `integrations/pi_smoke_test.sh` | `PASS` against local Uvicorn + MySQL |

The flow harness verified:

- registration and JWT use,
- income followed by an idempotent replay (no double credit),
- voice intent expense with category auto-creation and a 100000 rejection audit,
- expense with category auto-creation and insufficient-balance rejection,
- lending creating a loan, repayment reducing outstanding,
- overpayment rejection (`REPAYMENT_EXCEEDS_OUTSTANDING`),
- dashboard totals, recent activity and upcoming repayments,
- filtered/paged transactions, calendar, persons and categories,
- 404 handling and 403 for non-admin maintenance.

### 6.3 Sample verification output

```
$ pytest -q
66 passed, 2 skipped        # live integration gated behind RUN_INTEGRATION=1

$ RUN_INTEGRATION=1 pytest -q
passed                      # against live MySQL 8.0.46
```

The committed integration test exercised registration, idempotent replay,
insufficient-balance rejection, lending, repayment, dashboard totals, the
statement, and the `VOICE_COMMAND`/`AUDIT_LOG`/`APPLICATION_EVENT` writes. It
also covers the canonical `/commands` payload with a successful 2000-grocery
expense, an idempotent replay, a 100000 rejection and its `AUDIT_LOG` rejection
row. The release matrix adds wrong-password and expired-JWT handling, cross-user
IDOR and SQL-injection search attempts, admin password/confirmation enforcement,
foreign key and unique-constraint failures, rollback atomicity, and live non-INR
conversion with `EXCHANGE_RATE_CACHE` caching. Supporting-storage tests verify
voice upsert idempotency, per-user isolation, audit persistence, cache expiry and
the external-provider fallback.

### 6.4 Observations

- Row locking plus the unique request key eliminated duplicate writes in retry tests.
- Computing balances by aggregation kept the user row small and removed an update
  hotspot; the composite `(user_id, transaction_date)` index kept history queries
  fast on demo data.
- Returning decimal strings avoided client-side floating-point drift.

---

## 7. Limitations

1. Speech quality depends on Android's recognizer and network; the app has no bundled
   offline acoustic model.
2. The parser targets common English/India phrasings; unusual sentences need manual
   correction.
3. Live integration tests require MySQL; they were verified on MySQL 8.0.46
   during development but remain skipped when the service is unavailable. Repeat
   them on the target Raspberry Pi hardware.
4. The deployment targets a single household; authorization is per user, but there is
   no organization/tenant layer.
5. There is no automated nightly backup scheduler in the code; `CREATE_BACKUP` is
   invoked through the admin command or an external cron job.
6. Voice metadata, audit logs and application events are best-effort; a failure
   writing a supporting row can lose that row without affecting the ledger. When
   MySQL itself is unavailable, financial writes also fail, as expected.

---

## 8. Future Scope

- Offline draft queue with explicit conflict resolution and replay.
- Recurring transactions and reminders.
- Budgets per category with alerts.
- Loan interest accrual schedules and amortization reports.
- Multi-currency wallets with historical revaluation reports.
- Read replicas or managed MySQL for larger households.
- On-device offline speech model.
- Export to CSV/PDF and tax-year summaries.
- Automated encrypted backups shipped off the Pi.

---

## 9. Conclusion

The project demonstrates a complete database-backed system rather than a form over a
spreadsheet. A normalized MySQL schema enforces integrity; server-side rules keep
balances and loans consistent; idempotency and row locking make retries safe; MySQL
`JSON` columns handle event-shaped data without weakening the ledger or adding a
second database server; and the Raspberry Pi proves that a private, low-cost
deployment is practical. Voice input reduces entry friction,
while the review step and deterministic parser keep the user in control of what is
recorded.

The most important design decision is the separation of authority: the phone may
suggest a command, but only the Pi decides what is financially valid and what the
balance is.

---

## 10. References

1. MySQL 8.0 Reference Manual - InnoDB, transactions, indexes, window functions,
   native `JSON` and `DECIMAL` arithmetic.
2. FastAPI documentation - dependency injection and OpenAPI.
3. SQLAlchemy 2.0 documentation - ORM mappings and session transactions.
4. Flutter and Dart documentation - Material 3, Riverpod, go_router, Dio.
5. OWASP Application Security Verification Standard - authentication and input
   validation guidance.
6. Argon2 RFC 9106 - password hashing.
7. Android Developers - `SpeechRecognizer` and runtime permissions.

---

## Appendix A: Demo accounts

`python -m app.scripts.seed_demo` creates the demo user. The administrator is
created either by the `ADMIN_EMAIL` / `ADMIN_PASSWORD` startup bootstrap or by the
reference SQL seed.

| Email | Password | Role | Source |
| --- | --- | --- | --- |
| `demo@voiceledger.in` | `Demo@12345` | user | `seed_demo.py` |
| `admin@voiceledger.in` | `Admin@12345` | admin | `sql/seed/001_seed.sql` |

## Appendix B: Report query map

| Report section | Query file | Feature |
| --- | --- | --- |
| Users | `01_users.sql` | projection, filtering, sorting |
| Transaction history | `02_transactions.sql` | joins, date filters, pagination, `EXPLAIN` |
| Balance | `03_balance.sql` | conditional aggregation, balance view |
| Expense summary | `04_expense_summary.sql` | monthly grouping, `CASE`, `HAVING` |
| Income summary | `05_income_summary.sql` | running totals, window functions |
| Category analysis | `06_category_analysis.sql` | CTE, share, ranking |
| Lending | `07_lending.sql` | lent loans, repayment progress |
| Borrowing | `08_borrowing.sql` | liabilities, per-person net position |
| Repayments | `09_repayments.sql` | four-table join and totals |
| Outstanding loans | `10_outstanding_loans.sql` | urgency view, correlated subquery |
| Calendar | `11_calendar_transactions.sql` | daily/monthly aggregates |
| Join demonstrations | `12_join_demonstrations.sql` | outer joins, subqueries, `UNION ALL` |

## Appendix C: Documentation map

| Document | Contents |
| --- | --- |
| `README.md` | overview and quick start |
| `docs/database/README.md` | DBMS schema and demo query map |
| `docs/architecture/README.md` | component and request-flow summary |
| `docs/api/README.md` | endpoint quick reference |
| `docs/deployment/README.md` | Pi deployment checklist |
| `docs/architecture.md` | components, flows, security |
| `docs/database-design.md` | ER model, schema, normalization, concurrency |
| `docs/api-contract.md` | endpoints, payloads, errors |
| `rpi_server/README.md` | server setup and operations |
| `mobile_app/README.md` | client setup and architecture |
| `rpi_server/deployment/README.md` | Pi deployment checklist |
