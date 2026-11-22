# OPD Print root cause — v0.8.120

## Exact source locations
- `app/opd/page.tsx`, around lines 38–53: current rendered structure uses `article.opd-parchi-paper`, child `.opd-parchi-letterhead-wrap.opd-generated-letterhead`, and inner `.opd-letterhead-generated`.
- `app/globals.css`, around lines 1051–1067: legacy print styles still target `.opd-parchi-header`, and force white letterhead text in one print block.
- `app/globals.css`, around lines 1117–1130 and 1426–1469: further legacy styles target `.opd-parchi-header`; one old rule also adds a thick theme-coloured bottom border.
- `app/globals.css`, around lines 1663–1718: later cleanup still targets `.opd-parchi-header` instead of the actual wrapper class.

## Why previous fixes missed
The JSX no longer renders `.opd-parchi-header`. The actual wrapper is `.opd-parchi-letterhead-wrap` (also `.opd-generated-letterhead`). Therefore several high-specificity print overrides were aimed at a non-existent element.

## Fix
Added a final print-only override using the actual JSX class names. It neutralizes backgrounds, gradients, filters, pseudo-elements and legacy borders on the actual OPD paper/header. Plain-paper mode retains the generated clinic identity on white; pre-printed mode retains only the 76.2mm white spacer and hides generated letterhead.

## Verification
Archive integrity verified. Production build and browser print preview must still be run in the project environment.
