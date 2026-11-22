# IPD Diagnostic Bill Button Fix — v0.8.110

## Root cause found
The Create diagnostic bill button was disabled using `!diagnosticPatient` unconditionally. In IPD mode, the form correctly selects `diagnosticAdmission` and intentionally clears `diagnosticPatient`, so the button remained disabled for every IPD admission. This blocked both paid-now and credit bill creation before the RPC was called.

## Fix
The button now validates the selected field for the current mode:
- OPD: requires `diagnosticPatient`
- IPD: requires `diagnosticAdmission`
- Both modes require at least one selected test and no active save operation.

The previously added IPD RPC call still passes `p_admission_id`; OPD still passes `p_patient_id`.

## Verification
- Static assertion confirms the old unconditional `!diagnosticPatient` gate is removed from the submit button and the mode-aware condition is present.
- ZIP integrity checked after packaging.
- Full Next.js build and live browser payment flow not run because node_modules are not installed in this extracted package.
