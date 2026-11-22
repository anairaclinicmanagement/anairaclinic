# Build cleanup — v0.8.195

- Excluded nested legacy extracted project folders matching `Anaira_Healthcare_v*/**` from TypeScript project checking. This addresses stale nested project sources (such as `Anaira_Healthcare_v0.8.172/app/patients/page.tsx`) being picked up by the root tsconfig.
- Changed unsupported `align-items: end` CSS alignment values to `align-items: flex-end` to remove the Autoprefixer mixed-support warning.
- No database migration required.

Recommended local cleanup: delete any old nested `Anaira_Healthcare_v0.8.172` folder inside the project root and install/extract the latest release into a clean directory before building.
