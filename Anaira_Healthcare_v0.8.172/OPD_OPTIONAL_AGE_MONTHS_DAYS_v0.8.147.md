# v0.8.147 — OPD optional age months and days

- Age Months and Age Days are explicitly marked optional in the OPD registration UI.
- Blank month/day values remain null and are accepted by the existing age-details RPC and nullable database columns.
- Existing years-only, months-only/days-only, mixed age, and exact DOB entry remain supported.
- No new database migration is required; v0.8.146 already applied nullable columns and RPC validation.
