# Reports & Analytics Core Navigation — v0.8.158

- Reports & Analytics is treated as a core workspace navigation item and is no longer hidden by clinic plan/module entitlements.
- Reports & Analytics is included in the role navigation allow-list for all explicitly listed clinic roles, including reception, pharmacy, laboratory, and radiology technician roles.
- Desktop sidebar, tablet/laptop sidebar, and mobile navigation continue to render from the shared `visibleLinks` list; the mobile All Menus sheet therefore receives the same Reports & Analytics entry.
- This change affects navigation visibility only. It does not grant new database permissions or bypass page/API authorization.
