
--------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION www_main.test2(IN _pgwt.request, OUT _pgwt.response)
  LANGUAGE plpgsql
AS $function$
--
-- Test2
--
-- uri: /test2
-- methods: GET
--
DECLARE

BEGIN
  $2.body = jsonb_pretty(row_to_json($1)::jsonb)::text;
END;
$function$;
--------------------------------------------------------------------------------
