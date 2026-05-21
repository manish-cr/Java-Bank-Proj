-- ============================================================================
-- sp_create_account
-- Creates a new account with product-specific state.
-- ============================================================================
CREATE OR REPLACE FUNCTION sp_create_account(
    p_customer_id           UUID,
    p_account_type          VARCHAR(20),
    p_currency_code         CHAR(3) DEFAULT 'USD',
    p_interest_rate         DECIMAL(7,4) DEFAULT NULL,
    p_monthly_fee           DECIMAL(19,4) DEFAULT NULL,
    p_overdraft_limit       DECIMAL(19,4) DEFAULT NULL,
    p_original_principal    DECIMAL(19,4) DEFAULT NULL,
    p_loan_term_months      INTEGER DEFAULT NULL,
    p_monthly_payment       DECIMAL(19,4) DEFAULT NULL
)
RETURNS TABLE(
    out_account_id      UUID,
    out_account_number  VARCHAR(20),
    out_status          VARCHAR(20),
    out_message         VARCHAR(500)
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_account_id UUID;
    v_account_number VARCHAR(20);
    v_gl_code VARCHAR(10);
    v_customer RECORD;
    v_existing_count INTEGER;
BEGIN
    -- Validate customer exists and is verified
    SELECT c.customer_id, c.kyc_status INTO v_customer
    FROM customer c WHERE c.customer_id = p_customer_id FOR UPDATE;

    IF NOT FOUND THEN
        out_status := 'FAILED';
        out_message := 'Customer not found.';
        RETURN NEXT; RETURN;
    END IF;

    IF v_customer.kyc_status != 'VERIFIED' THEN
        out_status := 'FAILED';
        out_message := 'Customer KYC is not verified. Status: ' || v_customer.kyc_status;
        RETURN NEXT; RETURN;
    END IF;

    -- Determine GL account code
    CASE p_account_type
        WHEN 'CHECKING' THEN v_gl_code := '2001';
        WHEN 'SAVINGS' THEN v_gl_code := '2002';
        WHEN 'LOAN_RECEIVABLE' THEN v_gl_code := '2003';
        WHEN 'INVESTMENT' THEN v_gl_code := '2001';
        ELSE
            out_status := 'FAILED';
            out_message := 'Invalid account type: ' || p_account_type;
            RETURN NEXT; RETURN;
    END CASE;

    -- Generate account number (simple sequential)
    SELECT COUNT(*) + 1 INTO v_existing_count FROM account;
    v_account_number := CASE p_account_type
        WHEN 'CHECKING' THEN 'CHQ-1' || LPAD(v_existing_count::TEXT, 6, '0')
        WHEN 'SAVINGS' THEN 'SAV-1' || LPAD(v_existing_count::TEXT, 6, '0')
        WHEN 'LOAN_RECEIVABLE' THEN 'LOAN-1' || LPAD(v_existing_count::TEXT, 6, '0')
        WHEN 'INVESTMENT' THEN 'INV-1' || LPAD(v_existing_count::TEXT, 6, '0')
    END;

    -- Create account
    v_account_id := gen_random_uuid();
    INSERT INTO account (account_id, customer_id, gl_account_code, account_number, account_type, currency_code, status)
    VALUES (v_account_id, p_customer_id, v_gl_code, v_account_number, p_account_type, p_currency_code, 'ACTIVE');

    -- Create product state
    CASE p_account_type
        WHEN 'CHECKING' THEN
            INSERT INTO product_state_checking (account_id, monthly_fee, overdraft_limit)
            VALUES (v_account_id, COALESCE(p_monthly_fee, 5.0000), COALESCE(p_overdraft_limit, 0.0000));
        WHEN 'SAVINGS' THEN
            INSERT INTO product_state_savings (account_id, interest_rate, compounding_frequency)
            VALUES (v_account_id, COALESCE(p_interest_rate, 0.0500), 'MONTHLY');
        WHEN 'LOAN_RECEIVABLE' THEN
            INSERT INTO product_state_loan (account_id, original_principal, principal_outstanding, interest_rate, loan_term_months, monthly_payment, next_payment_date)
            VALUES (v_account_id, p_original_principal, p_original_principal, COALESCE(p_interest_rate, 0.0799),
                    p_loan_term_months, p_monthly_payment, CURRENT_DATE + INTERVAL '1 month');
        WHEN 'INVESTMENT' THEN
            INSERT INTO product_state_investment (account_id, stock_symbol)
            VALUES (v_account_id, 'DEFAULT');
    END CASE;

    out_account_id := v_account_id;
    out_account_number := v_account_number;
    out_status := 'ACTIVE';
    out_message := 'Account created successfully. Number: ' || v_account_number;
    RETURN NEXT; RETURN;

EXCEPTION WHEN OTHERS THEN
    out_account_id := NULL; out_account_number := NULL;
    out_status := 'FAILED';
    out_message := 'Account creation failed: ' || SQLERRM;
    RETURN NEXT; RETURN;
END;
$$;