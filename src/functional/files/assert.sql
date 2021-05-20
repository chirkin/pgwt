--
-- pgwt.assert()
--

--------------------------------------------------------------------------------
CREATE FUNCTION pgwt.assert(
  a_cond boolean DEFAULT false,
	a_msg text DEFAULT 'Assertion failed'
)
  RETURNS boolean
  LANGUAGE plpgsql
AS $$
--
-- Check that a_cond = true, raise if false
--
BEGIN
  IF (a_cond ISNULL OR a_msg ISNULL) THEN
	  RAISE 'Null argument';
	END IF;

	IF (NOT a_cond) THEN
    RAISE '%', a_msg;
  ELSE
    RETURN TRUE;
  END IF;
END;
$$;
--------------------------------------------------------------------------------
