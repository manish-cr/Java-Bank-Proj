-- ============================================================================
-- round_banker: Banker's Rounding (Round Half to Even)
-- ============================================================================
CREATE OR REPLACE FUNCTION round_banker(value DECIMAL, decimals INTEGER DEFAULT 4)
RETURNS DECIMAL
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
    multiplier DECIMAL;
    scaled DECIMAL;
    integer_part BIGINT;
    fractional_part DECIMAL;
BEGIN
    IF value IS NULL THEN
        RETURN NULL;
    END IF;

    multiplier := POWER(10, decimals)::DECIMAL;
    scaled := value * multiplier;
    integer_part := FLOOR(scaled)::BIGINT;
    fractional_part := scaled - integer_part;

    IF fractional_part < 0.5 THEN
        RETURN FLOOR(scaled) / multiplier;
    ELSIF fractional_part > 0.5 THEN
        RETURN CEIL(scaled) / multiplier;
    ELSE
        -- Exactly 0.5: round to even
        IF MOD(integer_part, 2) = 0 THEN
            RETURN integer_part / multiplier;
        ELSE
            RETURN (integer_part + 1) / multiplier;
        END IF;
    END IF;
END;
$$;

-- Quick test
SELECT round_banker(0.02735, 4); -- Expected: 0.0274 (3 is odd, round up)
SELECT round_banker(0.02745, 4); -- Expected: 0.0274 (4 is even, round down)
SELECT round_banker(0.02725, 4); -- Expected: 0.0272 (2 is even, round down)
SELECT round_banker(0.02755, 4); -- Expected: 0.0276 (5 is odd, round up)