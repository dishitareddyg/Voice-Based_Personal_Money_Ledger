-- 05_income_summary.sql ----------------------------------------------------
-- Income analysis using the typed `income` view.
USE voice_ledger;

SET @user_id = 2;

-- Income by month and source category.
SELECT
  DATE_FORMAT(transaction_date, '%Y-%m') AS month,
  COALESCE(category_name, 'Uncategorised') AS source,
  COUNT(*) AS income_count,
  SUM(amount_inr) AS total_inr,
  ROUND(AVG(amount_inr), 2) AS average_inr
FROM income
WHERE user_id = @user_id
GROUP BY month, category_name
ORDER BY month DESC, total_inr DESC;

-- Monthly income and month-over-month change (window function).
WITH monthly AS (
  SELECT
    DATE_FORMAT(transaction_date, '%Y-%m') AS month,
    SUM(amount_inr) AS total_income
  FROM income
  WHERE user_id = @user_id
  GROUP BY DATE_FORMAT(transaction_date, '%Y-%m')
)
SELECT
  month,
  total_income,
  SUM(total_income) OVER (ORDER BY month) AS cumulative_income,
  total_income - LAG(total_income) OVER (ORDER BY month) AS change_from_previous
FROM monthly
ORDER BY month;

-- Income concentration: categories above the average category income.
SELECT
  category_name,
  SUM(amount_inr) AS total_inr
FROM income
WHERE user_id = @user_id
GROUP BY category_name
HAVING SUM(amount_inr) > (
  SELECT AVG(category_total) FROM (
    SELECT SUM(amount_inr) AS category_total
    FROM income
    WHERE user_id = @user_id
    GROUP BY category_name
  ) AS category_totals
)
ORDER BY total_inr DESC;
