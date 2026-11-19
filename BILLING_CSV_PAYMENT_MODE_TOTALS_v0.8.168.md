# v0.8.168 — Billing CSV payment-mode totals

- Billing & Collection CSV now appends a payment-mode summary after transaction rows.
- Summary includes count and amount for each recorded payment method, grand total and transaction count.
- Per-day CSV download includes the same summary calculated for that day only.
- Only completed payment rows already loaded for the selected billing date range are included.
- UPI remains one method; GPay/PhonePe/Paytm cannot be separated unless stored separately in the source payment data.
