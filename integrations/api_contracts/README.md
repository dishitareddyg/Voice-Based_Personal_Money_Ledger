# API Contract Helpers

| File | Purpose |
| --- | --- |
| `voice-ledger.http` | VS Code REST Client / JetBrains HTTP Client collection |
| `../pi_smoke_test.sh` | End-to-end shell smoke test against a running Pi |

## HTTP collection

1. Start the API (`uvicorn app.main:app --port 8000`).
2. Open `voice-ledger.http`.
3. Run `Register`, then `Login`; the REST Client captures the named token.
4. Run the ledger requests in order.

The collection uses `demo@example.com`. Change the email or delete the account
before registering again. The contract itself is documented in
`docs/api-contract.md` and `docs/api/README.md`.
