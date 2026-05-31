-- ============================================================================
-- NexusBank Engine - Seed Data
-- ============================================================================

BEGIN;

-- Chart of Accounts
INSERT INTO chart_of_accounts (gl_account_code, account_name, gl_type, is_customer_facing) VALUES
('1001', 'Cash on Hand',                    'ASSET',    FALSE),
('1002', 'Cash at Central Bank',            'ASSET',    FALSE),
('2001', 'Customer Checking Deposits',      'LIABILITY', TRUE),
('2002', 'Customer Savings Deposits',       'LIABILITY', TRUE),
('2003', 'Customer Loan Receivable',        'ASSET',    TRUE),
('3001', 'Shareholder Equity',             'EQUITY',   FALSE),
('4001', 'Fee Income',                     'REVENUE',  FALSE),
('4002', 'Interest Income from Loans',     'REVENUE',  FALSE),
('5001', 'Interest Expense on Deposits',    'EXPENSE',  FALSE),
('9001', 'Suspense Account',               'LIABILITY', FALSE)
ON CONFLICT (gl_account_code) DO NOTHING;

-- Customers
INSERT INTO customer (customer_id, persona_type, kyc_status, legal_name, email) VALUES
('a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d', 'INDIVIDUAL', 'VERIFIED', 'Alice Johnson',    'alice.johnson@email.com'),
('b2c3d4e5-f6a7-4b8c-9d0e-1f2a3b4c5d6e', 'INDIVIDUAL', 'VERIFIED', 'Bob Smith',        'bob.smith@email.com'),
('c3d4e5f6-a7b8-4c9d-0e1f-2a3b4c5d6e7f', 'INDIVIDUAL', 'PENDING',  'Charlie Brown',    'charlie.brown@email.com'),
('d4e5f6a7-b8c9-4d0e-1f2a-3b4c5d6e7f8a', 'BUSINESS',   'VERIFIED', 'Acme Corporation',  'contact@acme.com'),
('e5f6a7b8-c9d0-4e1f-2a3b-4c5d6e7f8a9b', 'INDIVIDUAL', 'REJECTED', 'Diana Prince',     'diana.prince@email.com'),
('f6a7b8c9-d0e1-4f2a-3b4c-5d6e7f8a9b0c', 'INDIVIDUAL', 'VERIFIED', 'Ethan Hunt',       'ethan.hunt@email.com')
ON CONFLICT (customer_id) DO NOTHING;

-- Fee Schedule
INSERT INTO fee_schedule (fee_code, fee_name, amount, applies_to_account_type) VALUES
('MONTHLY_MAINT_CHECKING',  'Monthly Maintenance Fee - Checking',     5.0000, 'CHECKING'),
('MONTHLY_MAINT_SAVINGS',   'Monthly Maintenance Fee - Savings',      0.0000, 'SAVINGS'),
('OVERDRAFT',               'Overdraft Fee',                         35.0000, 'CHECKING'),
('WIRE_OUTGOING_DOMESTIC',  'Outgoing Domestic Wire Transfer',        15.0000, 'ALL'),
('WIRE_OUTGOING_INTL',      'Outgoing International Wire Transfer',   45.0000, 'ALL'),
('LATE_PAYMENT',            'Late Loan Payment Fee',                  25.0000, 'LOAN_RECEIVABLE'),
('LOAN_ORIGINATION',        'Loan Origination Fee',                   50.0000, 'LOAN_RECEIVABLE')
ON CONFLICT (fee_code) DO NOTHING;

COMMIT;
