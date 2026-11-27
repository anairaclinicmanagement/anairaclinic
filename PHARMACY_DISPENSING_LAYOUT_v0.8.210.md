# Anaira Healthcare v0.8.210 — Pharmacy Dispensing Layout

- Restored the Pharmacy blue visual identity from v0.8.209.
- Added dedicated layout classes for the dispensing form sections.
- Patient, IPD, prescription and payment controls use a consistent four-column desktop grid.
- Collect-payment checkbox is normalized to a compact 18px control and spans its own row.
- Medicine line items and discount controls use consistent three-column grids.
- Inputs/selects use consistent 44px height, full-width sizing, spacing and focus hierarchy.
- Bill summary is aligned as a distinct footer with total and primary action.
- Responsive layout collapses to two columns and then one column on smaller screens.
- No billing, dispensing, stock, payment or Supabase migration logic was changed.
- Verification: ZIP integrity and source-level structural checks only; production build/browser E2E not run.
