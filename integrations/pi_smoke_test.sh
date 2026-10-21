#!/usr/bin/env bash
# End-to-end smoke test for a running Voice Ledger API.
#
# Usage:
#   ./integrations/pi_smoke_test.sh [BASE_URL]
#   INSECURE=1 ./integrations/pi_smoke_test.sh https://raspberrypi.local/api/v1
#
# Requires curl and python3. Creates a throwaway smoke-*@example.com account.

set -euo pipefail

BASE="${1:-http://127.0.0.1:8000/api/v1}"
INSECURE="${INSECURE:-0}"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

KEY=""
STATUS=""
RESPONSE=""

CURL=(curl -sS --connect-timeout 10 --max-time 60)
if [ "$INSECURE" = "1" ]; then
  CURL+=(-k)
fi

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

json_get() {
  local path="$1"
  python3 -c '
import json, sys
value = json.load(sys.stdin)
for key in sys.argv[1].split("."):
    value = value[int(key)] if key.isdigit() else value[key]
if isinstance(value, bool):
    print("true" if value else "false")
elif value is None:
    print("null")
else:
    print(value)
' "$path"
}

assert_number() {
  local label="$1" actual="$2" expected="$3"
  python3 -c '
import sys
from decimal import Decimal, InvalidOperation
try:
    ok = Decimal(str(sys.argv[1])) == Decimal(str(sys.argv[2]))
except InvalidOperation:
    ok = False
sys.exit(0 if ok else 1)
' "$actual" "$expected" || fail "$label: expected $expected, got $actual"
}

assert_eq() {
  local label="$1" actual="$2" expected="$3"
  [ "$actual" = "$expected" ] || fail "$label: expected $expected, got $actual"
}

# request METHOD PATH [BODY] [IDEMPOTENCY_KEY]
request() {
  local method="$1" path="$2" body="${3:-}" key="${4:-}"
  local out="$TMP_DIR/response.json"
  local args=("${CURL[@]}" -X "$method" "$BASE$path" -H 'Accept: application/json')
  if [ -n "$KEY" ]; then
    args+=(-H "Authorization: Bearer $KEY")
  fi
  if [ -n "$key" ]; then
    args+=(-H "Idempotency-Key: $key")
  fi
  if [ -n "$body" ]; then
    args+=(-H 'Content-Type: application/json' --data "$body")
  fi
  STATUS="$("${args[@]}" -o "$out" -w '%{http_code}')"
  RESPONSE="$(cat "$out")"
  echo "$RESPONSE" >"$TMP_DIR/last.json"
}

uuid() {
  python3 -c 'import uuid; print(uuid.uuid4().hex)'
}

future_date() {
  python3 -c 'from datetime import date, timedelta; print(date.today() + timedelta(days=20))'
}

current_month() {
  python3 -c 'from datetime import date; print(date.today().strftime("%Y-%m"))'
}

echo "Smoke testing $BASE"

ROOT="${BASE%/api/v1}"
STATUS="$("${CURL[@]}" -o "$TMP_DIR/health.json" -w '%{http_code}' "$ROOT/health")"
RESPONSE="$(cat "$TMP_DIR/health.json")"
[ "$STATUS" = "200" ] || fail "health returned $STATUS: $RESPONSE"

EMAIL="smoke-$(date +%s)-$RANDOM@example.com"
PASSWORD='Smoke@12345'

request POST /auth/register "{
  \"full_name\": \"Smoke Tester\",
  \"email\": \"$EMAIL\",
  \"password\": \"$PASSWORD\",
  \"timezone\": \"Asia/Kolkata\"
}"
[ "$STATUS" = "201" ] || fail "register returned $STATUS: $RESPONSE"
KEY="$(printf '%s' "$RESPONSE" | json_get access_token)"
[ -n "$KEY" ] || fail "register did not return an access token"
echo "ok - register"

INCOME_ID="$(uuid)"
request POST /transactions "{
  \"request_id\": \"$INCOME_ID\",
  \"type\": \"income\",
  \"amount\": 5000.00,
  \"currency\": \"INR\",
  \"transaction_date\": \"$(python3 -c 'from datetime import date; print(date.today())')\"
}" "$INCOME_ID"
[ "$STATUS" = "201" ] || fail "income returned $STATUS: $RESPONSE"
BALANCE="$(printf '%s' "$RESPONSE" | json_get available_balance)"
assert_number "income balance" "$BALANCE" "5000.00"
echo "ok - income"

request POST /transactions "{
  \"request_id\": \"$INCOME_ID\",
  \"type\": \"income\",
  \"amount\": 5000.00,
  \"currency\": \"INR\"
}" "$INCOME_ID"
[ "$STATUS" = "201" ] || fail "replay returned $STATUS: $RESPONSE"
REPLAY="$(printf '%s' "$RESPONSE" | json_get idempotent_replay)"
BALANCE="$(printf '%s' "$RESPONSE" | json_get available_balance)"
assert_eq "replay flag" "$REPLAY" "true"
assert_number "replay balance" "$BALANCE" "5000.00"
echo "ok - idempotent replay"

VOICE_ID="$(uuid)"
request POST /commands "{
  \"request_id\": \"$VOICE_ID\",
  \"intent\": \"CREATE_EXPENSE\",
  \"original_amount\": 2000.00,
  \"original_currency\": \"INR\",
  \"category\": \"Groceries\",
  \"description\": \"Weekly groceries\",
  \"voice_text\": \"I spent 2000 rupees on groceries\",
  \"parser_confidence\": 0.97
}" "$VOICE_ID"
[ "$STATUS" = "201" ] || fail "voice command returned $STATUS: $RESPONSE"
BALANCE="$(printf '%s' "$RESPONSE" | json_get available_balance)"
assert_number "voice command balance" "$BALANCE" "3000.00"
CATEGORY="$(printf '%s' "$RESPONSE" | json_get transaction.category_name)"
assert_eq "voice command category" "$CATEGORY" "Groceries"
echo "ok - voice command"

REJECTED_ID="$(uuid)"
request POST /commands "{
  \"request_id\": \"$REJECTED_ID\",
  \"intent\": \"CREATE_EXPENSE\",
  \"original_amount\": 100000.00,
  \"original_currency\": \"INR\",
  \"category\": \"Groceries\",
  \"voice_text\": \"I spent 100000 rupees on groceries\"
}" "$REJECTED_ID"
[ "$STATUS" = "422" ] || fail "rejected command returned $STATUS (expected 422)"
ERROR_CODE="$(printf '%s' "$RESPONSE" | json_get error_code)"
assert_eq "rejected command code" "$ERROR_CODE" "INSUFFICIENT_BALANCE"
request GET /dashboard/summary
[ "$STATUS" = "200" ] || fail "summary after rejection returned $STATUS: $RESPONSE"
BALANCE="$(printf '%s' "$RESPONSE" | json_get summary.available_balance)"
assert_number "balance after rejection" "$BALANCE" "3000.00"
echo "ok - rejected command left balance unchanged"

EXPENSE_ID="$(uuid)"
request POST /expenses "{
  \"request_id\": \"$EXPENSE_ID\",
  \"amount\": 250.00,
  \"currency\": \"INR\",
  \"category_name\": \"Food\"
}" "$EXPENSE_ID"
[ "$STATUS" = "201" ] || fail "expense returned $STATUS: $RESPONSE"
BALANCE="$(printf '%s' "$RESPONSE" | json_get available_balance)"
assert_number "expense balance" "$BALANCE" "2750.00"
echo "ok - expense"

LENDING_ID="$(uuid)"
request POST /lending "{
  \"request_id\": \"$LENDING_ID\",
  \"amount\": 300.00,
  \"currency\": \"INR\",
  \"person_name\": \"Ravi\",
  \"due_date\": \"$(future_date)\"
}" "$LENDING_ID"
[ "$STATUS" = "201" ] || fail "lending returned $STATUS: $RESPONSE"
BALANCE="$(printf '%s' "$RESPONSE" | json_get available_balance)"
assert_number "lending balance" "$BALANCE" "2450.00"
echo "ok - lending"

REPAYMENT_ID="$(uuid)"
request POST /repayments "{
  \"request_id\": \"$REPAYMENT_ID\",
  \"amount\": 100.00,
  \"currency\": \"INR\",
  \"person_name\": \"Ravi\",
  \"repayment_direction\": \"received\"
}" "$REPAYMENT_ID"
[ "$STATUS" = "201" ] || fail "repayment returned $STATUS: $RESPONSE"
BALANCE="$(printf '%s' "$RESPONSE" | json_get available_balance)"
assert_number "repayment balance" "$BALANCE" "2550.00"
echo "ok - repayment"

request GET /loans?kind=lent
[ "$STATUS" = "200" ] || fail "loans returned $STATUS: $RESPONSE"
OUTSTANDING="$(printf '%s' "$RESPONSE" | json_get loans.0.outstanding_amount_inr)"
assert_number "loan outstanding" "$OUTSTANDING" "200.00"
echo "ok - loan outstanding"

request GET /dashboard/summary
[ "$STATUS" = "200" ] || fail "summary returned $STATUS: $RESPONSE"
BALANCE="$(printf '%s' "$RESPONSE" | json_get summary.available_balance)"
assert_number "summary balance" "$BALANCE" "2550.00"
echo "ok - dashboard"

request GET "/calendar?month=$(current_month)"
[ "$STATUS" = "200" ] || fail "calendar returned $STATUS: $RESPONSE"
DAYS="$(printf '%s' "$RESPONSE" | python3 -c 'import json,sys; print(len(json.load(sys.stdin)["days"]))')"
[ "$DAYS" -ge 1 ] || fail "calendar returned no activity days"
echo "ok - calendar"

request POST /admin/actions '{
  "action": "DATABASE_STATS",
  "password": "Smoke@12345",
  "confirm": true,
  "parameters": {}
}' 
[ "$STATUS" = "403" ] || fail "non-admin admin action returned $STATUS (expected 403)"
echo "ok - admin forbidden"

echo
echo "PASS - full ledger flow works against $BASE"
echo "Created $EMAIL (delete it with a database/admin cleanup if needed)."
