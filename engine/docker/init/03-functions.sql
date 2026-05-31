-- ============================================================================
-- NexusBank Engine - All Stored Procedures & Functions
-- ============================================================================

-- Banker's Rounding
CREATE OR REPLACE FUNCTION round_banker(value DECIMAL, decimals INTEGER DEFAULT 4)
RETURNS DECIMAL LANGUAGE plpgsql IMMUTABLE AS $$
DECLARE
    multiplier DECIMAL; scaled DECIMAL; integer_part BIGINT; fractional_part DECIMAL;
BEGIN
    IF value IS NULL THEN RETURN NULL; END IF;
    multiplier := POWER(10, decimals)::DECIMAL;
    scaled := value * multiplier;
    integer_part := FLOOR(scaled)::BIGINT;
    fractional_part := scaled - integer_part;
    IF fractional_part < 0.5 THEN RETURN FLOOR(scaled) / multiplier;
    ELSIF fractional_part > 0.5 THEN RETURN CEIL(scaled) / multiplier;
    ELSE IF MOD(integer_part, 2) = 0 THEN RETURN integer_part / multiplier;
         ELSE RETURN (integer_part + 1) / multiplier; END IF;
    END IF;
END; $$;

-- Days in Year
CREATE OR REPLACE FUNCTION fn_days_in_year(p_date DATE)
RETURNS INTEGER LANGUAGE plpgsql IMMUTABLE AS $$
DECLARE year_val INTEGER;
BEGIN
    year_val := EXTRACT(YEAR FROM p_date);
    IF (year_val % 4 = 0 AND year_val % 100 != 0) OR (year_val % 400 = 0) THEN RETURN 366;
    ELSE RETURN 365; END IF;
END; $$;

-- Is Compounding Date
CREATE OR REPLACE FUNCTION fn_is_compounding_date(p_frequency VARCHAR(10), p_current_date DATE DEFAULT CURRENT_DATE)
RETURNS BOOLEAN LANGUAGE plpgsql IMMUTABLE AS $$
DECLARE
    v_last_day DATE; v_day INTEGER; v_month INTEGER;
BEGIN
    v_day := EXTRACT(DAY FROM p_current_date);
    v_month := EXTRACT(MONTH FROM p_current_date);
    v_last_day := (DATE_TRUNC('MONTH', p_current_date) + INTERVAL '1 MONTH' - INTERVAL '1 DAY')::DATE;
    IF p_frequency = 'DAILY' THEN RETURN TRUE;
    ELSIF p_frequency = 'MONTHLY' THEN RETURN p_current_date = v_last_day;
    ELSIF p_frequency = 'QUARTERLY' THEN RETURN p_current_date = v_last_day AND v_month IN (3,6,9,12);
    ELSIF p_frequency = 'SEMIANNUALLY' THEN RETURN p_current_date = v_last_day AND v_month IN (6,12);
    ELSIF p_frequency = 'ANNUALLY' THEN RETURN p_current_date = v_last_day AND v_month = 12;
    ELSE RETURN FALSE; END IF;
END; $$;

-- Get Current Rate
CREATE OR REPLACE FUNCTION fn_get_current_rate(p_rate_code VARCHAR(30), p_currency_code CHAR(3) DEFAULT 'USD', p_as_of_date DATE DEFAULT CURRENT_DATE)
RETURNS DECIMAL(7,4) LANGUAGE plpgsql STABLE AS $$
DECLARE v_rate DECIMAL(7,4);
BEGIN
    SELECT rate_value INTO v_rate FROM interest_rate_schedule
    WHERE rate_code = p_rate_code AND currency_code = p_currency_code
      AND effective_from <= p_as_of_date AND (effective_until IS NULL OR effective_until > p_as_of_date)
    ORDER BY effective_from DESC LIMIT 1;
    RETURN v_rate;
END; $$;

-- Get Tiered Rate
CREATE OR REPLACE FUNCTION fn_get_tiered_rate(p_rate_code VARCHAR(30), p_balance DECIMAL(19,4), p_currency_code CHAR(3) DEFAULT 'USD', p_as_of_date DATE DEFAULT CURRENT_DATE)
RETURNS DECIMAL(7,4) LANGUAGE plpgsql STABLE AS $$
DECLARE v_rate DECIMAL(7,4);
BEGIN
    SELECT rate_value INTO v_rate FROM interest_rate_schedule
    WHERE rate_code = p_rate_code AND currency_code = p_currency_code
      AND effective_from <= p_as_of_date AND (effective_until IS NULL OR effective_until > p_as_of_date)
      AND (tier_min_balance IS NULL OR tier_min_balance <= p_balance)
      AND (tier_max_balance IS NULL OR tier_max_balance >= p_balance)
    ORDER BY tier_sequence LIMIT 1;
    RETURN v_rate;
END; $$;

-- Get Tiered Rates (split balance across tiers)
CREATE OR REPLACE FUNCTION fn_get_tiered_rates(p_rate_code VARCHAR(30), p_balance DECIMAL(19,4), p_currency_code CHAR(3) DEFAULT 'USD', p_as_of_date DATE DEFAULT CURRENT_DATE)
RETURNS TABLE(tier_sequence INTEGER, rate_value DECIMAL(7,4), tier_min DECIMAL(19,4), tier_max DECIMAL(19,4), applicable_balance DECIMAL(19,4))
LANGUAGE plpgsql STABLE AS $$
DECLARE v_remaining DECIMAL(19,4) := p_balance; v_tier RECORD;
BEGIN
    FOR v_tier IN SELECT * FROM interest_rate_schedule
        WHERE rate_code = p_rate_code AND currency_code = p_currency_code
          AND effective_from <= p_as_of_date AND (effective_until IS NULL OR effective_until > p_as_of_date)
        ORDER BY tier_sequence
    LOOP
        IF v_remaining <= 0 THEN EXIT; END IF;
        tier_sequence := v_tier.tier_sequence; rate_value := v_tier.rate_value;
        tier_min := v_tier.tier_min_balance; tier_max := v_tier.tier_max_balance;
        IF v_tier.tier_max_balance IS NULL OR v_remaining <= (v_tier.tier_max_balance - COALESCE(v_tier.tier_min_balance, 0)) THEN
            applicable_balance := v_remaining;
        ELSE applicable_balance := v_tier.tier_max_balance - COALESCE(v_tier.tier_min_balance, 0);
        END IF;
        v_remaining := v_remaining - applicable_balance;
        RETURN NEXT;
    END LOOP;
END; $$;

-- Calculate Monthly Payment
CREATE OR REPLACE FUNCTION fn_calculate_monthly_payment(p_principal DECIMAL(19,4), p_annual_rate DECIMAL(7,4), p_term_months INTEGER)
RETURNS DECIMAL(19,4) LANGUAGE plpgsql IMMUTABLE AS $$
DECLARE v_monthly_rate DECIMAL(19,10); v_payment DECIMAL(19,4);
BEGIN
    IF p_term_months <= 0 THEN RETURN p_principal; END IF;
    v_monthly_rate := p_annual_rate / 12;
    IF v_monthly_rate = 0 THEN RETURN round_banker(p_principal / p_term_months, 4); END IF;
    v_payment := round_banker(p_principal * (v_monthly_rate * POWER(1 + v_monthly_rate, p_term_months)) / (POWER(1 + v_monthly_rate, p_term_months) - 1), 4);
    RETURN v_payment;
END; $$;
