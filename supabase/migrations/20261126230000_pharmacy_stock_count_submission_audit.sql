-- Add an audit event when a store stock count is submitted.
-- Additive function replacement; no table/data deletion or backfill.
-- Preserves existing AAL2, clinic-role, store, batch and quantity validations.
-- Runtime verification must be performed with isolated NH3/Raghunath test data
-- before this migration is approved for production.

CREATE OR REPLACE FUNCTION public.pharmacy_submit_store_stock_count(
  p_clinic_id uuid,
  p_store_id uuid,
  p_batch_id uuid,
  p_physical_qty numeric,
  p_notes text DEFAULT NULL::text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  u uuid := auth.uid();
  q numeric;
  cid uuid := gen_random_uuid();
  n text;
  med uuid;
BEGIN
  IF (auth.jwt() ->> 'aal') IS DISTINCT FROM 'aal2' THEN
    RAISE EXCEPTION 'MFA verification required' USING ERRCODE = '42501';
  END IF;

  IF u IS NULL OR NOT private.has_clinic_role(
    p_clinic_id,
    ARRAY['owner','admin','pharmacist']
  ) THEN
    RAISE EXCEPTION 'Stock count permission required';
  END IF;

  IF p_physical_qty < 0 OR NOT EXISTS (
    SELECT 1
    FROM public.pharmacy_stores
    WHERE id = p_store_id
      AND clinic_id = p_clinic_id
      AND active
  ) THEN
    RAISE EXCEPTION 'Invalid physical quantity or store';
  END IF;

  SELECT ss.quantity, ss.medication_id
    INTO q, med
  FROM public.pharmacy_store_stock ss
  WHERE ss.clinic_id = p_clinic_id
    AND ss.store_id = p_store_id
    AND ss.batch_id = p_batch_id
  FOR UPDATE;

  IF q IS NULL THEN
    RAISE EXCEPTION 'Batch is not stocked in selected store';
  END IF;

  n := 'CNT-' || upper(substr(replace(cid::text, '-', ''), 1, 10));

  INSERT INTO public.pharmacy_stock_counts(
    id, clinic_id, count_no, store_id, status, counted_by, notes
  )
  VALUES (
    cid, p_clinic_id, n, p_store_id, 'pending', u, p_notes
  );

  INSERT INTO public.pharmacy_stock_count_items(
    clinic_id, count_id, batch_id, system_qty, physical_qty
  )
  VALUES (
    p_clinic_id, cid, p_batch_id, q, p_physical_qty
  );

  -- Keep the submission event in the same transaction as the count records.
  -- Do not copy free-text notes into the audit payload.
  INSERT INTO public.audit_logs(
    clinic_id, actor_user_id, action, entity_type, entity_id, details
  )
  VALUES (
    p_clinic_id,
    u,
    'pharmacy_store_stock_count_submitted',
    'stock_count',
    cid::text,
    jsonb_build_object(
      'count_no', n,
      'store_id', p_store_id,
      'batch_id', p_batch_id,
      'system_qty', q,
      'physical_qty', p_physical_qty,
      'variance', p_physical_qty - q
    )
  );

  RETURN jsonb_build_object(
    'id', cid,
    'count_no', n,
    'system_qty', q,
    'physical_qty', p_physical_qty,
    'variance', p_physical_qty - q
  );
END
$function$;
