# Anaira Healthcare v0.8.134 — Operation Theatre workflow

- Replaced the generic Clinical Operations OT screen with a dedicated surgical workspace.
- Added OT dashboard counts, searchable case register and status filtering.
- Added active IPD-linked patient/admission selection, operating room, surgeon, anaesthetist, schedule, procedure diagnosis, ASA class, anaesthesia type and estimated charge.
- Added structured pre-operative safety checklist: consent, identity, site marking, fasting, allergy review and instrument/swab count.
- Added operative notes/findings, estimated blood loss, complications, post-operative plan and recovery notes.
- Added case clinical record editing and controlled status lifecycle.
- Added additive Supabase migration `20261030210000_real_operation_theatre_surgical_workflow.sql` with tenant-scoped RPC and audit logging.
- Operation charge continues to be posted through the existing atomic IPD-linked case creation RPC.

Clinical documentation is an operational record and does not replace the hospital's approved surgical safety checklist, consent process, anaesthesia chart, nursing count protocol or clinician sign-off.
