# OPD Print Root-Cause Fix — v0.8.119

## Root cause
The OPD print CSS had accumulated conflicting legacy rules, including a 3-inch top-padding/header pseudo-element implementation for pre-printed letterhead mode. Later overrides reset the paper and header backgrounds but did not consistently neutralize all legacy header pseudo-elements and padding. This could leave a full-width blue block before the actual clinic details in print preview.

## Fix
- Added one final, high-specificity print-only normalization for the OPD paper subtree.
- Removed generated header pseudo-elements and legacy header top padding.
- Plain-paper mode now starts with the actual clinic letterhead and has no blank banner/spacer.
- Pre-printed mode retains only the intended 76.2mm white spacer and suppresses generated branding.
- Screen preview and non-OPD print documents are not targeted.

## Verification
- ZIP archive integrity verified after packaging.
- A production build and real Chrome print-preview verification still need to be run in the project environment.
