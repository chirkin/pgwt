--
-- pgwt.types
--

--------------------------------------------------------------------------------
CREATE TYPE pgwt.request_method AS ENUM (
  'GET', 'POST', 'PATCH', 'PUT', 'DELETE', 'OPTIONS'
);
--------------------------------------------------------------------------------
