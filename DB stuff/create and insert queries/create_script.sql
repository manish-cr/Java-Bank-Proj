-- ============================================================================
-- NEXUSBANK ENGINE - COMPLETE DATABASE SCHEMA
-- PostgreSQL 15+
-- Run this entire script. It is idempotent.
-- ============================================================================

BEGIN;

-- 1. DROP ALL TABLES IN DEPENDENCY ORDER (CHILDREN FIRST)
-- ============================================================================
DROP TABLE IF EXISTS outbox_event CASCADE;
DROP TABLE IF EXISTS ledger_entry CASCADE;
DROP TABLE IF EXISTS transaction CASCADE;
DROP TABLE IF EXISTS account CASCADE;
DROP TABLE IF EXISTS chart_of_accounts CASCADE;
DROP TABLE IF EXISTS customer CASCADE;

-- 2. CREATE TABLES IN DEPENDENCY ORDER (PARENTS FIRST)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- TABLE: customer
-- The legal entity that owns accounts.
-- ----------------------------------------------------------------------------
CREATE TABLE customer (
    customer_id     UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    persona_type    VARCHAR(20)     NOT NULL CHECK (persona_type IN ('INDIVIDUAL', 'BUSINESS')),
    kyc_status      VARCHAR(20)     NOT NULL DEFAULT 'PENDING' CHECK (kyc_status IN ('PENDING', 'VERIFIED', 'REJECTED')),
    legal_name      VARCHAR(255)    NOT NULL,
    email           VARCHAR(255)    NOT NULL UNIQUE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

-- ----------------------------------------------------------------------------
-- TABLE: chart_of_accounts
-- Master list of internal general ledger accounts.
-- ----------------------------------------------------------------------------
CREATE TABLE chart_of_accounts (
    gl_account_code     VARCHAR(10)     PRIMARY KEY,
    account_name        VARCHAR(100)    NOT NULL UNIQUE,
    gl_type             VARCHAR(20)     NOT NULL CHECK (gl_type IN ('ASSET', 'LIABILITY', 'EQUITY', 'REVENUE', 'EXPENSE')),
    is_customer_facing  BOOLEAN         NOT NULL DEFAULT FALSE,
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

-- ----------------------------------------------------------------------------
-- TABLE: account
-- Individual customer accounts. Each maps to a chart_of_accounts GL code.
-- ----------------------------------------------------------------------------
CREATE TABLE account (
    account_id          UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id         UUID            NOT NULL,
    gl_account_code     VARCHAR(10)     NOT NULL,
    account_number      VARCHAR(20)     NOT NULL UNIQUE,
    account_type        VARCHAR(20)     NOT NULL CHECK (account_type IN ('CHECKING', 'SAVINGS', 'LOAN_RECEIVABLE', 'INVESTMENT')),
    currency_code       CHAR(3)         NOT NULL DEFAULT 'USD',
    status              VARCHAR(20)     NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'FROZEN', 'CLOSED')),
    opened_at           TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),

    -- Foreign Keys
    CONSTRAINT fk_account_customer
        FOREIGN KEY (customer_id)
        REFERENCES customer (customer_id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_account_gl_code
        FOREIGN KEY (gl_account_code)
        REFERENCES chart_of_accounts (gl_account_code)
        ON DELETE RESTRICT
);

-- ----------------------------------------------------------------------------
-- TABLE: transaction
-- Immutable envelope for a business event. Carries no amounts, only identity.
-- ----------------------------------------------------------------------------
CREATE TABLE transaction (
    transaction_id      UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    idempotency_key     UUID            NOT NULL UNIQUE,
    transaction_type    VARCHAR(30)     NOT NULL CHECK (transaction_type IN (
                                            'TRANSFER', 'DEPOSIT', 'WITHDRAWAL',
                                            'FEE', 'INTEREST_ACCRUAL', 'LOAN_PAYMENT'
                                        )),
    status              VARCHAR(20)     NOT NULL DEFAULT 'PENDING' CHECK (status IN (
                                            'PENDING', 'POSTED', 'FAILED', 'REVERSED'
                                        )),
    business_date       DATE            NOT NULL,
    description         VARCHAR(500),
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

-- ----------------------------------------------------------------------------
-- TABLE: ledger_entry
-- THE CORE. Unified double-entry ledger. Customer sub-ledger AND bank general
-- ledger in one table.
-- ----------------------------------------------------------------------------
CREATE TABLE ledger_entry (
    ledger_entry_id     UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    transaction_id      UUID            NOT NULL,
    account_id          UUID            NOT NULL,
    gl_account_code     VARCHAR(10)     NOT NULL,
    entry_type          VARCHAR(6)      NOT NULL CHECK (entry_type IN ('DEBIT', 'CREDIT')),
    amount              DECIMAL(19,4)   NOT NULL CHECK (amount > 0),
    balance_after       DECIMAL(19,4)   NOT NULL,
    entry_date          DATE            NOT NULL,
    description         VARCHAR(500),
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),

    -- Foreign Keys
    CONSTRAINT fk_ledger_entry_transaction
        FOREIGN KEY (transaction_id)
        REFERENCES transaction (transaction_id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_ledger_entry_account
        FOREIGN KEY (account_id)
        REFERENCES account (account_id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_ledger_entry_gl_code
        FOREIGN KEY (gl_account_code)
        REFERENCES chart_of_accounts (gl_account_code)
        ON DELETE RESTRICT
);

-- Critical indexes for the ledger
CREATE INDEX idx_ledger_account_date
    ON ledger_entry (account_id, entry_date DESC);

CREATE INDEX idx_ledger_transaction
    ON ledger_entry (transaction_id);

CREATE INDEX idx_ledger_gl_date
    ON ledger_entry (gl_account_code, entry_date);

-- ----------------------------------------------------------------------------
-- TABLE: outbox_event
-- Transactional outbox for guaranteed event delivery.
-- ----------------------------------------------------------------------------
CREATE TABLE outbox_event (
    event_id            UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    transaction_id      UUID            NOT NULL,
    event_type          VARCHAR(50)     NOT NULL,
    payload_json        JSONB           NOT NULL,
    status              VARCHAR(20)     NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'PUBLISHED', 'FAILED')),
    retry_count         INTEGER         NOT NULL DEFAULT 0,
    last_error          VARCHAR(1000),
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),

    -- Foreign Key
    CONSTRAINT fk_outbox_transaction
        FOREIGN KEY (transaction_id)
        REFERENCES transaction (transaction_id)
        ON DELETE RESTRICT
);

-- Index for the outbox poller: find pending events ordered by creation
CREATE INDEX idx_outbox_pending
    ON outbox_event (status, created_at)
    WHERE status = 'PENDING';

-- -- ============================================================================
-- -- 3. SEED DATA: CHART OF ACCOUNTS (REQUIRED BEFORE CREATING ACCOUNTS)
-- -- ============================================================================

-- INSERT INTO chart_of_accounts (gl_account_code, account_name, gl_type, is_customer_facing) VALUES
-- ('1001', 'Cash on Hand',                    'ASSET',    FALSE),
-- ('1002', 'Cash at Central Bank',            'ASSET',    FALSE),
-- ('2001', 'Customer Checking Deposits',      'LIABILITY', TRUE),
-- ('2002', 'Customer Savings Deposits',       'LIABILITY', TRUE),
-- ('2003', 'Customer Loan Receivable',        'ASSET',    TRUE),
-- ('3001', 'Shareholder Equity',             'EQUITY',   FALSE),
-- ('4001', 'Fee Income',                     'REVENUE',  FALSE),
-- ('4002', 'Interest Income from Loans',     'REVENUE',  FALSE),
-- ('5001', 'Interest Expense on Deposits',    'EXPENSE',  FALSE),
-- ('9001', 'Suspense Account',               'LIABILITY', FALSE)
-- ON CONFLICT (gl_account_code) DO NOTHING;

-- COMMIT;

-- ============================================================================
-- VERIFICATION: Check that all tables exist
-- ============================================================================
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
ORDER BY table_name;