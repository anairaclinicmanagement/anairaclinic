import fs from 'node:fs';
import path from 'node:path';
const file = path.resolve('supabase/migrations/20261126210000_phase0c_security_definer_acl_hardening.sql');
const sql = fs.readFileSync(file, 'utf8');
const expectedRpc = [
  'create_pharmacy_purchase_return_from_store',
  'dispense_pharmacy_sale_discounted_from_store',
  'dispense_pharmacy_sale_for_admission_from_store',
  'dispense_pharmacy_sale_from_store',
  'pharmacy_approve_store_stock_count',
  'pharmacy_decide_sales_return_to_store',
  'pharmacy_submit_store_stock_count',
  'receive_pharmacy_grn_to_store',
];
const expectedTriggers = [
  'pharmacy_assign_payment_shift',
  'pharmacy_assign_refund_shift',
  'pharmacy_sync_batch_quantity_to_main_store',
  'prevent_ipd_bed_double_allocation',
  'release_ipd_room_allocation_beds_on_admission_change',
  'validate_ipd_admission_package_scope',
];
const missing = [...expectedRpc, ...expectedTriggers].filter((name) => !sql.includes(name));
const safeDynamicLookup = sql.includes('r.oid::regprocedure');
const exactCountGuards = sql.includes('v_rpc_count <> cardinality(v_rpc)') && sql.includes('v_trigger_count <> cardinality(v_trigger)');
const searchPathPinned = sql.includes("alter function public.validate_ipd_admission_package_scope() set search_path = '';");
if (missing.length || !safeDynamicLookup || !exactCountGuards || !searchPathPinned || /\b(drop|delete)\s+/i.test(sql)) {
  console.error({ missing, safeDynamicLookup, exactCountGuards, searchPathPinned });
  process.exit(1);
}
console.log('PASS: function OIDs resolved dynamically; 8 RPC + 6 trigger targets guarded; no DROP/DELETE.');
