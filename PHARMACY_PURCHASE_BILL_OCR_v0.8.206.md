# Pharmacy Purchase Bill Scan — v0.8.206

## Included
- Purchase workspace accepts JPG, PNG and WEBP invoice photos from camera/gallery.
- Authenticated Next.js API route validates the Supabase access token before OCR.
- Google Cloud Vision document OCR extracts invoice text server-side.
- UI pre-fills supplier (only when an existing supplier name is found), invoice number/date, and medicine rows that can be matched to the current clinic medicine catalogue.
- Extracted OCR text remains visible for manual correction.
- Purchase rows now include free quantity; free units are included in stock receipt payload but excluded from invoice amount.
- Duplicate supplier invoice check blocks repeat GRN posting for the same clinic + supplier + invoice number.
- Final stock posting continues through the existing `receive_pharmacy_grn_to_store` RPC, preserving its transactional GRN/store-stock/supplier-ledger workflow.

## Required deployment configuration
Set `GOOGLE_CLOUD_VISION_API_KEY` as a server-only environment variable in Vercel and redeploy. Do not expose it as a `NEXT_PUBLIC_` variable.
The key must have Google Cloud Vision API enabled and billing/quota configured.

## Safety / limitations
- OCR output is a draft, never an automatic stock posting. A staff member must review supplier, invoice number/date, medicine mapping, batch, expiry, quantity, free quantity and rates before pressing Save Purchase.
- Medicine lines that cannot be matched to the clinic catalogue are not auto-added; add/map them manually.
- Initial scan supports JPG, PNG and WEBP images up to 10 MB. PDF upload is not supported in this version; convert the PDF page to an image first.
- The uploaded photo is processed for OCR and is not persisted as an attachment in this release.
- OCR quality depends on image clarity and invoice layout. Validate every extracted field.
- No database migration is required for the UI OCR path; it reuses the existing goods receipt RPC and tables.
