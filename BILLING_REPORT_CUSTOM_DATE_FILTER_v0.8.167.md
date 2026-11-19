# Billing Report Custom Date Filter — v0.8.167

- Added independent Billing From Date and Billing To Date controls inside Reports & Analytics > Billing & Collection Report.
- Billing report defaults to today's date in Asia/Kolkata (IST).
- Selecting the same date in both fields generates a single-day report; selecting different dates generates a date-range report.
- Added Show Billing Report and Today's Billing actions.
- Payment query and CSV filename now use the billing-specific date range, independently of department/shift report dates.
- Existing payment-mode summary, transaction table, and CSV export remain.

No database schema or live data changes.
