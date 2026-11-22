# OPD print blue banner patch — v0.8.121

- Scope: print-only, plain-paper OPD letterhead.
- Removes painted background/gradient and pseudo-element decoration from the actual `.opd-parchi-letterhead-wrap` and `.opd-letterhead-generated` markup.
- Preserves the clinic logo, name, registration number, address, phone, email, website, validity line and OPD title.
- Does not alter the on-screen OPD preview or the pre-printed-letterhead mode.
- Browser print preview and production build have not been verified in this environment; validate with `npm ci`, `npm run build`, then Print > Save as PDF.
