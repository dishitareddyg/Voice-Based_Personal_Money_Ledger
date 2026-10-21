-- ===========================================================================
-- Demo seed data. Run once on a fresh database.
--
-- Two accounts are created:
--   admin@voiceledger.local / Admin@12345
--   demo@voiceledger.local  / Demo@12345
--
-- Regenerate password hashes with:
--   python -m app.scripts.hash_password "YourPassword"
--
-- Never keep these demo credentials in production.
--
-- Financial consistency:
--   income + borrowing + repayment(received) = 103000.00
--   expense + savings + lending + repayment(paid) = 40750.00
--   available balance = 62250.00
-- ===========================================================================

USE voice_ledger;

SET NAMES utf8mb4;

INSERT INTO users
  (id, full_name, email, password_hash, role, is_active, timezone,
   created_at, updated_at)
VALUES
  (1, 'Ledger Administrator', 'admin@voiceledger.local',
   '$argon2id$v=19$m=19456,t=2,p=1$QWzh9O0svICTK4Ol7br4lg$KGd6YiMQpFbgg4ulRTa1xxUlZdSKaPA93Bm9+GGDsv4',
   'admin', TRUE, 'Asia/Kolkata', UTC_TIMESTAMP(), UTC_TIMESTAMP()),
  (2, 'Demo User', 'demo@voiceledger.local',
   '$argon2id$v=19$m=19456,t=2,p=1$RWlGEC+DlZaE5JfeuzWyVQ$LLg7hME5PzFDhxNAHZYH2T+E9PpFJ0D7YOk+gA5n0PQ',
   'user', TRUE, 'Asia/Kolkata', UTC_TIMESTAMP(), UTC_TIMESTAMP());

INSERT INTO categories
  (id, user_id, name, type, color_hex, icon_key, is_default,
   created_at, updated_at)
VALUES
  (1,  2, 'Food',          'expense', '#E76F51', 'restaurant',       TRUE, UTC_TIMESTAMP(), UTC_TIMESTAMP()),
  (2,  2, 'Groceries',     'expense', '#F4A261', 'shopping_basket',  TRUE, UTC_TIMESTAMP(), UTC_TIMESTAMP()),
  (3,  2, 'Transport',     'expense', '#457B9D', 'directions_bus',   TRUE, UTC_TIMESTAMP(), UTC_TIMESTAMP()),
  (4,  2, 'Education',     'expense', '#6D597A', 'school',           TRUE, UTC_TIMESTAMP(), UTC_TIMESTAMP()),
  (5,  2, 'Bills',         'expense', '#B56576', 'receipt_long',     TRUE, UTC_TIMESTAMP(), UTC_TIMESTAMP()),
  (6,  2, 'Entertainment', 'expense', '#9B5DE5', 'movie',            TRUE, UTC_TIMESTAMP(), UTC_TIMESTAMP()),
  (7,  2, 'Healthcare',    'expense', '#2A9D8F', 'local_hospital',   TRUE, UTC_TIMESTAMP(), UTC_TIMESTAMP()),
  (8,  2, 'Shopping',      'expense', '#E9C46A', 'shopping_bag',     TRUE, UTC_TIMESTAMP(), UTC_TIMESTAMP()),
  (9,  2, 'Salary',        'income',  '#2A9D8F', 'payments',         TRUE, UTC_TIMESTAMP(), UTC_TIMESTAMP()),
  (10, 2, 'Freelance',     'income',  '#43AA8B', 'work',             TRUE, UTC_TIMESTAMP(), UTC_TIMESTAMP()),
  (11, 2, 'Savings',       'savings', '#E9C46A', 'savings',          TRUE, UTC_TIMESTAMP(), UTC_TIMESTAMP());

INSERT INTO persons
  (id, user_id, name, phone, email, notes, created_at, updated_at)
VALUES
  (1, 2, 'Ravi Kumar',   '+91-90000-00001', NULL, 'Friend',    UTC_TIMESTAMP(), UTC_TIMESTAMP()),
  (2, 2, 'Asha Patel',   '+91-90000-00002', NULL, 'Colleague', UTC_TIMESTAMP(), UTC_TIMESTAMP()),
  (3, 2, 'Priya Sharma', '+91-90000-00003', NULL, 'Neighbour', UTC_TIMESTAMP(), UTC_TIMESTAMP()),
  (4, 2, 'Arjun Mehta',  '+91-90000-00004', NULL, 'Family',    UTC_TIMESTAMP(), UTC_TIMESTAMP());

INSERT INTO interest_schemes
  (id, user_id, name, rate, interest_type, compounding_frequency,
   description, is_active, created_at, updated_at)
VALUES
  (1, 2, 'Family loan 8.5%', 8.500, 'simple', 'none',
   'Simple interest for informal family loans.',
   TRUE, UTC_TIMESTAMP(), UTC_TIMESTAMP());

INSERT INTO transactions
  (id, user_id, type, amount_inr, transaction_date, description,
   category_id, person_id, loan_id, repayment_direction,
   interest_rate, interest_type, status, request_id, created_at, updated_at)
VALUES
  (1,  2, 'income',    75000.00, CURDATE() - INTERVAL 25 DAY, 'Monthly salary',
   9,  NULL, NULL, NULL, NULL, NULL, 'completed', 'seed-income-0001',    UTC_TIMESTAMP(), UTC_TIMESTAMP()),
  (2,  2, 'income',    18000.00, CURDATE() - INTERVAL 12 DAY, 'Freelance website project',
   10, NULL, NULL, NULL, NULL, NULL, 'completed', 'seed-income-0002',    UTC_TIMESTAMP(), UTC_TIMESTAMP()),
  (3,  2, 'expense',    1250.00, CURDATE() - INTERVAL 20 DAY, 'Family dinner',
   1,  NULL, NULL, NULL, NULL, NULL, 'completed', 'seed-expense-0001',   UTC_TIMESTAMP(), UTC_TIMESTAMP()),
  (4,  2, 'expense',    4300.00, CURDATE() - INTERVAL 18 DAY, 'Monthly groceries',
   2,  NULL, NULL, NULL, NULL, NULL, 'completed', 'seed-expense-0002',   UTC_TIMESTAMP(), UTC_TIMESTAMP()),
  (5,  2, 'expense',     900.00, CURDATE() - INTERVAL 15 DAY, 'Metro and auto fares',
   3,  NULL, NULL, NULL, NULL, NULL, 'completed', 'seed-expense-0003',   UTC_TIMESTAMP(), UTC_TIMESTAMP()),
  (6,  2, 'expense',    2200.00, CURDATE() - INTERVAL 14 DAY, 'Electricity and internet',
   5,  NULL, NULL, NULL, NULL, NULL, 'completed', 'seed-expense-0004',   UTC_TIMESTAMP(), UTC_TIMESTAMP()),
  (7,  2, 'expense',    1500.00, CURDATE() - INTERVAL 9 DAY,  'Movie tickets',
   6,  NULL, NULL, NULL, NULL, NULL, 'completed', 'seed-expense-0005',   UTC_TIMESTAMP(), UTC_TIMESTAMP()),
  (8,  2, 'expense',    3000.00, CURDATE() - INTERVAL 8 DAY,  'Pharmacy and consultation',
   7,  NULL, NULL, NULL, NULL, NULL, 'completed', 'seed-expense-0006',   UTC_TIMESTAMP(), UTC_TIMESTAMP()),
  (9,  2, 'expense',    2600.00, CURDATE() - INTERVAL 6 DAY,  'Clothing',
   8,  NULL, NULL, NULL, NULL, NULL, 'completed', 'seed-expense-0007',   UTC_TIMESTAMP(), UTC_TIMESTAMP()),
  (10, 2, 'expense',    6000.00, CURDATE() - INTERVAL 3 DAY,  'Online course fee',
   4,  NULL, NULL, NULL, NULL, NULL, 'completed', 'seed-expense-0008',   UTC_TIMESTAMP(), UTC_TIMESTAMP()),
  (11, 2, 'savings',   10000.00, CURDATE() - INTERVAL 11 DAY, 'Emergency fund',
   11, NULL, NULL, NULL, NULL, NULL, 'completed', 'seed-savings-0001',   UTC_TIMESTAMP(), UTC_TIMESTAMP()),
  (12, 2, 'lending',    5000.00, CURDATE() - INTERVAL 16 DAY, 'Short-term loan to Ravi',
   NULL, 1, NULL, NULL, 8.500, 'simple', 'completed', 'seed-lending-0001', UTC_TIMESTAMP(), UTC_TIMESTAMP()),
  (13, 2, 'borrowing',  8000.00, CURDATE() - INTERVAL 13 DAY, 'Borrowed for laptop repair',
   NULL, 2, NULL, NULL, NULL, NULL, 'completed', 'seed-borrowing-0001', UTC_TIMESTAMP(), UTC_TIMESTAMP()),
  (14, 2, 'lending',    2500.00, CURDATE() - INTERVAL 7 DAY,  'Loan to Priya for books',
   NULL, 3, NULL, NULL, 10.000, 'compound', 'completed', 'seed-lending-0002', UTC_TIMESTAMP(), UTC_TIMESTAMP());

INSERT INTO loans
  (id, user_id, person_id, source_transaction_id, kind,
   principal_amount_inr, outstanding_amount_inr, interest_rate,
   interest_type, status, start_date, due_date,
   description, created_at, updated_at)
VALUES
  (1, 2, 1, 12, 'lent', 5000.00, 3000.00, 8.500, 'simple', 'open',
   CURDATE() - INTERVAL 16 DAY, CURDATE() + INTERVAL 14 DAY,
   'Short-term loan to Ravi', UTC_TIMESTAMP(), UTC_TIMESTAMP()),
  (2, 2, 2, 13, 'borrowed', 8000.00, 6500.00, 0.000, 'simple', 'open',
   CURDATE() - INTERVAL 13 DAY, CURDATE() + INTERVAL 20 DAY,
   'Borrowed for laptop repair', UTC_TIMESTAMP(), UTC_TIMESTAMP()),
  (3, 2, 3, 14, 'lent', 2500.00, 2500.00, 10.000, 'compound', 'open',
   CURDATE() - INTERVAL 7 DAY, CURDATE() + INTERVAL 30 DAY,
   'Loan to Priya for books', UTC_TIMESTAMP(), UTC_TIMESTAMP());

UPDATE transactions SET loan_id = 1 WHERE id = 12;
UPDATE transactions SET loan_id = 2 WHERE id = 13;
UPDATE transactions SET loan_id = 3 WHERE id = 14;

INSERT INTO transactions
  (id, user_id, type, amount_inr, transaction_date, description,
   category_id, person_id, loan_id, repayment_direction,
   interest_rate, interest_type, status, request_id, created_at, updated_at)
VALUES
  (15, 2, 'repayment', 2000.00, CURDATE() - INTERVAL 5 DAY,
   'Ravi repaid part of the loan', NULL, 1, 1, 'received',
   NULL, NULL, 'completed', 'seed-repayment-0001', UTC_TIMESTAMP(), UTC_TIMESTAMP()),
  (16, 2, 'repayment', 1500.00, CURDATE() - INTERVAL 4 DAY,
   'Paid Asha part of the borrowed amount', NULL, 2, 2, 'paid',
   NULL, NULL, 'completed', 'seed-repayment-0002', UTC_TIMESTAMP(), UTC_TIMESTAMP());

INSERT INTO repayments
  (id, user_id, loan_id, transaction_id, person_id, amount_inr,
   direction, payment_date, notes, status, created_at)
VALUES
  (1, 2, 1, 15, 1, 2000.00, 'received',
   CURDATE() - INTERVAL 5 DAY, 'Ravi repaid part of the loan',
   'completed', UTC_TIMESTAMP()),
  (2, 2, 2, 16, 2, 1500.00, 'paid',
   CURDATE() - INTERVAL 4 DAY, 'Paid Asha part of the borrowed amount',
   'completed', UTC_TIMESTAMP());
