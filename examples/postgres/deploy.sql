\set schema_owner postgres

\set pgver_schema pgwt
\cd /mnt/pgwt
\i pgver.sql

\set pgver_schema data
\cd /mnt/data
\i pgver.sql
