# Billing invoice creation layout — v0.8.179

- Reworked the Create Invoice panel to follow the Pehal Grewal Hospital billing reference: patient information, billing details, charge particulars, discount/tax summary, payment mode, and Generate Invoice action.
- Added quantity × rate calculation with percentage discount and tax; amount submitted to the existing `create_clinic_invoice` RPC is the calculated final amount.
- Preserved the existing invoice creation RPC and payment workflow; no database migration is required.
- Important scope: the existing RPC accepts one description and one total amount. This UI therefore creates one charge-head line per invoice; it does not claim to persist a multi-line itemised invoice through this RPC.
