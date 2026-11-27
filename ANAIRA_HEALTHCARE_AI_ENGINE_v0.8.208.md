# Anaira Healthcare v0.8.208 — Pharmacy AI Engine

## Implemented
- Server-side authenticated purchase-bill extraction endpoint.
- Gemini multimodal extraction is the primary provider for JPG, PNG, WEBP and PDF.
- Groq text-model fallback is wired after Google Cloud Vision OCR extracts text from an image.
- Provider/model selection is configurable through server-only environment variables.
- Strict JSON extraction prompt distinguishes medicine, batch, expiry, sale/purchase rates, quantity and free quantity; unreadable values must remain blank/null.
- Existing purchase form remains the review surface. The response is draft-only and does not call any stock, GRN or supplier-ledger RPC.
- Existing duplicate supplier invoice check and `receive_pharmacy_grn_to_store` approval/posting workflow remain in place.
- Upload control accepts PDF and common bill image formats (15 MB maximum).

## Required server environment variables
- `GEMINI_API_KEY` (required for primary)
- `GEMINI_MODEL` (optional; defaults to `gemini-2.5-flash`)
- `GROQ_API_KEY` (required for Groq backup)
- `GROQ_MODEL` (optional; defaults to `llama-3.3-70b-versatile`)
- `GOOGLE_CLOUD_VISION_API_KEY` (required for image OCR before Groq fallback)

All keys must be configured only in server/Vercel environment variables, never `NEXT_PUBLIC_` variables. Redeploy after setting them.

## Important scope and safety notes
- Groq's configured text model does not itself read image/PDF files. Backup therefore requires Google Cloud Vision OCR for image bills, followed by Groq structuring. PDF backup is not supported in this release; Gemini must be available for PDF extraction.
- A true on-device/local OCR engine is not included in this release. If both providers fail or are unconfigured, staff must enter the bill manually; no automatic stock posting occurs.
- This release does not upload or retain the original bill attachment and does not add a dedicated AI audit table. Do not treat OCR text as an immutable audit record.
- Provider data-use, retention and healthcare privacy terms must be reviewed by the deploying organization before sending real hospital invoices. Consider redacting patient identifiers and unrelated personal data before upload.
- No Supabase migration is included or required by the code changes in this release. Existing GRN tables/RPC and RLS remain the posting authority.
- Production build, live provider calls and end-to-end posting were not certified in this environment.
