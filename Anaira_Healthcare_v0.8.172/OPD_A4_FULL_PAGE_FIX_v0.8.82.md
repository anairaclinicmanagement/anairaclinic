# OPD A4 Full Page Fix v0.8.82

- Removed the `Full Name` wording from the doctor signature label.
- Ensured the clinic name is always rendered in the generated plain-paper header.
- Updated print layout to A4 portrait with 8 mm page margins and full-page writing area.
- The investigations required and findings columns stretch to the bottom of the writing grid.
- Four main writing sections share the available page height.
- No Supabase migration is required.

Validation: static checks and ZIP integrity only. Full Next.js production build and browser/printer preview were not run in this environment. In the browser print dialog, disable browser headers and footers to remove the `localhost:3000/opd` footer.
