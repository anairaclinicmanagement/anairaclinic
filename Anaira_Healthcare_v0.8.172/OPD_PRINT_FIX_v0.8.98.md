# Anaira Healthcare v0.8.98 — OPD Print Header Structural Fix

- Removed the legacy semantic `<header class="opd-parchi-header ...">` from the OPD parchi render path.
- Plain A4 mode uses a dedicated `opd-parchi-letterhead-wrap` element for clinic branding and parchi metadata.
- Pre-printed letterhead mode renders only a 76.2 mm white spacer followed by parchi metadata; it does not render the generated branding container.
- This is a source-level structural fix rather than another background-only override.
- No Supabase migration added.

Validation available in this environment: source structure and ZIP integrity. Browser PDF preview and full Next.js production build were not run.
