# Anaira Healthcare v0.8.126 — OPD print header correction

- Replaced the conflicting legacy print header cascade with a final, high-specificity A4 print rule set for plain-paper OPD slips.
- Forces the generated letterhead wrapper and header to white, removes inherited pseudo-element paint and wrapper spacing, and forces all letterhead text to readable dark navy.
- Defines a single A4 portrait page box with controlled padding and a compact header row.
- Leaves the pre-printed letterhead mode and normal screen layout unchanged.

Validation: source/static checks only. Browser print preview and live server behavior must still be verified after replacing the deployed source and restarting the Next.js process.
