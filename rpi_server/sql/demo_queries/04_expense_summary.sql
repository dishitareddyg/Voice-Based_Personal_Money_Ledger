-- 04_expense_summary.sql ---------------------------------------------------
-- Expense analysis using the typed `expenses` view.
USE voice_ledger;

SET @user_id = 2;

-- Monthly expense totals (GROUP BY, SUM, AVG, ORDER BY).
SELECT
  DATE_FORMAT(transaction_date, '%Y-%m') AS month,
  COUNT(*) AS expense_count,
  SUM(amount_inr) AS total_expense_inr,
  ROUND(AVG(amount_inr), 2) AS average_expense_inr
FROM expenses
WHERE user_id = @user_id
GROUP BY month
HAVING SUM(amount_inr) > 0
ORDER BY month DESC;

-- Spending per category with its share of all expenses (window function).
SELECT
  COALESCE(category_name, 'Uncategorised') AS category,
  COUNT(*) AS expense_count,
  SUM(amount_inr) AS total_inr,
  ROUND(
    100 * SUM(amount_inr) / SUM(SUM(amount_inr)) OVER (),
    2
  ) AS percentage_of_expenses
FROM expenses
WHERE user_id = @user_id
GROUP BY category_name
ORDER BY total_inr DESC;

-- Expenses above the user's average expense (subquery in HAVING).
SELECT
  transaction_id,
  transaction_date,
  amount_inr,
  description
FROM expenses
WHERE user_id = @user_id
  AND amount_inr > (
    SELECT AVG(amount_inr) FROM expenses WHERE user_id = @user_id
  )
ORDER BY amount_inr DESC;
