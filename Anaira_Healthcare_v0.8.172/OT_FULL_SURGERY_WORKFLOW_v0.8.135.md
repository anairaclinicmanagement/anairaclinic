# Operation Theatre full surgery workflow — v0.8.135

## Implemented
- Clinic-scoped procedure catalogue seeded with 50 common procedures across general surgery, obstetrics & gynaecology, orthopaedics, urology, ENT, ophthalmology, dental/maxillofacial, neurosurgery, cardiac and plastic/reconstructive surgery.
- Clinic-specific default estimate displayed for each catalogue item; final estimate is editable at booking. Seed rates are indicative starting estimates, not fixed quotations or clinical advice. Hospital admin must configure/confirm actual tariff and inclusions.
- OT booking requires an active IPD admission, selected patient, procedure and clinical indication.
- Patient demographic/contact profile, blood group, allergies, medical alerts, guardian and emergency contact are shown for verification.
- Booking captures relevant comorbidities/history, current medicines, previous surgery/anaesthesia history, pre-anaesthesia assessment, diagnosis, anaesthesia type, OT room, surgeon, anaesthetist, schedule and special arrangements.
- Booking creates the OT case and posts the estimate to the linked IPD invoice when amount is greater than zero.
- Existing pre-op safety checklist, intra-operative record, blood loss, complications, post-op plan and recovery/PACU documentation remain available.
- RLS and security-definer RPC enforce clinic membership/role and same-clinic patient/admission/staff/catalogue validation.

## Important clinical and billing safeguards
- Procedure list is a starter catalogue, not an exhaustive list. Admins must add/maintain local procedures and tariffs as needed.
- Prices are configurable estimates and must be confirmed by the hospital before communicating a quote. Implants, consumables, medicines, blood products, room, surgeon, anaesthesia, investigations and length of stay can change final charges.
- Clinical indication, pre-anaesthesia evaluation, consent, checklist completion and operative notes must be entered/verified by authorised clinical staff. This software does not recommend which operation a patient needs.

## Supabase
Applied to connected project `gdyvzvzmybbvufggxjty`: procedure catalogue table, case fields, clinic RLS, 50-procedure seed catalogue per clinic, full booking RPC and patient pre-anaesthesia history fields/RPC. Live verification returned 150 catalogue rows across 3 clinics, 6 required case columns, and the v2 booking RPC.

## Validation
Static project verification and TypeScript/build/browser E2E remain separate checks. Production build has not been certified in this environment.
