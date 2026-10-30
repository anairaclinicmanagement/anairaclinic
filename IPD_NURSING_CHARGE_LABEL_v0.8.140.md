# IPD Nursing Charge UI — v0.8.140

- Made the existing `nursing` IPD charge category explicit as **Nurse / Nursing charge**.
- Provider field now prompts for Nurse / staff name when Nursing is selected, Doctor name for doctor rounds, and generic provider for other charge types.
- Uses the existing `record_ipd_charge` RPC and `nursing` enum/check value; no database migration required.
- Charge remains in the admission running ledger and can be included in the IPD final bill through the existing workflow.
