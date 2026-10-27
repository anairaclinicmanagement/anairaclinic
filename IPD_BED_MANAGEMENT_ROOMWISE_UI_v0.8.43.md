# Anaira Clinic v0.8.43 — Room-wise IPD Bed Management UI

## Included
- Replaced the flat individual-bed table with a responsive room-wise bed-card layout.
- Each room shows ward, room type, bed count, occupancy, availability, and the per-bed 12-hour rate.
- Each physical bed card shows its rate and live Available/Occupied state from existing Supabase room_beds and active admissions data.
- Available bed cards open the existing admission workflow with that physical bed preselected.
- Occupied bed cards provide patient lookup and the existing bed-transfer workflow.
- Bed Edit and Room Edit actions reuse existing persisted forms and validations.
- Added responsive CSS for wide desktop, tablet, and mobile layouts.

## Data model notes
- Room and individual bed records remain in the existing `rooms` and `room_beds` tables.
- The current schema stores per-bed price per 12 hours. Newly created beds inherit the room form's rate; individual beds can be edited independently.
- This update does not introduce persisted Cleaning/Blocked states because the current `room_beds` type in this source does not expose a bed-status field. UI only labels states that are grounded in current admission/bed data.

## Verification
- Source-level patch applied to `app/ipd/page.tsx` and `app/globals.css`.
- Production build/typecheck must be run in the project environment with dependencies and environment configuration installed.
