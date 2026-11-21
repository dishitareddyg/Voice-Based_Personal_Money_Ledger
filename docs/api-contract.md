# API Contract

Base path: `/api/v1` (configurable with `API_PREFIX`). The server also exposes
`GET /health` and `GET /health/ready` outside the prefix.

This document matches the running FastAPI OpenAPI schema; the Flutter client in
`mobile_app/` consumes exactly these paths.

## 1. Conventions

### Authentication

Every endpoint except `POST /auth/register`, `POST /auth/login` and the health probes
requires:

```
Authorization: Bearer <JWT>
```

Tokens are HS256 JWTs with `sub` = user id, `role`, `iat` and `exp`. There is no
refresh token; the client signs in again when the access token expires.

### Request metadata

| Header | Required | Purpose |
| --- | --- | --- |
| `Authorization` | yes (except public routes) | bearer token |
| `Idempotency-Key` | recommended on POST financial writes | when present, must equal body `request_id` |
| `Content-Type` | on writes | `application/json` |
| `X-Request-ID` | no | client-supplied correlation id; server generates one if absent |

Every response includes `X-Request-ID`.

### Data types

- Money is returned as **decimal strings** (`"1234.50"`) to avoid floating-point
  rounding; clients parse them into their numeric type.
- `transaction_date`, `start_date`, `payment_date`, `due_date` are ISO dates
  (`YYYY-MM-DD`).
- Audit timestamps are UTC ISO-8601 with `Z` (`2026-10-20T05:34:21.100Z`).
- Enums are lowercase strings:
  - transaction `type`: `income | expense | savings | lending | borrowing | repayment`
  - loan `kind`: `lent | borrowed`
  - repayment direction: `received | paid`
  - interest type: `simple | compound | flat`
  - role: `user | admin`
  - loan status: `open | closed`
  - transaction status: `completed | reversed`
- IDs are integers in JSON; the Flutter client normalizes them to strings.

### Success envelope

Most responses wrap their payload:

```json
{ "success": true, "summary": { } }
```

`GET /transactions/{id}` returns a bare `TransactionOut` object; list endpoints wrap
their collection (`items`, `loans`, `repayments`, `persons`, `categories`, `days`).

### Error envelope

```json
{
  "success": false,
  "error_code": "INSUFFICIENT_BALANCE",
  "message": "Insufficient available balance for this transaction.",
  "request_id": "6f1d0e2a...",
  "details": {
    "available_balance": "250.00",
    "requested_amount": "1000.00"
  }
}
```

`details` is omitted when there is nothing to add. Validation errors use
`error_code: "VALIDATION_ERROR"` and `details.errors` with `loc`, `msg`, `type`.

## 2. Health

| Method | Path | Auth | Response |
| --- | --- | --- | --- |
| GET | `/health` | no | `{"status":"ok","service":"voice-ledger-api","time":"..."}` |
| GET | `/health/ready` | no | `200 {"status":"ready","checks":{"mysql":"ok"}}` when MySQL responds, `503 {"status":"degraded","checks":{"mysql":"unavailable"}}` otherwise |

## 3. Authentication

### Register

`POST /auth/register` (201)

```json
{
  "full_name": "Demo User",
  "email": "demo@example.com",
  "password": "S3curePass!",
  "timezone": "Asia/Kolkata"
}
```

```json
{
  "success": true,
  "access_token": "eyJhbGciOiJIUzI1NiIs...",
  "token_type": "bearer",
  "user": {
    "id": 2,
    "full_name": "Demo User",
    "email": "demo@example.com",
    "role": "user",
    "is_active": true,
    "timezone": "Asia/Kolkata",
    "created_at": "2026-10-20T05:34:20.900Z"
  }
}
```

`409 EMAIL_ALREADY_EXISTS` if the address is registered.

### Login

`POST /auth/login` (200), body `{"email": "...", "password": "..."}`. Same response
shape as register.

### Profile

| Method | Path | Body | Response |
| --- | --- | --- | --- |
| GET | `/auth/me` | - | `{"success": true, "user": UserOut}` |
| PATCH | `/auth/me` | `full_name?`, `timezone?` | `{"success": true, "user": UserOut}` |
| POST | `/auth/change-password` | `current_password`, `new_password` | `{"success": true, "message": "..."}` |
| POST | `/auth/logout` | - | `{"success": true, "message": "Signed out."}` |

Logout is stateless: the client deletes the token. The server does not keep a
revocation list.

## 4. Transactions

### Create a voice command

The Flutter voice flow sends this canonical structured command. Mobile never sends
SQL: the Pi maps `intent` to the same authoritative ledger service used by the
typed endpoints.

`POST /commands` (201). Send `Idempotency-Key` equal to `request_id`; the body
`request_id` is the authoritative idempotency key even when the header is absent.

```json
{
  "request_id": "8f14e45fceea167a5a36dedd4bea2543",
  "intent": "CREATE_EXPENSE",
  "original_amount": 2000.00,
  "original_currency": "INR",
  "category": "Groceries",
  "transaction_date": "2026-10-20",
  "description": "Weekly groceries",
  "voice_text": "I spent 2000 rupees on groceries",
  "parser_confidence": 0.97
}
```

Supported intents: `CREATE_INCOME`, `CREATE_EXPENSE`, `CREATE_SAVINGS`,
`CREATE_LENDING`, `CREATE_BORROWING`, `CREATE_REPAYMENT`. Optional fields are
`category_id`, `person`, `person_id`, `interest_rate`, `interest_type`,
`repayment_direction`, `loan_id`, `due_date`. For compatibility the aliases
`amount`, `currency`, `category_name` and `person_name` are accepted, but clients
should send the canonical names.

The response is the same `TransactionCreateResponse` documented below, including
`amount_inr`, `exchange_rate_to_inr`, `available_balance` and idempotent replay
flags. Business failures use the standard error envelope; rejected writes are also
recorded in MySQL `AUDIT_LOG` as `transaction_rejected`.

### Create a typed transaction

Manual-entry and typed screens use the generic endpoint with `type` in the body:

`POST /transactions` (201). Send `Idempotency-Key` equal to `request_id` when
using a retrying client; `request_id` itself enforces idempotency server-side.

```json
{
  "request_id": "8f14e45fceea167a5a36dedd4bea2543",
  "type": "expense",
  "amount": 850.00,
  "currency": "INR",
  "transaction_date": "2026-10-20",
  "description": "Groceries",
  "category_name": "Food"
}
```

Typed endpoints fix the type and reject/ignore a conflicting `type` by design (the
schema does not include it):

| Endpoint | Fixed type |
| --- | --- |
| `POST /expenses` | `expense` |
| `POST /income` | `income` |
| `POST /savings` | `savings` |
| `POST /lending` | `lending` |
| `POST /borrowing` | `borrowing` |
| `POST /repayments` | `repayment` |

Common optional fields: `transaction_date`, `description`, `category_id`,
`category_name`, `person_id`, `person_name`, `interest_rate`, `interest_type`,
`repayment_direction`, `loan_id`, `due_date`, `voice_text`, `parser_confidence`.

Rules per type:

- `expense`, `savings`, `lending` require sufficient available balance.
- `lending`, `borrowing` require a person (`person_id` or `person_name`) and create a
  loan; `due_date`, `interest_rate`, `interest_type` are optional.
- `repayment` requires `repayment_direction` (`received` for a `lent` loan, `paid` for
  a `borrowed` loan) and either `loan_id` or exactly one matching open loan for the
  person.
- `category_name` resolves to an existing category or creates one for the type.

Response (201):

```json
{
  "success": true,
  "message": "Expense recorded successfully.",
  "idempotent_replay": false,
  "duplicate": false,
  "transaction": {
    "id": 12,
    "user_id": 2,
    "type": "expense",
    "amount_inr": "850.00",
    "currency": "INR",
    "original_amount": null,
    "original_currency": null,
    "exchange_rate_to_inr": null,
    "transaction_date": "2026-10-20",
    "description": "Groceries",
    "category_id": 1,
    "category_name": "Food",
    "person_id": null,
    "person_name": null,
    "interest_rate": null,
    "interest_type": null,
    "loan_id": null,
    "repayment_direction": null,
    "status": "completed",
    "reference": null,
    "request_id": "8f14e45fceea167a5a36dedd4bea2543",
    "created_at": "2026-10-20T05:34:21.100Z",
    "updated_at": "2026-10-20T05:34:21.100Z"
  },
  "amount_inr": "850.00",
  "exchange_rate_to_inr": null,
  "available_balance": "9150.00"
}
```

Retrying with the same `request_id` returns 201 with the original transaction,
`idempotent_replay: true` and `duplicate: true`; no second row is created.

### Read transactions

`GET /transactions`

| Query | Type | Default | Notes |
| --- | --- | --- | --- |
| `page` | int | 1 | ≥ 1 |
| `page_size` | int | 20 | 1..100 |
| `type` | string | - | one of the six enum values |
| `search` | string | - | description / person / category match |
| `from` | date | - | inclusive |
| `to` | date | - | inclusive |
| `person_id` | int | - | |
| `category_id` | int | - | |

```json
{
  "success": true,
  "items": [ TransactionOut ],
  "page": 1,
  "page_size": 20,
  "total": 34,
  "has_more": true,
  "pagination": { "page": 1, "page_size": 20, "total": 34, "has_more": true }
}
```

`GET /transactions/{id}` returns `TransactionOut` directly (404 `NOT_FOUND` if the
transaction does not belong to the caller).

Typed `GET /expenses`, `/income`, `/savings`, `/lending`, `/borrowing` accept the same
filters and always constrain the type.

## 5. Dashboard and calendar

`GET /dashboard/summary` (200)

```json
{
  "success": true,
  "summary": {
    "available_balance": 9150.0,
    "total_income": 50000.0,
    "total_expenses": 850.0,
    "total_savings": 5000.0,
    "money_lent": 3000.0,
    "money_borrowed": 0.0,
    "outstanding_lent": 2000.0,
    "outstanding_borrowed": 0.0,
    "upcoming_repayment_total": 2000.0,
    "upcoming_repayment_count": 1,
    "recent_transactions": [ TransactionOut ],
    "category_breakdown": [
      {
        "category_id": "1",
        "name": "Food",
        "amount": 850.0,
        "percentage": 100.0,
        "color_hex": "#E76F51",
        "icon_key": "restaurant"
      }
    ],
    "upcoming_repayments": [
      {
        "id": "1",
        "loan_id": "1",
        "person_name": "Ravi",
        "amount": 2000.0,
        "due_date": "2026-11-09",
        "direction": "received",
        "kind": "lent"
      }
    ],
    "notes": [],
    "currency": "INR"
  }
}
```

`GET /calendar?month=YYYY-MM` (200)

```json
{
  "success": true,
  "month": "2026-10",
  "days": [
    {
      "date": "2026-10-20",
      "income": 0.0,
      "expense": 850.0,
      "savings": 0.0,
      "lending": 0.0,
      "borrowing": 0.0,
      "repayment": 0.0,
      "transaction_count": 1,
      "transactions": [ TransactionOut ]
    }
  ]
}
```

Only days with activity are returned. `422 VALIDATION_ERROR` for a malformed month.

## 6. Loans and repayments

`GET /loans?kind=lent|borrowed&status=open|closed&person_id=&limit=`

```json
{
  "success": true,
  "loans": [
    {
      "id": 1,
      "kind": "lent",
      "person_id": 1,
      "person_name": "Ravi",
      "principal_amount_inr": "3000.00",
      "outstanding_amount_inr": "2000.00",
      "start_date": "2026-10-10",
      "interest_rate": "0.000",
      "interest_type": "simple",
      "due_date": "2026-11-09",
      "status": "open",
      "description": "Short-term loan",
      "created_at": "2026-10-10T06:00:00.000Z"
    }
  ]
}
```

`GET /repayments?loan_id=&limit=` (default limit 50, max 500)

```json
{
  "success": true,
  "repayments": [
    {
      "id": 1,
      "loan_id": 1,
      "person_id": 1,
      "person_name": "Ravi",
      "amount_inr": "1000.00",
      "payment_date": "2026-10-17",
      "direction": "received",
      "notes": "Part repayment",
      "status": "completed",
      "created_at": "2026-10-17T07:00:00.000Z"
    }
  ]
}
```

Repayment creation uses `POST /repayments` (or `POST /transactions` with
`type: "repayment"`):

```json
{
  "request_id": "d3b07384d113edec49eaa6238ad5ff00",
  "amount": 1000.00,
  "currency": "INR",
  "person_name": "Ravi",
  "repayment_direction": "received",
  "loan_id": 1,
  "transaction_date": "2026-10-17"
}
```

Errors: `INVALID_LOAN` (ambiguous/missing loan), `LOAN_NOT_FOUND`,
`LOAN_CLOSED`, `REPAYMENT_EXCEEDS_OUTSTANDING`.

## 7. Persons and categories

### Persons

| Method | Path | Body / query | Response |
| --- | --- | --- | --- |
| GET | `/persons?search=` | search matches name/phone/email | `{"success":true,"persons":[PersonOut]}` |
| POST | `/persons` | `name`, `phone?`, `email?`, `notes?` | `{"success":true,"person":PersonOut}` (201) |
| PATCH | `/persons/{id}` | any of the same fields | `{"success":true,"person":PersonOut}` |
| DELETE | `/persons/{id}` | - | 204, or `409 PERSON_IN_USE` |

`PersonOut` includes computed `outstanding_lent` and `outstanding_borrowed` totals
from open loans.

### Categories

| Method | Path | Body / query | Response |
| --- | --- | --- | --- |
| GET | `/categories?type=` | filter by transaction type | `{"success":true,"categories":[CategoryOut]}` |
| POST | `/categories` | `name`, `type`, `color_hex?`, `icon?` | `{"success":true,"category":CategoryOut}` (201) |
| PATCH | `/categories/{id}` | `name?`, `color_hex?`, `icon?` | `{"success":true,"category":CategoryOut}` |
| DELETE | `/categories/{id}` | - | 204, or `409 CATEGORY_IN_USE` |

`CategoryOut` returns `icon_key` (the write field is `icon`), plus
`transaction_count`, `total_amount` and `is_default`.

## 8. Administration

All routes require `role = admin`. `POST /admin/actions` additionally requires the
administrator's password and `confirm: true`.

```json
{
  "action": "DATABASE_STATS",
  "password": "Admin@12345",
  "confirm": true,
  "parameters": {}
}
```

```json
{
  "success": true,
  "action": "DATABASE_STATS",
  "message": "Database statistics collected.",
  "completed_at": "2026-10-20T05:40:00.000Z",
  "details": {
    "mysql_version": "8.0.39",
    "database": "voice_ledger",
    "counts": { "users": 2, "transactions": 5 },
    "tables": [ { "table": "transactions", "rows": 5, "size_mb": 0.02 } ],
    "supporting_tables": {
      "voice_commands": 4,
      "audit_logs": 12,
      "application_events": 8,
      "exchange_rate_cache": 3
    }
  }
}
```

Whitelisted `action` values:

| Action | Effect |
| --- | --- |
| `DATABASE_STATS` | row counts, MySQL version, table sizes, supporting-table counts |
| `RUN_MIGRATIONS` | `alembic upgrade head` in a subprocess |
| `CREATE_BACKUP` | `mysqldump --single-transaction` into `BACKUP_DIR` |
| `OPTIMIZE_INDEXES` | `ANALYZE TABLE` on the fixed table list |
| `PRUNE_RATE_CACHE` | deletes expired `EXCHANGE_RATE_CACHE` rows |

There is no endpoint that accepts raw SQL. Unknown actions fail schema validation.

`GET /admin/users` returns all accounts (admin only).

## 9. Status codes and error codes

| HTTP | Meaning | Typical codes |
| --- | --- | --- |
| 200 | read/update success | - |
| 201 | created (register, transaction, person, category) | - |
| 204 | deleted | - |
| 400 | invalid confirmation/unsupported action | `ADMIN_CONFIRMATION_REQUIRED`, `UNSUPPORTED_ACTION` |
| 401 | missing/invalid/expired token, bad login | `UNAUTHORIZED`, `INVALID_CREDENTIALS`, `USER_INACTIVE` |
| 403 | not an admin, wrong admin password | `FORBIDDEN`, `ADMIN_PASSWORD_INVALID` |
| 404 | missing or not owned by the caller | `NOT_FOUND`, `LOAN_NOT_FOUND` |
| 409 | uniqueness/usage conflict | `EMAIL_ALREADY_EXISTS`, `PERSON_IN_USE`, `CATEGORY_IN_USE`, `IDEMPOTENCY_CONFLICT` |
| 422 | validation or business rule failure | `VALIDATION_ERROR`, `INVALID_AMOUNT`, `INSUFFICIENT_BALANCE`, `INVALID_LOAN`, `REPAYMENT_EXCEEDS_OUTSTANDING` |
| 500 | database/unexpected server failure | `DATABASE_ERROR`, `INTERNAL_ERROR` |
| 503 | dependency unavailable | `EXCHANGE_RATE_UNAVAILABLE`, `SERVICE_UNAVAILABLE` |

Full enum: `rpi_server/app/core/enums.py` (`ErrorCode`).

## 10. cURL examples

```bash
BASE=http://127.0.0.1:8000/api/v1

# Register
curl -s -X POST "$BASE/auth/register" \
  -H 'Content-Type: application/json' \
  -d '{"full_name":"Demo User","email":"demo@example.com","password":"S3curePass!"}'

TOKEN=...   # access_token from the response

# Record an expense (idempotent)
curl -s -X POST "$BASE/expenses" \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -H 'Idempotency-Key: 8f14e45fceea167a5a36dedd4bea2543' \
  -d '{"request_id":"8f14e45fceea167a5a36dedd4bea2543","amount":850.00,
       "currency":"INR","category_name":"Food","transaction_date":"2026-10-20"}'

# Dashboard
curl -s "$BASE/dashboard/summary" -H "Authorization: Bearer $TOKEN"

# Month calendar
curl -s "$BASE/calendar?month=2026-10" -H "Authorization: Bearer $TOKEN"
```

A runnable request collection is in
`integrations/api_contracts/voice-ledger.http`.
