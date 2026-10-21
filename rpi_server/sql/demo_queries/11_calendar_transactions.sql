-- 11_calendar_transactions.sql --------------------------------------------
-- Calendar / month-view aggregates for the Flutter calendar screen.
USE voice_ledger;

SET @user_id = 2;
SET @month_start = DATE_FORMAT(CURDATE(), '%Y-%m-01');

-- Per-day totals for the current month (conditional aggregation).
SELECT
  transaction_date,
  COUNT(*) AS transaction_count,
  SUM(CASE WHEN type = 'income' THEN amount_inr ELSE 0 END) AS income,
  SUM(CASE WHEN type = 'expense' THEN amount_inr ELSE 0 END) AS expense,
  SUM(CASE WHEN type = 'savings' THEN amount_inr ELSE 0 END) AS savings,
  SUM(CASE WHEN type = 'lending' THEN amount_inr ELSE 0 END) AS lending,
  SUM(CASE WHEN type = 'borrowing' THEN amount_inr ELSE 0 END) AS borrowing,
  SUM(CASE WHEN type = 'repayment' THEN amount_inr ELSE 0 END) AS repayment
FROM transactions
WHERE user_id = @user_id
  AND status = 'completed'
  AND transaction_date >= @month_start
  AND transaction_date < DATE_ADD(@month_start, INTERVAL 1 MONTH)
GROUP BY transaction_date
ORDER BY transaction_date;

-- Daily net cash movement (income + borrowing + received - outflows).
SELECT
  transaction_date,
  SUM(
    CASE WHEN type IN ('income', 'borrowing') THEN amount_inr
         WHEN type = 'repayment' AND repayment_direction = 'received'
              THEN amount_inr
         ELSE -amount_inr END
  ) AS net_change_inr
FROM transactions
WHERE user_id = @user_id
  AND status = 'completed'
  AND transaction_date >= @month_start
  AND transaction_date < DATE_ADD(@month_start, INTERVAL 1 MONTH)
GROUP BY transaction_date
ORDER BY transaction_date;

-- Monthly totals for the last six months (date grouping + HAVING).
SELECT
  DATE_FORMAT(transaction_date, '%Y-%m') AS month,
  COUNT(*) AS rows_count,
  SUM(amount_inr) AS gross_volume_inr
FROM transactions
WHERE user_id = @user_id
  AND status = 'completed'
GROUP BY DATE_FORMAT(transaction_date, '%Y-%m')
HAVING COUNT(*) >= 1
ORDER BY month DESC
LIMIT 6;
