# OPD Letterhead Fix v0.8.85

- Fixed the generated plain-paper header so an empty blue banner cannot cover the clinic name/details.
- Header uses the saved clinic name, logo, registration number, address, phone, email and website according to the existing OPD header checkboxes.
- The clinic name is now controlled by the Show clinic/hospital name setting.
- Logo is placed on the right, matching the supplied letterhead reference.
- Pre-printed letterhead mode hides the generated header; plain paper mode prints it.
- No Supabase migration required.

Validation: static source checks and ZIP integrity only; full Next.js production build and browser PDF preview must be run in an environment with dependencies installed.
