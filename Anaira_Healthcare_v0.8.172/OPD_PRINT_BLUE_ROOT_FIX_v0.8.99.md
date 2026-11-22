# OPD print blue root banner fix v0.8.99

- Disabled all generated `::before` and `::after` decorations inside the OPD print paper for both print modes.
- Forced the paper/header backgrounds to white while preserving clinic branding text in plain-A4 mode.
- Preserved the actual 76.2 mm white spacer in pre-printed-letterhead mode and hides generated branding in that mode.
- No Supabase migration required.

Verification: source checks and ZIP integrity only. A live browser print preview and full Next.js build must still be run in the user's environment.
