--
-- pgwt
--

--------------------------------------------------------------------------------
CREATE SCHEMA pgwt AUTHORIZATION :"schema_owner";
REVOKE ALL ON SCHEMA pgwt FROM PUBLIC;
--------------------------------------------------------------------------------

SET LOCAL SESSION AUTHORIZATION :"schema_owner";

\ir files/func_attrs.sql
\ir files/init.sql
\ir files/types.sql
\ir files/assert.sql
\ir files/parse_proc_header.sql
\ir files/cookie_parse.sql
\ir files/compose_request.sql
\ir files/route_parse.sql
\ir files/error.sql
\ir files/http_error.sql
\ir files/raise.sql
\ir files/request_handler.sql
\ir files/request.sql
\ir files/logger.sql
\ir files/error_debug.sql
\ir files/errorlog/__deploy.sql

RESET SESSION AUTHORIZATION;
