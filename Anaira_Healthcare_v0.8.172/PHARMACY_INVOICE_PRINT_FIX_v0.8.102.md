# Pharmacy invoice print fix v0.8.102

- Scoped pharmacy invoice print page to A5 so later global OPD A4 print rules do not override its page size.
- Forced pharmacy invoice header, title and store details to use a white background and visible dark text in print.
- Reset header pseudo-elements and inherited background styling that could produce a blank blue banner.
- Kept invoice rows, totals, and the existing pharmacy billing workflow unchanged.

Validation: source/CSS review and ZIP integrity check. Browser print preview and live clinic branding still need to be verified in the user's environment.
