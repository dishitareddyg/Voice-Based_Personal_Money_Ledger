-- 03_balance.sql -----------------------------------------------------------
-- Authoritative available balance for one user and all users.
USE voice_ledger;

SET @user_id = 2;

-- One user, inline conditional aggregation over the ledger.
SELECT
  @user_id AS user_id,
  SUM(CASE WHEN type = 'income'    THEN amount_inr ELSE 0 END) AS income,
  SUM(CASE WHEN type = 'expense'   THEN amount_inr ELSE 0 END) AS expenses,
  SUM(CASE WHEN type = 'savings'   THEN amount_inr ELSE 0 END) AS savings,
  SUM(CASE WHEN type = 'lending'   THEN amount_inr ELSE 0 END) AS lent,
  SUM(CASE WHEN type = 'borrowing' THEN amount_inr ELSE 0 END) AS borrowed,
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
WHERE user_id = @user_id
  AND status = 'completed';

-- Every user through the reusable view.
SELECT * FROM v_user_balances ORDER BY user_id;

-- Cross-check the view against the inline query (subquery comparison).
SELECT
  b.user_id,
  b.available_balance AS view_balance,
  (
    SELECT SUM(
      CASE WHEN t.type IN ('income', 'borrowing') THEN t.amount_inr
           WHEN t.type = 'repayment' AND t.repayment_direction = 'received'
                THEN t.amount_inr
           ELSE -t.amount_inr END
    )
    FROM transactions t
    WHERE t.user_id = b.user_id AND t.status = 'completed'
  ) AS recomputed_balance
FROM v_user_balances b
ORDER BY b.user_id;
