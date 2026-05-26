-- ============================================================================
-- fn_days_in_year: Returns 365 or 366 for a given date's year
-- ============================================================================
CREATE OR REPLACE FUNCTION fn_days_in_year(p_date DATE)
RETURNS INTEGER
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
    year_val INTEGER;
BEGIN
    year_val := EXTRACT(YEAR FROM p_date);
    -- Leap year: divisible by 4, but not by 100 unless also divisible by 400
    IF (year_val % 4 = 0 AND year_val % 100 != 0) OR (year_val % 400 = 0) THEN
        RETURN 366;
    ELSE
        RETURN 365;
    END IF;
END;
$$;

-- Test
SELECT fn_days_in_year('2025-06-01'); -- 365 (not leap year)
SELECT fn_days_in_year('2024-06-01'); -- 366 (leap year)
SELECT fn_days_in_year('2028-06-01'); -- 366 (leap year)