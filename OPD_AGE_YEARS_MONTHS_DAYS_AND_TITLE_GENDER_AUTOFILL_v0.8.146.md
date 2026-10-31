# v0.8.146 — OPD age precision and title-to-gender defaults

- Selecting Mr. or Master defaults gender to male.
- Selecting Miss, Mrs. or Ms. defaults gender to female. Gender remains editable.
- New patient intake accepts age in years, months and days, or an exact date of birth.
- Age entered without DOB is converted to a calendar DOB for existing clinical workflows and stored with its original years/months/days plus the age-recorded date.
- OPD parchi prints age as Y / M / D.
- Database migration adds age_months, age_days and age_recorded_on (if missing), validates ranges and creates the clinic-scoped set_patient_age_details RPC.
- Migration applied to the connected Supabase project.
