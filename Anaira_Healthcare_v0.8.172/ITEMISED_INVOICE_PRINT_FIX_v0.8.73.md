# Itemised invoice print fix — v0.8.73

- Replaced generic “Healthcare services / invoice items” print row with live invoice line items from `invoice_items`.
- Print header reads the actual clinic/hospital name, address, phone, email and registration number from `clinics`. It does not hardcode Anaira branding.
- Includes patient/UHID, invoice number/date/status, OPD/IPD context, quantities, rates, discounts, tax, line totals, subtotal, bill total, paid and balance due.
- IPD admission number/timestamps/status are included when invoice has an `admission_id`.
- Does not fabricate missing line items: if the source invoice has no saved particulars, the printout explicitly warns that the source bill needs correction.

Verification: source-level project verification only; no authenticated browser print test was run.
