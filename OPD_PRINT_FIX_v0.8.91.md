# OPD Print Fix v0.8.91

- Replaced the pseudo-element based pre-printed-letterhead blank region with a dedicated `.opd-preprinted-top-spacer` element.
- Pre-printed mode prints a true white 76.2 mm (3 inch) space from the physical top edge, with no header pseudo-element or blue banner.
- Plain A4 mode retains the generated clinic branding header.
- No Supabase migration required.

Verification: `node scripts/verify-project.mjs` passed (36 routes, 57 migrations, 21 required files). Full Next.js build and browser PDF print preview were not run in this environment.
