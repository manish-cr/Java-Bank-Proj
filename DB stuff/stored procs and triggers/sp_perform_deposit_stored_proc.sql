-- ============================================================================
-- sp_perform_deposit
-- Deposits money into an account. Bank receives cash (ASSET up),
-- customer deposit liability (LIABILITY up).
-- ============================================================================
CREATE OR REPLACE FUNCTION sp_perform_deposit(
    p_idempotency_key   UUID,
    p_to_account_id     UUID,
    p_amount            DECIMAL(19,4),
    p_description       VARCHAR(500) DEFAULT 'Cash deposit'
)
RETURNS TABLE(
    out_transaction_id  UUID,
    out_status          VARCHAR(20),
    out_message         VARCHAR(500)
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_new_transaction_id    UUID;
    v_account RECORD;
    v_current_balance DECIMAL(19,4);
    v_new_balance DECIMAL(19,4);
    v_existing_txn RECORD;
BEGIN
    -- Idempotency check
    SELECT t.transaction_id, t.status INTO v_existing_txn
    FROM transaction t WHERE t.idempotency_key = p_idempotency_key FOR UPDATE;
    IF FOUND THEN
        out_transaction_id := v_existing_txn.transaction_id;
        out_status := v_existing_txn.status;
        out_message := 'Duplicate request. Original transaction returned.';
        RETURN NEXT; RETURN;
    END IF;

    -- Validation
    IF p_amount IS NULL OR p_amount <= 0 THEN
        out_status := 'FAILED';
        out_message := 'Deposit amount must be greater than zero.';
        RETURN NEXT; RETURN;
    END IF;

    -- Lock account
    SELECT a.account_id, a.gl_account_code, a.status, a.currency_code
    INTO v_account FROM account a WHERE a.account_id = p_to_account_id FOR UPDATE;

    IF v_account.account_id IS NULL THEN
        out_status := 'FAILED';
        out_message := 'Account not found.';
        RETURN NEXT; RETURN;
    END IF;

    IF v_account.status != 'ACTIVE' THEN
        out_status := 'FAILED';
        out_message := 'Account is not active. Status: ' || v_account.status;
        RETURN NEXT; RETURN;
    END IF;

    -- Get current balance
    SELECT le.balance_after INTO v_current_balance
    FROM ledger_entry le WHERE le.account_id = p_to_account_id
    ORDER BY le.entry_date DESC, le.created_at DESC LIMIT 1;
    IF v_current_balance IS NULL THEN v_current_balance := 0; END IF;

    -- Compute new balance
    v_new_balance := v_current_balance + p_amount;

    -- Create transaction
    v_new_transaction_id := gen_random_uuid();
    INSERT INTO transaction (transaction_id, idempotency_key, transaction_type, status, business_date, description)
    VALUES (v_new_transaction_id, p_idempotency_key, 'DEPOSIT', 'PENDING', CURRENT_DATE, p_description);

    -- Double-entry posting
    -- Entry A: DEBIT Cash on Hand (ASSET up)
    INSERT INTO ledger_entry (ledger_entry_id, transaction_id, account_id, gl_account_code, entry_type, amount, balance_after, entry_date, description)
    VALUES (gen_random_uuid(), v_new_transaction_id, p_to_account_id, '1001', 'DEBIT', p_amount, v_new_balance, CURRENT_DATE, 'Cash received');

    -- Entry B: CREDIT customer account (LIABILITY up)
    INSERT INTO ledger_entry (ledger_entry_id, transaction_id, account_id, gl_account_code, entry_type, amount, balance_after, entry_date, description)
    VALUES (gen_random_uuid(), v_new_transaction_id, p_to_account_id, v_account.gl_account_code, 'CREDIT', p_amount, v_new_balance, CURRENT_DATE, p_description);

    -- Finalize
    UPDATE transaction txn SET status = 'POSTED', updated_at = NOW() WHERE txn.transaction_id = v_new_transaction_id;

    -- Outbox
    INSERT INTO outbox_event (event_id, transaction_id, event_type, payload_json, status)
    VALUES (gen_random_uuid(), v_new_transaction_id, 'DEPOSIT_COMPLETED',
        jsonb_build_object('transactionId', v_new_transaction_id, 'accountId', p_to_account_id, 'amount', p_amount, 'timestamp', NOW()),
        'PENDING');

    out_transaction_id := v_new_transaction_id;
    out_status := 'POSTED';
    out_message := 'Deposit completed. Amount: ' || p_amount;
    RETURN NEXT; RETURN;

EXCEPTION WHEN OTHERS THEN
    IF v_new_transaction_id IS NOT NULL THEN
        UPDATE transaction txn SET status = 'FAILED', updated_at = NOW() WHERE txn.transaction_id = v_new_transaction_id;
    END IF;
    out_transaction_id := NULL; out_status := 'FAILED';
    out_message := 'Deposit failed: ' || SQLERRM;
    RETURN NEXT; RETURN;
END;
$$;