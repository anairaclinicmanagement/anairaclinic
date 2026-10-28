# OPD pre-printed letterhead blue banner fix — v0.8.89

- Print-only override targets `.opd-paper-preprinted`.
- Removes generated header element and all pseudo-element backgrounds/borders.
- Reserves a 3-inch blank area from the physical A4 top edge for pre-printed stationery.
- Plain-paper mode is not changed by this override.
- No Supabase migration required.

Validation: CSS source inspected and ZIP integrity checked. A full Next.js build/browser PDF render was not available in this environment.
