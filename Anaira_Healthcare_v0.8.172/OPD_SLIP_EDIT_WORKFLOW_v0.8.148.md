# v0.8.148 — Edit OPD Slip

- Added Edit OPD Slip action in the OPD queue for clinic registration roles and assigned doctors.
- Editable fields: complaint/problem, remarks, department, doctor display name, referred by, visit type and validity days.
- Saves changes to the existing opd_visits row; it does not create a new visit or alter invoice/payment history.
- Updated visit data is reflected in the queue and can be reprinted using Reprint parchi.
- Uses existing opd_visits update RLS policy; no database migration required.
- Static verification passed. Typecheck/build and browser E2E remain pending.
