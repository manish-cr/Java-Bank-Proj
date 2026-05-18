-- ============================================================================
-- sp_reverse_transaction
-- Reverses a POSTED transaction by creating offsetting ledger entries.
-- The original transaction's status is updated to REVERSED.
-- ============================================================================
CREATE OR REPLACE FUNCTION sp_reverse_transaction(
    p_original_transaction_id UUID,
    p_idempotency_key UUID,
    p_reason VARCHAR(500) DEFAULT 'Transaction reversed'
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
    v_original_txn RECORD;
    v_entry RECORD;
    v_from_current_balance DECIMAL(19,4);
    v_to_current_balance DECIMAL(19,4);
    v_new_balance DECIMAL(19,4);
BEGIN
    -- 1. IDEMPOTENCY CHECK
    SELECT t.transaction_id, t.status
    INTO v_original_txn
    FROM transaction t
    WHERE t.idempotency_key = p_idempotency_key
    FOR UPDATE;

    IF FOUND THEN
        out_transaction_id := v_original_txn.transaction_id;
        out_status := v_original_txn.status;
        out_message := 'Duplicate reversal request. Original reversal returned.';
        RETURN NEXT;
        RETURN;
    END IF;

    -- 2. LOCK AND VALIDATE ORIGINAL TRANSACTION
    SELECT t.transaction_id, t.status, t.transaction_type
    INTO v_original_txn
    FROM transaction t
    WHERE t.transaction_id = p_original_transaction_id
    FOR UPDATE;

    IF NOT FOUND THEN
        out_status := 'FAILED';
        out_message := 'Original transaction not found.';
        RETURN NEXT;
        RETURN;
    END IF;

    IF v_original_txn.status != 'POSTED' THEN
        out_status := 'FAILED';
        out_message := 'Cannot reverse transaction. Current status: ' || v_original_txn.status;
        RETURN NEXT;
        RETURN;
    END IF;

    -- 3. CREATE REVERSAL TRANSACTION ENVELOPE
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
        'REVERSAL: ' || p_reason || ' [Original: ' || p_original_transaction_id || ']'
    );

    -- 4. FOR EACH LEDGER ENTRY, CREATE OPPOSITE ENTRY
    FOR v_entry IN
        SELECT le.*
        FROM ledger_entry le
        WHERE le.transaction_id = p_original_transaction_id
        ORDER BY le.created_at
    LOOP
        -- Get current balance for this account
        SELECT le2.balance_after
        INTO v_new_balance
        FROM ledger_entry le2
        WHERE le2.account_id = v_entry.account_id
        ORDER BY le2.entry_date DESC, le2.created_at DESC
        LIMIT 1;

        IF v_new_balance IS NULL THEN
            v_new_balance := 0;
        END IF;

        -- Reverse the entry type
        IF v_entry.entry_type = 'DEBIT' THEN
            v_new_balance := v_new_balance + v_entry.amount;
            INSERT INTO ledger_entry (
                ledger_entry_id, transaction_id, account_id,
                gl_account_code, entry_type, amount,
                balance_after, entry_date, description
            ) VALUES (
                gen_random_uuid(),
                v_new_transaction_id,
                v_entry.account_id,
                v_entry.gl_account_code,
                'CREDIT',
                v_entry.amount,
                v_new_balance,
                CURRENT_DATE,
                'Reversal: ' || COALESCE(v_entry.description, '')
            );
        ELSE
            v_new_balance := v_new_balance - v_entry.amount;
            INSERT INTO ledger_entry (
                ledger_entry_id, transaction_id, account_id,
                gl_account_code, entry_type, amount,
                balance_after, entry_date, description
            ) VALUES (
                gen_random_uuid(),
                v_new_transaction_id,
                v_entry.account_id,
                v_entry.gl_account_code,
                'DEBIT',
                v_entry.amount,
                v_new_balance,
                CURRENT_DATE,
                'Reversal: ' || COALESCE(v_entry.description, '')
            );
        END IF;
    END LOOP;

    -- 5. MARK REVERSAL AS POSTED
    UPDATE transaction txn
    SET status = 'POSTED', updated_at = NOW()
    WHERE txn.transaction_id = v_new_transaction_id;

    -- 6. MARK ORIGINAL AS REVERSED
    UPDATE transaction txn
    SET status = 'REVERSED', updated_at = NOW()
    WHERE txn.transaction_id = p_original_transaction_id;

    -- 7. WRITE TO OUTBOX
    INSERT INTO outbox_event (
        event_id, transaction_id, event_type, payload_json, status
    ) VALUES (
        gen_random_uuid(),
        v_new_transaction_id,
        'TRANSFER_REVERSED',
        jsonb_build_object(
            'reversalTransactionId', v_new_transaction_id,
            'originalTransactionId', p_original_transaction_id,
            'reason', p_reason,
            'timestamp', NOW()
        ),
        'PENDING'
    );

    -- 8. RETURN SUCCESS
    out_transaction_id := v_new_transaction_id;
    out_status := 'POSTED';
    out_message := 'Transaction reversed successfully. Original: ' || p_original_transaction_id;
    RETURN NEXT;
    RETURN;

EXCEPTION
    WHEN OTHERS THEN
        IF v_new_transaction_id IS NOT NULL THEN
            UPDATE transaction txn
            SET status = 'FAILED', updated_at = NOW()
            WHERE txn.transaction_id = v_new_transaction_id;
        END IF;

        out_transaction_id := NULL;
        out_status := 'FAILED';
        out_message := 'Reversal failed: ' || SQLERRM;
        RETURN NEXT;
        RETURN;
END;
$$;