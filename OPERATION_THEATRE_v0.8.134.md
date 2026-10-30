# Operation Theatre – v0.8.134

- Replaced the generic clinical operations view with a dedicated OT workspace.
- Added OT dashboard counts, searchable/filterable surgery register, patient/IPD admission booking, surgeon and anaesthetist assignment, schedule, room, estimated charge and anaesthesia notes.
- Added clinical case documentation for ASA class, anaesthesia type, surgical safety checklist, intra-operative notes/findings, blood loss, complications, post-operative plan and recovery notes.
- Case creation uses the tenant-validated RPC and adds a positive OT charge to the linked IPD invoice.
- Clinical updates use the tenant/role-validated RPC with audit logging and actual start/end timestamps.
- Added additive compatibility migration for older OT table layouts.

## Verification scope
Supabase migration was applied and schema/function presence is verified. Static project verification is run separately. Browser workflow, build and clinical sign-off are not represented as completed unless separately tested.
