# Anaira Healthcare v0.8.214 — Pharmacy Payment Controls

- Payment method and Collect payment now are combined into one compact field.
- Payment method dropdown and compact checkbox share a single horizontal row on desktop.
- This removes the separate payment and collect-now field boxes, reclaiming horizontal and vertical space.
- Patient / Named and Cash / Walk-in modes remain unchanged.
- No billing RPC, payment, stock, or Supabase schema logic changed.
- No new migration required.
- Verification: source-level check and ZIP integrity only; production build/browser E2E pending.
