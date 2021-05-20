--
-- Additional api functions attributes
--

CREATE TABLE pgwt.func_attrs (
  nm text NOT NULL,
  mandatory boolean NOT NULL DEFAULT false,
  multiple boolean NOT NULL DEFAULT false,
  acceptable_values text[] NOT NULL DEFAULT '{}'::text[],
  conflicts text[] NOT NULL DEFAULT '{}'::text[],
  CONSTRAINT func_attrs_pkey PRIMARY KEY (nm)
);

INSERT INTO pgwt.func_attrs
  (nm, mandatory, multiple, acceptable_values, conflicts) VALUES

  ('uri', true, false, default, default),
  ('methods', true, true, array['GET', 'POST', 'PATCH', 'PUT', 'DELETE', 'OPTIONS', 'HEAD'], default),
  ('raw_error', false, false, default, default),
  ('logwrite', false, false, default, default),
  ('logwrite_hidebody', false, false, default, default),
  ('raw_body', false, false, default, default);
