# Anaira Clinic Print Audit v1.0.9

## Changes
- Reworked OPD parchi to follow the supplied reference structure: validity and fee line, clinic name, patient demographics, OPD registration/visit number, date/time, UHID, phone/address, department/doctor/room, investigations, complaint, examination, provisional diagnosis, advice/medicines, findings column, and doctor signature.
- OPD parchi is a separate document from diagnostic/pharmacy invoices.
- A5 portrait print rules isolate the parchi from the app shell and hide navigation/actions.
- Existing pharmacy and diagnostic invoice `.print-document` rules remain isolated so printing targets the actual invoice, not the whole app.
- Existing prescription print panel is isolated from the app shell.
- OPD patient query now fetches address for the printed parchi.
- Clinic name is fetched from the selected clinic record for the OPD heading.

## Audit findings
- `app/opd/page.tsx`: OPD parchi print
- `app/prescriptions/page.tsx`: prescription print
- `app/billing/page.tsx`: diagnostic invoice print
- `app/pharmacy/page.tsx`: pharmacy invoice print
- `app/globals.css`: print isolation and A5 layout rules

## Verification
- `node scripts/verify-project.mjs`: PASS (35 routes, 33 migrations).
- ZIP integrity: checked after packaging.
- Full Next.js production build and real printer/PDF visual verification were not run in this environment. Select A5 portrait and Save as PDF in the browser print dialog.
