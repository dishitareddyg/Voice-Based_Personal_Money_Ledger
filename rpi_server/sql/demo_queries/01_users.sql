-- 01_users.sql -------------------------------------------------------------
-- User directory, role counts and per-user activity.
USE voice_ledger;

-- All active accounts (SELECT, WHERE, ORDER BY).
SELECT
  id,
  full_name,
  email,
  role,
  timezone,
  created_at
FROM users
WHERE is_active = TRUE
ORDER BY id;

-- How many accounts exist per role (GROUP BY, HAVING).
SELECT
  role,
  COUNT(*) AS account_count,
  MIN(created_at) AS first_registration,
  MAX(created_at) AS latest_registration
FROM users
GROUP BY role
HAVING COUNT(*) >= 1
ORDER BY account_count DESC;

-- Per-user ledger activity (LEFT JOIN, COUNT, SUM, COALESCE).
SELECT
  u.id AS user_id,
  u.full_name,
  COUNT(t.id) AS transaction_count,
  COALESCE(SUM(t.amount_inr), 0) AS total_volume_inr
FROM users u
LEFT JOIN transactions t ON t.user_id = u.id
GROUP BY u.id, u.full_name
ORDER BY total_volume_inr DESC;
