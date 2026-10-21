-- 07_lending.sql -----------------------------------------------------------
-- Money lent to people, repayment progress and overdue loans.
USE voice_ledger;

SET @user_id = 2;

-- Open loans receivable, newest first.
SELECT
  l.id AS loan_id,
  p.name AS person,
  l.principal_amount_inr,
  l.outstanding_amount_inr,
  l.principal_amount_inr - l.outstanding_amount_inr AS repaid_inr,
  l.interest_rate,
  l.interest_type,
  l.start_date,
  l.due_date,
  l.status
FROM loans l
JOIN persons p ON p.id = l.person_id
WHERE l.user_id = @user_id
  AND l.kind = 'lent'
  AND l.status = 'open'
ORDER BY l.due_date IS NULL, l.due_date;

-- Totals for lending (conditional aggregation).
SELECT
  COUNT(*) AS open_loans,
  SUM(principal_amount_inr) AS principal_outstanding_total,
  SUM(outstanding_amount_inr) AS still_owed_to_me,
  SUM(principal_amount_inr - outstanding_amount_inr) AS repaid_to_me
FROM loans
WHERE user_id = @user_id
  AND kind = 'lent'
  AND status = 'open';

-- Repayment history for a lent loan (JOIN + correlated subquery).
SELECT
  l.id AS loan_id,
  p.name AS person,
  l.principal_amount_inr,
  (
    SELECT COALESCE(SUM(r.amount_inr), 0)
    FROM repayments r
    WHERE r.loan_id = l.id AND r.direction = 'received'
  ) AS received_back,
  (
    SELECT COUNT(*)
    FROM repayments r
    WHERE r.loan_id = l.id AND r.direction = 'received'
  ) AS repayment_count
FROM loans l
JOIN persons p ON p.id = l.person_id
WHERE l.user_id = @user_id
  AND l.kind = 'lent'
ORDER BY l.start_date DESC;
