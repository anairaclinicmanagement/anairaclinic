# Anaira Healthcare v0.8.213 — Compact Pharmacy Billing

- Restored an explicit two-way customer choice: Patient / Named and Cash / Walk-in.
- Patient / Named mode exposes existing patient selection and Add customer; patient remains required in this mode.
- Cash / Walk-in mode requires no customer name or phone and retains the generic per-clinic cash customer flow.
- IPD admission and prescription selectors are disabled in anonymous cash mode and available only for a selected named patient.
- Dispensing form spacing tightened: compact top controls, single-row medicine/quantity/price/remove layout, tighter discount section and shorter summary footer.
- Modal widened and optimized for desktop viewport; mobile layout collapses responsively.
- No SQL migration or billing/stock RPC changes in this version.
- Verification: source-level checks and ZIP integrity only; production build and live browser/E2E test not run.
