--
-- pgwt.cookie_parse()
--

--------------------------------------------------------------------------------
CREATE FUNCTION pgwt.cookie_parse(text)
 RETURNS hstore
 LANGUAGE sql
 IMMUTABLE
AS $function$
--
-- Parse http cookie header
--
SELECT COALESCE(hstore(array_agg(r[1]), array_agg(r[2])), ''::hstore)
  FROM (
    SELECT regexp_matches(s, '^(.*)=(.*)$') r
      FROM regexp_split_to_table($1, '\s*;\s*') s
  ) foo;
$function$;
--------------------------------------------------------------------------------
