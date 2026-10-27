# Anaira Healthcare v0.8.72 — ambulance, lab worklist and invoice printing

## Verified live database findings
- NH3 Clinic has one ambulance trip for vehicle HP 34 B 9584: dispatched, 5 km, patient charge ₹1,250, hospital cost ₹125, no patient_id and no invoice_id.
- Hospital subscription plan omitted the ambulance module while clinic enabled_modules included it. Added a clinic-level ambulance module override (enabled=true, no expiry) so the module entitlement function can permit access, subject to the user's active clinic membership and feature flag.
- NH3 Clinic has nine lab orders with paid invoices. Added a security-definer helper and SELECT policies to allow the assigned active lab technician to read only paid laboratory orders and their items within the same clinic. No invoice data is broadly exposed.
- Billing Recent invoices had no Print action. Added per-invoice Print button that opens a printable invoice/receipt with invoice number, patient/UHID, total, paid amount, balance, status, and date.

## Caveats
- The printable invoice is a summary receipt; detailed item lines are not fetched by the current Recent invoices query.
- Source static verification is not a substitute for an authenticated browser E2E test. Verify with the NH3 Clinic owner/receptionist and lab technician logins after deploying this ZIP.
