--
-- pgwt.error()
--
-- Throws exception with specific code "P1001", that means user-level error.
-- Error message should be returned from response.
--

--------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION pgwt.error(a_msg text, a_code text DEFAULT null)
  RETURNS boolean
  LANGUAGE plpgsql
AS $$
--
-- Throw error
--
BEGIN
  PERFORM pgwt.assert(NULLIF(a_msg, '') NOTNULL, 'Null argument');

  RAISE '%', a_msg
    USING errcode = 'P1001',
          hint = COALESCE(a_code, '');
END;
$$;
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION pgwt.error(a_cond boolean, a_msg text, a_code text DEFAULT null)
  RETURNS boolean
  LANGUAGE plpgsql
AS $$
--
-- Throw error if condition = true
--
BEGIN
  PERFORM pgwt.assert(
    a_cond NOTNULL AND NULLIF(a_msg, '') NOTNULL,
    'Null argument'
  );

	IF (a_cond) THEN
    RAISE '%', a_msg
      USING errcode = 'P1001',
            hint = COALESCE(a_code, '');
  ELSE
    RETURN true;
  END IF;
END;
$$;
--------------------------------------------------------------------------------
