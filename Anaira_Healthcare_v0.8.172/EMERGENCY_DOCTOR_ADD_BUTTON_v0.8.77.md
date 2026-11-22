# Emergency Add Doctor button — v0.8.77

- Added an `Add Doctor` button to the Emergency / Casualty page header.
- Added an `Add Doctor / Doctor Details` button beside the responsible emergency doctor selector.
- Both buttons open `Doctors & staff accounts` (`/staff`), where a clinic owner/admin can create a Doctor / Consultant staff login and enter full name, specialty, medical registration number, room, phone, email and login credentials.
- After creating the doctor, return to Emergency / Casualty and press Refresh; the new active staff profile will be available in the responsible-doctor dropdown.
- No database migration required; uses the existing staff profile creation workflow.
