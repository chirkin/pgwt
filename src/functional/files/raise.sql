--
-- pgwt.raise()
--

--------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION pgwt.raise(a_msg text)
  RETURNS boolean
  LANGUAGE plpgsql
AS $$
--
-- Raise exception visible in response body
--
BEGIN
  PERFORM pgwt.assert(NULLIF(a_msg, '') NOTNULL, 'Null argument');

  RAISE '%', json_build_object('message', a_msg)
    USING errcode = 'P4000';
END;
$$;
--------------------------------------------------------------------------------
