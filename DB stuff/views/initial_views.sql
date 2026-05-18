-- View: Full account details with product-specific state
CREATE OR REPLACE VIEW v_account_full AS
SELECT
    a.account_id,
    a.account_number,
    a.account_type,
    a.currency_code,
    a.status,
    a.opened_at,
    c.customer_id,
    c.legal_name AS customer_name,
    c.persona_type AS customer_type,
    coa.gl_account_code,
    coa.account_name AS gl_account_name,
    coa.gl_type AS gl_type,

    (SELECT le.balance_after
     FROM ledger_entry le
     WHERE le.account_id = a.account_id
     ORDER BY le.entry_date DESC, le.created_at DESC
     LIMIT 1) AS current_balance,

    psc.monthly_fee AS checking_monthly_fee,
    psc.overdraft_limit,
    psc.last_fee_date,

    pss.interest_rate AS savings_interest_rate,
    pss.compounding_frequency,
    pss.interest_accrued_pending AS savings_interest_pending,
    pss.interest_accrued_ytd AS savings_interest_ytd,
    pss.last_interest_date,

    psl.original_principal AS loan_original_principal,
    psl.principal_outstanding,
    psl.interest_rate AS loan_interest_rate,
    psl.loan_term_months,
    psl.monthly_payment,
    psl.next_payment_date,
    psl.days_past_due,

    psi.stock_symbol,
    psi.quantity_held,
    psi.average_cost_basis,
    psi.current_market_price

FROM account a
JOIN customer c ON a.customer_id = c.customer_id
JOIN chart_of_accounts coa ON a.gl_account_code = coa.gl_account_code
LEFT JOIN product_state_checking psc ON a.account_id = psc.account_id
LEFT JOIN product_state_savings pss ON a.account_id = pss.account_id
LEFT JOIN product_state_loan psl ON a.account_id = psl.account_id
LEFT JOIN product_state_investment psi ON a.account_id = psi.account_id;

-- View: Next actions needed
CREATE OR REPLACE VIEW v_pending_actions AS
SELECT
    'CHECKING_FEE_DUE' AS action_type,
    a.account_id,
    a.account_number,
    c.legal_name,
    psc.monthly_fee,
    COALESCE(psc.last_fee_date, a.opened_at::DATE) AS last_action_date
FROM account a
JOIN product_state_checking psc ON a.account_id = psc.account_id
JOIN customer c ON a.customer_id = c.customer_id
WHERE a.status = 'ACTIVE'
  AND psc.monthly_fee > 0
  AND (psc.last_fee_date IS NULL OR psc.last_fee_date < CURRENT_DATE - INTERVAL '30 days')

UNION ALL

SELECT
    'LOAN_PAYMENT_DUE' AS action_type,
    a.account_id,
    a.account_number,
    c.legal_name,
    psl.monthly_payment AS amount_due,
    psl.next_payment_date AS last_action_date
FROM account a
JOIN product_state_loan psl ON a.account_id = psl.account_id
JOIN customer c ON a.customer_id = c.customer_id
WHERE a.status = 'ACTIVE'
  AND psl.principal_outstanding > 0
  AND psl.next_payment_date <= CURRENT_DATE;