# IPD pharmacy invoice admission number — v0.8.106

- Pharmacy invoice print now displays the admission's human-readable `admission_no` (for example `IPD-20261029-33B1FCC7`) instead of exposing the internal admission UUID.
- The issued-invoice Print action resolves `admissions.admission_no` by clinic and admission ID, including historical/discharged admissions.
- The immediate latest-bill print view displays the selected active admission number when an IPD admission was selected during dispensing.
- Normal outpatient/walk-in pharmacy invoices do not show an admission number.
- No billing totals, payment calculations, stock deduction or database schema changed.

Validation: source assertions and ZIP integrity checked. Full build/live browser print was not run in this environment.
