# Architecture Overview

The full design and security discussion is in
[`../architecture.md`](../architecture.md).

## Components

```text
Flutter Android app
  SpeechRecognizer -> editable transcript -> deterministic Dart parser
  -> review screen -> POST /commands (intent JSON)

Nginx (TLS) -> FastAPI / Uvicorn
                 |-> MySQL 8.x: ledger, loans, repayments, users, categories
                 |              voice metadata, audit/events, FX cache
                 +-> exchange-rate provider (HTTPS)
```

- The phone performs speech recognition and parsing. Raw audio is never sent.
- FastAPI owns authentication, validation, balances, loan state and currency.
- MySQL is the single persistent store for financial facts and supporting data.
- The four supporting tables (`VOICE_COMMAND`, `AUDIT_LOG`,
  `APPLICATION_EVENT`, `EXCHANGE_RATE_CACHE`) are best-effort and never change a
  balance.
- Nginx terminates TLS and Uvicorn listens on loopback only.

## Write request

1. Nginx forwards the request; middleware assigns `X-Request-ID`.
2. JWT authentication loads the active user.
3. `Idempotency-Key` must equal body `request_id`.
4. Pydantic validates and normalizes the payload.
5. The service starts a transaction, locks the user row, checks for a replay,
   resolves person/category, validates rules, inserts the ledger row and any
   loan/repayment rows, then commits.
6. Audit/voice/application events are written to MySQL after commit through an
   independent session; a rejected command writes `transaction_rejected` to
   `AUDIT_LOG` without a ledger row.
7. The response returns the stored transaction and recomputed balance.

## Balance and loans

```text
available = income + borrowing + repayment(received)
          - expense - savings - lending - repayment(paid)
```

Only `completed` transactions count. Lending/borrowing creates one open loan.
A repayment updates `outstanding_amount_inr` under the same transaction; a zero
outstanding closes the loan. Overpayment and direction mismatches are rejected.

## Reliability and security

- `UNIQUE(user_id, request_id)` plus `SELECT ... FOR UPDATE` prevents duplicates
  and lost updates.
- Money uses `DECIMAL(15,2)`; rates use `DECIMAL(18,8)`.
- Argon2id passwords, HS256 JWTs, HTTPS-only deployment.
- Admin commands are a fixed enum with password re-verification and
  `confirm: true`; there is no arbitrary SQL endpoint.
- Non-INR requests fail with `EXCHANGE_RATE_UNAVAILABLE` rather than inventing a
  rate.
