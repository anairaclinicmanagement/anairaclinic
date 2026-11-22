# IPD Compact Workspace & Popup Refresh — v0.8.107

- Removed the Shared Pharmacy & Stock and Shared Billing & Payments tiles from the IPD home dashboard as requested. Pharmacy and central billing remain available from their own workspace/sidebar pages.
- Reduced the IPD home overview/header and module cards to use less vertical space; desktop dashboard uses a compact three-column layout with responsive tablet/mobile layouts.
- Renumbered the remaining nine dashboard modules sequentially.
- Refined IPD modal width, max-height, heading, fields, spacing, action buttons, and responsive behavior for a more consistent popup workflow.
- No database schema, billing calculations, admission logic, or Supabase data was changed in this UI-only pass.
- Validation: source-level checks and ZIP integrity; browser/E2E and production build should still be run in the configured project environment.
