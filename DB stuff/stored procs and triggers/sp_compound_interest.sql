-- ============================================================================
-- sp_compound_interest
-- Posts accumulated pending interest to the ledger for an account.
-- Should be called on the compounding date (month-end, quarter-end, etc.)
-- ============================================================================
CREATE OR REPLACE FUNCTION sp_compound_interest(
    p_account_id UUID,
    p_idempotency_key UUID
)
RETURNS TABLE(
    out_transaction_id UUID,
    out_status VARCHAR(20),
    out_message VARCHAR(500)
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_new_transaction_id UUID;
    v_account RECORD;
    v_savings RECORD;
    v_pending_interest DECIMAL(19,4);
    v_current_balance DECIMAL(19,4);
    v_new_balance DECIMAL(19,4);
    v_existing_txn RECORD;
BEGIN
    -- Idempotency check
    SELECT t.transaction_id, t.status INTO v_existing_txn
    FROM transaction t
    WHERE t.idempotency_key = p_idempotency_key
    FOR UPDATE;

    IF FOUND THEN
        out_transaction_id := v_existing_txn.transaction_id;
        out_status := v_existing_txn.status;
        out_message := 'Duplicate request. Original returned.';
        RETURN NEXT; RETURN;
    END IF;

    -- Lock and validate account
    SELECT a.account_id, a.gl_account_code, a.status
    INTO v_account
    FROM account a
    WHERE a.account_id = p_account_id
    FOR UPDATE;

    IF NOT FOUND THEN
        out_status := 'FAILED';
        out_message := 'Account not found.';
        RETURN NEXT; RETURN;
    END IF;

    -- Get savings state
    SELECT * INTO v_savings
    FROM product_state_savings
    WHERE account_id = p_account_id;

    IF NOT FOUND THEN
        out_status := 'FAILED';
        out_message := 'Not a savings account.';
        RETURN NEXT; RETURN;
    END IF;

    v_pending_interest := v_savings.interest_accrued_pending;

    IF v_pending_interest <= 0 THEN
        out_status := 'SKIPPED';
        out_message := 'No pending interest to compound.';
        RETURN NEXT; RETURN;
    END IF;

    -- Get current balance
    SELECT le.balance_after INTO v_current_balance
    FROM ledger_entry le
    WHERE le.account_id = p_account_id
    ORDER BY le.entry_date DESC, le.created_at DESC
    LIMIT 1;

    IF v_current_balance IS NULL THEN
        v_current_balance := 0;
    END IF;

    v_new_balance := v_current_balance + v_pending_interest;

    -- Create transaction
    v_new_transaction_id := gen_random_uuid();
    INSERT INTO transaction (transaction_id, idempotency_key, transaction_type, status, business_date, description)
    VALUES (v_new_transaction_id, p_idempotency_key, 'INTEREST_ACCRUAL', 'PENDING', CURRENT_DATE,
            'Interest compounding - ' || v_savings.compounding_frequency);

    -- Double-entry posting
    -- Entry A: DEBIT Interest Expense (5001)
    INSERT INTO ledger_entry (ledger_entry_id, transaction_id, account_id, gl_account_code, entry_type, amount, balance_after, entry_date, description)
    VALUES (gen_random_uuid(), v_new_transaction_id, p_account_id, '5001', 'DEBIT', v_pending_interest, v_new_balance, CURRENT_DATE, 'Interest expense');

    -- Entry B: CREDIT Savings Account (2002) - increases customer balance
    INSERT INTO ledger_entry (ledger_entry_id, transaction_id, account_id, gl_account_code, entry_type, amount, balance_after, entry_date, description)
    VALUES (gen_random_uuid(), v_new_transaction_id, p_account_id, '2002', 'CREDIT', v_pending_interest, v_new_balance, CURRENT_DATE, 'Interest earned');

    -- Update product state
    UPDATE product_state_savings
    SET interest_accrued_pending = 0.0000,
        interest_accrued_ytd = interest_accrued_ytd + v_pending_interest,
        last_compound_date = CURRENT_DATE
    WHERE account_id = p_account_id;

    -- Finalize transaction
    UPDATE transaction txn SET status = 'POSTED', updated_at = NOW() WHERE txn.transaction_id = v_new_transaction_id;

    -- Outbox
    INSERT INTO outbox_event (event_id, transaction_id, event_type, payload_json, status)
    VALUES (gen_random_uuid(), v_new_transaction_id, 'INTEREST_COMPOUNDED',
            jsonb_build_object('transactionId', v_new_transaction_id, 'accountId', p_account_id, 'amount', v_pending_interest, 'timestamp', NOW()),
            'PENDING');

    out_transaction_id := v_new_transaction_id;
    out_status := 'POSTED';
    out_message := 'Interest compounded: ' || v_pending_interest;
    RETURN NEXT; RETURN;

EXCEPTION WHEN OTHERS THEN
    IF v_new_transaction_id IS NOT NULL THEN
        UPDATE transaction txn SET status = 'FAILED', updated_at = NOW() WHERE txn.transaction_id = v_new_transaction_id;
    END IF;
    out_transaction_id := NULL;
    out_status := 'FAILED';
    out_message := 'Compounding failed: ' || SQLERRM;
    RETURN NEXT; RETURN;
END;
$$;