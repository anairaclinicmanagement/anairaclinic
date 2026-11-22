# Anaira Healthcare v0.8.176 — IPD Room-wise and Bed-wise Allocation

## Admission Step 3
- Added two allocation modes: Bed-wise (one physical bed) and Full Room (all active beds in the selected room).
- Both modes first select a ward / room. Bed-wise then selects one free bed in that room.
- Full Room lists only rooms where every active physical bed is free.
- The Full Room mode reserves all active beds in one transaction and links each reserved bed to the same admission.
- A room admission stores the first physical bed as the legacy primary bed for compatibility, while the room allocation register reserves all bed slots.
- The room rate is calculated automatically as the sum of the current rates of every active bed in that room, per 12-hour block.
- Bed-wise pricing uses only the selected bed's rate per 12-hour block.
- The final admission review displays allocation type, number of beds and the correct automatic rate.

## Occupancy and billing
- Whole-room allocation marks every bed in that room as occupied in the bed cards and bed register.
- Room occupancy counts occupied physical beds, not just admission records.
- IPD bed-charge estimate uses the saved room-rate snapshot for whole-room admissions; bed-wise admissions continue to use the selected bed rate.
- Opening Create IPD Bill pre-fills the amount from the calculated room/bed charge and 12-hour block count.
- Room allocation rows retain per-bed rate snapshots for traceability.
- A database trigger releases all whole-room reservations when an admission is discharged/cancelled or transferred to another room/bed.
- A database guard prevents older bed-wise admission and transfer workflows from allocating a bed reserved by a whole-room admission.

## Database
- Added migration `20261122180000_ipd_room_wise_bed_allocation.sql`.
- Added clinic-scoped `ipd_room_allocation_beds` table with RLS read policy and active-bed uniqueness.
- Added transactional RPC `create_clinic_room_admission_v1` with room/bed row locks, availability checks, admission creation, per-bed allocation rows and audit log.
- Existing single-bed admission RPC remains compatible.

## Verification
- TSX syntax transpilation and static project/migration verification performed.
- Full Next.js production build, TypeScript project typecheck, live Supabase migration execution and browser end-to-end tests remain pending.
