# Anaira Healthcare v0.8.35 — IPD Dashboard Action Modals

## Included
- Updated IPD dashboard cards to behave as keyboard-accessible buttons instead of passive anchor cards.
- Added module-specific action popups for all 11 IPD sections shown in the reference image.
- Wired admission actions to the existing admission form, room/bed actions to room management, nursing and bed transfer actions to existing forms, and discharge actions to the existing discharge workflow.
- Wired shared Pharmacy, Laboratory, Radiology, OT, Billing, Reports, Consultation, Patient and Settings actions to their existing module routes.
- Added responsive modal action-grid styling; preserved existing Supabase data access, clinic scope and current workflow handlers.
- Preserved the existing Supabase migration files for bed transfer, nursing chart and shared IPD billing.

## Verification
- TypeScript TSX syntax transpilation passed for `app/ipd/page.tsx`.
- Full `npm run typecheck` could not be certified in this environment because the installed dependency/type-definition tree is incomplete (`@types/node`, React, and several other implicit type packages are missing).
- Production build and live browser workflow tests remain pending.

## Important behavior
- Where a workflow already has an implementation, the modal routes to it or opens its existing form.
- Some listed clinical workflows open the existing Consultation, Pharmacy, Laboratory, Radiology, OT, Billing, Reports, or Settings page; this release does not claim every submenu is a new standalone implementation.
