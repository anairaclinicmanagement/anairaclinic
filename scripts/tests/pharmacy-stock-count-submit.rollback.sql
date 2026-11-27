-- Disposable-clinic rollback regression for pharmacy stock-count submission.
-- Required psql vars: clinic_id, store_id, batch_id, test_user_id.
-- Never run with PEHAL IDs or against the POS Local Server Docker DB.
\set ON_ERROR_STOP on
BEGIN;

SELECT set_config('anaira.test_clinic_id', :'clinic_id', true);
SELECT set_config('anaira.test_store_id', :'store_id', true);
SELECT set_config('anaira.test_batch_id', :'batch_id', true);
SELECT set_config('anaira.test_user_id', :'test_user_id', true);

SELECT set_config(
  'request.jwt.claims',
  json_build_object(
    'sub', :'test_user_id',
    'role', 'authenticated',
    'aal', 'aal2'
  )::text,
  true
);

CREATE TEMP TABLE _stock_count_test_before ON COMMIT DROP AS
SELECT quantity AS before_qty
FROM public.pharmacy_store_stock
WHERE clinic_id = current_setting('anaira.test_clinic_id')::uuid
  AND store_id = current_setting('anaira.test_store_id')::uuid
  AND batch_id = current_setting('anaira.test_batch_id')::uuid;

-- Hold the fixture row stable until the transaction is rolled back.
SELECT quantity
FROM public.pharmacy_store_stock
WHERE clinic_id = current_setting('anaira.test_clinic_id')::uuid
  AND store_id = current_setting('anaira.test_store_id')::uuid
  AND batch_id = current_setting('anaira.test_batch_id')::uuid
FOR UPDATE;

DO $$
BEGIN
  IF (SELECT count(*) FROM _stock_count_test_before) <> 1 THEN
    RAISE EXCEPTION 'Fixture error: expected exactly one matching store-stock row';
  END IF;
END
$$;

CREATE TEMP TABLE _stock_count_test_result ON COMMIT DROP AS
SELECT public.pharmacy_submit_store_stock_count(
  current_setting('anaira.test_clinic_id')::uuid,
  current_setting('anaira.test_store_id')::uuid,
  current_setting('anaira.test_batch_id')::uuid,
  (SELECT before_qty + 2 FROM _stock_count_test_before),
  'AUTOMATED ROLLBACK TEST - NO PATIENT DATA'
) AS payload;

DO $$
DECLARE
  v_id uuid;
  v_qty numeric;
  v_before numeric;
  v_after numeric;
  v_audit_count integer;
  v_status text;
BEGIN
  v_id := ((_stock_count_test_result.payload ->> 'id')::uuid);
  IF v_id IS NULL THEN
    RAISE EXCEPTION 'RPC did not return a count ID';
  END IF;

  SELECT before_qty INTO v_before FROM _stock_count_test_before;

  SELECT status INTO v_status
  FROM public.pharmacy_stock_counts
  WHERE id = v_id
    AND clinic_id = current_setting('anaira.test_clinic_id')::uuid;
  IF v_status IS DISTINCT FROM 'pending' THEN
    RAISE EXCEPTION 'Expected pending count; got %', v_status;
  END IF;

  SELECT physical_qty INTO v_qty
  FROM public.pharmacy_stock_count_items
  WHERE count_id = v_id
    AND clinic_id = current_setting('anaira.test_clinic_id')::uuid
    AND batch_id = current_setting('anaira.test_batch_id')::uuid;
  IF v_qty IS DISTINCT FROM (v_before + 2) THEN
    RAISE EXCEPTION 'Physical quantity mismatch. Expected %, got %', v_before + 2, v_qty;
  END IF;

  SELECT count(*) INTO v_audit_count
  FROM public.audit_logs
  WHERE clinic_id = current_setting('anaira.test_clinic_id')::uuid
    AND actor_user_id = current_setting('anaira.test_user_id')::uuid
    AND action = 'pharmacy_store_stock_count_submitted'
    AND entity_type = 'stock_count'
    AND entity_id = v_id::text;
  IF v_audit_count <> 1 THEN
    RAISE EXCEPTION 'Expected exactly one submission audit event; got %', v_audit_count;
  END IF;

  SELECT quantity INTO v_after
  FROM public.pharmacy_store_stock
  WHERE clinic_id = current_setting('anaira.test_clinic_id')::uuid
    AND store_id = current_setting('anaira.test_store_id')::uuid
    AND batch_id = current_setting('anaira.test_batch_id')::uuid;
  IF v_after IS DISTINCT FROM v_before THEN
    RAISE EXCEPTION 'Submission unexpectedly changed stock. Before %, after %', v_before, v_after;
  END IF;

  RAISE NOTICE 'PASS: pending count + item + one audit event; stock unchanged. Count ID: %', v_id;
END
$$;

ROLLBACK;
