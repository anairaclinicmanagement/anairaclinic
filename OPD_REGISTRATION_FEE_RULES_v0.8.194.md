# OPD Registration Fee Rules — v0.8.194

- Added configurable daily, Sunday, selected holiday and emergency registration fees.
- Fee amount ₹0 is supported and creates a free parchi without generating a zero-value invoice.
- Holiday dates are clinic-specific and use India local date (YYYY-MM-DD).
- Fee precedence: Emergency visit > configured holiday > Sunday > daily rate.
- OPD intake v2 calculates the selected fee server-side before creating invoice, payment and visit records, avoiding client-side fee tampering.
- Existing OPD validity and daily fee settings remain compatible; no existing visits are recalculated.
- Apply migration `20261122220000_opd_registration_fee_rules.sql` before use.
