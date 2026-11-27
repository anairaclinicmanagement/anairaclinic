# Anaira Healthcare v0.8.221 — AI Purchase Stock Salt Capture

- AI purchase bill extraction schema includes `salt_composition`.
- OCR output text includes the extracted salt/composition per medicine line.
- Purchase OCR parsing carries salt into each reviewable purchase line.
- Purchase entry table includes an editable Salt / Composition column.
- Existing catalogue matches prefill the salt field from `medications.generic_name`.
- Unmatched OCR rows that include salt or batch/quantity details are surfaced for manual medicine matching instead of silently discarded.
- Selecting a catalogue medicine pre-fills its known salt, while allowing the staff member to correct the line-level value for review.
- Stock is still posted only through the existing GRN RPC after the required catalogue medicine, batch, quantity and rates are supplied.
- No database migration added. Line-level salt is a review field; it does not silently overwrite the medicine master. Update the medicine master through Add/Edit Medicine when its permanent composition needs correction.
- Verification: 8 source-level checks and ZIP integrity; production build, live OCR and browser/E2E testing remain pending.
