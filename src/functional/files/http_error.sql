--
-- pgwt.http_error()
--

--------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION pgwt.http_error(
  a_status int, a_msg text, a_raw_error boolean DEFAULT false
)
  RETURNS boolean
  LANGUAGE plpgsql
AS $$
--
-- Generate http error
--
BEGIN
  PERFORM pgwt.assert(a_status NOTNULL AND NULLIF(a_msg, '') NOTNULL, 'Null argument');
  PERFORM pgwt.assert(a_status >= 400 AND a_status < 600);

  RAISE '%', json_build_object('message', a_msg)
    USING errcode = CASE WHEN a_raw_error THEN 'P3' ELSE 'P2' END||a_status::text;
END;
$$;
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION pgwt.http_error(
  a_status int, a_msg json, a_raw_error boolean DEFAULT false
)
  RETURNS boolean
  LANGUAGE plpgsql
AS $$
--
-- Generate http error
--
BEGIN
  PERFORM pgwt.assert(a_status NOTNULL, 'Null argument');
  PERFORM pgwt.assert(a_status >= 400 AND a_status < 600);

  RAISE '%', a_msg
    USING errcode = CASE WHEN a_raw_error THEN 'P3' ELSE 'P2' END||a_status::text;
END;
$$;
--------------------------------------------------------------------------------
