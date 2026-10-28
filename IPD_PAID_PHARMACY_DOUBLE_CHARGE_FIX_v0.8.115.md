# Anaira Healthcare v0.8.115 — Paid Pharmacy Bill Double-Charge Fix

- Corrected the current IPD final invoice `IPDF-20261029-4961992C`: removed the duplicate pharmacy summary line `PH-20261029-4BDD374B` (₹343.35) and reduced the final IPD total from ₹2,743.35 to ₹2,400.00.
- Kept the original pharmacy invoice `PH-20261029-4BDD374B` marked paid at ₹343.35 and unlinked it from the final IPD invoice so its payment is not treated as an unpaid source balance.
- The patient-level financial view should now show pharmacy ₹343.35 paid once and IPD final bill ₹2,400 due, rather than charging pharmacy twice.
- Updated final IPD bill source selection to exclude fully paid department invoices from future consolidations. Part-paid/unpaid department invoices may still be consolidated and their collected amount carried forward.
- Added a follow-up Supabase migration for already-installed projects.

Verification: source filter assertion and ZIP integrity check; browser and full production build are not claimed as run.
