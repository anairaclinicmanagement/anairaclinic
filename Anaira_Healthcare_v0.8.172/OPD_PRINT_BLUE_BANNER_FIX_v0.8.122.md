# OPD print blue banner fix — v0.8.122

- Corrected the v0.8.121 print override: actual generated-letterhead wrapper and inner header are now explicitly painted white rather than transparent.
- Targets the real JSX classes `.opd-parchi-letterhead-wrap.opd-generated-letterhead` and `.opd-letterhead-generated` in plain-paper print mode.
- Suppresses only legacy header/pseudo-element decoration in print; preserves the actual clinic logo, name, registration, address, phone, email, website, validity, and OPD title.
- On-screen OPD preview and pre-printed-letterhead mode are not changed.
- Production build and Chromium print preview still require verification in the user's environment; no live Supabase data was accessed.
