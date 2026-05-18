-- ============================================================================
-- NEXUSBANK ENGINE - PRODUCT STATE TABLES
-- Stores product-specific parameters and mutable state.
-- One row per account, linked 1:1 with the account table.
-- ============================================================================

BEGIN;

-- 1. DROP EXISTING (for idempotent runs)
-- ============================================================================
DROP TABLE IF EXISTS product_state_loan CASCADE;
DROP TABLE IF EXISTS product_state_savings CASCADE;
DROP TABLE IF EXISTS product_state_checking CASCADE;
DROP TABLE IF EXISTS product_state_investment CASCADE;
DROP TABLE IF EXISTS fee_schedule CASCADE;

-- ============================================================================
-- 2. PRODUCT STATE: CHECKING
-- Minimal state. Checking accounts typically don't earn interest.
-- ============================================================================
CREATE TABLE product_state_checking (
    account_id              UUID            PRIMARY KEY,
    monthly_fee             DECIMAL(19,4)   NOT NULL DEFAULT 0.0000,
    overdraft_limit         DECIMAL(19,4)   NOT NULL DEFAULT 0.0000,
    last_fee_date           DATE,

    CONSTRAINT fk_ps_checking_account
        FOREIGN KEY (account_id)
        REFERENCES account (account_id)
        ON DELETE RESTRICT
);

-- ============================================================================
-- 3. PRODUCT STATE: SAVINGS
-- Tracks interest rate and pending accruals for compound interest.
-- ============================================================================
CREATE TABLE product_state_savings (
    account_id                  UUID            PRIMARY KEY,
    interest_rate               DECIMAL(7,4)    NOT NULL,  -- e.g., 0.0500 = 5.00%
    compounding_frequency       VARCHAR(10)     NOT NULL DEFAULT 'MONTHLY'
                                    CHECK (compounding_frequency IN ('DAILY', 'MONTHLY', 'QUARTERLY', 'ANNUALLY')),
    interest_accrued_pending    DECIMAL(19,4)   NOT NULL DEFAULT 0.0000,
    interest_accrued_ytd        DECIMAL(19,4)   NOT NULL DEFAULT 0.0000,
    last_interest_date          DATE,
    last_compound_date          DATE,

    CONSTRAINT fk_ps_savings_account
        FOREIGN KEY (account_id)
        REFERENCES account (account_id)
        ON DELETE RESTRICT
);

-- ============================================================================
-- 4. PRODUCT STATE: LOAN
-- Tracks amortization schedule for a loan receivable.
-- ============================================================================
CREATE TABLE product_state_loan (
    account_id                  UUID            PRIMARY KEY,
    original_principal          DECIMAL(19,4)   NOT NULL,
    principal_outstanding       DECIMAL(19,4)   NOT NULL,
    interest_rate               DECIMAL(7,4)    NOT NULL,  -- e.g., 0.0799 = 7.99%
    loan_term_months            INTEGER         NOT NULL,
    monthly_payment             DECIMAL(19,4)   NOT NULL,
    next_payment_date           DATE            NOT NULL,
    days_past_due               INTEGER         NOT NULL DEFAULT 0,
    total_interest_paid_ytd     DECIMAL(19,4)   NOT NULL DEFAULT 0.0000,

    CONSTRAINT fk_ps_loan_account
        FOREIGN KEY (account_id)
        REFERENCES account (account_id)
        ON DELETE RESTRICT
);

-- ============================================================================
-- 5. PRODUCT STATE: INVESTMENT
-- Simplified holding state. Tracks quantity and cost basis.
-- ============================================================================
CREATE TABLE product_state_investment (
    account_id                  UUID            PRIMARY KEY,
    stock_symbol                VARCHAR(10)     NOT NULL,
    quantity_held               DECIMAL(19,6)   NOT NULL DEFAULT 0,
    average_cost_basis          DECIMAL(19,4)   NOT NULL DEFAULT 0.0000,
    current_market_price        DECIMAL(19,4)   NOT NULL DEFAULT 0.0000,
    last_valuation_date         DATE,

    CONSTRAINT fk_ps_investment_account
        FOREIGN KEY (account_id)
        REFERENCES account (account_id)
        ON DELETE RESTRICT
);

-- ============================================================================
-- 6. FEE SCHEDULE (Reference Table)
-- Defines system-wide fees. Your procedures will look up amounts here.
-- ============================================================================
CREATE TABLE fee_schedule (
    fee_code                VARCHAR(30)     PRIMARY KEY,
    fee_name                VARCHAR(100)    NOT NULL,
    amount                  DECIMAL(19,4)   NOT NULL,
    currency_code           CHAR(3)         NOT NULL DEFAULT 'USD',
    applies_to_account_type VARCHAR(20)     NOT NULL
                                CHECK (applies_to_account_type IN ('CHECKING', 'SAVINGS', 'LOAN_RECEIVABLE', 'INVESTMENT', 'ALL')),
    is_active               BOOLEAN         NOT NULL DEFAULT TRUE
);

--rollback;

-- ============================================================================
-- 7. SEED DATA: FEE SCHEDULE
-- ============================================================================
INSERT INTO fee_schedule (fee_code, fee_name, amount, applies_to_account_type) VALUES
('MONTHLY_MAINT_CHECKING',  'Monthly Maintenance Fee - Checking',     5.0000, 'CHECKING'),
('MONTHLY_MAINT_SAVINGS',   'Monthly Maintenance Fee - Savings',      0.0000, 'SAVINGS'),
('OVERDRAFT',               'Overdraft Fee',                         35.0000, 'CHECKING'),
('WIRE_OUTGOING_DOMESTIC',  'Outgoing Domestic Wire Transfer',        15.0000, 'ALL'),
('WIRE_OUTGOING_INTL',      'Outgoing International Wire Transfer',   45.0000, 'ALL'),
('LATE_PAYMENT_LOAN',       'Late Loan Payment Fee',                  25.0000, 'LOAN_RECEIVABLE'),
('LOAN_ORIGINATION',        'Loan Origination Fee',                   50.0000, 'LOAN_RECEIVABLE')
ON CONFLICT (fee_code) DO NOTHING;

-- ============================================================================
-- 8. SEED DATA: PRODUCT STATE FOR EXISTING ACCOUNTS
-- Matches the 8 accounts created in the previous seed script.
-- ============================================================================

-- --------------------------------------------------------------------------
-- Alice's CHECKING account (CHQ-1000001)
-- $5 monthly maintenance fee, no overdraft set up
-- --------------------------------------------------------------------------
INSERT INTO product_state_checking (account_id, monthly_fee, overdraft_limit, last_fee_date)
VALUES ('11111111-1111-4111-8111-111111111111', 5.0000, 0.0000, '2025-02-01')
ON CONFLICT (account_id) DO NOTHING;

-- --------------------------------------------------------------------------
-- Alice's SAVINGS account (SAV-1000001)
-- 5% annual interest, compounding monthly
-- interest_accrued_pending is $0 because Monthly Fee txn already posted
-- --------------------------------------------------------------------------
INSERT INTO product_state_savings (account_id, interest_rate, compounding_frequency,
    interest_accrued_pending, interest_accrued_ytd, last_interest_date, last_compound_date)
VALUES ('22222222-2222-4222-8222-222222222222', 0.0500, 'MONTHLY',
    0.0000, 1.5000, '2025-02-01', NULL)
ON CONFLICT (account_id) DO NOTHING;

-- --------------------------------------------------------------------------
-- Bob's CHECKING account (CHQ-1000002)
-- No monthly fee, $100 overdraft limit
-- --------------------------------------------------------------------------
INSERT INTO product_state_checking (account_id, monthly_fee, overdraft_limit, last_fee_date)
VALUES ('33333333-3333-4333-8333-333333333333', 0.0000, 100.0000, NULL)
ON CONFLICT (account_id) DO NOTHING;

-- --------------------------------------------------------------------------
-- Charlie's CHECKING account (CHQ-1000003)
-- $5 monthly maintenance fee
-- --------------------------------------------------------------------------
INSERT INTO product_state_checking (account_id, monthly_fee, overdraft_limit, last_fee_date)
VALUES ('44444444-4444-4444-8444-444444444444', 5.0000, 0.0000, NULL)
ON CONFLICT (account_id) DO NOTHING;

-- --------------------------------------------------------------------------
-- Charlie's SAVINGS account (SAV-1000003)
-- 3.5% annual interest, monthly compounding, no activity yet
-- --------------------------------------------------------------------------
INSERT INTO product_state_savings (account_id, interest_rate, compounding_frequency,
    interest_accrued_pending, interest_accrued_ytd, last_interest_date, last_compound_date)
VALUES ('55555555-5555-4555-8555-555555555555', 0.0350, 'MONTHLY',
    0.0000, 0.0000, NULL, NULL)
ON CONFLICT (account_id) DO NOTHING;

-- --------------------------------------------------------------------------
-- Acme Corp CHECKING account (CHQ-2000001)
-- Business account, $25 monthly fee, no overdraft
-- --------------------------------------------------------------------------
INSERT INTO product_state_checking (account_id, monthly_fee, overdraft_limit, last_fee_date)
VALUES ('66666666-6666-4666-8666-666666666666', 25.0000, 0.0000, NULL)
ON CONFLICT (account_id) DO NOTHING;

-- --------------------------------------------------------------------------
-- Ethan's CHECKING account (CHQ-1000004)
-- No monthly fee
-- --------------------------------------------------------------------------
INSERT INTO product_state_checking (account_id, monthly_fee, overdraft_limit, last_fee_date)
VALUES ('77777777-7777-4777-8777-777777777777', 0.0000, 0.0000, NULL)
ON CONFLICT (account_id) DO NOTHING;

-- --------------------------------------------------------------------------
-- Ethan's LOAN account (LOAN-1000001)
-- $5,000 loan at 7.99%, 24-month term
-- Monthly payment calculated using amortization formula:
-- M = P × [r(1+r)^n] / [(1+r)^n - 1]
-- where r = 0.0799/12 = 0.0066583, n = 24
-- M = 5000 × [0.0066583(1.0066583)^24] / [(1.0066583)^24 - 1]
-- M = 5000 × [0.0066583 × 1.1727] / [1.1727 - 1]
-- M = 5000 × 0.007808 / 0.1727
-- M = 5000 × 0.04522
-- M = 226.10 (approximately)
-- --------------------------------------------------------------------------
INSERT INTO product_state_loan (
    account_id, original_principal, principal_outstanding,
    interest_rate, loan_term_months, monthly_payment,
    next_payment_date, days_past_due, total_interest_paid_ytd
) VALUES (
    '88888888-8888-4888-8888-888888888888',
    5000.0000,          -- original_principal
    5000.0000,          -- principal_outstanding (no payments yet)
    0.0799,             -- interest_rate (7.99%)
    24,                 -- loan_term_months (2 years)
    226.1000,           -- monthly_payment
    '2025-06-01',       -- next_payment_date
    0,                  -- days_past_due
    0.0000              -- total_interest_paid_ytd
) ON CONFLICT (account_id) DO NOTHING;