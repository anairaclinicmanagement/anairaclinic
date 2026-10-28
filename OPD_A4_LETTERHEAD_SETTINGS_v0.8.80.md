# OPD A4 Letterhead & Print Settings — v0.8.80

- Added clinic-specific OPD parchi print configuration inside Clinic & Hospital Settings.
- Supports plain A4 paper with generated clinic header and pre-printed letterhead with generated header suppressed.
- Configurable header fields: clinic name, logo, address, phone, email, registration number, website and accent colour.
- Reworked OPD parchi print CSS for A4 portrait, removed the unnecessary outer document border, and retained patient/clinical sections and signature area.
- Settings are stored under `clinics.clinic_profile.opd_parchi`; no database migration is required.
- Static verification passed. Full Next.js build, browser print preview, and live Supabase verification must still be run in the project environment.
