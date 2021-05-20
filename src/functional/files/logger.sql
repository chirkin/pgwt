--
-- pgwt.logger
--
-- Api requests logger
--

CREATE UNLOGGED TABLE pgwt.logger
(
  route_id text NOT NULL,
  lastmo timestamp with time zone NOT NULL,               -- last request timestamp
  count int NOT NULL,                                     -- total requests count
  runtime int NOT NULL,                                   -- last request execution time
  runtimemin int NOT NULL,                                -- mininum reqeuest execution time
  runtimemax int NOT NULL,                                -- maximum request execution time
  runtimeavg int NOT NULL,                                -- average request execution time
  successcount int NOT NULL,                              -- count of successfull executions
  errorscount int NOT NULL,                               -- count of unsuccessfull executions (internal server error)
  lasterror text,                                         -- last error diagnostics
  CONSTRAINT logger_pkey PRIMARY KEY (route_id)
);
