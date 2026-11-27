import fs from 'node:fs';

const migrationPath = new URL('../supabase/migrations/20261126230000_pharmacy_stock_count_submission_audit.sql', import.meta.url);
const sql = fs.readFileSync(migrationPath, 'utf8');

const required = [
  'CREATE OR REPLACE FUNCTION public.pharmacy_submit_store_stock_count',
  "IS DISTINCT FROM 'aal2'",
  "ARRAY['owner','admin','pharmacist']",
  "status, counted_by, notes",
  'FOR UPDATE',
  "'pharmacy_store_stock_count_submitted'",
  "'stock_count'",
  "'system_qty', q",
  "'physical_qty', p_physical_qty",
  "'variance', p_physical_qty - q",
  'RETURN jsonb_build_object'
];

for (const token of required) {
  if (!sql.includes(token)) {
    console.error(`FAIL: missing required token: ${token}`);
    process.exit(1);
  }
}

if (/\\b(DROP\\s+(TABLE|FUNCTION|POLICY)|DELETE\\s+FROM)\\b/i.test(sql)) {
  console.error('FAIL: destructive SQL detected');
  process.exit(1);
}

if (sql.includes("'notes', p_notes")) {
  console.error('FAIL: free-text notes must not be copied to audit payload');
  process.exit(1);
}

console.log('PASS: stock-count submission audit migration preserves auth/validation and adds transactional audit event; no DROP/DELETE detected.');
