-- ============================================================================
-- NexusBank Engine - Docker Init Script
-- Creates schema, seeds data, and installs all stored procedures.
-- Runs automatically on first container start.
-- ============================================================================

BEGIN;

-- ============================================================================
-- 1. CORE SCHEMA
-- ============================================================================

CREATE TABLE customer (
    customer_id     UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    persona_type    VARCHAR(20)     NOT NULL CHECK (persona_type IN ('INDIVIDUAL', 'BUSINESS')),
    kyc_status      VARCHAR(20)     NOT NULL DEFAULT 'PENDING' CHECK (kyc_status IN ('PENDING', 'VERIFIED', 'REJECTED')),
    legal_name      VARCHAR(255)    NOT NULL,
    email           VARCHAR(255)    NOT NULL UNIQUE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

CREATE TABLE chart_of_accounts (
    gl_account_code     VARCHAR(10)     PRIMARY KEY,
    account_name        VARCHAR(100)    NOT NULL UNIQUE,
    gl_type             VARCHAR(20)     NOT NULL CHECK (gl_type IN ('ASSET', 'LIABILITY', 'EQUITY', 'REVENUE', 'EXPENSE')),
    is_customer_facing  BOOLEAN         NOT NULL DEFAULT FALSE,
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

CREATE TABLE account (
    account_id          UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id         UUID            NOT NULL,
    gl_account_code     VARCHAR(10)     NOT NULL,
    account_number      VARCHAR(20)     NOT NULL UNIQUE,
    account_type        VARCHAR(20)     NOT NULL CHECK (account_type IN ('CHECKING', 'SAVINGS', 'LOAN_RECEIVABLE', 'INVESTMENT')),
    currency_code       VARCHAR(3)      NOT NULL DEFAULT 'USD',
    status              VARCHAR(20)     NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'FROZEN', 'CLOSED')),
    opened_at           TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_account_customer FOREIGN KEY (customer_id) REFERENCES customer (customer_id) ON DELETE RESTRICT,
    CONSTRAINT fk_account_gl_code FOREIGN KEY (gl_account_code) REFERENCES chart_of_accounts (gl_account_code) ON DELETE RESTRICT
);

CREATE TABLE transaction (
    transaction_id      UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    idempotency_key     UUID            NOT NULL UNIQUE,
    transaction_type    VARCHAR(30)     NOT NULL CHECK (transaction_type IN ('TRANSFER', 'DEPOSIT', 'WITHDRAWAL', 'FEE', 'INTEREST_ACCRUAL', 'LOAN_PAYMENT')),
    status              VARCHAR(20)     NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'POSTED', 'FAILED', 'REVERSED')),
    business_date       DATE            NOT NULL,
    description         VARCHAR(500),
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

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
    CONSTRAINT fk_ledger_entry_transaction FOREIGN KEY (transaction_id) REFERENCES transaction (transaction_id) ON DELETE RESTRICT,
    CONSTRAINT fk_ledger_entry_account FOREIGN KEY (account_id) REFERENCES account (account_id) ON DELETE RESTRICT,
    CONSTRAINT fk_ledger_entry_gl_code FOREIGN KEY (gl_account_code) REFERENCES chart_of_accounts (gl_account_code) ON DELETE RESTRICT
);

CREATE INDEX idx_ledger_account_date ON ledger_entry (account_id, entry_date DESC);
CREATE INDEX idx_ledger_transaction ON ledger_entry (transaction_id);
CREATE INDEX idx_ledger_gl_date ON ledger_entry (gl_account_code, entry_date);

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
    CONSTRAINT fk_outbox_transaction FOREIGN KEY (transaction_id) REFERENCES transaction (transaction_id) ON DELETE RESTRICT
);

CREATE INDEX idx_outbox_pending ON outbox_event (status, created_at) WHERE status = 'PENDING';

CREATE TABLE fee_schedule (
    fee_code                VARCHAR(30)     PRIMARY KEY,
    fee_name                VARCHAR(100)    NOT NULL,
    amount                  DECIMAL(19,4)   NOT NULL,
    currency_code           VARCHAR(3)      NOT NULL DEFAULT 'USD',
    applies_to_account_type VARCHAR(20)     NOT NULL CHECK (applies_to_account_type IN ('CHECKING', 'SAVINGS', 'LOAN_RECEIVABLE', 'INVESTMENT', 'ALL')),
    is_active               BOOLEAN         NOT NULL DEFAULT TRUE
);

CREATE TABLE product_state_checking (
    account_id              UUID            PRIMARY KEY,
    monthly_fee             DECIMAL(19,4)   NOT NULL DEFAULT 0.0000,
    overdraft_limit         DECIMAL(19,4)   NOT NULL DEFAULT 0.0000,
    last_fee_date           DATE,
    CONSTRAINT fk_ps_checking_account FOREIGN KEY (account_id) REFERENCES account (account_id) ON DELETE RESTRICT
);

CREATE TABLE product_state_savings (
    account_id                  UUID            PRIMARY KEY,
    interest_rate               DECIMAL(7,4)    NOT NULL,
    compounding_frequency       VARCHAR(10)     NOT NULL DEFAULT 'MONTHLY' CHECK (compounding_frequency IN ('DAILY', 'MONTHLY', 'QUARTERLY', 'ANNUALLY')),
    interest_accrued_pending    DECIMAL(19,4)   NOT NULL DEFAULT 0.0000,
    interest_accrued_ytd        DECIMAL(19,4)   NOT NULL DEFAULT 0.0000,
    last_interest_date          DATE,
    last_compound_date          DATE,
    rate_type                   VARCHAR(20)     NOT NULL DEFAULT 'FIXED' CHECK (rate_type IN ('FIXED', 'VARIABLE', 'TIERED', 'PROMOTIONAL')),
    rate_code                   VARCHAR(30),
    CONSTRAINT fk_ps_savings_account FOREIGN KEY (account_id) REFERENCES account (account_id) ON DELETE RESTRICT
);

CREATE TABLE product_state_loan (
    account_id                  UUID            PRIMARY KEY,
    original_principal          DECIMAL(19,4)   NOT NULL,
    principal_outstanding       DECIMAL(19,4)   NOT NULL,
    interest_rate               DECIMAL(7,4)    NOT NULL,
    loan_term_months            INTEGER         NOT NULL,
    monthly_payment             DECIMAL(19,4)   NOT NULL,
    next_payment_date           DATE            NOT NULL,
    days_past_due               INTEGER         NOT NULL DEFAULT 0,
    total_interest_paid_ytd     DECIMAL(19,4)   NOT NULL DEFAULT 0.0000,
    rate_type                   VARCHAR(20)     NOT NULL DEFAULT 'FIXED' CHECK (rate_type IN ('FIXED', 'VARIABLE', 'TIERED', 'PROMOTIONAL')),
    rate_code                   VARCHAR(30),
    reference_rate_code         VARCHAR(20),
    margin                      DECIMAL(7,4),
    fixed_period_months         INTEGER,
    adjustment_frequency        VARCHAR(20) CHECK (adjustment_frequency IN ('MONTHLY', 'QUARTERLY', 'ANNUALLY')),
    next_rate_adjustment        DATE,
    annual_cap                  DECIMAL(7,4),
    lifetime_cap                DECIMAL(7,4),
    lifetime_floor              DECIMAL(7,4),
    CONSTRAINT fk_ps_loan_account FOREIGN KEY (account_id) REFERENCES account (account_id) ON DELETE RESTRICT
);

CREATE TABLE product_state_investment (
    account_id                  UUID            PRIMARY KEY,
    stock_symbol                VARCHAR(10)     NOT NULL,
    quantity_held               DECIMAL(19,6)   NOT NULL DEFAULT 0,
    average_cost_basis          DECIMAL(19,4)   NOT NULL DEFAULT 0.0000,
    current_market_price        DECIMAL(19,4)   NOT NULL DEFAULT 0.0000,
    last_valuation_date         DATE,
    CONSTRAINT fk_ps_investment_account FOREIGN KEY (account_id) REFERENCES account (account_id) ON DELETE RESTRICT
);

CREATE TABLE interest_rate_schedule (
    rate_id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    rate_code           VARCHAR(30) NOT NULL,
    rate_value          DECIMAL(7,4) NOT NULL,
    currency_code       VARCHAR(3) NOT NULL DEFAULT 'USD',
    rate_category       VARCHAR(20) NOT NULL CHECK (rate_category IN ('BASE', 'BENCHMARK', 'PRODUCT', 'PROMOTIONAL', 'PENALTY', 'FOREX')),
    effective_from      DATE NOT NULL,
    effective_until     DATE,
    tier_min_balance    DECIMAL(19,4),
    tier_max_balance    DECIMAL(19,4),
    tier_sequence       INTEGER,
    loan_term_min_months INTEGER,
    loan_term_max_months INTEGER,
    collateral_required VARCHAR(20) CHECK (collateral_required IN ('SECURED', 'UNSECURED', 'ANY')),
    is_promotional      BOOLEAN NOT NULL DEFAULT FALSE,
    promo_description   VARCHAR(200),
    description         VARCHAR(200),
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE rate_derivation_rules (
    rule_id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_rate_code   VARCHAR(30) NOT NULL,
    base_rate_code      VARCHAR(30) NOT NULL,
    formula_type        VARCHAR(20) NOT NULL CHECK (formula_type IN ('SPREAD', 'MULTIPLIER', 'FIXED')),
    spread_value        DECIMAL(7,4),
    multiplier          DECIMAL(7,4),
    floor_rate          DECIMAL(7,4),
    ceiling_rate        DECIMAL(7,4),
    currency_code       VARCHAR(3) NOT NULL DEFAULT 'USD',
    effective_from      DATE NOT NULL,
    effective_until     DATE,
    description         VARCHAR(200),
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMIT;
