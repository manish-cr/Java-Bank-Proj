-- ============================================================================
-- fn_is_compounding_date
-- Returns TRUE if today is a compounding date for the given frequency
-- ============================================================================
CREATE OR REPLACE FUNCTION fn_is_compounding_date(
    p_frequency VARCHAR(10),
    p_current_date DATE DEFAULT CURRENT_DATE
)
RETURNS BOOLEAN
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
    v_last_day_of_month DATE;
    v_day INTEGER;
    v_month INTEGER;
BEGIN
    v_day := EXTRACT(DAY FROM p_current_date);
    v_month := EXTRACT(MONTH FROM p_current_date);

    -- Calculate last day of current month
    v_last_day_of_month := (DATE_TRUNC('MONTH', p_current_date) + INTERVAL '1 MONTH' - INTERVAL '1 DAY')::DATE;

    IF p_frequency = 'DAILY' THEN
        RETURN TRUE;
    ELSIF p_frequency = 'MONTHLY' THEN
        -- Is today the last day of the month?
        RETURN p_current_date = v_last_day_of_month;
    ELSIF p_frequency = 'QUARTERLY' THEN
        -- Is today the last day of March, June, September, or December?
        RETURN p_current_date = v_last_day_of_month AND v_month IN (3, 6, 9, 12);
    ELSIF p_frequency = 'SEMIANNUALLY' THEN
        -- Is today the last day of June or December?
        RETURN p_current_date = v_last_day_of_month AND v_month IN (6, 12);
    ELSIF p_frequency = 'ANNUALLY' THEN
        -- Is today the last day of December?
        RETURN p_current_date = v_last_day_of_month AND v_month = 12;
    ELSE
        RETURN FALSE;
    END IF;
END;
$$;

-- Test
SELECT fn_is_compounding_date('MONTHLY');       -- True only if today is last day of month
SELECT fn_is_compounding_date('DAILY');          -- Always true
SELECT fn_is_compounding_date('QUARTERLY');      -- True on Mar 31, Jun 30, Sep 30, Dec 31
SELECT fn_is_compounding_date('ANNUALLY');       -- True only on Dec 31