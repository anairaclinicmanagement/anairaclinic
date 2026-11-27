import fs from 'node:fs';
import path from 'node:path';
const migrationDir = path.resolve('supabase/migrations');
const files = fs.readdirSync(migrationDir).filter((name) => name.endsWith('.sql'));
const versions = files.map((name) => name.match(/^(\d+)_/)?.[1]).filter(Boolean);
const duplicates = versions.filter((v, i) => versions.indexOf(v) !== i);
const cash = fs.readFileSync(path.join(migrationDir, '20261126190000_pharmacy_generic_cash_walkin_customer.sql'), 'utf8');
const checks = {
  uniqueMigrationVersions: duplicates.length === 0,
  cashCustomerIncludesRequiredUhid: /clinic_id\s*,\s*uhid/i.test(cash),
  cashCustomerGeneratesUhid: /v_uhid\s*:=\s*'UHID-'/i.test(cash),
  cashCustomerHasExplicitId: /v_id\s*:=\s*gen_random_uuid\(\)/i.test(cash),
  noDestructivePatientDelete: !/\bdelete\s+from\s+public\.patients/i.test(cash),
};
if (Object.values(checks).some((v) => !v)) {
  console.error({ checks, duplicates });
  process.exit(1);
}
console.log('PASS: unique migration versions and cash walk-in UHID requirements verified.', checks);
