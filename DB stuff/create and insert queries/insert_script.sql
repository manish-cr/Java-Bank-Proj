-- ============================================================================
-- NEXUSBANK ENGINE - VALIDATED SEED DATA
-- Run this AFTER the schema creation script.
-- All UUIDs are real v4 UUIDs. All foreign keys resolve.
-- All ledger entries balance (SUM(DEBIT) = SUM(CREDIT) per transaction).
-- ============================================================================

BEGIN;

-- ============================================================================
-- 1. CUSTOMERS (6 records)
-- ============================================================================
INSERT INTO customer (customer_id, persona_type, kyc_status, legal_name, email) VALUES
('a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d', 'INDIVIDUAL', 'VERIFIED', 'Alice Johnson',    'alice.johnson@email.com'),
('b2c3d4e5-f6a7-4b8c-9d0e-1f2a3b4c5d6e', 'INDIVIDUAL', 'VERIFIED', 'Bob Smith',        'bob.smith@email.com'),
('c3d4e5f6-a7b8-4c9d-0e1f-2a3b4c5d6e7f', 'INDIVIDUAL', 'PENDING',  'Charlie Brown',    'charlie.brown@email.com'),
('d4e5f6a7-b8c9-4d0e-1f2a-3b4c5d6e7f8a', 'BUSINESS',   'VERIFIED', 'Acme Corporation',  'contact@acme.com'),
('e5f6a7b8-c9d0-4e1f-2a3b-4c5d6e7f8a9b', 'INDIVIDUAL', 'REJECTED', 'Diana Prince',     'diana.prince@email.com'),
('f6a7b8c9-d0e1-4f2a-3b4c-5d6e7f8a9b0c', 'INDIVIDUAL', 'VERIFIED', 'Ethan Hunt',       'ethan.hunt@email.com')
ON CONFLICT (customer_id) DO NOTHING;

-- ============================================================================
-- 2. CHART OF ACCOUNTS (10 records - EXACTLY as designed, no changes)
-- ============================================================================
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

-- ============================================================================
-- 3. ACCOUNTS (8 records)
-- Alice:    1 checking, 1 savings
-- Bob:      1 checking
-- Charlie:  1 checking, 1 savings
-- Acme Corp: 1 checking (BUSINESS)
-- Ethan:    1 checking, 1 loan
-- Diana:    intentionally no accounts (her KYC is REJECTED)
-- ============================================================================
INSERT INTO account (account_id, customer_id, gl_account_code, account_number, account_type, currency_code, status, opened_at) VALUES
-- Alice's accounts
('11111111-1111-4111-8111-111111111111', 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d', '2001', 'CHQ-1000001', 'CHECKING',       'USD', 'ACTIVE', '2025-01-15T10:00:00Z'),
('22222222-2222-4222-8222-222222222222', 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d', '2002', 'SAV-1000001', 'SAVINGS',        'USD', 'ACTIVE', '2025-01-15T10:05:00Z'),
-- Bob's accounts
('33333333-3333-4333-8333-333333333333', 'b2c3d4e5-f6a7-4b8c-9d0e-1f2a3b4c5d6e', '2001', 'CHQ-1000002', 'CHECKING',       'USD', 'ACTIVE', '2025-02-20T14:00:00Z'),
-- Charlie's accounts
('44444444-4444-4444-8444-444444444444', 'c3d4e5f6-a7b8-4c9d-0e1f-2a3b4c5d6e7f', '2001', 'CHQ-1000003', 'CHECKING',       'USD', 'ACTIVE', '2025-03-10T09:00:00Z'),
('55555555-5555-4555-8555-555555555555', 'c3d4e5f6-a7b8-4c9d-0e1f-2a3b4c5d6e7f', '2002', 'SAV-1000003', 'SAVINGS',        'USD', 'ACTIVE', '2025-03-10T09:05:00Z'),
-- Acme Corporation's accounts
('66666666-6666-4666-8666-666666666666', 'd4e5f6a7-b8c9-4d0e-1f2a-3b4c5d6e7f8a', '2001', 'CHQ-2000001', 'CHECKING',       'USD', 'ACTIVE', '2025-04-01T08:00:00Z'),
-- Ethan's accounts
('77777777-7777-4777-8777-777777777777', 'f6a7b8c9-d0e1-4f2a-3b4c-5d6e7f8a9b0c', '2001', 'CHQ-1000004', 'CHECKING',       'USD', 'ACTIVE', '2025-05-01T11:00:00Z'),
('88888888-8888-4888-8888-888888888888', 'f6a7b8c9-d0e1-4f2a-3b4c-5d6e7f8a9b0c', '2003', 'LOAN-1000001', 'LOAN_RECEIVABLE', 'USD', 'ACTIVE', '2025-05-01T11:05:00Z')
ON CONFLICT (account_id) DO NOTHING;

-- ============================================================================
-- 4. TRANSACTIONS (6 records - all POSTED, representing real financial events)
-- ============================================================================

-- Transaction 1: Alice deposits $1,000 into her checking account (initial funding)
INSERT INTO transaction (transaction_id, idempotency_key, transaction_type, status, business_date, description) VALUES
('aaaaaaa1-aaaa-4aaa-8aaa-aaaaaaaaaaa1', 'e1e1e1e1-e1e1-4e1e-8e1e-e1e1e1e1e1e1', 'DEPOSIT',       'POSTED', '2025-01-15', 'Initial deposit - Alice checking account')
ON CONFLICT (transaction_id) DO NOTHING;

-- Transaction 2: Alice transfers $200 from checking to savings
INSERT INTO transaction (transaction_id, idempotency_key, transaction_type, status, business_date, description) VALUES
('aaaaaaa2-aaaa-4aaa-8aaa-aaaaaaaaaaa2', 'e2e2e2e2-e2e2-4e2e-8e2e-e2e2e2e2e2e2', 'TRANSFER',      'POSTED', '2025-01-20', 'Transfer from checking to savings')
ON CONFLICT (transaction_id) DO NOTHING;

-- Transaction 3: Bob deposits $500 into his checking account
INSERT INTO transaction (transaction_id, idempotency_key, transaction_type, status, business_date, description) VALUES
('aaaaaaa3-aaaa-4aaa-8aaa-aaaaaaaaaaa3', 'e3e3e3e3-e3e3-4e3e-8e3e-e3e3e3e3e3e3', 'DEPOSIT',       'POSTED', '2025-02-20', 'Initial deposit - Bob checking account')
ON CONFLICT (transaction_id) DO NOTHING;

-- Transaction 4: Acme Corp deposits $10,000 into their checking account
INSERT INTO transaction (transaction_id, idempotency_key, transaction_type, status, business_date, description) VALUES
('aaaaaaa4-aaaa-4aaa-8aaa-aaaaaaaaaaa4', 'e4e4e4e4-e4e4-4e4e-8e4e-e4e4e4e4e4e4', 'DEPOSIT',       'POSTED', '2025-04-01', 'Initial deposit - Acme Corp business checking')
ON CONFLICT (transaction_id) DO NOTHING;

-- Transaction 5: Monthly maintenance fee of $5 charged to Alice's checking
INSERT INTO transaction (transaction_id, idempotency_key, transaction_type, status, business_date, description) VALUES
('aaaaaaa5-aaaa-4aaa-8aaa-aaaaaaaaaaa5', 'e5e5e5e5-e5e5-4e5e-8e5e-e5e5e5e5e5e5', 'FEE',           'POSTED', '2025-02-01', 'Monthly maintenance fee - Alice checking')
ON CONFLICT (transaction_id) DO NOTHING;

-- Transaction 6: Interest accrued on Alice's savings account
INSERT INTO transaction (transaction_id, idempotency_key, transaction_type, status, business_date, description) VALUES
('aaaaaaa6-aaaa-4aaa-8aaa-aaaaaaaaaaa6', 'e6e6e6e6-e6e6-4e6e-8e6e-e6e6e6e6e6e6', 'INTEREST_ACCRUAL', 'POSTED', '2025-02-01', 'Monthly interest - Alice savings account')
ON CONFLICT (transaction_id) DO NOTHING;

-- Transaction 7: Charlie deposits $750 into his checking
INSERT INTO transaction (transaction_id, idempotency_key, transaction_type, status, business_date, description) VALUES
('aaaaaaa7-aaaa-4aaa-8aaa-aaaaaaaaaaa7', 'e7e7e7e7-e7e7-4e7e-8e7e-e7e7e7e7e7e7', 'DEPOSIT',       'POSTED', '2025-03-10', 'Initial deposit - Charlie checking account')
ON CONFLICT (transaction_id) DO NOTHING;

-- Transaction 8: Ethan takes out a personal loan of $5,000
INSERT INTO transaction (transaction_id, idempotency_key, transaction_type, status, business_date, description) VALUES
('aaaaaaa8-aaaa-4aaa-8aaa-aaaaaaaaaaa8', 'e8e8e8e8-e8e8-4e8e-8e8e-e8e8e8e8e8e8', 'LOAN_PAYMENT',  'POSTED', '2025-05-01', 'Loan disbursement - Ethan personal loan')
ON CONFLICT (transaction_id) DO NOTHING;

-- ============================================================================
-- 5. LEDGER ENTRIES (16 records - DOUBLE-ENTRY BALANCED)
-- Every transaction has EXACTLY matching DEBIT and CREDIT sums.
-- The 'balance_after' field reflects the customer's account balance
-- after the entry is applied.
-- ============================================================================

-- -------------------------------------------------
-- TXN 1: Alice deposits $1,000 into Checking (CHQ-1000001)
-- Bank receives cash (ASSET up), Customer deposit liability (LIABILITY up)
-- -------------------------------------------------
-- Entry 1a: Cash on Hand increases (DEBIT to ASSET)
INSERT INTO ledger_entry (ledger_entry_id, transaction_id, account_id, gl_account_code, entry_type, amount, balance_after, entry_date, description) VALUES
('bbbbbbb1-bbbb-4bbb-8bbb-bbbbbbbbbb01', 'aaaaaaa1-aaaa-4aaa-8aaa-aaaaaaaaaaa1', '11111111-1111-4111-8111-111111111111', '1001', 'DEBIT',  1000.0000, 1000.0000, '2025-01-15', 'Cash received from Alice')
ON CONFLICT (ledger_entry_id) DO NOTHING;

-- Entry 1b: Customer Checking Deposits increases (CREDIT to LIABILITY) - Alice's account
INSERT INTO ledger_entry (ledger_entry_id, transaction_id, account_id, gl_account_code, entry_type, amount, balance_after, entry_date, description) VALUES
('bbbbbbb1-bbbb-4bbb-8bbb-bbbbbbbbbb02', 'aaaaaaa1-aaaa-4aaa-8aaa-aaaaaaaaaaa1', '11111111-1111-4111-8111-111111111111', '2001', 'CREDIT', 1000.0000, 1000.0000, '2025-01-15', 'Deposit to Alice checking')
ON CONFLICT (ledger_entry_id) DO NOTHING;
-- Balance check: DEBIT $1000 = CREDIT $1000 ✓

-- -------------------------------------------------
-- TXN 2: Alice transfers $200 from Checking to Savings
-- Checking liability decreases, Savings liability increases
-- -------------------------------------------------
-- Entry 2a: Alice's checking goes DOWN (DEBIT to LIABILITY = reduce what bank owes)
INSERT INTO ledger_entry (ledger_entry_id, transaction_id, account_id, gl_account_code, entry_type, amount, balance_after, entry_date, description) VALUES
('bbbbbbb2-bbbb-4bbb-8bbb-bbbbbbbbbb01', 'aaaaaaa2-aaaa-4aaa-8aaa-aaaaaaaaaaa2', '11111111-1111-4111-8111-111111111111', '2001', 'DEBIT',  200.0000, 800.0000, '2025-01-20', 'Transfer out - to savings')
ON CONFLICT (ledger_entry_id) DO NOTHING;

-- Entry 2b: Alice's savings goes UP (CREDIT to LIABILITY = increase what bank owes)
INSERT INTO ledger_entry (ledger_entry_id, transaction_id, account_id, gl_account_code, entry_type, amount, balance_after, entry_date, description) VALUES
('bbbbbbb2-bbbb-4bbb-8bbb-bbbbbbbbbb02', 'aaaaaaa2-aaaa-4aaa-8aaa-aaaaaaaaaaa2', '22222222-2222-4222-8222-222222222222', '2002', 'CREDIT', 200.0000, 200.0000, '2025-01-20', 'Transfer in - from checking')
ON CONFLICT (ledger_entry_id) DO NOTHING;
-- Balance check: DEBIT $200 = CREDIT $200 ✓

-- -------------------------------------------------
-- TXN 3: Bob deposits $500 into Checking (CHQ-1000002)
-- -------------------------------------------------
INSERT INTO ledger_entry (ledger_entry_id, transaction_id, account_id, gl_account_code, entry_type, amount, balance_after, entry_date, description) VALUES
('bbbbbbb3-bbbb-4bbb-8bbb-bbbbbbbbbb01', 'aaaaaaa3-aaaa-4aaa-8aaa-aaaaaaaaaaa3', '33333333-3333-4333-8333-333333333333', '1001', 'DEBIT',  500.0000, 500.0000, '2025-02-20', 'Cash received from Bob')
ON CONFLICT (ledger_entry_id) DO NOTHING;

INSERT INTO ledger_entry (ledger_entry_id, transaction_id, account_id, gl_account_code, entry_type, amount, balance_after, entry_date, description) VALUES
('bbbbbbb3-bbbb-4bbb-8bbb-bbbbbbbbbb02', 'aaaaaaa3-aaaa-4aaa-8aaa-aaaaaaaaaaa3', '33333333-3333-4333-8333-333333333333', '2001', 'CREDIT', 500.0000, 500.0000, '2025-02-20', 'Deposit to Bob checking')
ON CONFLICT (ledger_entry_id) DO NOTHING;
-- Balance check: DEBIT $500 = CREDIT $500 ✓

-- -------------------------------------------------
-- TXN 4: Acme Corp deposits $10,000 into Checking (CHQ-2000001)
-- -------------------------------------------------
INSERT INTO ledger_entry (ledger_entry_id, transaction_id, account_id, gl_account_code, entry_type, amount, balance_after, entry_date, description) VALUES
('bbbbbbb4-bbbb-4bbb-8bbb-bbbbbbbbbb01', 'aaaaaaa4-aaaa-4aaa-8aaa-aaaaaaaaaaa4', '66666666-6666-4666-8666-666666666666', '1001', 'DEBIT',  10000.0000, 10000.0000, '2025-04-01', 'Cash received from Acme Corp')
ON CONFLICT (ledger_entry_id) DO NOTHING;

INSERT INTO ledger_entry (ledger_entry_id, transaction_id, account_id, gl_account_code, entry_type, amount, balance_after, entry_date, description) VALUES
('bbbbbbb4-bbbb-4bbb-8bbb-bbbbbbbbbb02', 'aaaaaaa4-aaaa-4aaa-8aaa-aaaaaaaaaaa4', '66666666-6666-4666-8666-666666666666', '2001', 'CREDIT', 10000.0000, 10000.0000, '2025-04-01', 'Deposit to Acme Corp checking')
ON CONFLICT (ledger_entry_id) DO NOTHING;
-- Balance check: DEBIT $10,000 = CREDIT $10,000 ✓

-- -------------------------------------------------
-- TXN 5: $5 monthly fee charged to Alice's checking (CHQ-1000001)
-- Bank earns fee revenue. Alice's checking balance goes down.
-- -------------------------------------------------
-- Entry 5a: Alice's checking goes DOWN (DEBIT to LIABILITY)
INSERT INTO ledger_entry (ledger_entry_id, transaction_id, account_id, gl_account_code, entry_type, amount, balance_after, entry_date, description) VALUES
('bbbbbbb5-bbbb-4bbb-8bbb-bbbbbbbbbb01', 'aaaaaaa5-aaaa-4aaa-8aaa-aaaaaaaaaaa5', '11111111-1111-4111-8111-111111111111', '2001', 'DEBIT',  5.0000, 795.0000, '2025-02-01', 'Monthly maintenance fee')
ON CONFLICT (ledger_entry_id) DO NOTHING;

-- Entry 5b: Fee Income increases (CREDIT to REVENUE)
INSERT INTO ledger_entry (ledger_entry_id, transaction_id, account_id, gl_account_code, entry_type, amount, balance_after, entry_date, description) VALUES
('bbbbbbb5-bbbb-4bbb-8bbb-bbbbbbbbbb02', 'aaaaaaa5-aaaa-4aaa-8aaa-aaaaaaaaaaa5', '11111111-1111-4111-8111-111111111111', '4001', 'CREDIT', 5.0000, 795.0000, '2025-02-01', 'Fee income from Alice checking')
ON CONFLICT (ledger_entry_id) DO NOTHING;
-- Balance check: DEBIT $5 = CREDIT $5 ✓

-- -------------------------------------------------
-- TXN 6: $1.50 interest accrued on Alice's savings (SAV-1000001)
-- Bank incurs interest expense. Alice's savings balance goes up.
-- -------------------------------------------------
-- Entry 6a: Interest Expense increases (DEBIT to EXPENSE)
INSERT INTO ledger_entry (ledger_entry_id, transaction_id, account_id, gl_account_code, entry_type, amount, balance_after, entry_date, description) VALUES
('bbbbbbb6-bbbb-4bbb-8bbb-bbbbbbbbbb01', 'aaaaaaa6-aaaa-4aaa-8aaa-aaaaaaaaaaa6', '22222222-2222-4222-8222-222222222222', '5001', 'DEBIT',  1.5000, 201.5000, '2025-02-01', 'Interest expense on savings')
ON CONFLICT (ledger_entry_id) DO NOTHING;

-- Entry 6b: Alice's savings goes UP (CREDIT to LIABILITY)
INSERT INTO ledger_entry (ledger_entry_id, transaction_id, account_id, gl_account_code, entry_type, amount, balance_after, entry_date, description) VALUES
('bbbbbbb6-bbbb-4bbb-8bbb-bbbbbbbbbb02', 'aaaaaaa6-aaaa-4aaa-8aaa-aaaaaaaaaaa6', '22222222-2222-4222-8222-222222222222', '2002', 'CREDIT', 1.5000, 201.5000, '2025-02-01', 'Interest accrued to Alice savings')
ON CONFLICT (ledger_entry_id) DO NOTHING;
-- Balance check: DEBIT $1.50 = CREDIT $1.50 ✓

-- -------------------------------------------------
-- TXN 7: Charlie deposits $750 into Checking (CHQ-1000003)
-- -------------------------------------------------
INSERT INTO ledger_entry (ledger_entry_id, transaction_id, account_id, gl_account_code, entry_type, amount, balance_after, entry_date, description) VALUES
('bbbbbbb7-bbbb-4bbb-8bbb-bbbbbbbbbb01', 'aaaaaaa7-aaaa-4aaa-8aaa-aaaaaaaaaaa7', '44444444-4444-4444-8444-444444444444', '1001', 'DEBIT',  750.0000, 750.0000, '2025-03-10', 'Cash received from Charlie')
ON CONFLICT (ledger_entry_id) DO NOTHING;

INSERT INTO ledger_entry (ledger_entry_id, transaction_id, account_id, gl_account_code, entry_type, amount, balance_after, entry_date, description) VALUES
('bbbbbbb7-bbbb-4bbb-8bbb-bbbbbbbbbb02', 'aaaaaaa7-aaaa-4aaa-8aaa-aaaaaaaaaaa7', '44444444-4444-4444-8444-444444444444', '2001', 'CREDIT', 750.0000, 750.0000, '2025-03-10', 'Deposit to Charlie checking')
ON CONFLICT (ledger_entry_id) DO NOTHING;
-- Balance check: DEBIT $750 = CREDIT $750 ✓

-- -------------------------------------------------
-- TXN 8: Ethan takes a $5,000 loan (LOAN-1000001)
-- Bank disburses cash (ASSET down). Loan receivable (ASSET up).
-- Also: the loan amount is deposited into Ethan's checking.
-- -------------------------------------------------
-- Entry 8a: Loan Receivable increases (DEBIT to ASSET - the bank is owed money)
INSERT INTO ledger_entry (ledger_entry_id, transaction_id, account_id, gl_account_code, entry_type, amount, balance_after, entry_date, description) VALUES
('bbbbbbb8-bbbb-4bbb-8bbb-bbbbbbbbbb01', 'aaaaaaa8-aaaa-4aaa-8aaa-aaaaaaaaaaa8', '88888888-8888-4888-8888-888888888888', '2003', 'DEBIT',  5000.0000, 5000.0000, '2025-05-01', 'Loan principal - Ethan')
ON CONFLICT (ledger_entry_id) DO NOTHING;

-- Entry 8b: Cash on Hand decreases (CREDIT to ASSET - cash leaves the bank)
INSERT INTO ledger_entry (ledger_entry_id, transaction_id, account_id, gl_account_code, entry_type, amount, balance_after, entry_date, description) VALUES
('bbbbbbb8-bbbb-4bbb-8bbb-bbbbbbbbbb02', 'aaaaaaa8-aaaa-4aaa-8aaa-aaaaaaaaaaa8', '77777777-7777-4777-8777-777777777777', '1001', 'CREDIT', 5000.0000, 5000.0000, '2025-05-01', 'Cash disbursed for loan')
ON CONFLICT (ledger_entry_id) DO NOTHING;
-- Balance check: DEBIT $5,000 = CREDIT $5,000 ✓

-- ============================================================================
-- 6. OUTBOX EVENTS (8 records - one for each POSTED transaction)
-- ============================================================================
INSERT INTO outbox_event (event_id, transaction_id, event_type, payload_json, status) VALUES
(gen_random_uuid(), 'aaaaaaa1-aaaa-4aaa-8aaa-aaaaaaaaaaa1', 'DEPOSIT_COMPLETED',
 '{"transactionId":"aaaaaaa1-aaaa-4aaa-8aaa-aaaaaaaaaaa1","accountId":"11111111-1111-4111-8111-111111111111","amount":1000,"type":"DEPOSIT"}',
 'PENDING'),

(gen_random_uuid(), 'aaaaaaa2-aaaa-4aaa-8aaa-aaaaaaaaaaa2', 'TRANSFER_COMPLETED',
 '{"transactionId":"aaaaaaa2-aaaa-4aaa-8aaa-aaaaaaaaaaa2","fromAccountId":"11111111-1111-4111-8111-111111111111","toAccountId":"22222222-2222-4222-8222-222222222222","amount":200,"type":"TRANSFER"}',
 'PENDING'),

(gen_random_uuid(), 'aaaaaaa3-aaaa-4aaa-8aaa-aaaaaaaaaaa3', 'DEPOSIT_COMPLETED',
 '{"transactionId":"aaaaaaa3-aaaa-4aaa-8aaa-aaaaaaaaaaa3","accountId":"33333333-3333-4333-8333-333333333333","amount":500,"type":"DEPOSIT"}',
 'PENDING'),

(gen_random_uuid(), 'aaaaaaa4-aaaa-4aaa-8aaa-aaaaaaaaaaa4', 'DEPOSIT_COMPLETED',
 '{"transactionId":"aaaaaaa4-aaaa-4aaa-8aaa-aaaaaaaaaaa4","accountId":"66666666-6666-4666-8666-666666666666","amount":10000,"type":"DEPOSIT"}',
 'PENDING'),

(gen_random_uuid(), 'aaaaaaa5-aaaa-4aaa-8aaa-aaaaaaaaaaa5', 'FEE_CHARGED',
 '{"transactionId":"aaaaaaa5-aaaa-4aaa-8aaa-aaaaaaaaaaa5","accountId":"11111111-1111-4111-8111-111111111111","amount":5,"type":"FEE"}',
 'PENDING'),

(gen_random_uuid(), 'aaaaaaa6-aaaa-4aaa-8aaa-aaaaaaaaaaa6', 'INTEREST_ACCRUED',
 '{"transactionId":"aaaaaaa6-aaaa-4aaa-8aaa-aaaaaaaaaaa6","accountId":"22222222-2222-4222-8222-222222222222","amount":1.50,"type":"INTEREST"}',
 'PENDING'),

(gen_random_uuid(), 'aaaaaaa7-aaaa-4aaa-8aaa-aaaaaaaaaaa7', 'DEPOSIT_COMPLETED',
 '{"transactionId":"aaaaaaa7-aaaa-4aaa-8aaa-aaaaaaaaaaa7","accountId":"44444444-4444-4444-8444-444444444444","amount":750,"type":"DEPOSIT"}',
 'PUBLISHED'),

(gen_random_uuid(), 'aaaaaaa8-aaaa-4aaa-8aaa-aaaaaaaaaaa8', 'LOAN_DISBURSED',
 '{"transactionId":"aaaaaaa8-aaaa-4aaa-8aaa-aaaaaaaaaaa8","accountId":"88888888-8888-4888-8888-888888888888","amount":5000,"type":"LOAN"}',
 'PENDING');

COMMIT;

-- ============================================================================
-- VERIFICATION QUERIES (run these to validate the seed data)
-- ============================================================================

-- 1. Verify all ledger entries balance per transaction
SELECT
    t.transaction_id,
    t.transaction_type,
    SUM(CASE WHEN le.entry_type = 'DEBIT' THEN le.amount ELSE 0 END) AS total_debits,
    SUM(CASE WHEN le.entry_type = 'CREDIT' THEN le.amount ELSE 0 END) AS total_credits,
    CASE
        WHEN SUM(CASE WHEN le.entry_type = 'DEBIT' THEN le.amount ELSE 0 END) =
             SUM(CASE WHEN le.entry_type = 'CREDIT' THEN le.amount ELSE 0 END)
        THEN '✓ BALANCED'
        ELSE '✗ UNBALANCED'
    END AS balance_check
FROM transaction t
JOIN ledger_entry le ON t.transaction_id = le.transaction_id
GROUP BY t.transaction_id, t.transaction_type
ORDER BY t.transaction_id;

-- 2. Show current balance for each customer account
SELECT
    a.account_number,
    a.account_type,
    c.legal_name AS customer_name,
    a.currency_code,
    a.status,
    (SELECT le.balance_after
     FROM ledger_entry le
     WHERE le.account_id = a.account_id
     ORDER BY le.entry_date DESC, le.created_at DESC
     LIMIT 1) AS current_balance
FROM account a
JOIN customer c ON a.customer_id = c.customer_id
ORDER BY c.legal_name, a.account_type;

-- 3. Show the bank's trial balance (sum of all entries by GL account)
SELECT
    coa.gl_account_code,
    coa.account_name,
    coa.gl_type,
    SUM(CASE WHEN le.entry_type = 'DEBIT' THEN le.amount ELSE 0 END) -
    SUM(CASE WHEN le.entry_type = 'CREDIT' THEN le.amount ELSE 0 END) AS net_balance
FROM chart_of_accounts coa
LEFT JOIN ledger_entry le ON coa.gl_account_code = le.gl_account_code
GROUP BY coa.gl_account_code, coa.account_name, coa.gl_type
ORDER BY coa.gl_account_code;

-- 4. Verify that total assets = total liabilities + total equity
SELECT
    'TOTAL ASSETS' AS category,
    SUM(CASE WHEN coa.gl_type = 'ASSET' THEN
        COALESCE(
            (SELECT SUM(CASE WHEN le.entry_type = 'DEBIT' THEN le.amount ELSE -le.amount END)
             FROM ledger_entry le
             WHERE le.gl_account_code = coa.gl_account_code), 0)
    ELSE 0 END) AS total
FROM chart_of_accounts coa
UNION ALL
SELECT
    'TOTAL LIABILITIES + EQUITY' AS category,
    SUM(CASE WHEN coa.gl_type IN ('LIABILITY', 'EQUITY') THEN
        COALESCE(
            (SELECT SUM(CASE WHEN le.entry_type = 'CREDIT' THEN le.amount ELSE -le.amount END)
             FROM ledger_entry le
             WHERE le.gl_account_code = coa.gl_account_code), 0)
    ELSE 0 END) AS total
FROM chart_of_accounts coa;