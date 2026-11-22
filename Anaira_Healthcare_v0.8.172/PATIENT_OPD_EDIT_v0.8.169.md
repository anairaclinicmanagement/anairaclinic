# Anaira Healthcare v0.8.169 — Patient & OPD Editing

- Added an Edit action to each patient in the Patient Directory.
- Patient edit updates the existing patient row in the active clinic, preserving UHID and registration identity.
- Editable patient fields: name, phone, gender, date of birth, address, allergies and medical alerts.
- Added Edit Patient Details from the selected-patient panel in OPD registration.
- Existing Edit OPD Slip workflow remains available for complaint, remarks, department, doctor, referral, visit type and validity.
- OPD patient edits refresh the local patient list and visible visit labels after a successful Supabase update.
- No database migration required; uses existing `patients` and `opd_visits` tables.
