-- 10_outstanding_loans.sql ------------------------------------------------
-- Outstanding lending/borrowing and urgency classification.
USE voice_ledger;

-- The reusable view already classifies urgency.
SELECT
  id AS loan_id,
  kind,
  person_name,
  principal_amount_inr,
  outstanding_amount_inr,
  due_date,
  urgency
FROM v_open_loans
WHERE user_id = 2
ORDER BY
  CASE urgency
    WHEN 'overdue' THEN 1
    WHEN 'due_soon' THEN 2
    ELSE 3
  END,
  due_date;

-- Outstanding totals by kind and urgency.
SELECT
  kind,
  urgency,
  COUNT(*) AS loan_count,
  SUM(outstanding_amount_inr) AS outstanding_inr
FROM v_open_loans
WHERE user_id = 2
GROUP BY kind, urgency
HAVING SUM(outstanding_amount_inr) > 0
ORDER BY kind, outstanding_inr DESC;

-- People whose net outstanding exceeds the average person's exposure.
SELECT
  person_name,
  SUM(outstanding_amount_inr) AS total_outstanding
FROM v_open_loans
WHERE user_id = 2
GROUP BY person_name
HAVING SUM(outstanding_amount_inr) > (
  SELECT AVG(person_total) FROM (
    SELECT SUM(outstanding_amount_inr) AS person_total
    FROM v_open_loans
    WHERE user_id = 2
    GROUP BY person_name
  ) AS totals
)
ORDER BY total_outstanding DESC;

-- Persons who have never participated in a repayment (`NOT EXISTS`).
SELECT
  p.id,
  p.name
FROM persons p
WHERE p.user_id = 2
  AND NOT EXISTS (
    SELECT 1
    FROM repayments r
    WHERE r.person_id = p.id
      AND r.user_id = p.user_id
  )
ORDER BY p.name;
