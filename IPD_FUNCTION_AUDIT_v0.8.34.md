# IPD Function Audit — v0.8.34

This audit describes source/database presence, not a claim of end-to-end clinical certification.

| Reference workflow | Current implementation | Verification |
|---|---|---|
| Patient admission and search | Existing admission RPC; patient selector; admission list now searches patient name, UHID, phone and admission number | Source reviewed; no live browser workflow run |
| Ward / room setup | Create, edit, deactivate room; bed capacity and occupied/available count | Source reviewed; capacity/occupancy uses active admission count |
| Bed allotment | Admission creation RPC assigns selected room | Existing RPC retained; no live test patient created |
| Bed transfer | New RPC validates active admission, clinic-owned active room and capacity; records from/to/reason and audit event | Migration applied; RPC/table presence verified; no real transfer test run |
| Doctor / clinical details | Links to existing Consultation module; admission notes editable | Route/source present; no E2E test |
| Nursing chart | New saved chart UI and RPC for vitals, notes, intake/output, MAR, injection/IV, monitoring and shift handover | Migration applied; RPC presence verified; no live record written during verification |
| Laboratory / radiology | Links to existing Laboratory and Radiology modules | Existing routes retained; IPD order linkage not certified by this change |
| Pharmacy / stock | Single shared `/pharmacy` route, `medications` catalogue and `inventory_batches` stock tables | Database table presence verified; prescription-to-dispense and stock deduction E2E not run |
| Billing / payments | IPD invoice is stored in shared `invoices` and `invoice_items`; optional upfront collection records in shared `payments`; shared `/billing` route | Shared invoice RPC applied and existence verified; payment UI E2E not run |
| Discharge | Existing discharge RPC requires summary and marks admission discharged | Source retained; discharge clearance/final-bill enforcement not added or tested |
| Reports / registers | Links to existing Reports module; admissions and IPD invoice lists in page | Route/source present; export correctness not tested |
| Permissions / tenant isolation | New RPCs check clinic role and clinic-scoped admission/room; bed transfer table has RLS policies | Static SQL checks only; hostile cross-clinic tests still required |

## Known limitations before production sign-off
- Full `npm run typecheck` and `npm run build` could not run because dependency installation timed out and `node_modules` remained incomplete. The changed TSX was syntax-transpiled with the globally available TypeScript compiler and passed.
- No browser-based E2E was run, and no patient, admission, nursing record, invoice or payment test data was inserted.
- Nursing records currently save vitals/intake-output fields as JSON observations and narrative notes; they do not independently issue medicine, execute MAR stock deduction, or create lab/radiology orders.
- Bed capacity is tracked at room level (`rooms.bed_count`) rather than separate numbered bed entities.
- Discharge is not blocked automatically by unpaid invoices; final bill clearance must be implemented/verified before requiring that policy.
