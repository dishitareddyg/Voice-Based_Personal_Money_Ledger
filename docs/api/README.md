# API Quick Reference

Complete payloads and examples: [`../api-contract.md`](../api-contract.md).
Interactive OpenAPI: `http://127.0.0.1:8000/docs`.

Base path: `/api/v1`. Financial routes require
`Authorization: Bearer <jwt>`. Writes also require
`Idempotency-Key: <request_id>` matching the body.

## Endpoints

| Method | Path | Purpose |
| --- | --- | --- |
| POST | `/auth/register` | create account and return JWT |
| POST | `/auth/login` | authenticate |
| GET/PATCH | `/auth/me` | profile |
| POST | `/auth/change-password` | change password |
| POST | `/auth/logout` | stateless logout |
| POST | `/commands` | execute a confirmed voice command (`intent`) |
| POST | `/transactions` | create typed transaction |
| GET | `/transactions` | paged/filtered history |
| GET | `/transactions/{id}` | single transaction |
| GET | `/dashboard/summary` | balances, totals, recent activity |
| GET | `/calendar` | month/day aggregates |
| GET | `/loans` | lent/borrowed loans |
| GET | `/repayments` | repayment history |
| POST/GET | `/expenses` | expense write/list |
| POST/GET | `/income` | income write/list |
| POST/GET | `/savings` | savings write/list |
| POST/GET | `/lending` | lending write/list |
| POST/GET | `/borrowing` | borrowing write/list |
| POST/GET | `/repayments` | repayment write/list |
| GET/POST | `/persons` | directory |
| PATCH/DELETE | `/persons/{id}` | update/delete person |
| GET/POST | `/categories` | directory |
| PATCH/DELETE | `/categories/{id}` | update/delete category |
| POST | `/admin/actions` | whitelisted maintenance |
| GET | `/admin/users` | admin user list |

## Error envelope

```json
{
  "success": false,
  "error_code": "INSUFFICIENT_BALANCE",
  "message": "Insufficient available balance for this transaction.",
  "request_id": "b4f0a3...",
  "details": {
    "available_balance": "100.00",
    "requested_amount": "250.00"
  }
}
```

Every response includes `X-Request-ID`. Decimal amounts are serialized as
strings; the Flutter client parses them as numbers for display.

## Admin actions

`DATABASE_STATS`, `RUN_MIGRATIONS`, `CREATE_BACKUP`, `OPTIMIZE_INDEXES`,
`PRUNE_RATE_CACHE`. Each request includes the administrator password and
`confirm: true`.
