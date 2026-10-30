# Anaira Healthcare Management System v0.8.125

## OPD plain-paper print background correction

- Added a final print-only reset at the complete OPD print boundary.
- Normalized the app-shell ancestors to white during OPD parchi printing.
- Removed inherited background colors, gradients, shadows and filters from nested letterhead/patient/writing content while preserving text, logo and structural borders.
- Kept pre-printed letterhead spacer behavior and normal screen styling unchanged.

## Validation
- Source-level checks are run against this release package.
- Browser print-preview validation requires the running clinic application and an actual OPD visit; it cannot be certified from a source ZIP alone.
