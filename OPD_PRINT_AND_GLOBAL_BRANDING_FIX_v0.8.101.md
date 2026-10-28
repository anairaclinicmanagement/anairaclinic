# Anaira Healthcare v0.8.101 — OPD Print & Global Branding

- Replaced the accumulated/contradictory OPD print CSS patch history with one authoritative A4 stylesheet.
- Print card and all its pseudo-elements are explicitly neutralized, including the enclosing `.print-prescription` pseudo-elements that older fixes did not target.
- Plain A4 renders a white generated header with clinic name/contact details and uploaded logo; pre-printed letterhead renders a real 76.2 mm white spacer and hides generated branding.
- Removed old A5 page rule from OPD print styling; print uses A4 portrait.
- Clinic `primary_color` and `accent_color` from `clinics.clinic_profile` now feed app-wide CSS custom properties; shared green/primary UI tokens follow the selected clinic.
- Sidebar facility mark uses the active clinic's uploaded `logo_url` when available, with Anaira logo fallback.
- Supabase Storage bucket `clinic-assets` and clinic-owner/admin scoped write policies were applied to the connected project and verified.
- OPD print button now opens an isolated print document with its own inline A4 stylesheet, instead of calling `window.print()` on the entire application DOM. This avoids old global `@media print` rules and legacy blue banner styles leaking into the PDF.
