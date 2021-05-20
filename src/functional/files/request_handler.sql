
--------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION pgwt.request_handler(
  IN _pgwt.request, OUT _pgwt.response
)
 LANGUAGE plpgsql
AS $function$
--
-- Default request handler
--
BEGIN
  -- call api function
  EXECUTE 'SELECT (r).* FROM '
    ||quote_ident('www_'||$1.area)||'.'
    ||quote_ident($1.route.proname)||'($1) r'
    INTO $2
    USING $1;
END;
$function$;
--------------------------------------------------------------------------------
