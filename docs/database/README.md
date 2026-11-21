# Database Documentation

Quick reference for the DBMS evaluation. The detailed design is in
[`../database-design.md`](../database-design.md); the report text is in
[`../dbms-report.md`](../dbms-report.md).

## 1. Single MySQL store

| Area | Tables | Authority |
| --- | --- | --- |
| Core ledger | `users`, `persons`, `categories`, `interest_schemes`, `loans`, `transactions`, `repayments` | System of record for every financial fact |
| Supporting | `VOICE_COMMAND`, `AUDIT_LOG`, `APPLICATION_EVENT`, `EXCHANGE_RATE_CACHE` | Audit trail, voice metadata, operational events and FX cache |

MySQL 8.0 / InnoDB is the only database server. Balances are always derived from
the ledger tables; the supporting tables never hold money that affects a
balance. There is no MongoDB, Redis or other store in the deployment.

## 2. Schema

```text
users 1---n persons
users 1---n categories
users 1---n interest_schemes
users 1---n loans
users 1---n transactions
users 1---n repayments

persons 1---n loans
persons 1---n transactions
persons 1---n repayments
categories 1---n transactions

transactions 1---0..1 loans       (loans.source_transaction_id, UNIQUE)
loans 1---n transactions          (transactions.loan_id)
loans 1---n repayments
transactions 1---0..1 repayments  (repayments.transaction_id, UNIQUE)
```

`transactions` is the central ledger. `loans` stores the loan lifecycle state,
and `repayments` links each repayment transaction to its loan.

### Typed views instead of subtype tables

`income`, `expenses` and `savings` are read-only views over `transactions`.
Storing the same amount in both `transactions` and separate subtype tables would
duplicate facts and introduce update anomalies. The views give simple relations
for queries without violating 3NF.

## 3. Integrity rules

- Primary keys are `BIGINT AUTO_INCREMENT`; money is `DECIMAL(15,2)`.
- `UNIQUE(users.email)`.
- `UNIQUE(persons.user_id, name)`.
- `UNIQUE(categories.user_id, name, type)`.
- `UNIQUE(interest_schemes.user_id, name)`.
- `UNIQUE(loans.source_transaction_id)`.
- `UNIQUE(transactions.user_id, request_id)` provides idempotency.
- `UNIQUE(repayments.transaction_id)` enforces 1:1 repayment/transaction.
- Foreign keys use `CASCADE` for user-owned data, `RESTRICT` where a
  counterparty/history must survive, and `SET NULL` for optional links.
- CHECK constraints validate transaction/loan/category enums, positive amounts,
  non-negative outstanding, interest rates, repayment directions and dates.
- `loans.outstanding_amount_inr >= 0`; a loan closes only at zero.
- User deletion cascades owned rows; person/category deletion is restricted when
  a loan/repayment depends on it, or nulls an optional transaction reference.

The circular pair (`loans.source_transaction_id` and `transactions.loan_id`) is
created with one `ALTER TABLE` after both tables exist.

### Supporting tables

| Table | Key and uniqueness | Purpose |
| --- | --- | --- |
| `VOICE_COMMAND` | `UNIQUE(user_id, request_id)` | Confirmed transcript, parser confidence, optional transaction link and `JSON` NLP metadata; upsert makes voice retries idempotent |
| `AUDIT_LOG` | `(event_type, request_id, user_id, created_at)` dedupe | Auth, write and admin audit events; `payload` is `JSON` |
| `APPLICATION_EVENT` | same shape as `AUDIT_LOG` | Startup, shutdown, migration and maintenance events |
| `EXCHANGE_RATE_CACHE` | `UNIQUE(base_currency, target_currency)` | `DECIMAL(18,8)` rate, provider, `retrieved_at`, `valid_until` for expiry |

Supporting writes use an independent `SessionLocal()` so a failed audit or voice
write never rolls back a committed financial transaction. They are best-effort
by design.

## 4. Indexes

| Index | Use |
| --- | --- |
| `transactions(user_id, transaction_date, id)` | paged history and calendar |
| `transactions(user_id, type)` | typed lists and summaries |
| `transactions(user_id, category_id)` | category analysis |
| `transactions(user_id, person_id)` | person ledger |
| `transactions(user_id, loan_id)` | loan-linked history |
| `transactions(request_id)` | idempotency lookup |
| `loans(user_id, kind, status)` | open lent/borrowed lists |
| `loans(user_id, status)` | dashboard outstanding totals |
| `repayments(user_id, payment_date)` | repayment history |
| `repayments(loan_id, payment_date)` | per-loan progress |
| `categories(user_id, type)` | directory filters |
| `VOICE_COMMAND(user_id, created_at)` | recent voice history per user |
| `AUDIT_LOG(user_id, created_at)` | user audit trail |
| `AUDIT_LOG(event_type, created_at)` | admin event filters |
| `APPLICATION_EVENT(event_type, created_at)` | operational event filters |
| `EXCHANGE_RATE_CACHE(valid_until)` | expiry cleanup |

## 5. Concurrency and idempotency

```text
START TRANSACTION
  SELECT ... FROM users WHERE id = :uid FOR UPDATE
  SELECT ... FROM transactions WHERE user_id = :uid AND request_id = :rid
  IF exists: COMMIT and replay the stored transaction
  compute balance and validate financial rules
  INSERT transaction (+ loan / repayment)
COMMIT
```

The user-row lock serializes writes for one user. `UNIQUE(user_id, request_id)`
is the final guard: concurrent duplicates roll back and replay the winner.

## 6. Reporting views

| View | Purpose |
| --- | --- |
| `v_user_balances` | income, expense, savings, lending, borrowing, repayments and available balance |
| `v_open_loans` | join to persons with `overdue` / `due_soon` / `on_track` urgency |
| `income` | completed income rows with category/person names |
| `expenses` | completed expense rows with category/person names |
| `savings` | completed savings rows with category/person names |

## 7. Demo query map

Run after `sql/schema/001_schema.sql`, `002_views.sql` and
`sql/seed/001_seed.sql`.

| File | Concepts |
| --- | --- |
| `01_users.sql` | projection, filters, ordering |
| `02_transactions.sql` | joins, ranges, pagination, `EXPLAIN` |
| `03_balance.sql` | `CASE` aggregation, `v_user_balances` |
| `04_expense_summary.sql` | monthly totals, `HAVING` |
| `05_income_summary.sql` | running totals, window functions |
| `06_category_analysis.sql` | CTE, percentage share, ranking |
| `07_lending.sql` | lent loans and repayment progress |
| `08_borrowing.sql` | liabilities and per-person net position |
| `09_repayments.sql` | four-table repayment audit |
| `10_outstanding_loans.sql` | urgency view, correlated subquery |
| `11_calendar_transactions.sql` | daily and monthly calendar aggregates |
| `12_join_demonstrations.sql` | outer joins, subqueries, `UNION ALL` |

## 8. Migration and seed commands

Use **one** schema path on a fresh database.

Alembic + Python seed (normal application setup):

```bash
cd rpi_server
alembic upgrade head          # includes 0003_supporting_tables
python -m app.scripts.seed_demo
```

Reference SQL path (for the DBMS evaluation):

```bash
mysql -u root -p < rpi_server/sql/schema/001_schema.sql
mysql -u root -p voice_ledger < rpi_server/sql/schema/002_views.sql
mysql -u root -p voice_ledger < rpi_server/sql/seed/001_seed.sql
```

`0002_dbms_layer` adds compounding frequency, CHECK constraints, composite
indexes, the balance/loan reporting views and the typed views. `0003_supporting_tables`
creates `VOICE_COMMAND`, `AUDIT_LOG`, `APPLICATION_EVENT` and
`EXCHANGE_RATE_CACHE` without altering or dropping the financial tables. Existing
rows must satisfy the new constraints before upgrading; a fresh installation is
the verified path.

### Legacy document-store export

If an older install has supporting documents to keep, export each collection to
JSON Lines before decommissioning it and import after the migration:

```bash
cd rpi_server
.venv/bin/python -m app.scripts.import_legacy_supporting_export \
  --source-dir /var/backups/voice_ledger/legacy_export
```

The importer expects `voice_commands.jsonl`, `audit_logs.jsonl`,
`application_events.jsonl` and `exchange_rates.jsonl`. It is resumable and never
writes the financial tables. See the deployment guide for the `mongoexport`
commands.
