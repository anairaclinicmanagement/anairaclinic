# Anaira Healthcare v0.8.211 — Optional customer for pharmacy cash sales

- Pharmacy counter supports Cash / Walk-in sale without entering a customer's name or phone.
- The default cash-sale mode uses one generic `Cash / Walk-in Customer` patient placeholder per clinic.
- The placeholder is created/reused by a clinic-scoped SECURITY DEFINER RPC with pharmacy role and module checks.
- Existing atomic `dispense_pharmacy_sale_for_admission` remains the only stock/billing posting path.
- Named patient/customer mode remains available, including named walk-in customer creation.
- Anonymous cash mode clears/disallows patient-specific prescription and IPD admission links; select a named patient for those workflows.
- No individual customer identity data is collected in anonymous mode.
- Migration required: `20261126190000_pharmacy_generic_cash_walkin_customer.sql`.
- Static source and ZIP integrity checks only; live Supabase migration and dispense E2E tests are pending.
