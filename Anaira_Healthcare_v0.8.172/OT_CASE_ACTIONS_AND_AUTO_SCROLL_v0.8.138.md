# Operation Theatre case workflow — v0.8.138

- Selecting **Open case** now automatically scrolls the Surgical Case Record into view and highlights it.
- Added explicit **Start Operation**, **Move to Recovery & Post Bill**, and **Complete Case** actions according to the current case status.
- Start Operation requires consent, patient identity, fasting and allergy review checkboxes before allowing the status transition.
- Recovery transition saves clinical details and invokes the existing idempotent IPD charge-posting RPC. Existing posted charges are not duplicated.
- The existing status selector and full clinical documentation form remain available.

No database schema change is required; this release uses the existing OT clinical update and IPD charge-posting RPCs.
