# OPD Blue Gradient Root-Cause Fix — v0.8.95

- Removed the original `linear-gradient(...)` declaration from `.opd-workspace .opd-parchi-paper .opd-letterhead-generated`, rather than relying only on lower-specificity overrides.
- Generated header is now white with dark clinic text and a thin divider in plain A4 mode.
- Pre-printed mode continues to hide generated branding and use its explicit white spacer.
- No Supabase migration required.
- Static checks and ZIP integrity checked; browser print preview/full Next.js build not run in this environment.
