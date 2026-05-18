-- ============================================================================
-- sp_perform_transfer (CORRECTED - No ambiguous column references)
-- ============================================================================
CREATE OR REPLACE FUNCTION sp_perform_transfer(
    p_idempotency_key   UUID,
    p_from_account_id   UUID,
    p_to_account_id     UUID,
    p_amount            DECIMAL(19,4),
    p_description       VARCHAR(500) DEFAULT 'Transfer between accounts'
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
    v_from_account RECORD;
    v_to_account RECORD;
    v_from_gl_code VARCHAR(10);
    v_to_gl_code VARCHAR(10);
    v_from_current_balance DECIMAL(19,4);
    v_to_current_balance DECIMAL(19,4);
    v_from_new_balance DECIMAL(19,4);
    v_to_new_balance DECIMAL(19,4);
    v_existing_txn RECORD;
BEGIN
    -- ========================================================================
    -- STEP 1: IDEMPOTENCY CHECK
    -- ========================================================================
    SELECT t.transaction_id, t.status
    INTO v_existing_txn
    FROM transaction t
    WHERE t.idempotency_key = p_idempotency_key
    FOR UPDATE;

    IF FOUND THEN
        out_transaction_id := v_existing_txn.transaction_id;
        out_status := v_existing_txn.status;
        out_message := 'Duplicate request. Original transaction returned.';
        RETURN NEXT;
        RETURN;
    END IF;

    -- ========================================================================
    -- STEP 2: INPUT VALIDATION
    -- ========================================================================
    IF p_amount IS NULL OR p_amount <= 0 THEN
        out_status := 'FAILED';
        out_message := 'Transfer amount must be greater than zero.';
        RETURN NEXT;
        RETURN;
    END IF;

    IF p_from_account_id = p_to_account_id THEN
        out_status := 'FAILED';
        out_message := 'Source and destination accounts must be different.';
        RETURN NEXT;
        RETURN;
    END IF;

    -- ========================================================================
    -- STEP 3: ACCOUNT LOCK (Deadlock Prevention)
    -- ========================================================================
    IF p_from_account_id < p_to_account_id THEN
        SELECT a.account_id, a.gl_account_code, a.account_type, a.status, a.currency_code
        INTO v_from_account
        FROM account a
        WHERE a.account_id = p_from_account_id
        FOR UPDATE;

        SELECT a.account_id, a.gl_account_code, a.account_type, a.status, a.currency_code
        INTO v_to_account
        FROM account a
        WHERE a.account_id = p_to_account_id
        FOR UPDATE;
    ELSE
        SELECT a.account_id, a.gl_account_code, a.account_type, a.status, a.currency_code
        INTO v_to_account
        FROM account a
        WHERE a.account_id = p_to_account_id
        FOR UPDATE;

        SELECT a.account_id, a.gl_account_code, a.account_type, a.status, a.currency_code
        INTO v_from_account
        FROM account a
        WHERE a.account_id = p_from_account_id
        FOR UPDATE;
    END IF;

    -- ========================================================================
    -- STEP 4: ACCOUNT EXISTENCE & STATUS VALIDATION
    -- ========================================================================
    IF v_from_account.account_id IS NULL THEN
        out_status := 'FAILED';
        out_message := 'Source account not found.';
        RETURN NEXT;
        RETURN;
    END IF;

    IF v_to_account.account_id IS NULL THEN
        out_status := 'FAILED';
        out_message := 'Destination account not found.';
        RETURN NEXT;
        RETURN;
    END IF;

    IF v_from_account.status != 'ACTIVE' THEN
        out_status := 'FAILED';
        out_message := 'Source account is not active. Current status: ' || v_from_account.status;
        RETURN NEXT;
        RETURN;
    END IF;

    IF v_to_account.status != 'ACTIVE' THEN
        out_status := 'FAILED';
        out_message := 'Destination account is not active. Current status: ' || v_to_account.status;
        RETURN NEXT;
        RETURN;
    END IF;

    -- ========================================================================
    -- STEP 5: CURRENCY CHECK
    -- ========================================================================
    IF v_from_account.currency_code != v_to_account.currency_code THEN
        out_status := 'FAILED';
        out_message := 'Currency mismatch. Source: ' || v_from_account.currency_code ||
                      ', Destination: ' || v_to_account.currency_code;
        RETURN NEXT;
        RETURN;
    END IF;

    -- ========================================================================
    -- STEP 6: BALANCE CHECK (Sufficient Funds)
    -- ========================================================================
    SELECT le.balance_after
    INTO v_from_current_balance
    FROM ledger_entry le
    WHERE le.account_id = p_from_account_id
    ORDER BY le.entry_date DESC, le.created_at DESC
    LIMIT 1;

    IF v_from_current_balance IS NULL THEN
        v_from_current_balance := 0;
    END IF;

    IF v_from_current_balance < p_amount THEN
        out_status := 'FAILED';
        out_message := 'Insufficient funds. Available: ' || v_from_current_balance ||
                      ', Requested: ' || p_amount;
        RETURN NEXT;
        RETURN;
    END IF;

    -- ========================================================================
    -- STEP 7: GET CURRENT BALANCE OF DESTINATION ACCOUNT
    -- ========================================================================
    SELECT le.balance_after
    INTO v_to_current_balance
    FROM ledger_entry le
    WHERE le.account_id = p_to_account_id
    ORDER BY le.entry_date DESC, le.created_at DESC
    LIMIT 1;

    IF v_to_current_balance IS NULL THEN
        v_to_current_balance := 0;
    END IF;

    -- ========================================================================
    -- STEP 8: COMPUTE NEW BALANCES
    -- ========================================================================
    v_from_new_balance := v_from_current_balance - p_amount;
    v_to_new_balance := v_to_current_balance + p_amount;

    IF v_from_new_balance < 0 THEN
        out_status := 'FAILED';
        out_message := 'Calculation error: resulting balance would be negative.';
        RETURN NEXT;
        RETURN;
    END IF;

    -- ========================================================================
    -- STEP 9: GET GL ACCOUNT CODES
    -- ========================================================================
    v_from_gl_code := v_from_account.gl_account_code;
    v_to_gl_code := v_to_account.gl_account_code;

    -- ========================================================================
    -- STEP 10: CREATE TRANSACTION ENVELOPE
    -- ========================================================================
    v_new_transaction_id := gen_random_uuid();

    INSERT INTO transaction (
        transaction_id,
        idempotency_key,
        transaction_type,
        status,
        business_date,
        description
    ) VALUES (
        v_new_transaction_id,
        p_idempotency_key,
        'TRANSFER',
        'PENDING',
        CURRENT_DATE,
        p_description
    );

    -- ========================================================================
    -- STEP 11: POST TO LEDGER (DOUBLE-ENTRY)
    -- ========================================================================

    -- Entry A: DEBIT source account
    INSERT INTO ledger_entry (
        ledger_entry_id,
        transaction_id,
        account_id,
        gl_account_code,
        entry_type,
        amount,
        balance_after,
        entry_date,
        description
    ) VALUES (
        gen_random_uuid(),
        v_new_transaction_id,
        p_from_account_id,
        v_from_gl_code,
        'DEBIT',
        p_amount,
        v_from_new_balance,
        CURRENT_DATE,
        'Transfer out to account ' || (SELECT acc.account_number FROM account acc WHERE acc.account_id = p_to_account_id)
    );

    -- Entry B: CREDIT destination account
    INSERT INTO ledger_entry (
        ledger_entry_id,
        transaction_id,
        account_id,
        gl_account_code,
        entry_type,
        amount,
        balance_after,
        entry_date,
        description
    ) VALUES (
        gen_random_uuid(),
        v_new_transaction_id,
        p_to_account_id,
        v_to_gl_code,
        'CREDIT',
        p_amount,
        v_to_new_balance,
        CURRENT_DATE,
        'Transfer in from account ' || (SELECT acc.account_number FROM account acc WHERE acc.account_id = p_from_account_id)
    );

    -- ========================================================================
    -- STEP 12: FINALIZE TRANSACTION (aliased to avoid ambiguity)
    -- ========================================================================
    UPDATE transaction txn
    SET status = 'POSTED',
        updated_at = NOW()
    WHERE txn.transaction_id = v_new_transaction_id;

    -- ========================================================================
    -- STEP 13: WRITE TO OUTBOX
    -- ========================================================================
    INSERT INTO outbox_event (
        event_id,
        transaction_id,
        event_type,
        payload_json,
        status
    ) VALUES (
        gen_random_uuid(),
        v_new_transaction_id,
        'TRANSFER_COMPLETED',
        jsonb_build_object(
            'transactionId', v_new_transaction_id,
            'fromAccountId', p_from_account_id,
            'toAccountId', p_to_account_id,
            'amount', p_amount,
            'currency', v_from_account.currency_code,
            'timestamp', NOW()
        ),
        'PENDING'
    );

    -- ========================================================================
    -- STEP 14: RETURN SUCCESS
    -- ========================================================================
    out_transaction_id := v_new_transaction_id;
    out_status := 'POSTED';
    out_message := 'Transfer completed successfully. ' ||
                   'Amount: ' || p_amount || ' ' || v_from_account.currency_code ||
                   '. From: ' || p_from_account_id ||
                   ' To: ' || p_to_account_id;
    RETURN NEXT;
    RETURN;

EXCEPTION
    WHEN OTHERS THEN
        IF v_new_transaction_id IS NOT NULL THEN
            UPDATE transaction txn
            SET status = 'FAILED',
                updated_at = NOW()
            WHERE txn.transaction_id = v_new_transaction_id;
        END IF;

        out_transaction_id := NULL;
        out_status := 'FAILED';
        out_message := 'Transfer failed due to error: ' || SQLERRM;
        RETURN NEXT;
        RETURN;
END;
$$;

-- DROP FUNCTION IF EXISTS sp_perform_transfer(UUID, UUID, UUID, DECIMAL, VARCHAR);
