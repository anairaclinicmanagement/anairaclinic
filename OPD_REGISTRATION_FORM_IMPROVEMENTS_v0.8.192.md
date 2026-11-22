# OPD Registration Form Improvements — v0.8.192

- Added General & Laparoscopic Surgery to OPD department options.
- Replaced separate Father Name and Husband Name inputs with one relationship selector and one name field. The selected value is persisted to the existing father_name or husband_name patient field through the existing registration-details RPC.
- Replaced separate years/months/days inputs with one age input and a unit selector (Years, Months, Days). The selected unit is mapped to the existing patient age RPC fields and DOB calculation.
- No database migration required.
