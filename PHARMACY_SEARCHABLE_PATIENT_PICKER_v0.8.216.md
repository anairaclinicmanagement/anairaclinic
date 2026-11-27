# Anaira Healthcare v0.8.216 — Searchable Patient Picker

- Added a patient search field in Patient / Named mode.
- Search matches patient full name, first/middle/last name, phone number and UHID.
- Kept the existing native dropdown with all patient options; the dropdown options filter as the search query changes.
- Selecting a patient keeps that patient selected and displays the patient's name and phone in the search field.
- Add customer action remains available.
- Cash / Walk-in mode remains unchanged and does not require customer details.
- No database migration or billing/stock logic changes.
- Verification: source-level checks and ZIP integrity only; production build and browser E2E pending.
