CREATE OR REPLACE FUNCTION sp_accrue_daily_interest_for_account(
    p_account_id UUID
)
RETURNS TABLE(
    out_account_id UUID,
    out_days_processed INTEGER,
    out_interest_accrued DECIMAL(19,4),
    out_status VARCHAR(20),
    out_message VARCHAR(500)
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_account RECORD;
    v_savings RECORD;
    v_current_balance DECIMAL(19,4);
    v_interest_rate DECIMAL(7,4);
    v_daily_rate DECIMAL(19,10);
    v_daily_interest DECIMAL(19,10);
    v_accrued DECIMAL(19,4);
    v_process_date DATE;
    v_today DATE;
    v_last_date DATE;
    v_days_in_year INTEGER;
    v_days_processed INTEGER := 0;
    v_total_interest DECIMAL(19,4) := 0;
BEGIN
    v_today := CURRENT_DATE;

    -- Lock and validate account
    SELECT a.account_id, a.status, a.opened_at
    INTO v_account
    FROM account a
    WHERE a.account_id = p_account_id
    FOR UPDATE;

    IF NOT FOUND THEN
        out_status := 'FAILED';
        out_message := 'Account not found.';
        RETURN NEXT; RETURN;
    END IF;

    IF v_account.status != 'ACTIVE' THEN
        out_status := 'FAILED';
        out_message := 'Account is not active.';
        RETURN NEXT; RETURN;
    END IF;

    -- Get savings product state
    SELECT pss.* INTO v_savings
    FROM product_state_savings pss
    WHERE pss.account_id = p_account_id;

    IF NOT FOUND THEN
        out_status := 'FAILED';
        out_message := 'Not a savings account.';
        RETURN NEXT; RETURN;
    END IF;

    v_interest_rate := v_savings.interest_rate;

    -- Determine starting date
    IF v_savings.last_interest_date IS NOT NULL THEN
        v_last_date := v_savings.last_interest_date;
    ELSE
        v_last_date := v_account.opened_at::DATE;
    END IF;

    -- If already processed today, skip
    IF v_last_date >= v_today THEN
        out_account_id := p_account_id;
        out_days_processed := 0;
        out_interest_accrued := 0;
        out_status := 'SKIPPED';
        out_message := 'Already processed today.';
        RETURN NEXT; RETURN;
    END IF;

    -- Get current balance as of the last processed date
    SELECT le.balance_after INTO v_current_balance
    FROM ledger_entry le
    WHERE le.account_id = p_account_id
      AND le.entry_date <= v_last_date
    ORDER BY le.entry_date DESC, le.created_at DESC
    LIMIT 1;

    IF v_current_balance IS NULL THEN
        v_current_balance := 0;
    END IF;

    -- Process each missed day
    v_process_date := v_last_date + 1;

    WHILE v_process_date <= v_today LOOP
        v_days_in_year := fn_days_in_year(v_process_date);
        v_daily_rate := v_interest_rate / v_days_in_year;
        v_daily_interest := v_current_balance * v_daily_rate;

        -- Round using banker's rounding to 4 decimal places
        v_accrued := round_banker(v_daily_interest, 4);

        v_total_interest := v_total_interest + v_accrued;
        v_days_processed := v_days_processed + 1;

        -- For daily compounding: add to principal immediately for next day's calculation
        IF v_savings.compounding_frequency = 'DAILY' THEN
            v_current_balance := v_current_balance + v_accrued;
        END IF;

        v_process_date := v_process_date + 1;
    END LOOP;

    -- Update product state
    UPDATE product_state_savings
    SET interest_accrued_pending = interest_accrued_pending + v_total_interest,
        last_interest_date = v_today
    WHERE account_id = p_account_id;

    out_account_id := p_account_id;
    out_days_processed := v_days_processed;
    out_interest_accrued := v_total_interest;
    out_status := 'SUCCESS';
    out_message := 'Processed ' || v_days_processed || ' days. Interest: ' || v_total_interest;
    RETURN NEXT;
    RETURN;

EXCEPTION WHEN OTHERS THEN
    out_status := 'FAILED';
    out_message := 'Interest accrual failed: ' || SQLERRM;
    RETURN NEXT; RETURN;
END;
$$;