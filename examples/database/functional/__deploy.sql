CREATE SCHEMA data AUTHORIZATION :"schema_owner";

\ir www_main/__deploy.sql

SELECT pgwt.init();
