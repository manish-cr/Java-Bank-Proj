-- ============================================================================
-- sp_perform_withdrawal
-- Withdraws money from an account. Bank gives cash (ASSET down),
-- customer deposit liability (LIABILITY down).
-- ============================================================================
CREATE OR REPLACE FUNCTION sp_perform_withdrawal(
    p_idempotency_key   UUID,
    p_from_account_id   UUID,
    p_amount            DECIMAL(19,4),
    p_description       VARCHAR(500) DEFAULT 'Cash withdrawal'
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
        out_message := 'Withdrawal amount must be greater than zero.';
        RETURN NEXT; RETURN;
    END IF;

    -- Lock account
    SELECT a.account_id, a.gl_account_code, a.status, a.currency_code
    INTO v_account FROM account a WHERE a.account_id = p_from_account_id FOR UPDATE;

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
    FROM ledger_entry le WHERE le.account_id = p_from_account_id
    ORDER BY le.entry_date DESC, le.created_at DESC LIMIT 1;
    IF v_current_balance IS NULL THEN v_current_balance := 0; END IF;

    -- Sufficient funds check
    IF v_current_balance < p_amount THEN
        out_status := 'FAILED';
        out_message := 'Insufficient funds. Available: ' || v_current_balance || ', Requested: ' || p_amount;
        RETURN NEXT; RETURN;
    END IF;

    -- Compute new balance
    v_new_balance := v_current_balance - p_amount;

    -- Create transaction
    v_new_transaction_id := gen_random_uuid();
    INSERT INTO transaction (transaction_id, idempotency_key, transaction_type, status, business_date, description)
    VALUES (v_new_transaction_id, p_idempotency_key, 'WITHDRAWAL', 'PENDING', CURRENT_DATE, p_description);

    -- Double-entry posting
    -- Entry A: DEBIT customer account (LIABILITY down)
    INSERT INTO ledger_entry (ledger_entry_id, transaction_id, account_id, gl_account_code, entry_type, amount, balance_after, entry_date, description)
    VALUES (gen_random_uuid(), v_new_transaction_id, p_from_account_id, v_account.gl_account_code, 'DEBIT', p_amount, v_new_balance, CURRENT_DATE, p_description);

    -- Entry B: CREDIT Cash on Hand (ASSET down)
    INSERT INTO ledger_entry (ledger_entry_id, transaction_id, account_id, gl_account_code, entry_type, amount, balance_after, entry_date, description)
    VALUES (gen_random_uuid(), v_new_transaction_id, p_from_account_id, '1001', 'CREDIT', p_amount, v_new_balance, CURRENT_DATE, 'Cash disbursed');

    -- Finalize
    UPDATE transaction txn SET status = 'POSTED', updated_at = NOW() WHERE txn.transaction_id = v_new_transaction_id;

    -- Outbox
    INSERT INTO outbox_event (event_id, transaction_id, event_type, payload_json, status)
    VALUES (gen_random_uuid(), v_new_transaction_id, 'WITHDRAWAL_COMPLETED',
        jsonb_build_object('transactionId', v_new_transaction_id, 'accountId', p_from_account_id, 'amount', p_amount, 'timestamp', NOW()),
        'PENDING');

    out_transaction_id := v_new_transaction_id;
    out_status := 'POSTED';
    out_message := 'Withdrawal completed. Amount: ' || p_amount;
    RETURN NEXT; RETURN;

EXCEPTION WHEN OTHERS THEN
    IF v_new_transaction_id IS NOT NULL THEN
        UPDATE transaction txn SET status = 'FAILED', updated_at = NOW() WHERE txn.transaction_id = v_new_transaction_id;
    END IF;
    out_transaction_id := NULL; out_status := 'FAILED';
    out_message := 'Withdrawal failed: ' || SQLERRM;
    RETURN NEXT; RETURN;
END;
$$;