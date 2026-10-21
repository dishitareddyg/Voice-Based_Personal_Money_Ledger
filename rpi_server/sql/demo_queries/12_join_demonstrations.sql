-- 12_join_demonstrations.sql ----------------------------------------------
-- Multi-table joins, outer joins, subqueries and set operations.
USE voice_ledger;

SET @user_id = 2;

-- 1. Full transaction context across five tables.
SELECT
  t.id AS transaction_id,
  t.transaction_date,
  t.type,
  t.amount_inr,
  c.name AS category,
  p.name AS person,
  l.kind AS loan_kind,
  r.direction AS repayment_direction
FROM transactions t
LEFT JOIN categories c ON c.id = t.category_id
LEFT JOIN persons p ON p.id = t.person_id
LEFT JOIN loans l ON l.id = t.loan_id
LEFT JOIN repayments r ON r.transaction_id = t.id
WHERE t.user_id = @user_id
ORDER BY t.transaction_date DESC, t.id DESC;

-- 2. Persons with no open loan (LEFT JOIN + IS NULL).
SELECT
  p.id,
  p.name,
  p.phone
FROM persons p
LEFT JOIN loans l
  ON l.person_id = p.id
 AND l.status = 'open'
WHERE p.user_id = @user_id
  AND l.id IS NULL
ORDER BY p.name;

-- 3. Per-person financial relationship summary (pre-aggregated joins avoid
--    row multiplication between loans and repayments).
SELECT
  p.name,
  COALESCE(l.loan_count, 0) AS loan_count,
  COALESCE(l.open_outstanding, 0) AS open_outstanding,
  COALESCE(r.repayment_count, 0) AS repayment_count,
  COALESCE(r.repaid_total, 0) AS repaid_total
FROM persons p
LEFT JOIN (
  SELECT
    person_id,
    COUNT(*) AS loan_count,
    SUM(CASE WHEN status = 'open' THEN outstanding_amount_inr ELSE 0 END)
      AS open_outstanding
  FROM loans
  WHERE user_id = @user_id
  GROUP BY person_id
) AS l ON l.person_id = p.id
LEFT JOIN (
  SELECT
    person_id,
    COUNT(*) AS repayment_count,
    SUM(amount_inr) AS repaid_total
  FROM repayments
  WHERE user_id = @user_id AND status = 'completed'
  GROUP BY person_id
) AS r ON r.person_id = p.id
WHERE p.user_id = @user_id
ORDER BY open_outstanding DESC, p.name;

-- 4. Subquery: latest transaction for each user.
SELECT
  u.id AS user_id,
  u.full_name,
  latest.id AS latest_transaction_id,
  latest.transaction_date,
  latest.type,
  latest.amount_inr
FROM users u
LEFT JOIN transactions latest
  ON latest.id = (
    SELECT t2.id
    FROM transactions t2
    WHERE t2.user_id = u.id
    ORDER BY t2.transaction_date DESC, t2.id DESC
    LIMIT 1
  )
ORDER BY u.id;

-- 5. UNION: money owed to me and money I owe (labelled exposure).
SELECT
  'they_owe_me' AS exposure,
  person_name AS person,
  outstanding_amount_inr AS amount_inr
FROM v_open_loans
WHERE user_id = @user_id AND kind = 'lent'
UNION ALL
SELECT
  'i_owe_them' AS exposure,
  person_name AS person,
  outstanding_amount_inr AS amount_inr
FROM v_open_loans
WHERE user_id = @user_id AND kind = 'borrowed'
ORDER BY exposure, amount_inr DESC;
