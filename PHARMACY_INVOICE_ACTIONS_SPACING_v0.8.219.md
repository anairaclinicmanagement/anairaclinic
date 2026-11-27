# Anaira Healthcare v0.8.219 — Pharmacy Invoice Actions Spacing

- Added a dedicated class to the New pharmacy bill / Refresh invoices / Billing & tax settings toolbar.
- Toolbar is now a separate flex row with consistent gaps, button heights and right alignment.
- Added explicit bottom spacing before the invoice table wrapper so controls no longer visually merge with the table column/header.
- Table wrapper is a separate block with clear/float reset and its own horizontal margins.
- Mobile toolbar wraps and buttons distribute across available width.
- No invoice query, billing, payment, stock, or database logic changed.
- No migration required.
- Verification: source-level checks and ZIP integrity only; browser screenshot/build not run.
