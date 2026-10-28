# OPD Print Header Fix v0.8.94

## Root cause
The print stylesheet had conflicting legacy rules. The pre-printed mode already rendered an explicit 3-inch spacer, while a legacy rule also applied `padding-top: 3in` to the OPD header. The header's old background/gradient could therefore paint a blue banner in the reserved blank area and the spacing was compounded.

## Fix
- The explicit `.opd-preprinted-top-spacer` is now the only element responsible for the 3-inch blank area in pre-printed mode.
- Removed header padding as a spacing mechanism in print.
- Removed backgrounds, gradients, shadows and pseudo-elements from the print header.
- Plain A4 mode hides the spacer and retains the generated clinic branding.
- Pre-printed mode hides the generated branding but retains the validity and OPD title below the spacer.
- No Supabase migration required.

## Verification
Static source checks and ZIP integrity can be run locally. Full Next.js build and browser PDF rendering were not run in this environment.
