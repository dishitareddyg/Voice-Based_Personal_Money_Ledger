# System Architecture

## 1. Goals

The system lets a person record everyday money movements by speaking, while keeping
the financial record consistent, auditable and authoritative on a small home server.

Design goals:

1. **Text, not audio, leaves the phone.** Speech recognition happens on the device.
2. **The server is authoritative.** Balances, loan outstanding and currency
   conversion are computed on the Raspberry Pi, never trusted from the client.
3. **Writes are idempotent.** A retried HTTP request must never create a second
   transaction.
4. **Financial data and audit data have different shapes.** Structured, relational
   records live in MySQL; event documents and caches live in MongoDB.
5. **The deployment fits a Raspberry Pi 4B.** No container orchestration, no
   message broker, no external cache; Nginx, Uvicorn, MySQL and MongoDB only.
6. **Administration is constrained.** Administrators run a fixed command set and
   there is no arbitrary SQL endpoint.

Non-goals: multi-tenant SaaS, bank integrations, investment portfolio tracking,
offline transaction queueing, and LLM-based language understanding.

## 2. Components

### Flutter client (`mobile_app/`)

| Layer | Responsibility |
| --- | --- |
| `features/` | Screens for auth, voice, dashboard, calendar, history, ledger entry, people, categories, profile, settings, admin |
| `features/voice/` | `speech_to_text` wrapper, rule-based NLP parser and review UI |
| `providers/` | Riverpod state and dependency wiring |
| `repositories/` | Typed API access; no widget calls Dio directly |
| `services/api_client.dart` | Dio, interceptors, retries, typed errors, request ids |
| `services/secure_token_storage.dart` | JWT in Android Keystore via `flutter_secure_storage` |

The client renders server results. It may format amounts and dates, but it does not
decide whether a balance is sufficient or what a foreign amount is worth.

### API server (`rpi_server/`)

```
request
  -> Nginx (TLS, size limits, proxy headers)
  -> FastAPI middleware (request id, CORS, error envelope)
  -> router (auth / transactions / ledger / directories / admin)
  -> dependency (JWT user, admin check, idempotency header)
  -> service (financial rules, loan lifecycle, dashboard assembly)
  -> repository (user-scoped SQLAlchemy queries)
  -> MySQL
       + best-effort audit event -> MongoDB
```

| Layer | Files | Notes |
| --- | --- | --- |
| API | `app/api/routes/*`, `app/api/deps.py` | HTTP only; no business rules |
| Services | `app/services/*` | Transaction boundaries, orchestration |
| Business rules | `app/business_rules/financial_rules.py` | Pure functions, independently tested |
| Repositories | `app/repositories/*` | All queries filter by `user_id` |
| Models | `app/models/*` | SQLAlchemy 2 typed mappings |
| Schemas | `app/schemas/*` | Pydantic v2 request/response contract |
| Core | `app/core/*` | Config, enums, errors, JWT/Argon2, time, bootstrap |
| Databases | `app/database/mysql`, `app/database/mongodb` | Engine/session and Mongo client |

### Storage

**MySQL 8.x (InnoDB)** is the system of record for:

- users and credentials,
- persons and categories,
- transactions (all money movements),
- loans and repayments,
- optional reusable interest schemes.

**MongoDB** stores:

- `voice_commands`: confirmed voice text, parser confidence and extraction metadata,
- `audit_logs`: login, committed/rejected financial writes and admin audit events,
- `application_events`: auth, lifecycle and operational events,
- `exchange_rates`: short-lived FX cache keyed by base/target currency.

MongoDB is never used to compute a balance. Losing voice metadata, an audit
document or the FX cache does not change the ledger; losing MySQL data does.

### Edge and supervision

Nginx terminates TLS and proxies to Uvicorn bound on `127.0.0.1:8000`. A systemd
unit restarts the API on failure. MySQL and MongoDB listen only on localhost.

## 3. Voice-to-ledger flow

```
1. User taps the microphone.
2. Android SpeechRecognizer streams a partial transcript.
3. The user edits the final transcript and presses Confirm.
4. Dart parser extracts:
     intent      income | expense | savings | lending | borrowing | repayment
     amount, currency, date, person, category, loan hints
     confidence 0..1
5. Review screen shows the structured command and warnings.
6. On Save, the app creates request_id and sends the intent payload over HTTPS to
   `POST /api/v1/commands`.
7. FastAPI authenticates, validates, locks the user row, applies rules,
   writes the transaction (and loan/repayment rows) in one DB transaction.
8. The response returns the stored transaction and the new available balance.
9. The client refreshes dashboard/history from the server.
```

Properties:

- Audio buffers stay in the speech plugin and are discarded.
- The parser is deterministic and unit-tested; the same sentence yields the same
  command.
- Voice text and confidence are stored in MongoDB `voice_commands` for metadata
  and evaluation; they never affect the stored amount.
- Rejected commands are recorded in `audit_logs` with the error code; no
  financial row is committed.
- If recognition is wrong, the user corrects the text before anything is sent.

## 4. Write request lifecycle

A typical `POST /api/v1/expenses`:

1. **Middleware** assigns/propagates `X-Request-ID` and starts timing.
2. **Auth dependency** decodes the HS256 JWT and loads an active user.
3. **Idempotency dependency** requires `Idempotency-Key` and checks it equals the
   body `request_id`.
4. **Schema validation** normalizes currency, trims text and validates amount and
   enum values.
5. **Service** begins a transaction:
   - lock the user row with `SELECT ... FOR UPDATE`,
   - check for an existing `(user_id, request_id)`; if found, return it with
     `idempotent_replay: true`,
   - resolve or create person/category where applicable,
   - fetch the current balance with a SQL aggregate,
   - apply business rules (sufficient balance, loan direction, overpayment),
   - insert the transaction, then loan/repayment rows,
   - commit.
6. **Events** write best-effort MongoDB documents to `audit_logs`,
   `application_events` and, when voice text is present, `voice_commands`.
   Failures here are logged and ignored.
7. **Response** returns `transaction`, `amount_inr`, optional `exchange_rate_to_inr`
   and the recomputed `available_balance`.

If two requests race, the unique key `(user_id, request_id)` is the final guard: the
loser rolls back and replays the winner's stored result.

## 5. Balance and loan consistency

Balances are derived from `transactions` with `status = 'completed'`:

```
available = income + borrowing + repayment(received)
          - expense - savings - lending - repayment(paid)
```

Loan outstanding is stored on `loans` because it is a lifecycle attribute updated
under the same transaction as the repayment row. The invariant is:

```
outstanding = principal - sum(completed repayments for that loan)
```

A lending/borrowing transaction creates exactly one loan; a repayment inserts one
`repayments` row and one transaction in the same commit. Overpayments and mismatched
directions are rejected before any write.

## 6. Currency conversion

```
request(amount, currency)
  -> INR?  rate = 1, no network
  -> Mongo cache hit and valid_until > now? use it
  -> provider GET {EXCHANGE_RATE_BASE_URL}/{BASE}
       rates["INR"] -> Decimal rate
       cache document with retrieved_at / valid_until
  -> unavailable -> 503 EXCHANGE_RATE_UNAVAILABLE (never a made-up rate)
```

The transaction stores both the original amount/currency and the INR amount plus the
rate used, so later rate changes cannot rewrite history.

## 7. Error handling

All failures use one envelope:

```json
{
  "success": false,
  "error_code": "INSUFFICIENT_BALANCE",
  "message": "Insufficient available balance for this transaction.",
  "request_id": "b4f0a3...",
  "details": {
    "available_balance": "250.00",
    "requested_amount": "1000.00"
  }
}
```

- Business errors map to HTTP 4xx with stable machine codes.
- Infrastructure errors map to 5xx (`DATABASE_ERROR`, `SERVICE_UNAVAILABLE`,
  `EXCHANGE_RATE_UNAVAILABLE`, `INTERNAL_ERROR`).
- Validation errors are normalized to `VALIDATION_ERROR` with field details.
- Every response carries `X-Request-ID`; the same id is logged and returned.
- Stack traces and SQL are never exposed to the client.

## 8. Security model

| Concern | Control |
| --- | --- |
| Password storage | Argon2id (`argon2-cffi`) |
| Sessions | Short-lived HS256 JWT bearer tokens |
| Transport | HTTPS at Nginx; Uvicorn only on loopback |
| Authorization | Every query scoped by `user_id`; admin routes require role `admin` |
| Admin actions | Whitelist enum, `confirm: true`, Argon2 password re-verification |
| SQL injection | SQLAlchemy bound parameters; no string-built SQL |
| Input limits | Pydantic length/range checks, Nginx body limit |
| Secrets | Environment variables / `.env`, excluded from git |
| Voice privacy | No audio upload; text only after confirmation |
| Audit | Mongo events for auth, writes and admin actions; no passwords logged |

## 9. Availability and failure behavior

- `/health` proves the process is alive; `/health/ready` checks MySQL and MongoDB.
- Audit, application-event and voice-metadata writes are best-effort; a MongoDB
  outage does not roll back a committed transaction (the API logs the failure).
- If MySQL is unreachable, financial routes fail with `DATABASE_ERROR`; the client
  shows a retry message.
- If the FX provider is unreachable, non-INR requests fail with
  `EXCHANGE_RATE_UNAVAILABLE`; INR traffic is unaffected.
- The mobile app may retry idempotent writes safely with the same `request_id`.

## 10. Why this architecture fits a DBMS project

- A normalized relational schema demonstrates keys, constraints, indexes, joins,
  aggregates, views, transactions and concurrency control.
- MongoDB shows a deliberate polyglot split: append-only event documents and a TTL
  cache instead of forcing every payload into tables.
- Server-side rules demonstrate that integrity is enforced in the database/service
  layer rather than in the UI.
- Idempotency and row locking make the concurrency section concrete and testable.
