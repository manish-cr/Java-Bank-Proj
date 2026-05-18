-- ============================================================================
-- ROLLBACK TEST DATA
-- Deletes all transactions, ledger entries, and outbox events created
-- AFTER the original seed data (which all had transaction IDs starting with
-- 'aaaaaaa*-aaaa-4aaa-8aaa-aaaaaaaaaaa*').
-- NOTE: Do this only if you have already done the tests for sp_perform_transfer stored proc!
-- ============================================================================

BEGIN;

-- 1. Delete outbox events from test transactions
DELETE FROM outbox_event
WHERE transaction_id NOT IN (
    'aaaaaaa1-aaaa-4aaa-8aaa-aaaaaaaaaaa1',
    'aaaaaaa2-aaaa-4aaa-8aaa-aaaaaaaaaaa2',
    'aaaaaaa3-aaaa-4aaa-8aaa-aaaaaaaaaaa3',
    'aaaaaaa4-aaaa-4aaa-8aaa-aaaaaaaaaaa4',
    'aaaaaaa5-aaaa-4aaa-8aaa-aaaaaaaaaaa5',
    'aaaaaaa6-aaaa-4aaa-8aaa-aaaaaaaaaaa6',
    'aaaaaaa7-aaaa-4aaa-8aaa-aaaaaaaaaaa7',
    'aaaaaaa8-aaaa-4aaa-8aaa-aaaaaaaaaaa8'
);

-- 2. Delete ledger entries from test transactions
DELETE FROM ledger_entry
WHERE transaction_id NOT IN (
    'aaaaaaa1-aaaa-4aaa-8aaa-aaaaaaaaaaa1',
    'aaaaaaa2-aaaa-4aaa-8aaa-aaaaaaaaaaa2',
    'aaaaaaa3-aaaa-4aaa-8aaa-aaaaaaaaaaa3',
    'aaaaaaa4-aaaa-4aaa-8aaa-aaaaaaaaaaa4',
    'aaaaaaa5-aaaa-4aaa-8aaa-aaaaaaaaaaa5',
    'aaaaaaa6-aaaa-4aaa-8aaa-aaaaaaaaaaa6',
    'aaaaaaa7-aaaa-4aaa-8aaa-aaaaaaaaaaa7',
    'aaaaaaa8-aaaa-4aaa-8aaa-aaaaaaaaaaa8'
);

-- 3. Delete test transactions
DELETE FROM transaction
WHERE transaction_id NOT IN (
    'aaaaaaa1-aaaa-4aaa-8aaa-aaaaaaaaaaa1',
    'aaaaaaa2-aaaa-4aaa-8aaa-aaaaaaaaaaa2',
    'aaaaaaa3-aaaa-4aaa-8aaa-aaaaaaaaaaa3',
    'aaaaaaa4-aaaa-4aaa-8aaa-aaaaaaaaaaa4',
    'aaaaaaa5-aaaa-4aaa-8aaa-aaaaaaaaaaa5',
    'aaaaaaa6-aaaa-4aaa-8aaa-aaaaaaaaaaa6',
    'aaaaaaa7-aaaa-4aaa-8aaa-aaaaaaaaaaa7',
    'aaaaaaa8-aaaa-4aaa-8aaa-aaaaaaaaaaa8'
);

COMMIT;

-- ============================================================================
-- VERIFICATION: Confirm balances match original seed data
-- ============================================================================
SELECT
    a.account_number,
    a.account_type,
    c.legal_name,
    (SELECT le.balance_after
     FROM ledger_entry le
     WHERE le.account_id = a.account_id
     ORDER BY le.entry_date DESC, le.created_at DESC
     LIMIT 1) AS current_balance
FROM account a
JOIN customer c ON a.customer_id = c.customer_id
ORDER BY c.legal_name, a.account_type;