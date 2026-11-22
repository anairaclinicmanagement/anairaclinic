# OPD Handwritten Parchi Attachment — v0.8.187

- Added an upload control to the existing “Write / edit same parchi” doctor workflow.
- Supports JPG, PNG, WEBP and PDF up to 10 MB.
- Uploads the attachment to the existing clinic-assets bucket under a clinic/visit-specific path and saves its URL on the matching `opd_visits` row.
- Added a View uploaded parchi preview modal and a full-size/open link from the OPD visit view.
- Added migration `20261122200000_opd_handwritten_parchi_attachment.sql`.
- Apply the migration before using uploads. Existing visits remain unchanged; no sample records are inserted.
