-- 08_borrowing.sql ---------------------------------------------------------
-- Money borrowed from people and the user's liability.
USE voice_ledger;

SET @user_id = 2;

-- Open borrowed loans payable.
SELECT
  l.id AS loan_id,
  p.name AS person,
  l.principal_amount_inr,
  l.outstanding_amount_inr,
  l.principal_amount_inr - l.outstanding_amount_inr AS repaid_inr,
  l.due_date,
  DATEDIFF(l.due_date, CURDATE()) AS days_until_due,
  l.status
FROM loans l
JOIN persons p ON p.id = l.person_id
WHERE l.user_id = @user_id
  AND l.kind = 'borrowed'
ORDER BY l.due_date IS NULL, l.due_date;

-- Total liability and repayment progress.
SELECT
  COUNT(*) AS open_loans,
  SUM(principal_amount_inr) AS principal_borrowed,
  SUM(outstanding_amount_inr) AS i_still_owe,
  SUM(principal_amount_inr - outstanding_amount_inr) AS i_have_repaid
FROM loans
WHERE user_id = @user_id
  AND kind = 'borrowed'
  AND status = 'open';

-- Net position per person (lent minus borrowed).
SELECT
  p.id AS person_id,
  p.name AS person,
  COALESCE(SUM(CASE WHEN l.kind = 'lent'
                    THEN l.outstanding_amount_inr ELSE 0 END), 0)
    AS they_owe_me,
  COALESCE(SUM(CASE WHEN l.kind = 'borrowed'
                    THEN l.outstanding_amount_inr ELSE 0 END), 0)
    AS i_owe_them,
  COALESCE(SUM(CASE WHEN l.kind = 'lent'
                    THEN l.outstanding_amount_inr
                    ELSE -l.outstanding_amount_inr END), 0)
    AS net_position
FROM persons p
LEFT JOIN loans l
  ON l.person_id = p.id
 AND l.status = 'open'
WHERE p.user_id = @user_id
GROUP BY p.id, p.name
ORDER BY net_position DESC;
