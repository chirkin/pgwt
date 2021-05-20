
-------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION pgwt.error_debug(
  a_errorlog_id bigint,
  a_isolated boolean DEFAULT true
)
  RETURNS void
  LANGUAGE plpgsql
AS $function$
DECLARE
  v_errorlog record;
  v_request _pgwt.request;
  v_response _pgwt.response;
BEGIN
  SELECT id, request INTO v_errorlog
    FROM _pgwt.errorlog l
    WHERE id = $1;
  --
  IF NOT found THEN
    RAISE 'Error #% not found', $1;
  END IF;
  v_request = populate_record(v_request, v_errorlog.request);

  -- execute area request handler
  EXECUTE 'SELECT (r).* FROM '||quote_ident('www_'||v_request.area)||'._request_handler($1) r'
    INTO v_response
    USING v_request;

  IF $2 THEN
    RAISE 'SUCCESS'
      USING DETAIL = jsonb_pretty(row_to_json(v_response)::jsonb);
  ELSE
    RAISE INFO 'SUCCESS';
  END IF;
END;
$function$;
-------------------------------------------------------------------------------
