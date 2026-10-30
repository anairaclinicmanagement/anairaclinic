# OPD Print Blue Banner Fix — v0.8.118

- Added a final print-only override for the actual OPD plain-A4 print wrapper and generated letterhead.
- Resets the full `background` shorthand and `background-image`, not only `background-color`.
- Disables pseudo-element decoration on the letterhead wrappers while preserving clinic logo and text.
- Does not change the on-screen OPD preview or pre-printed letterhead spacer.
- Production build and browser print-preview verification remain to be run.
