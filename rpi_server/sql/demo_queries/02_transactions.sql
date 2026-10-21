-- 02_transactions.sql ------------------------------------------------------
-- Transaction history with category/person names and filtering.
USE voice_ledger;

SET @user_id = 2;

-- Latest ledger rows (SELECT, JOIN, WHERE, ORDER BY, LIMIT).
SELECT
  t.id AS transaction_id,
  t.transaction_date,
  t.type,
  t.amount_inr,
  COALESCE(c.name, '-') AS category,
  COALESCE(p.name, '-') AS person,
  t.description,
  t.status
FROM transactions t
LEFT JOIN categories c ON c.id = t.category_id
LEFT JOIN persons p ON p.id = t.person_id
WHERE t.user_id = @user_id
  AND t.status = 'completed'
ORDER BY t.transaction_date DESC, t.id DESC
LIMIT 15;

-- Search descriptions and names (LIKE).
SELECT
  id,
  transaction_date,
  type,
  amount_inr,
  description
FROM transactions
WHERE user_id = @user_id
  AND (description LIKE '%loan%' OR description LIKE '%salary%')
ORDER BY transaction_date DESC;

-- Volume and count by type (GROUP BY, HAVING, AVG).
SELECT
  type,
  COUNT(*) AS transaction_count,
  SUM(amount_inr) AS total_inr,
  ROUND(AVG(amount_inr), 2) AS average_inr
FROM transactions
WHERE user_id = @user_id
  AND status = 'completed'
GROUP BY type
HAVING COUNT(*) >= 1
ORDER BY total_inr DESC;

-- Rows in the last 30 days (date arithmetic, subquery).
SELECT
  id,
  transaction_date,
  type,
  amount_inr
FROM transactions
WHERE user_id = @user_id
  AND transaction_date >= (
    SELECT DATE_SUB(MAX(transaction_date), INTERVAL 30 DAY)
    FROM transactions
    WHERE user_id = @user_id
  )
ORDER BY transaction_date DESC;

-- Query plan for the paged history access path (MySQL 8.0.18+).
EXPLAIN ANALYZE
SELECT id, transaction_date, type, amount_inr, description
FROM transactions
WHERE user_id = @user_id
  AND status = 'completed'
ORDER BY transaction_date DESC, id DESC
LIMIT 20;
