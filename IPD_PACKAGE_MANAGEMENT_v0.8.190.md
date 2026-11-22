# IPD Package Management — v0.8.190

- Added clinic-scoped IPD package catalogue with create/edit, category, package price, included stay days, doctor rounds/day and inclusion flags.
- Added active admission package assignment and applied-package register.
- Successful admission submission takes the admin to the Packages tab with the newly created admission preselected when the RPC returns its admission id.
- Added RLS policies and clinic/admission/patient scope validation.
- Apply migration `20261122210000_ipd_package_management.sql` before using package management.
- Package amount is stored as a package assignment snapshot. It is not automatically posted into the invoice/charge ledger in this release; existing billing workflows remain unchanged.
