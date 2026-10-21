-- 09_repayments.sql --------------------------------------------------------
-- Repayment audit trail across loans, transactions and people.
USE voice_ledger;

SET @user_id = 2;

-- Full repayment context (four-table JOIN).
SELECT
  r.id AS repayment_id,
  r.payment_date,
  p.name AS person,
  l.kind AS loan_kind,
  r.direction,
  r.amount_inr,
  r.status,
  t.id AS transaction_id,
  t.description
FROM repayments r
JOIN loans l ON l.id = r.loan_id
JOIN persons p ON p.id = r.person_id
JOIN transactions t ON t.id = r.transaction_id
WHERE r.user_id = @user_id
ORDER BY r.payment_date DESC, r.id DESC;

-- Totals by direction (GROUP BY, SUM, AVG, COUNT).
SELECT
  direction,
  COUNT(*) AS repayment_count,
  SUM(amount_inr) AS total_inr,
  ROUND(AVG(amount_inr), 2) AS average_inr,
  MIN(payment_date) AS first_payment,
  MAX(payment_date) AS latest_payment
FROM repayments
WHERE user_id = @user_id
  AND status = 'completed'
GROUP BY direction
ORDER BY total_inr DESC;

-- Loans that have repayment activity and their progress.
SELECT
  l.id AS loan_id,
  p.name AS person,
  l.principal_amount_inr,
  SUM(r.amount_inr) AS repaid_inr,
  ROUND(100 * SUM(r.amount_inr) / l.principal_amount_inr, 2) AS percent_repaid
FROM repayments r
JOIN loans l ON l.id = r.loan_id
JOIN persons p ON p.id = l.person_id
WHERE r.user_id = @user_id
GROUP BY l.id, p.name, l.principal_amount_inr
HAVING SUM(r.amount_inr) > 0
ORDER BY percent_repaid DESC;
