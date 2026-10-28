# OPD print mode fix v0.8.87

- Pre-printed letterhead mode now inserts an explicit white 4-inch print spacer measured from the physical A4 page edge. It does not rely on hiding a generated header with a mismatched descendant selector.
- Plain A4 mode uses a white generated clinic header with configured name/logo/contact fields and removes legacy blue gradient backgrounds/pseudo-elements in print CSS.
- Print-only CSS constrains the A4 canvas and prevents horizontal overflow.
- No new Supabase migration.

Verification: source changes and ZIP integrity checked; full Next.js build/browser PDF preview not run in this environment.
