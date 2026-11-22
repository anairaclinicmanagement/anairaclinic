# Anaira Healthcare v0.8.84 — OPD A4 header/overflow correction

- Based on the user-provided v0.8.82 source ZIP.
- Replaced the oversized solid/gradient header block in print with a white, full-width letterhead header and visible clinic name/logo/details.
- Set print canvas to exact A4 portrait (210 × 297 mm) with 8 mm internal padding and zero @page margins.
- Constrained the writing grid to the printable page width to prevent horizontal overflow/scrollbars.
- No Supabase migration added.

Verification: static checks and ZIP integrity only; full Next.js production build and browser/PDF preview were not run in this environment.
