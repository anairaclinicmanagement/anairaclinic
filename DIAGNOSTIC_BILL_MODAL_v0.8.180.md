# Diagnostic Bill Modal — v0.8.180

- Removed the always-open diagnostic billing form from the Billing page.
- Added a dedicated **Diagnostic Bill** button on the Billing page.
- Clicking the button opens the existing OPD/IPD diagnostic billing workflow in a modal dialog.
- Added Close control and backdrop-click dismissal (disabled while a bill is being saved).
- After successful bill creation, the modal closes and the latest diagnostic bill remains visible in the Billing page.
- Existing diagnostic RPCs, test selection, discount, payment collection and department worklist release behavior are preserved.
