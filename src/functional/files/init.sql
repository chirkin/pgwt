
--------------------------------------------------------------------------------
CREATE FUNCTION pgwt.init()
	RETURNS void
	LANGUAGE plpgsql
AS $function$
--
-- Initialize pgwt routes.
--
DECLARE
	v_proc record;
	v_header record;
	v_parsed_path record;

	v_func_attrs jsonb NOT NULL = '{}'::jsonb;
	v_custom_request_handler boolean;
	v_custom_response_handler boolean;

	v_attr record;
	v_attr_key text;
	v_attr_val jsonb;

	v_allowed_attrs jsonb;
BEGIN
	DROP RULE IF EXISTS i ON _pgwt.route;
	DROP RULE IF EXISTS u ON _pgwt.route;
	DROP RULE IF EXISTS d ON _pgwt.route;
	TRUNCATE _pgwt.route;

  FOR v_proc IN
    SELECT nspname||'.'||proname AS fullname, nspname, proname, prosrc,
					 (regexp_matches(n.nspname, '^www_(\w+)$'))[1] AS area
			FROM pg_catalog.pg_proc p
      JOIN pg_catalog.pg_namespace n ON n.oid = p.pronamespace
			LEFT JOIN pg_catalog.pg_description d ON p.oid = d.objoid
			WHERE n.nspname ~ '^www_(\w+)$'
				AND NOT p.proname ~ '^_'
	LOOP
		v_header = pgwt.parse_proc_header(v_proc.prosrc);

		IF EXISTS(
		  SELECT FROM information_schema.tables
		   	WHERE table_schema = 'www_'||v_proc.area
		   		AND table_name = 'func_attrs'
		) THEN
			EXECUTE format(
				'SELECT jsonb_object_agg(p.nm, row_to_json(p))
					FROM (
						TABLE pgwt.func_attrs UNION TABLE %I.func_attrs
					) p
				', 'www_'||v_proc.area, v_proc.proname
			) INTO v_allowed_attrs;
		END IF;

		-- check all mandatory attributes in function definition
		FOR v_attr IN
			SELECT (p).*
				FROM jsonb_each(v_allowed_attrs) p
				WHERE p.value->'mandatory' = 'true'::jsonb
		LOOP
			IF NOT v_header.attrs ? v_attr.key THEN
				RAISE 'pgwt: Missing mandatory attribute "%" in api function "%"', v_attr.key, v_proc.fullname;
			END IF;
		END LOOP;

		SELECT jsonb_object_agg(
			key,
			CASE WHEN v_allowed_attrs->key->'multiple' = 'true'::jsonb
					 THEN to_jsonb(regexp_split_to_array(value, '\s*,\s*'))
					 ELSE to_jsonb(value)
			END
		)
		FROM each(v_header.attrs)
		INTO v_func_attrs;

		FOR v_attr_key, v_attr_val IN SELECT key, value FROM jsonb_each(v_func_attrs)
		LOOP
			-- check that function attribute is allowed
			IF NOT v_allowed_attrs ? v_attr_key THEN
				RAISE 'pgwt: Unknown attribute "%" in api function "%"', v_attr_key, v_proc.fullname;
			END IF;

			-- if attribute has acceptable values
			IF jsonb_array_length(v_allowed_attrs->v_attr_key->'acceptable_values') > 0 THEN
				-- check if value of attribute is acceptable
				IF NOT v_allowed_attrs->v_attr_key->'acceptable_values' @> v_attr_val
				THEN
					RAISE 'pgwt: Value "%" of attribute "%" in api function "%" not acceptable', v_attr_val, v_attr_key, v_proc.fullname;
				END IF;
			END IF;

			-- check conflicted attributes
			IF jsonb_array_length(v_allowed_attrs->v_attr_key->'conflicts') > 0 THEN
				DECLARE
					v_key text;
				BEGIN
					FOR v_key IN SELECT jsonb_array_elements_text(v_allowed_attrs->v_attr_key->'conflicts')
					LOOP
						IF v_header.attrs ? v_key THEN
							RAISE 'pgwt: Attribute "%" should not specified with attribute "%" in function "%"', v_attr_key, v_key, v_proc.fullname;
						END IF;
					END LOOP;
				END;
			END IF;
		END LOOP;

		v_parsed_path = pgwt.route_parse(v_header.attrs->'uri');

		v_custom_request_handler = EXISTS(
			SELECT
				FROM pg_catalog.pg_proc p
	      JOIN pg_catalog.pg_namespace n ON n.oid = p.pronamespace
				WHERE n.nspname = v_proc.nspname
					AND p.proname = '_request_handler'
		);

		v_custom_response_handler = EXISTS(
			SELECT
				FROM pg_catalog.pg_proc p
	      JOIN pg_catalog.pg_namespace n ON n.oid = p.pronamespace
				WHERE n.nspname = v_proc.nspname
					AND p.proname = '_response_handler'
		);

		INSERT INTO _pgwt.route (
			id, nspname, proname, area, nm, comments, params, regexp_path, func_attrs,
			custom_request_handler, custom_response_handler
		) VALUES (
			v_proc.fullname, v_proc.nspname, v_proc.proname, v_proc.area,
			v_header.title, v_header.comments, v_parsed_path.params,
			v_parsed_path.regexp_path, v_func_attrs, v_custom_request_handler,
			v_custom_response_handler
		);
	END LOOP;

	CREATE RULE i AS ON INSERT TO _pgwt.route DO INSTEAD NOTHING;
	CREATE RULE u AS ON UPDATE TO _pgwt.route DO INSTEAD NOTHING;
	CREATE RULE d AS ON DELETE TO _pgwt.route DO INSTEAD NOTHING;
END;
$function$;
--------------------------------------------------------------------------------
