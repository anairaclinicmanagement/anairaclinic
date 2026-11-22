# Operation Theatre Emergency and IPD Billing — v0.8.137

- Added separate Scheduled Surgery and Emergency / On-the-Spot OT entry actions.
- Emergency cases are created with the current timestamp and enter pre-operative status without requiring a future slot.
- Both modes require a matching active IPD admission; emergency patients must first be registered/admitted through Emergency/IPD.
- Removed invoice creation at OT booking. The estimate is not a posted bill.
- When an OT case is moved to Recovery or Completed, the UI posts the final OT charge once to `ipd_charge_entries` through a row-locked, idempotent RPC.
- The final IPD bill collects this charge through the existing IPD billing workflow; payment is collected in Billing. Existing cases and historical invoices are preserved.
- A case with a posted charge cannot create a duplicate entry on subsequent edits.
