# IPD Admission Popup — Back to IPD Button (v0.8.177)

- Added a clearly labelled **Back to IPD** action beside the patient search field in the New Admission header.
- Clicking it closes the admission workspace and returns to the existing IPD page without navigating away or submitting the form.
- The current admission form state is retained if the user reopens the popup during the same page session.
- Kept the existing close control in the top application bar.

Validation: source-level JSX/TSX transpilation and project verification run after packaging. Full dependency-based build and live browser/Supabase testing remain environment-dependent.
