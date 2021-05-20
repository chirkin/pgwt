--------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION www_main.test1(IN _pgwt.request, OUT _pgwt.response)
  LANGUAGE plpgsql
AS $function$
--
-- Test1
--
-- uri: /test1
-- methods: GET
--
DECLARE

BEGIN
  $2.body = 'Current time: '||(current_time)::text;
END;
$function$;
--------------------------------------------------------------------------------
