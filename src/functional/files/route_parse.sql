--
-- pgwt.route_parse()
--

--------------------------------------------------------------------------------
CREATE FUNCTION pgwt.route_parse(
  IN path text,
	OUT regexp_path text,
  OUT params text[]
)
	LANGUAGE plpgsql
AS $$
DECLARE
  v_pkey text;
	v_pval text;
	v_path text = path;
	v_unknown_params text;

	v_elem text[];
BEGIN
	SELECT COALESCE(array_agg(r[1]), '{}')
    FROM regexp_matches(path, '\(\?<([a-z0-9\_-]+)>([^\)]+)\)', 'g') r
	  INTO STRICT params;

	regexp_path = regexp_replace('^'||path||'$', '\(\?<([a-z0-9\_-]+)>([^\)]+)\)', '(\2)', 'g');
END;
$$;
--------------------------------------------------------------------------------
