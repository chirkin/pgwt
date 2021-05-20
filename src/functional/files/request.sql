--
-- pgwt.request()
--

--------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION pgwt.request(
	IN a_request json,
  IN a_request_body text,
	OUT status int,
	OUT body text,
	OUT headers json,
  OUT commands json,
  OUT int_headers json,
	OUT diag json
)
  LANGUAGE plpgsql
	SECURITY DEFINER
AS $$
--
-- PGWT request entrypoint
--
DECLARE
  a_debug boolean = false;
  a_test boolean = false;

	v_request _pgwt.request;
	v_response _pgwt.response;
	v_route _pgwt.route;

	-- do not wrap up error into json
	v_raw_error boolean NOT NULL = false;
	v_runtime int;

	-- error vars:
  e_code text;
  e_hint text;
	v_error json;
	v_message jsonb;

  -- diag vars:
  d_sqlstate text;
  d_hint text;
  d_message text;
  d_detail text;
  d_context text;

	v_request_mo timestamp;
BEGIN
	-- do lock for successfull db redeployment
	PERFORM pg_advisory_xact_lock_shared(0, 0);

	v_request = pgwt.compose_request(a_request);
  a_debug = v_request.cookies ? 'DEBUG';

	<<internal>>
	BEGIN
		IF v_request.method = 'OPTIONS' THEN
	  	EXIT internal;
	  END IF;

		SELECT * INTO v_route
			FROM _pgwt.route r
			WHERE r.area = v_request.area
				AND '/'||v_request.path ~* r.regexp_path
				AND r.func_attrs->'methods' @> to_jsonb(v_request.method)
			LIMIT 1;
		--
		IF NOT found THEN
			PERFORM pgwt.http_error(404, 'Route not found');
		END IF;

		IF v_request.method <> 'GET' THEN
			IF v_route.func_attrs->>'raw_body' = 'true' THEN
				v_request.body_raw = a_request_body;
			ELSE
				BEGIN
					v_request.body = a_request_body;
				EXCEPTION WHEN invalid_text_representation THEN
					v_request.body_raw = a_request_body;
				END;
			END IF;
		END IF;

		v_request.route = v_route;

		IF v_route.params <> '{}'::text[]
		THEN
		 	SELECT hstore(v_route.params, r) INTO v_request.params
	      FROM regexp_matches('/'||v_request.path, v_route.regexp_path, 'g') r;
		END IF;

		IF v_route.custom_request_handler THEN
			-- execute custom request handler
			EXECUTE 'SELECT (r).* FROM '||quote_ident('www_'||v_request.area)||'._request_handler($1) r'
				INTO v_response
				USING v_request;
		ELSE
			-- execute default request handler
			EXECUTE 'SELECT (r).* FROM pgwt.request_handler($1) r'
				INTO v_response
				USING v_request;
		END IF;

	EXCEPTION
	  WHEN OTHERS THEN
		  GET STACKED DIAGNOSTICS d_sqlstate = RETURNED_SQLSTATE,
	                            d_message = MESSAGE_TEXT,
	                            d_hint = PG_EXCEPTION_HINT,
	                            d_detail = PG_EXCEPTION_DETAIL,
	                            d_context = PG_EXCEPTION_CONTEXT;

  		IF d_sqlstate = 'P1001' THEN
	  		-- pgwt.error
        v_response.status = 400;

			  v_message = json_build_object(
					'message', d_message,
					'code', COALESCE(NULLIF(d_hint, ''), 'error')
				);
      ELSIF d_sqlstate ~ '^P2' THEN
        -- pgwt.http_error

        v_response.status = substring(d_sqlstate from 3 for 3)::int;
        v_message = d_message;

			ELSIF d_sqlstate ~ '^P3' THEN
        -- pgwt.http_error raw

        v_response.status = substring(d_sqlstate from 3 for 3)::int;
        v_message = d_message;
				v_raw_error = true;

			ELSIF d_sqlstate = 'P4000' THEN
				-- pgwt.raise

				v_response.status = 500;
				v_message = d_message;

				diag = '{}';	-- need to set diag
		  ELSE
		    -- RAISE

				v_response.status = 500;
				v_message = jsonb_build_object('message', 'Internal server error');

				diag = '{}';	-- need to set diag
		  END IF;


			IF diag NOTNULL THEN
				diag = jsonb_pretty(jsonb_build_object(
					'hint', d_hint,
					'sqlstate', d_sqlstate,
				 	'message', d_message,
				 	'detail', d_detail,
				 	'context', d_context,
				 	'request', row_to_json(v_request)
				));
			END IF;

			IF (v_request.route).id NOTNULL AND (v_request.route).func_attrs ? 'raw_error'
			THEN
				v_raw_error = true;
			END IF;

			IF a_debug AND diag NOTNULL THEN
				v_message = jsonb_set(v_message::jsonb, '{diag}', diag::jsonb);
			END IF;

			IF NOT v_raw_error OR a_debug
			THEN
				-- client wants to get errors in json format
  	    v_response.body = jsonb_pretty(v_message);

				v_response.headers = json_build_object(
					'Content-Type', 'application/javascript'
				);
			ELSE
				v_response.body = '';
				v_response.commands = json_build_object(
					'error', v_message
				);

				v_response.headers = json_build_object(
					'Content-Type', 'text/html'
				);
			END IF;

			IF d_sqlstate !~ ALL (ARRAY['P1001','^P2','^P3']) THEN
				INSERT INTO _pgwt.errorlog (uri, diag, request) VALUES (v_request.path, diag, hstore(v_request));
			END IF;

			-- set diag to null because error already logged
			diag = null;
	END;

	IF v_route.custom_response_handler THEN
		-- execute custom area response handler
		EXECUTE 'SELECT (r).* FROM '||quote_ident('www_'||v_request.area)||'._response_handler($1, $2) r'
			INTO v_response
			USING v_request, v_response;
	END IF;

	status = COALESCE(v_response.status, 200);
	body = COALESCE(v_response.body, '');
	headers = v_response.headers;
	commands = v_response.commands;

	v_runtime = EXTRACT(MILLISECONDS FROM (clock_timestamp() - now()))::int;

	IF v_route.id NOTNULL THEN
		INSERT INTO pgwt.logger as l (
				route_id, lastmo, count, runtime, runtimemin, runtimemax, runtimeavg,
				successcount, errorscount, lasterror
			)
			VALUES (
				v_route.id, now(), 1, v_runtime, v_runtime, v_runtime, v_runtime,
				CASE WHEN status < 500 THEN 1 ELSE 0 END,
				CASE WHEN status >= 500 THEN 1 ELSE 0 END,
				CASE WHEN status >= 500 THEN diag ELSE NULL END
			)
			ON CONFLICT ON CONSTRAINT logger_pkey DO UPDATE
				SET lastmo = EXCLUDED.lastmo,
						count = l.count + 1,
						runtime = EXCLUDED.runtime,
						runtimemin = CASE WHEN l.runtimemin > EXCLUDED.runtime THEN EXCLUDED.runtime ELSE l.runtimemin END,
						runtimemax = CASE WHEN l.runtimemax < EXCLUDED.runtime THEN EXCLUDED.runtime ELSE l.runtimemax END,
						runtimeavg = (l.runtimeavg::bigint * l.count + EXCLUDED.runtime) / (l.count + 1),
						successcount = l.successcount + EXCLUDED.successcount,
						errorscount = l.errorscount + EXCLUDED.errorscount,
						lasterror = EXCLUDED.lasterror;
	END IF;
END;
$$;
--------------------------------------------------------------------------------
