# Prescription Workspace & A4 Print — v0.8.136

- Expanded patient summary with UHID, demographics, contact, blood group, allergies/alerts and address.
- Added required dose/frequency/duration validation, expanded route options and catalogue-backed medicine selection.
- Added prescription register search and print action for previously issued prescriptions.
- Added dedicated A4 print sheet with patient details, medicine directions, validity, clinic heading and doctor signature area.
- Print stylesheet hides the application shell and prints only the prescription sheet.
- Uses existing clinic-scoped prescription RPCs and validity policy; migration ensures these RPCs exist with clinic-role authorization.

Clinical use requires authorized prescriber review and signature. No medicine or dose is auto-recommended.
