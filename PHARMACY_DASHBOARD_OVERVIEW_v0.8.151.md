# Anaira Healthcare v0.8.151 — Pharmacy Business Dashboard

## Reference-inspired dashboard
- Redesigned Pharmacy Overview based on the supplied Localwell dashboard reference: compact KPI cards, sales trend, stock valuation, customer/invoice summary, collection and outstanding panel, stock health and stock review table.
- Dashboard loads pharmacy invoice history after the active clinic membership is resolved.
- Sales/collection figures use non-consolidated, non-cancelled/non-void pharmacy invoices. Last-30-day figures use invoice creation dates.
- Stock value is estimated from current batch quantity × purchase rate.
- Expiry/low-stock figures are computed from live inventory batches and medicine reorder levels.
- Customer count is distinct patient IDs in the pharmacy invoice history.

## Accuracy notes
- Cash-vs-UPI-vs-cheque breakdown is not shown because the current page's invoice query does not retrieve payment-method transaction rows.
- Net profit and purchase-period trend are not shown as verified figures because there is no reliable COGS/purchase-invoice ledger in the current pharmacy page data.
- "Stock review" list is a current-stock shortlist, not a proven slow-moving ranking; sales-by-product history is required to calculate slow-moving products.

## Validation
- Static project verification only. Run `npm run typecheck` and `npm run build` in the target environment.
