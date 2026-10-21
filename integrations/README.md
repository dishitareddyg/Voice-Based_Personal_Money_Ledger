# Integrations

Runnable helpers for exercising the API outside the Flutter app.

| Path | Purpose |
| --- | --- |
| `api_contracts/voice-ledger.http` | Request collection for VS Code REST Client / JetBrains HTTP Client |
| `api_contracts/README.md` | How to run the collection |
| `currency/README.md` | FX lookup, cache and failure behavior |
| `currency/check_rate.py` | Live provider + MongoDB cache verification on the Pi |
| `pi_smoke_test.sh` | End-to-end smoke test against a running Pi API |

## HTTP collection

1. Start the API (`uvicorn app.main:app --port 8000`).
2. Open `api_contracts/voice-ledger.http`.
3. Run `Register`, then `Login`. With the VS Code REST Client, the token is captured
   from the named request automatically.
4. Run the ledger requests in order.

Demo values use a unique email only in the shell script; the `.http` file reuses
`demo@example.com`, so delete that account or change the email before registering a
second time.

## Pi smoke test

From any machine that can reach the Pi:

```bash
chmod +x integrations/pi_smoke_test.sh
./integrations/pi_smoke_test.sh https://raspberrypi.local/api/v1
```

The HTTP collection also shows the canonical voice contract on `POST /commands`
and the rejected-command path. The Pi script creates a unique account, records
income, a 2000-rupee voice expense, a rejected 100000-rupee voice expense,
typed expense, lending and a repayment, then checks:

- the idempotent replay returns the original transaction,
- a rejected voice command returns `INSUFFICIENT_BALANCE` and changes no balance,
- the dashboard balance and outstanding loan,
- the month calendar,
- that a normal user receives 403 from the admin endpoint.

Requirements: `curl` and `python3` (both present on Raspberry Pi OS). The script
does not need `jq`.

It exits non-zero on the first failed assertion. Use a throwaway deployment or delete
the generated `smoke-*@example.com` account afterwards.
