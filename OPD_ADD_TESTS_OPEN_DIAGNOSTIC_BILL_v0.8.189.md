# OPD Add Tests & Bill — v0.8.189

- OPD queue “Add tests & bill” now opens Billing with the selected patient and `open_diagnostic=1`.
- Billing detects that handoff, preselects the patient, opens the Diagnostic Billing modal after patient records load, and removes the one-time open flag from the URL to prevent reopening on refresh.
- Existing standalone Billing navigation and Diagnostic Bill button behavior remain unchanged.
- No database migration required.
