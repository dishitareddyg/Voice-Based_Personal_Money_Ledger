-- ===========================================================================
-- Voice-Enabled Personal Financial Ledger - MySQL 8.x schema
--
-- Authoritative DDL for the DBMS report and for fresh installations.
-- Requires MySQL 8.0.18+; CHECK constraints are enforced and EXPLAIN ANALYZE
-- is available for the demo query plans.
--
-- The central `transactions` table is the single source of truth. The
-- `income`, `expenses` and `savings` relations are read-only views defined in
-- 002_views.sql; keeping one physical ledger avoids update anomalies.
--
-- Alembic migrations 0001_initial, 0002_dbms_layer and 0003_support_tables
-- create the same objects. MySQL is the only database: voice-command
-- metadata, audit/application events and the FX cache live in the four
-- upper-case support tables at the end of this file (names are case-sensitive
-- on Linux).
-- ===========================================================================

CREATE DATABASE IF NOT EXISTS voice_ledger
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_0900_ai_ci;

USE voice_ledger;

SET NAMES utf8mb4;

CREATE TABLE IF NOT EXISTS users (
  id              BIGINT       NOT NULL AUTO_INCREMENT,
  full_name       VARCHAR(120) NOT NULL,
  email           VARCHAR(255) NOT NULL,
  password_hash   VARCHAR(255) NOT NULL,
  role            VARCHAR(20)  NOT NULL DEFAULT 'user',
  is_active       BOOLEAN      NOT NULL DEFAULT TRUE,
  timezone        VARCHAR(64)  NOT NULL DEFAULT 'Asia/Kolkata',
  created_at      DATETIME     NOT NULL,
  updated_at      DATETIME     NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY ix_users_email (email),
  CONSTRAINT ck_users_role CHECK (role IN ('user', 'admin')),
  CONSTRAINT ck_users_full_name CHECK (CHAR_LENGTH(TRIM(full_name)) > 0),
  CONSTRAINT ck_users_timezone CHECK (CHAR_LENGTH(TRIM(timezone)) > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS persons (
  id          BIGINT       NOT NULL AUTO_INCREMENT,
  user_id     BIGINT       NOT NULL,
  name        VARCHAR(120) NOT NULL,
  phone       VARCHAR(30)  NULL,
  email       VARCHAR(255) NULL,
  notes       VARCHAR(500) NULL,
  created_at  DATETIME     NOT NULL,
  updated_at  DATETIME     NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_persons_user_name (user_id, name),
  KEY ix_persons_user_id (user_id),
  CONSTRAINT ck_persons_name CHECK (CHAR_LENGTH(TRIM(name)) > 0),
  CONSTRAINT fk_persons_user FOREIGN KEY (user_id)
    REFERENCES users (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS categories (
  id          BIGINT      NOT NULL AUTO_INCREMENT,
  user_id     BIGINT      NOT NULL,
  name        VARCHAR(80) NOT NULL,
  type        VARCHAR(20) NOT NULL,
  color_hex   VARCHAR(9)  NOT NULL DEFAULT '#0E6B5C',
  icon_key    VARCHAR(40) NOT NULL DEFAULT 'category',
  is_default  BOOLEAN     NOT NULL DEFAULT FALSE,
  created_at  DATETIME    NOT NULL,
  updated_at  DATETIME    NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_categories_user_name_type (user_id, name, type),
  KEY ix_categories_user_id (user_id),
  KEY ix_categories_type (type),
  KEY ix_categories_user_type (user_id, type),
  CONSTRAINT ck_categories_type CHECK (
    type IN ('income', 'expense', 'savings', 'lending', 'borrowing', 'repayment')
  ),
  CONSTRAINT ck_categories_name CHECK (CHAR_LENGTH(TRIM(name)) > 0),
  CONSTRAINT fk_categories_user FOREIGN KEY (user_id)
    REFERENCES users (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS interest_schemes (
  id                     BIGINT       NOT NULL AUTO_INCREMENT,
  user_id                BIGINT       NOT NULL,
  name                   VARCHAR(80)  NOT NULL,
  rate                   DECIMAL(6,3) NOT NULL,
  interest_type          VARCHAR(20)  NOT NULL DEFAULT 'simple',
  compounding_frequency  VARCHAR(20)  NOT NULL DEFAULT 'none',
  description            VARCHAR(255) NULL,
  is_active              BOOLEAN      NOT NULL DEFAULT TRUE,
  created_at             DATETIME     NOT NULL,
  updated_at             DATETIME     NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_interest_schemes_user_name (user_id, name),
  KEY ix_interest_schemes_user_id (user_id),
  CONSTRAINT ck_interest_schemes_name CHECK (CHAR_LENGTH(TRIM(name)) > 0),
  CONSTRAINT ck_interest_schemes_rate CHECK (rate >= 0 AND rate <= 100),
  CONSTRAINT ck_interest_schemes_type CHECK (
    interest_type IN ('simple', 'compound', 'flat')
  ),
  CONSTRAINT ck_interest_schemes_compounding CHECK (
    compounding_frequency IN
      ('none', 'daily', 'monthly', 'quarterly', 'half_yearly', 'yearly')
  ),
  CONSTRAINT fk_interest_schemes_user FOREIGN KEY (user_id)
    REFERENCES users (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- loans is created before transactions because transactions.loan_id points to
-- it. The reverse foreign key (source_transaction_id) is added after both
-- tables exist to break the circular dependency.
CREATE TABLE IF NOT EXISTS loans (
  id                     BIGINT        NOT NULL AUTO_INCREMENT,
  user_id                BIGINT        NOT NULL,
  person_id              BIGINT        NOT NULL,
  source_transaction_id  BIGINT        NULL,
  kind                   VARCHAR(10)   NOT NULL,
  principal_amount_inr   DECIMAL(15,2) NOT NULL,
  outstanding_amount_inr DECIMAL(15,2) NOT NULL,
  interest_rate          DECIMAL(6,3)  NOT NULL DEFAULT 0.000,
  interest_type          VARCHAR(20)   NOT NULL DEFAULT 'simple',
  status                 VARCHAR(20)   NOT NULL DEFAULT 'open',
  start_date             DATE          NOT NULL,
  due_date               DATE          NULL,
  description            VARCHAR(255)  NULL,
  created_at             DATETIME      NOT NULL,
  updated_at             DATETIME      NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_loans_source_transaction (source_transaction_id),
  KEY ix_loans_user_id (user_id),
  KEY ix_loans_person_id (person_id),
  KEY ix_loans_kind (kind),
  KEY ix_loans_status (status),
  KEY ix_loans_user_status (user_id, status),
  KEY ix_loans_user_kind_status (user_id, kind, status),
  CONSTRAINT ck_loans_kind CHECK (kind IN ('lent', 'borrowed')),
  CONSTRAINT ck_loans_status CHECK (status IN ('open', 'closed')),
  CONSTRAINT ck_loans_principal_positive CHECK (principal_amount_inr > 0),
  CONSTRAINT ck_loans_outstanding_nonnegative CHECK (outstanding_amount_inr >= 0),
  CONSTRAINT ck_loans_interest_rate CHECK (interest_rate >= 0 AND interest_rate <= 100),
  CONSTRAINT ck_loans_interest_type CHECK (
    interest_type IN ('simple', 'compound', 'flat')
  ),
  CONSTRAINT ck_loans_due_after_start CHECK (
    due_date IS NULL OR due_date >= start_date
  ),
  CONSTRAINT fk_loans_user FOREIGN KEY (user_id)
    REFERENCES users (id) ON DELETE CASCADE,
  CONSTRAINT fk_loans_person FOREIGN KEY (person_id)
    REFERENCES persons (id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS transactions (
  id                    BIGINT        NOT NULL AUTO_INCREMENT,
  user_id               BIGINT        NOT NULL,
  type                  VARCHAR(20)   NOT NULL,
  amount_inr            DECIMAL(15,2) NOT NULL,
  original_amount       DECIMAL(15,2) NULL,
  original_currency     VARCHAR(3)    NULL,
  exchange_rate_to_inr  DECIMAL(18,8) NULL,
  transaction_date      DATE          NOT NULL,
  description           VARCHAR(255)  NULL,
  category_id           BIGINT        NULL,
  person_id             BIGINT        NULL,
  loan_id               BIGINT        NULL,
  repayment_direction   VARCHAR(10)   NULL,
  interest_rate         DECIMAL(6,3)  NULL,
  interest_type         VARCHAR(20)   NULL,
  status                VARCHAR(20)   NOT NULL DEFAULT 'completed',
  request_id            VARCHAR(64)   NOT NULL,
  created_at            DATETIME      NOT NULL,
  updated_at            DATETIME      NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_transactions_user_request (user_id, request_id),
  KEY ix_transactions_user_id (user_id),
  KEY ix_transactions_type (type),
  KEY ix_transactions_transaction_date (transaction_date),
  KEY ix_transactions_category_id (category_id),
  KEY ix_transactions_person_id (person_id),
  KEY ix_transactions_loan_id (loan_id),
  KEY ix_transactions_request_id (request_id),
  KEY ix_transactions_user_date (user_id, transaction_date),
  KEY ix_transactions_user_date_id (user_id, transaction_date, id),
  KEY ix_transactions_user_type (user_id, type),
  KEY ix_transactions_user_category (user_id, category_id),
  KEY ix_transactions_user_person (user_id, person_id),
  KEY ix_transactions_user_loan (user_id, loan_id),
  CONSTRAINT ck_transactions_type CHECK (
    type IN ('income', 'expense', 'savings', 'lending', 'borrowing', 'repayment')
  ),
  CONSTRAINT ck_transactions_amount_positive CHECK (amount_inr > 0),
  CONSTRAINT ck_transactions_original_amount_positive CHECK (
    original_amount IS NULL OR original_amount > 0
  ),
  CONSTRAINT ck_transactions_original_currency CHECK (
    original_currency IS NULL OR CHAR_LENGTH(original_currency) = 3
  ),
  CONSTRAINT ck_transactions_exchange_rate_positive CHECK (
    exchange_rate_to_inr IS NULL OR exchange_rate_to_inr > 0
  ),
  CONSTRAINT ck_transactions_direction CHECK (
    repayment_direction IS NULL
    OR repayment_direction IN ('received', 'paid')
  ),
  CONSTRAINT ck_transactions_interest_rate CHECK (
    interest_rate IS NULL
    OR (interest_rate >= 0 AND interest_rate <= 100)
  ),
  CONSTRAINT ck_transactions_status CHECK (status IN ('completed', 'reversed')),
  CONSTRAINT ck_transactions_request_id_length CHECK (CHAR_LENGTH(request_id) >= 8),
  CONSTRAINT fk_transactions_user FOREIGN KEY (user_id)
    REFERENCES users (id) ON DELETE CASCADE,
  CONSTRAINT fk_transactions_category FOREIGN KEY (category_id)
    REFERENCES categories (id) ON DELETE SET NULL,
  CONSTRAINT fk_transactions_person FOREIGN KEY (person_id)
    REFERENCES persons (id) ON DELETE SET NULL,
  CONSTRAINT fk_transactions_loan FOREIGN KEY (loan_id)
    REFERENCES loans (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

ALTER TABLE loans
  ADD CONSTRAINT fk_loans_source_transaction
  FOREIGN KEY (source_transaction_id) REFERENCES transactions (id)
  ON DELETE SET NULL;

CREATE TABLE IF NOT EXISTS repayments (
  id              BIGINT        NOT NULL AUTO_INCREMENT,
  user_id         BIGINT        NOT NULL,
  loan_id         BIGINT        NOT NULL,
  transaction_id  BIGINT        NOT NULL,
  person_id       BIGINT        NOT NULL,
  amount_inr      DECIMAL(15,2) NOT NULL,
  direction       VARCHAR(10)   NOT NULL,
  payment_date    DATE          NOT NULL,
  notes           VARCHAR(255)  NULL,
  status          VARCHAR(20)   NOT NULL DEFAULT 'completed',
  created_at      DATETIME      NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_repayments_transaction (transaction_id),
  KEY ix_repayments_user_id (user_id),
  KEY ix_repayments_loan_id (loan_id),
  KEY ix_repayments_person_id (person_id),
  KEY ix_repayments_user_date (user_id, payment_date),
  KEY ix_repayments_loan_date (loan_id, payment_date),
  CONSTRAINT ck_repayments_amount_positive CHECK (amount_inr > 0),
  CONSTRAINT ck_repayments_direction CHECK (
    direction IN ('received', 'paid')
  ),
  CONSTRAINT ck_repayments_status CHECK (
    status IN ('completed', 'reversed')
  ),
  CONSTRAINT fk_repayments_user FOREIGN KEY (user_id)
    REFERENCES users (id) ON DELETE CASCADE,
  CONSTRAINT fk_repayments_loan FOREIGN KEY (loan_id)
    REFERENCES loans (id) ON DELETE RESTRICT,
  CONSTRAINT fk_repayments_transaction FOREIGN KEY (transaction_id)
    REFERENCES transactions (id) ON DELETE CASCADE,
  CONSTRAINT fk_repayments_person FOREIGN KEY (person_id)
    REFERENCES persons (id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- ---------------------------------------------------------------------------
-- Support tables (migration 0003_support_tables)
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS VOICE_COMMAND (
  id                BIGINT       NOT NULL AUTO_INCREMENT,
  user_id           BIGINT       NOT NULL,
  request_id        VARCHAR(64)  NOT NULL,
  voice_text        TEXT         NOT NULL,
  parser_confidence DOUBLE       NULL,
  transaction_id    BIGINT       NULL,
  nlp               JSON         NOT NULL,
  source            VARCHAR(64)  NOT NULL DEFAULT 'android_speech_recognizer',
  created_at        DATETIME(6)  NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_voice_command_user_request (user_id, request_id),
  KEY ix_voice_command_user_created (user_id, created_at),
  KEY ix_voice_command_transaction (transaction_id),
  CONSTRAINT ck_voice_command_confidence CHECK (
    parser_confidence IS NULL
    OR (parser_confidence >= 0 AND parser_confidence <= 1)
  ),
  CONSTRAINT ck_voice_command_request_id_length CHECK (
    CHAR_LENGTH(request_id) >= 8
  ),
  CONSTRAINT fk_voice_command_user FOREIGN KEY (user_id)
    REFERENCES users (id) ON DELETE CASCADE,
  CONSTRAINT fk_voice_command_transaction FOREIGN KEY (transaction_id)
    REFERENCES transactions (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS AUDIT_LOG (
  id          BIGINT       NOT NULL AUTO_INCREMENT,
  event_type  VARCHAR(64)  NOT NULL,
  user_id     BIGINT       NULL,
  request_id  VARCHAR(128) NULL,
  ip_address  VARCHAR(45)  NULL,
  user_agent  VARCHAR(512) NULL,
  payload     JSON         NULL,
  created_at  DATETIME(6)  NOT NULL,
  PRIMARY KEY (id),
  KEY ix_audit_log_user_created (user_id, created_at),
  KEY ix_audit_log_request (request_id),
  KEY ix_audit_log_event_created (event_type, created_at),
  CONSTRAINT ck_audit_log_event_type CHECK (
    CHAR_LENGTH(TRIM(event_type)) > 0
  ),
  CONSTRAINT fk_audit_log_user FOREIGN KEY (user_id)
    REFERENCES users (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS APPLICATION_EVENT (
  id          BIGINT       NOT NULL AUTO_INCREMENT,
  event_type  VARCHAR(64)  NOT NULL,
  user_id     BIGINT       NULL,
  request_id  VARCHAR(128) NULL,
  ip_address  VARCHAR(45)  NULL,
  user_agent  VARCHAR(512) NULL,
  payload     JSON         NULL,
  created_at  DATETIME(6)  NOT NULL,
  PRIMARY KEY (id),
  KEY ix_application_event_user_created (user_id, created_at),
  KEY ix_application_event_request (request_id),
  KEY ix_application_event_event_created (event_type, created_at),
  CONSTRAINT ck_application_event_event_type CHECK (
    CHAR_LENGTH(TRIM(event_type)) > 0
  ),
  CONSTRAINT fk_application_event_user FOREIGN KEY (user_id)
    REFERENCES users (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS EXCHANGE_RATE_CACHE (
  id              BIGINT         NOT NULL AUTO_INCREMENT,
  base_currency   VARCHAR(3)     NOT NULL,
  target_currency VARCHAR(3)     NOT NULL,
  rate            DECIMAL(28,12) NOT NULL,
  provider        VARCHAR(255)   NOT NULL,
  retrieved_at    DATETIME(6)    NOT NULL,
  valid_until     DATETIME(6)    NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_exchange_rate_cache_pair (base_currency, target_currency),
  KEY ix_exchange_rate_cache_valid_until (valid_until),
  CONSTRAINT ck_exchange_rate_cache_rate CHECK (rate > 0),
  CONSTRAINT ck_exchange_rate_cache_currency CHECK (
    CHAR_LENGTH(base_currency) = 3 AND CHAR_LENGTH(target_currency) = 3
  ),
  CONSTRAINT ck_exchange_rate_cache_validity CHECK (valid_until >= retrieved_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
