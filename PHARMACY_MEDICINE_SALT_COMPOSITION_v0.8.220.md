# Anaira Healthcare v0.8.220 — Medicine Salt / Generic Composition

- Reuses the existing `medications.generic_name` column as the Medicine Salt / Generic Composition field; no duplicate schema or new migration.
- Medicine create/edit form now labels the field as Medicine Salt / Generic Composition and explains single-ingredient and combination entries.
- Catalogue search already includes generic_name; catalogue rows now explicitly display `Salt: ...`.
- Stock search label now invites medicine/salt/brand/batch search; the existing filter already searches generic_name.
- Stock batch rows show the medicine salt beneath the brand/product name.
- Receive-stock and purchase medicine dropdowns display salt alongside the medicine name and strength.
- Dispensing medicine search suggestions show salt composition and exact unique salt searches can resolve to a single catalogue medicine; ambiguous shared salts are not auto-selected.
- Purchase bill OCR schema now asks for optional salt_composition and OCR catalogue matching includes existing generic_name.
- Existing medicine records and billing/stock RPCs remain unchanged. No migration required.
- Verification: source-level checks and ZIP integrity only; production build and browser/E2E testing pending.
