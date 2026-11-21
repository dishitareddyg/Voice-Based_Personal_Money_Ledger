# Currency Integration

The server stores every amount in INR (`DECIMAL(15,2)`). For non-INR input it
uses a synchronous provider lookup and never invents a rate.

## Flow

```text
INR -> rate = 1, no network
other currency
  -> MySQL EXCHANGE_RATE_CACHE: unexpired (base, target=INR)?
  -> provider GET {EXCHANGE_RATE_BASE_URL}/{BASE}
       rates["INR"] -> Decimal rate
       upsert cache with retrieved_at / valid_until / provider
  -> provider unavailable -> HTTP 503 EXCHANGE_RATE_UNAVAILABLE
```

The transaction stores `original_amount`, `original_currency` and
`exchange_rate_to_inr` as historical facts, so later rate changes do not rewrite
history.

## Verify on the Pi

Run the same service used by financial writes, from the server directory so
`.env` is loaded:

```bash
cd /opt/voice-ledger/rpi_server
.venv/bin/python ../integrations/currency/check_rate.py USD
```

The command prints the live rate and the resulting MySQL
`EXCHANGE_RATE_CACHE` row. A provider outage exits with status `2` and
`EXCHANGE_RATE_UNAVAILABLE`; the server never substitutes a stale rate. Use
`--target EUR` to check another target, though ledger writes always target INR.

## Configuration

| Variable | Meaning |
| --- | --- |
| `EXCHANGE_RATE_BASE_URL` | provider root, e.g. `https://open.er-api.com/v6/latest` |
| `EXCHANGE_RATE_CACHE_MINUTES` | cache validity window |

## Cache row

```json
{
  "base_currency": "USD",
  "target_currency": "INR",
  "rate": "83.12000000",
  "provider": "open.er-api.com",
  "retrieved_at": "2026-10-20T05:00:00",
  "valid_until": "2026-10-20T06:00:00"
}
```

`rate` is `DECIMAL(18,8)`. The unique key `(base_currency, target_currency)`
makes the upsert idempotent, and an index on `valid_until` supports cleanup.
`PRUNE_RATE_CACHE` deletes expired rows. An expired row is never treated as a
valid rate.

## Failure behavior

- INR traffic is unaffected by provider outages.
- Non-INR writes fail with `EXCHANGE_RATE_UNAVAILABLE` and no transaction is
  committed.
- The mobile client shows a retry message rather than guessing an amount.
