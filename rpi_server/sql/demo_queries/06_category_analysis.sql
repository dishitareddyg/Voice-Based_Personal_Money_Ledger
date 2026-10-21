-- 06_category_analysis.sql ------------------------------------------------
-- Category coverage and spending distribution.
USE voice_ledger;

SET @user_id = 2;

-- Every category, including unused ones (LEFT JOIN, COUNT, COALESCE).
SELECT
  c.id AS category_id,
  c.name AS category,
  c.type,
  COUNT(t.id) AS transaction_count,
  COALESCE(SUM(t.amount_inr), 0) AS total_inr
FROM categories c
LEFT JOIN transactions t
  ON t.category_id = c.id
 AND t.user_id = c.user_id
 AND t.status = 'completed'
WHERE c.user_id = @user_id
GROUP BY c.id, c.name, c.type
ORDER BY c.type, total_inr DESC;

-- Expense category ranking and cumulative share (window functions).
SELECT
  COALESCE(c.name, 'Uncategorised') AS category,
  SUM(t.amount_inr) AS total_inr,
  RANK() OVER (ORDER BY SUM(t.amount_inr) DESC) AS rank_by_spend,
  ROUND(
    100 * SUM(SUM(t.amount_inr)) OVER (
      ORDER BY SUM(t.amount_inr) DESC
      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) / SUM(SUM(t.amount_inr)) OVER (),
    2
  ) AS cumulative_percentage
FROM transactions t
LEFT JOIN categories c ON c.id = t.category_id
WHERE t.user_id = @user_id
  AND t.type = 'expense'
  AND t.status = 'completed'
GROUP BY c.name
ORDER BY total_inr DESC;

-- Categories used by more than one transaction (GROUP BY + HAVING).
SELECT
  c.name AS category,
  COUNT(*) AS uses,
  SUM(t.amount_inr) AS total_inr
FROM transactions t
JOIN categories c ON c.id = t.category_id
WHERE t.user_id = @user_id
GROUP BY c.id, c.name
HAVING COUNT(*) > 1
ORDER BY uses DESC;
