--
-- pgver / Simple PostgreSQL schema versioning tool
--
-- Version: 1.0.6
-- Author: Aleksey Chirkin.
--

\set ON_ERROR_STOP
\set pgver_schema :pgver_schema

CREATE OR REPLACE FUNCTION __pgver_assert__(boolean, text) RETURNS void LANGUAGE plpgsql
AS $$ BEGIN IF NOT $1 THEN RAISE '%', $2; END IF; END; $$;

SELECT __pgver_assert__(:'pgver_schema' <> ':pgver_schema', 'You need to specify "pgver_schema" variable');

CREATE TEMP TABLE __pgver_shell_log__ (line text);
-- check that we are in the right directory, use "\copy" becouse "\! exit 1" not stops script execution
\copy __pgver_shell_log__ from program 'test -d functional # directory not found, please run this script inside your scripts directory'
\copy __pgver_shell_log__ from program 'test -d updates # directory not found, please run this script inside your scripts directory'
DROP TABLE __pgver_shell_log__;

SELECT EXISTS (SELECT * FROM pg_catalog.pg_namespace WHERE nspname = :'pgver_schema') AS pgver_schema_exists \gset

CREATE TEMP TABLE __pgver_folder_md5sum__ (value text) ON COMMIT DROP;
\copy __pgver_folder_md5sum__ from program 'find . -type f -exec md5sum {} \; | sort -k 2 | md5sum | cut -c 1-32'
SELECT value AS __pgver_folder_md5sum__ FROM __pgver_folder_md5sum__ \gset
DROP TABLE __pgver_folder_md5sum__;

SELECT COALESCE(split_part(schema_descr, '|', 1), '') AS __pgver_version_md5__,
       COALESCE(NULLIF(split_part(schema_descr, '|', 2), ''), '0') AS __pgver_version_num__
  FROM (
    SELECT replace(pg_catalog.obj_description(oid, 'pg_namespace'), 'PGVER_', '') AS schema_descr
      FROM pg_catalog.pg_namespace
      WHERE nspname = :'pgver_schema'
        AND pg_catalog.obj_description(oid, 'pg_namespace') LIKE 'PGVER_%'
    UNION ALL
    SELECT ''
    LIMIT 1
  ) foo \gset

SELECT :'__pgver_folder_md5sum__' IS NOT DISTINCT FROM :'__pgver_version_md5__' AS quit \gset

SELECT __pgver_assert__(
  NOT EXISTS (SELECT * FROM pg_catalog.pg_namespace WHERE nspname = :'pgver_schema') OR
  nullif(:'__pgver_version_md5__', '') NOTNULL,
  'pgver_schema exists, but not contains "PGVER_" marker, to prevent unwanted modification of existing data, please choose another schema or drop current'
);

\if :quit
-- scripts not changed from last deployment, exit
DROP FUNCTION __pgver_assert__(boolean, text);
\echo unchanged
\q
\endif

CREATE TEMP TABLE __pgver_update_files__ (filename text NOT NULL);
\copy __pgver_update_files__ from program 'find ./updates -type f'

-- find missing updates
SELECT true AS __pgver_missing_update__,
       row_number AS __pgver_missing_update_num__
  FROM (
    SELECT version, row_number() OVER ()
      FROM (
        SELECT (regexp_match(filename, '/update--(\d+)\.sql$'))[1]::int AS version
          FROM __pgver_update_files__
          WHERE filename ~ '/update--\d+.sql$'
          ORDER BY version
      ) AS foo1
  ) foo2
  WHERE version IS DISTINCT FROM row_number
UNION ALL
SELECT false, NULL
LIMIT 1 \gset

\if :__pgver_missing_update__
SELECT __pgver_assert__(false, 'MISSING UPDATE NUMBER '||:'__pgver_missing_update_num__');
\endif

\i ./functional/__drop.sql

CREATE TEMP TABLE __pgver_new_update_files__ AS
  SELECT filename
    FROM (
      SELECT filename, (regexp_match(filename, '/update--(\d+)\.sql$'))[1]::int AS version
        FROM __pgver_update_files__
        WHERE filename ~ '/update--\d+.sql$'
    ) AS foo
    WHERE version > (:'__pgver_version_num__')::int
    ORDER BY version;

DROP TABLE __pgver_update_files__;

-- compose all new updates into single file
\copy __pgver_new_update_files__ to program 'xargs -n 1 cat > .__pgver_updates.sql'
\i ./.__pgver_updates.sql
\! rm ./.__pgver_updates.sql

\i ./functional/__deploy.sql
SELECT 'PGVER_'||:'__pgver_folder_md5sum__'||'|'||version AS __pgver_schema_descr__
  FROM (
    SELECT ((regexp_match(filename, '/update--(\d+)\.sql$'))[1])::int AS version
      FROM __pgver_new_update_files__
    UNION ALL
    SELECT (:'__pgver_version_num__')::int
  ) AS foo
  ORDER BY version DESC
  LIMIT 1 \gset

DROP TABLE __pgver_new_update_files__;

COMMENT ON SCHEMA :"pgver_schema" IS :'__pgver_schema_descr__';

DROP FUNCTION __pgver_assert__(boolean, text);

\echo changed
