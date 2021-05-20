--
-- Public www api
--

--------------------------------------------------------------------------------
CREATE SCHEMA www_main AUTHORIZATION :schema_owner;
COMMENT ON SCHEMA www_main IS 'Public www api';
--------------------------------------------------------------------------------

CREATE TABLE www_main.func_attrs() INHERITS (pgwt.func_attrs);

SET LOCAL SESSION AUTHORIZATION :schema_owner;

\ir index.sql
\ir test1.sql
\ir test2.sql

RESET SESSION AUTHORIZATION;
