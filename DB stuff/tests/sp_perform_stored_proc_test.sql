-- ============================================================================
-- TEST 1: Successful Transfer
-- Transfer $50 from Alice's checking to Alice's savings
-- ============================================================================

-- First, check current balances
SELECT
    a.account_number,
    a.account_type,
    (SELECT le.balance_after
     FROM ledger_entry le
     WHERE le.account_id = a.account_id
     ORDER BY le.entry_date DESC, le.created_at DESC
     LIMIT 1) AS current_balance
FROM account a
WHERE a.account_id IN (
    '11111111-1111-4111-8111-111111111111',  -- Alice Checking
    '22222222-2222-4222-8222-222222222222'   -- Alice Savings
);

-- Execute the transfer
SELECT * FROM sp_perform_transfer(
    'f1f1f1f1-f1f1-4f1f-8f1f-f1f1f1f1f1f1',  -- idempotency_key (generate new UUID if you prefer)
    '11111111-1111-4111-8111-111111111111',    -- from: Alice Checking
    '22222222-2222-4222-8222-222222222222',    -- to: Alice Savings
    50.0000,                                    -- amount
    'Test transfer: checking to savings'
);

-- Verify new balances (should be: Checking $745, Savings $251.50)
SELECT
    a.account_number,
    a.account_type,
    (SELECT le.balance_after
     FROM ledger_entry le
     WHERE le.account_id = a.account_id
     ORDER BY le.entry_date DESC, le.created_at DESC
     LIMIT 1) AS current_balance
FROM account a
WHERE a.account_id IN (
    '11111111-1111-4111-8111-111111111111',
    '22222222-2222-4222-8222-222222222222'
);

-- ============================================================================
-- TEST 2: Idempotency
-- Call the EXACT same transfer again with the same idempotency key.
-- Should return the ORIGINAL transaction, not a duplicate.
-- ============================================================================
SELECT * FROM sp_perform_transfer(
    'f1f1f1f1-f1f1-4f1f-8f1f-f1f1f1f1f1f1',  -- SAME idempotency key
    '11111111-1111-4111-8111-111111111111',
    '22222222-2222-4222-8222-222222222222',
    50.0000,
    'Test transfer: checking to savings'
);

-- Balances should be UNCHANGED (still $745 and $251.50)
SELECT
    a.account_number,
    (SELECT le.balance_after
     FROM ledger_entry le
     WHERE le.account_id = a.account_id
     ORDER BY le.entry_date DESC, le.created_at DESC
     LIMIT 1) AS current_balance
FROM account a
WHERE a.account_id IN (
    '11111111-1111-4111-8111-111111111111',
    '22222222-2222-4222-8222-222222222222'
);

-- ============================================================================
-- TEST 3: Insufficient Funds
-- Try to transfer $10,000 from Bob's checking (has only $500)
-- ============================================================================
SELECT * FROM sp_perform_transfer(
    'f2f2f2f2-f2f2-4f2f-8f2f-f2f2f2f2f2f2',
    '33333333-3333-4333-8333-333333333333',  -- Bob Checking ($500)
    '11111111-1111-4111-8111-111111111111',  -- Alice Checking
    10000.0000,
    'Test: insufficient funds'
);
-- Expected: status = 'FAILED', message = 'Insufficient funds...'

-- ============================================================================
-- TEST 4: Non-existent Account
-- ============================================================================
SELECT * FROM sp_perform_transfer(
    'f3f3f3f3-f3f3-4f3f-8f3f-f3f3f3f3f3f3',
    '99999999-9999-4999-8999-999999999999',  -- Does not exist
    '11111111-1111-4111-8111-111111111111',
    100.0000,
    'Test: bad account'
);
-- Expected: status = 'FAILED', message = 'Source account not found.'

-- ============================================================================
-- TEST 5: Closed Account
-- ============================================================================
-- First, close one of the accounts temporarily (we'll revert after)
-- UPDATE account SET status = 'CLOSED' WHERE account_id = '44444444-4444-4444-8444-444444444444';

SELECT * FROM sp_perform_transfer(
    'f4f4f4f4-f4f4-4f4f-8f4f-f4f4f4f4f4f4',
    '44444444-4444-4444-8444-444444444444',  -- Charlie Checking (if you closed it)
    '11111111-1111-4111-8111-111111111111',
    100.0000,
    'Test: closed account'
);
-- Expected: status = 'FAILED', message = 'Source account is not active...'

-- Don't forget to reopen if you tested this:
-- UPDATE account SET status = 'ACTIVE' WHERE account_id = '44444444-4444-4444-8444-444444444444';

-- ============================================================================
-- TEST 6: Verify Double-Entry Balance
-- After all tests, verify ledger still balances
-- ============================================================================
WITH tb AS (
    SELECT
        coa.gl_account_code,
        coa.account_name,
        coa.gl_type,
        COALESCE(SUM(CASE WHEN le.entry_type = 'DEBIT' THEN le.amount ELSE 0 END), 0) AS debits,
        COALESCE(SUM(CASE WHEN le.entry_type = 'CREDIT' THEN le.amount ELSE 0 END), 0) AS credits
    FROM chart_of_accounts coa
    LEFT JOIN ledger_entry le ON coa.gl_account_code = le.gl_account_code
    GROUP BY coa.gl_account_code, coa.account_name, coa.gl_type
),
calc AS (
    SELECT
        gl_type,
        CASE
            WHEN gl_type IN ('ASSET', 'EXPENSE') THEN debits - credits
            WHEN gl_type IN ('LIABILITY', 'EQUITY', 'REVENUE') THEN credits - debits
        END AS balance
    FROM tb
)
SELECT
    (SELECT SUM(balance) FROM calc WHERE gl_type = 'ASSET') AS total_assets,
    (SELECT SUM(balance) FROM calc WHERE gl_type IN ('LIABILITY', 'EQUITY', 'REVENUE')) -
    (SELECT SUM(balance) FROM calc WHERE gl_type = 'EXPENSE') AS total_liabilities_equity,
    CASE
        WHEN (SELECT SUM(balance) FROM calc WHERE gl_type = 'ASSET') =
             (SELECT SUM(balance) FROM calc WHERE gl_type IN ('LIABILITY', 'EQUITY', 'REVENUE')) -
             (SELECT SUM(balance) FROM calc WHERE gl_type = 'EXPENSE')
        THEN '✓ BALANCED'
        ELSE '✗ UNBALANCED'
    END AS balance_check;