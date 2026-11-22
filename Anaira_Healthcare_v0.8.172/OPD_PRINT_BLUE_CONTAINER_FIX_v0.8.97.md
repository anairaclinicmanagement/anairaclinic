# OPD Print Blue Container Fix v0.8.97

- Added a final, higher-specificity print CSS override targeting the actual OPD paper, header, spacer, and generated letterhead.
- Forces white background/no gradient in both paper modes.
- Pre-printed mode hides generated branding and retains a 76.2 mm white top spacer.
- Plain A4 retains the configured generated clinic header content.
- No database migration required.

Validation: ZIP integrity and static source checks only. A real browser print preview/build was not run in this environment.
