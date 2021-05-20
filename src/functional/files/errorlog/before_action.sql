
-------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION pgwt.errorlog_before_action()
  RETURNS trigger
  LANGUAGE plpgsql
AS $function$
DECLARE
  v_issue_id int;
BEGIN
  INSERT INTO _pgwt.issue AS i (
    nm, error, total_count, last_diag, last_errorlog_id
  ) VALUES (
    COALESCE(NEW.diag->'request'->'route'->>'id', 'undefined'),
    COALESCE(NEW.diag->>'message', 'undefined'),
    1,
    NEW.diag::jsonb,
    NEW.id
  )
  ON CONFLICT ON CONSTRAINT issue_ukey0 DO UPDATE
    SET total_count = i.total_count + 1,
        lastmo = now(),
        last_diag = EXCLUDED.last_diag,
        last_errorlog_id = EXCLUDED.last_errorlog_id
  RETURNING id INTO v_issue_id;

  NEW.issue_id = v_issue_id;

  RETURN NEW;
END;
$function$;
-------------------------------------------------------------------------------
