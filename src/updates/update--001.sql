
CREATE EXTENSION IF NOT EXISTS hstore;

--------------------------------------------------------------------------------
CREATE SCHEMA _pgwt AUTHORIZATION :"schema_owner";
REVOKE ALL ON SCHEMA _pgwt FROM PUBLIC;
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
CREATE TABLE _pgwt.route (
	id text NOT NULL,
	nspname text NOT NULL,
	proname text NOT NULL,
  area text NOT NULL,
	nm text NOT NULL,
	comments text NOT NULL,
	params text[] NOT NULL,
	regexp_path text NOT NULL,
	func_attrs jsonb NOT NULL,
	custom_request_handler boolean NOT NULL DEFAULT false,
	custom_response_handler boolean NOT NULL DEFAULT false,
	CONSTRAINT route_pkey PRIMARY KEY (id),
  CONSTRAINT route_ukey0 UNIQUE (area, proname)
);
ALTER TABLE _pgwt.route OWNER TO :"schema_owner";
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
CREATE TYPE _pgwt.request AS (
	area text,
	host text,
	path text,
	args jsonb,
	remote_addr inet,
  remote_host text,
	user_agent text,
  cookies hstore,
	body json,
  body_raw text,
	params hstore,
	method text,
	server_host text,
	server_addr text,
	headers json,
	route _pgwt.route,
	custom jsonb,
  resp_headers json,
  status smallint,
	body_bytes_sent bigint,
  request_completion text
);
ALTER TYPE _pgwt.request OWNER TO :"schema_owner";
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
CREATE TYPE _pgwt.response AS (
  body text,  -- NULL = ''
	status int, -- NULL = 200
	headers jsonb,
  commands jsonb  -- system commands (interlal redirect, speed limit, etc.)
);
ALTER TYPE _pgwt.response OWNER TO :"schema_owner";
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
CREATE TABLE _pgwt.issue (
  id serial not null,
  nm text NOT NULL,
  error text NOT NULL,
  total_count int NOT NULL,
  firstmo timestamptz NOT NULL DEFAULT now(),
  lastmo timestamptz NOT NULL DEFAULT now(),
  last_diag jsonb NOT NULL,
  last_errorlog_id bigint NOT NULL,
  CONSTRAINT issue_pkey PRIMARY KEY (id),
  CONSTRAINT issue_ukey0 UNIQUE (nm, error)
);
ALTER TABLE _pgwt.issue OWNER TO :"schema_owner";
--------------------------------------------------------------------------------

-------------------------------------------------------------------------------
CREATE TABLE _pgwt.errorlog (
  id serial NOT NULL,
  mo timestamptz NOT NULL DEFAULT now(),
  issue_id int NOT NULL,
  uri text NOT NULL,
  request hstore NOT NULL,
  diag json NOT NULL,
  CONSTRAINT errorlog_pkey PRIMARY KEY (id),
  CONSTRAINT errorlog_fkey0 FOREIGN KEY (issue_id)
    REFERENCES _pgwt.issue (id)
);
ALTER TABLE _pgwt.errorlog OWNER TO :"schema_owner";
-------------------------------------------------------------------------------
