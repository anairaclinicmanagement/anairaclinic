# Emergency / Casualty workflow update — v0.8.76

## Implemented in source
- Emergency triage priority with red, orange, yellow, green and blue categories.
- Arrival mode and ambulance assignment/cost-estimate flow retained.
- Responsible clinician assignment.
- Initial vital-sign documentation: systolic/diastolic blood pressure, pulse, respiratory rate, SpO2, temperature, blood glucose, GCS and pain score.
- Allergy and relevant medical-history documentation.
- Injury / incident mechanism, clinician assessment and treatment/intervention notes.
- Disposition selection: under assessment, triaged, being seen, observation, stabilized, admit to IPD, transfer, discharge, left without being seen and deceased.
- Disposition/handover notes, receiving hospital and emergency contact.
- Existing emergency visits can be loaded into the form and updated, not just status-changed.
- Emergency register displays available initial vitals and assigned clinician.
- Additive Supabase migration adds nullable documentation fields and bounds checks without deleting existing data.

## Database action required
Apply `supabase/migrations/20261028210000_emergency_casualty_complete_assessment.sql` to the connected Supabase project before using the new fields. Existing migration `20261028180000_emergency_schema_compatibility_save_fix.sql` must also be applied for the current status values.

## Important limits
This release improves the emergency documentation workflow; it is not a substitute for a validated clinical protocol or clinician judgement. This source package does not yet implement a dedicated resuscitation timer/Code Blue event log, electronic medication administration record, linked lab/radiology ordering from the emergency visit, or automatic IPD admission creation. Those require additional transactional workflows and database design.
