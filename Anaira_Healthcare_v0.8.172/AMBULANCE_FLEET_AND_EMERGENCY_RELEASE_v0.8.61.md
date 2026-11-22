# Anaira Healthcare Management System v0.8.61

## Ambulance and Emergency arrival update

- Adds a clinic-scoped ambulance fleet/provider register (`ambulance_vehicles`).
- Separates ownership: patient-owned, hospital-owned, and hospital-hired.
- Stores vehicle/provider code, driver, hospital operating cost per kilometre, patient charge per kilometre, fixed hire cost and active status.
- Ambulance trips capture patient, emergency visit, pickup/destination, distance, hospital cost, patient charge, dispatch/status and linked invoice.
- Emergency/Casualty arrival can select a registered hospital/hired ambulance. If a hired provider is not registered, entering the provider/vehicle name creates the registry entry during arrival submission.
- Patient-owned ambulance arrival does not create a hospital fleet charge.
- Ambulance trip creation records the trip and estimated charges only; it does not create an invoice or collect payment.
- Billing & Payments lists completed, patient-linked unbilled ambulance trips and creates the invoice there. All payment collection and balance tracking use the existing central billing workflow.
- Existing ambulance trips and invoices are preserved; migration is additive.

## Apply migration

Apply `supabase/migrations/20261028160000_ambulance_fleet_costing_and_billing.sql` to the same Supabase project configured by the application before testing the UI. Do not reset the database.

## Verification

`npm run verify:static` passes (35 routes, 50 SQL migrations). TypeScript and production build could not be completed in this environment because the included `node_modules` is incomplete and required type definitions are missing. Live Supabase permissions and browser workflows must be tested after applying the migration.


## Central billing update (v0.8.63)

- Apply `supabase/migrations/20261028200000_ambulance_central_billing_workflow.sql`.
- Ambulance and Emergency/Casualty flows only save operational trip details and estimated charges.
- Invoice creation is restricted to Billing & Payments through `create_ambulance_invoice_from_billing`; the RPC requires a completed trip, a linked patient and a positive charge. It prevents duplicate invoice creation and records an audit event.
- Use the existing Billing & Payments page to record payments and manage balances. No payment form or payment collection is added to Ambulance.
