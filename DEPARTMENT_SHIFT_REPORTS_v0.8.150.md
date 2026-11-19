# Department-wise and shift-wise reports — v0.8.150

- Replaced the basic reports screen with department/shift operational reporting.
- Date range filters use India local time (Asia/Kolkata).
- Shift buckets: Morning 06:00–13:59, Evening 14:00–21:59, Night 22:00–05:59.
- Department activity sources: OPD appointments, IPD admissions (admission department), laboratory orders (department_key), radiology orders, OT cases, emergency arrivals and nursing records.
- Shows activity counts by department and shift, totals, existing clinic KPI cards and CSV export.
- Invoice summary excludes invoices linked into another consolidated invoice to avoid duplicate financial totals.
- Does not claim to be a staff-attendance roster or audited cash closing report; those require dedicated clock-in/shift-close records.

Validation: ZIP integrity and project static verification. Production build not run because node_modules is not included in the delivered source archive.
