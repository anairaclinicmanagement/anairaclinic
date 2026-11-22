# OPD Header Accent Setting Removal — v0.8.100

- Removed the OPD `Header accent colour` control from Clinic & Hospital Settings and OPD registration settings.
- Removed `opd_parchi.primaryColor` from the TypeScript configuration model and default configuration.
- Removed reads of the legacy `opd_parchi.primaryColor` value and stopped persisting it when OPD print settings are saved.
- OPD header preview uses the fixed standard navy colour `#17436d`; branding fields and global facility accent colour remain separate.
- No database migration is required because this setting was stored inside the existing `clinic_profile` JSON object.
