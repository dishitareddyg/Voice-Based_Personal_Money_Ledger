-- ===========================================================================
-- Analytical and typed views used by the DBMS report and evaluator demos.
--
-- MySQL does not support INSTEAD OF triggers, so these views are read-only.
-- `income`, `expenses` and `savings` are projections over the single central
-- ledger; they never store a second copy of a financial fact.
-- ===========================================================================

USE voice_ledger;

SET NAMES utf8mb4;

CREATE OR REPLACE VIEW v_user_balances AS
SELECT
  user_id,
  SUM(CASE WHEN type = 'income'     THEN amount_inr ELSE 0 END) AS total_income,
  SUM(CASE WHEN type = 'expense'    THEN amount_inr ELSE 0 END) AS total_expenses,
  SUM(CASE WHEN type = 'savings'    THEN amount_inr ELSE 0 END) AS total_savings,
  SUM(CASE WHEN type = 'lending'    THEN amount_inr ELSE 0 END) AS money_lent,
  SUM(CASE WHEN type = 'borrowing'  THEN amount_inr ELSE 0 END) AS money_borrowed,
  SUM(CASE WHEN type = 'repayment' AND repayment_direction = 'received'
           THEN amount_inr ELSE 0 END) AS repayments_received,
  SUM(CASE WHEN type = 'repayment' AND repayment_direction = 'paid'
           THEN amount_inr ELSE 0 END) AS repayments_paid,
  SUM(
      CASE WHEN type = 'income'    THEN amount_inr
           WHEN type = 'borrowing' THEN amount_inr
           WHEN type = 'repayment' AND repayment_direction = 'received'
                THEN amount_inr
           ELSE -amount_inr END
  ) AS available_balance
FROM transactions
WHERE status = 'completed'
GROUP BY user_id;

CREATE OR REPLACE VIEW v_open_loans AS
SELECT
  l.id,
  l.user_id,
  l.kind,
  p.name AS person_name,
  l.principal_amount_inr,
  l.outstanding_amount_inr,
  l.start_date,
  l.due_date,
  l.status,
  CASE
    WHEN l.due_date IS NOT NULL AND l.due_date < CURDATE() THEN 'overdue'
    WHEN l.due_date IS NOT NULL AND l.due_date <= CURDATE() + INTERVAL 30 DAY
         THEN 'due_soon'
    ELSE 'on_track'
  END AS urgency
FROM loans l
JOIN persons p ON p.id = l.person_id
WHERE l.status = 'open';

-- One row per completed income transaction, with display names resolved.
CREATE OR REPLACE VIEW income AS
SELECT
  t.id AS transaction_id,
  t.user_id,
  t.amount_inr,
  t.original_amount,
  t.original_currency,
  t.exchange_rate_to_inr,
  t.transaction_date,
  t.description,
  t.category_id,
  c.name AS category_name,
  t.person_id,
  p.name AS person_name,
  t.request_id,
  t.created_at,
  t.updated_at
FROM transactions t
LEFT JOIN categories c ON c.id = t.category_id
LEFT JOIN persons p ON p.id = t.person_id
WHERE t.type = 'income' AND t.status = 'completed';

CREATE OR REPLACE VIEW expenses AS
SELECT
  t.id AS transaction_id,
  t.user_id,
  t.amount_inr,
  t.original_amount,
  t.original_currency,
  t.exchange_rate_to_inr,
  t.transaction_date,
  t.description,
  t.category_id,
  c.name AS category_name,
  t.person_id,
  p.name AS person_name,
  t.request_id,
  t.created_at,
  t.updated_at
FROM transactions t
LEFT JOIN categories c ON c.id = t.category_id
LEFT JOIN persons p ON p.id = t.person_id
WHERE t.type = 'expense' AND t.status = 'completed';

CREATE OR REPLACE VIEW savings AS
SELECT
  t.id AS transaction_id,
  t.user_id,
  t.amount_inr,
  t.original_amount,
  t.original_currency,
  t.exchange_rate_to_inr,
  t.transaction_date,
  t.description,
  t.category_id,
  c.name AS category_name,
  t.person_id,
  p.name AS person_name,
  t.request_id,
  t.created_at,
  t.updated_at
FROM transactions t
LEFT JOIN categories c ON c.id = t.category_id
LEFT JOIN persons p ON p.id = t.person_id
WHERE t.type = 'savings' AND t.status = 'completed';
