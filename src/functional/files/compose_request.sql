--
-- pgwt.compose_request()
--

-------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION pgwt.compose_request(IN json, OUT _pgwt.request)
  LANGUAGE plpgsql
AS $function$
BEGIN
  $2.area = NULLIF($1->>'area', '');
  $2.host = NULLIF($1->>'host', '');
  $2.path = NULLIF($1->>'path', '/');
  $2.args = COALESCE($1->'args', '{}');
  $2.remote_addr = NULLIF($1->>'remote_addr', '');
  $2.remote_host = NULLIF($1->>'remote_host', '');
  $2.user_agent = NULLIF($1->'headers'->>'user-agent', '');
  $2.method = NULLIF($1->>'method', '');
  $2.server_host = NULLIF($1->>'server_host', '');
  $2.server_addr = NULLIF($1->>'server_addr', '');
  $2.headers = $1->'headers';
  $2.cookies = pgwt.cookie_parse($1->'headers'->>'cookie');
  $2.status = $1->>'status';
  $2.resp_headers = $1->'resp_headers';
  $2.body_bytes_sent = $1->>'body_bytes_sent';
  $2.request_completion = $1->>'request_completion';

  IF $2.area ISNULL THEN
    RAISE 'pgwt: compose_request: area is not defined';
  END IF;

  IF $2.host ISNULL THEN
    RAISE 'pgwt: compose_request: host is not defined';
  END IF;

  IF $2.path ISNULL THEN
    RAISE 'pgwt: compose_request: path is not defined';
  END IF;

  IF $2.remote_addr ISNULL THEN
    RAISE 'pgwt: compose_request: remote_addr is not defined';
  END IF;

  IF $2.method ISNULL THEN
    RAISE 'pgwt: compose_request: method is not defined';
  END IF;

  IF $2.server_host ISNULL THEN
    RAISE 'pgwt: compose_request: server_host is not defined';
  END IF;

  IF $2.server_addr ISNULL THEN
    RAISE 'pgwt: compose_request: server_addr is not defined';
  END IF;
END;
$function$;
-------------------------------------------------------------------------------
