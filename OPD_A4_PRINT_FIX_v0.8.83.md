# Anaira Healthcare v0.8.83 — OPD A4 print correction

- Replaced the solid blue header slab with a white clinic letterhead header, narrow accent stripe, dark clinic name, configurable details, and optional logo.
- Added trimmed/fallback clinic name rendering.
- Reworked print page to A4 portrait with a 6 mm page margin and fixed 198 mm × 285 mm content canvas.
- Prevented horizontal overflow and hid scrollbars in the print document.
- Writing grid flexes to fill the remaining A4 height; investigations columns stretch with it.
- Print button label now says A4 / PDF.

No Supabase migration required. Static verification only; browser print preview/full production build must still be tested in the user's environment.
