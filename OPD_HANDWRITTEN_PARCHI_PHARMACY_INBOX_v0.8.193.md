# OPD handwritten parchi → Pharmacy inbox — v0.8.193

- Pharmacist role notifications now include OPD visits that have a handwritten parchi attachment.
- Pharmacy has a Doctor Parchis inbox listing clinic-scoped OPD visits with uploaded handwritten images/PDFs.
- Inbox refreshes on entry and every 30 seconds while open; a manual refresh is available.
- Pharmacist can open the source image/PDF and start a medicine issue with the linked patient preselected.
- Uploading an image does not convert handwriting into a structured prescription or automatically dispense medicines. Staff must verify the prescription and enter matching catalogue medicines before billing/dispensing.
- No new migration required; uses the existing `opd_visits.handwritten_parchi_image_url` field and existing pharmacist SELECT access.
