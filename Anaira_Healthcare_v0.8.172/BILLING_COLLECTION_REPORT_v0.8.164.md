# Billing & Collection Report — v0.8.164

- Added payment-level billing report to Reports & Analytics.
- Uses completed `payments` rows within the selected date range based on `paid_at`.
- Shows collection totals grouped by Cash, UPI, Card, Bank Transfer, Insurance and Other.
- Shows transaction rows with patient, UHID, invoice number, payment mode, amount, reference and status.
- Added CSV export for payment transactions.
- UPI remains a single payment mode; GPay/PhonePe/Paytm are not inferred from UPI records.
- No database schema or live Supabase data changes.
