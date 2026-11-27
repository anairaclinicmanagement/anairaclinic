import { NextRequest, NextResponse } from 'next/server';

export const runtime = 'nodejs';
export const maxDuration = 60;

const MAX_BYTES = 15 * 1024 * 1024;
const ALLOWED_TYPES = new Set(['image/jpeg', 'image/png', 'image/webp', 'application/pdf']);
const EXTRACTION_PROMPT = `You extract supplier purchase invoices for a hospital pharmacy. Read the supplied bill and return ONLY valid JSON (no markdown) with this schema: {"supplier_name":"","invoice_number":"","invoice_date":"YYYY-MM-DD or empty","currency":"INR","items":[{"medicine_name":"","salt_composition":"","strength":"","batch_number":"","expiry_date":"YYYY-MM-DD or empty","quantity":null,"free_quantity":0,"purchase_rate":null,"sale_rate":null,"gst_percent":null,"line_total":null}],"subtotal":null,"tax_total":null,"grand_total":null,"raw_text":""}. Never guess unreadable values: use empty string or null. Distinguish quantity from free quantity, purchase rate from MRP/sale rate, and batch from invoice number. Preserve medicine names as printed. Dates must be normalized only when unambiguous. This is an untrusted draft; do not approve or post anything.`;

function jsonFromText(value: string): Record<string, any> | null {
  const cleaned = value.replace(/^```(?:json)?\s*/i, '').replace(/\s*```$/, '').trim();
  try { const parsed = JSON.parse(cleaned); return parsed && typeof parsed === 'object' ? parsed : null; } catch { return null; }
}

function asText(data: Record<string, any>, fallback = ''): string {
  const rows = Array.isArray(data.items) ? data.items.map((x: any) =>
    [x.medicine_name, x.salt_composition ? `Salt: ${x.salt_composition}` : '', x.strength, x.batch_number ? `Batch: ${x.batch_number}` : '', x.expiry_date ? `Expiry: ${x.expiry_date}` : '', x.quantity != null ? `Qty: ${x.quantity}` : '', x.free_quantity ? `Free Qty: ${x.free_quantity}` : '', x.purchase_rate != null ? `Rate: ${x.purchase_rate}` : '', x.sale_rate != null ? `MRP: ${x.sale_rate}` : ''].filter(Boolean).join(' | ')
  ) : [];
  return [
    data.supplier_name ? `Supplier: ${data.supplier_name}` : '',
    data.invoice_number ? `Invoice No: ${data.invoice_number}` : '',
    data.invoice_date ? `Invoice Date: ${data.invoice_date}` : '',
    ...rows,
    data.grand_total != null ? `Grand Total: ${data.grand_total}` : '',
    data.raw_text || fallback,
  ].filter(Boolean).join('\n');
}

async function extractWithGemini(apiKey: string, mimeType: string, base64: string) {
  const model = process.env.GEMINI_MODEL || 'gemini-2.5-flash';
  const response = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(model)}:generateContent?key=${encodeURIComponent(apiKey)}`, {
    method: 'POST', headers: { 'Content-Type': 'application/json' }, cache: 'no-store',
    body: JSON.stringify({ contents: [{ parts: [{ text: EXTRACTION_PROMPT }, { inline_data: { mime_type: mimeType, data: base64 } }] }], generationConfig: { temperature: 0.1, responseMimeType: 'application/json' } }),
  });
  const body = await response.json().catch(() => ({}));
  if (!response.ok) throw new Error(body?.error?.message || `Gemini request failed (${response.status}).`);
  const content = body?.candidates?.[0]?.content?.parts?.map((p: any) => p.text || '').join('') || '';
  const parsed = jsonFromText(content);
  if (!parsed) throw new Error('Gemini returned an unreadable extraction response.');
  return parsed;
}

async function extractOcrTextWithVision(apiKey: string, mimeType: string, base64: string) {
  if (mimeType === 'application/pdf') throw new Error('Vision OCR fallback accepts images only; PDF needs Gemini to be available.');
  const response = await fetch(`https://vision.googleapis.com/v1/images:annotate?key=${encodeURIComponent(apiKey)}`, {
    method: 'POST', headers: { 'Content-Type': 'application/json' }, cache: 'no-store',
    body: JSON.stringify({ requests: [{ image: { content: base64 }, features: [{ type: 'DOCUMENT_TEXT_DETECTION' }], imageContext: { languageHints: ['en', 'hi'] } }] }),
  });
  const body = await response.json().catch(() => ({}));
  if (!response.ok) throw new Error(body?.error?.message || `OCR fallback failed (${response.status}).`);
  const text = body?.responses?.[0]?.fullTextAnnotation?.text || '';
  if (!text.trim()) throw new Error('OCR could not detect readable text.');
  return text;
}

async function structureWithGroq(apiKey: string, ocrText: string) {
  const model = process.env.GROQ_MODEL || 'llama-3.3-70b-versatile';
  const response = await fetch('https://api.groq.com/openai/v1/chat/completions', {
    method: 'POST', headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${apiKey}` }, cache: 'no-store',
    body: JSON.stringify({ model, temperature: 0.1, response_format: { type: 'json_object' }, messages: [{ role: 'system', content: EXTRACTION_PROMPT }, { role: 'user', content: `Structure the following OCR text. Do not infer missing values:\n\n${ocrText.slice(0, 30000)}` }] }),
  });
  const body = await response.json().catch(() => ({}));
  if (!response.ok) throw new Error(body?.error?.message || `Groq request failed (${response.status}).`);
  const content = body?.choices?.[0]?.message?.content || '';
  const parsed = jsonFromText(content);
  if (!parsed) throw new Error('Groq returned an unreadable extraction response.');
  parsed.raw_text = parsed.raw_text || ocrText;
  return parsed;
}

export async function POST(request: NextRequest) {
  try {
    const auth = request.headers.get('authorization') || '';
    const token = auth.startsWith('Bearer ') ? auth.slice(7) : '';
    const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
    const anonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
    if (!token || !supabaseUrl || !anonKey) return NextResponse.json({ error: 'Please sign in again before scanning a purchase bill.' }, { status: 401 });
    const userResponse = await fetch(`${supabaseUrl}/auth/v1/user`, { headers: { apikey: anonKey, Authorization: `Bearer ${token}` }, cache: 'no-store' });
    if (!userResponse.ok) return NextResponse.json({ error: 'Your session is not valid. Please sign in again.' }, { status: 401 });

    const form = await request.formData();
    const file = form.get('file');
    if (!(file instanceof File)) return NextResponse.json({ error: 'Choose a supplier bill first.' }, { status: 400 });
    if (!ALLOWED_TYPES.has(file.type)) return NextResponse.json({ error: 'Supported files: JPG, PNG, WEBP and PDF.' }, { status: 415 });
    if (file.size > MAX_BYTES) return NextResponse.json({ error: 'Bill must be 15 MB or smaller.' }, { status: 413 });
    const base64 = Buffer.from(await file.arrayBuffer()).toString('base64');

    const geminiKey = process.env.GEMINI_API_KEY;
    const groqKey = process.env.GROQ_API_KEY;
    const visionKey = process.env.GOOGLE_CLOUD_VISION_API_KEY;
    const failures: string[] = [];

    if (geminiKey) {
      try {
        const data = await extractWithGemini(geminiKey, file.type, base64);
        return NextResponse.json({ provider: 'gemini', mode: 'primary', data, text: asText(data), requiresReview: true });
      } catch (error) { failures.push(`Gemini: ${error instanceof Error ? error.message : 'failed'}`); }
    } else failures.push('Gemini API key is not configured.');

    if (visionKey && groqKey) {
      try {
        const ocrText = await extractOcrTextWithVision(visionKey, file.type, base64);
        const data = await structureWithGroq(groqKey, ocrText);
        return NextResponse.json({ provider: 'groq', ocrProvider: 'google-vision', mode: 'backup', data, text: asText(data, ocrText), requiresReview: true, warning: 'Backup extraction used OCR text. Verify all fields against the original bill.' });
      } catch (error) { failures.push(`Groq/OCR backup: ${error instanceof Error ? error.message : 'failed'}`); }
    } else failures.push('Groq backup requires GROQ_API_KEY and GOOGLE_CLOUD_VISION_API_KEY.');

    return NextResponse.json({ error: `AI bill extraction is unavailable. ${failures.join(' ') } You can enter the purchase manually; no stock has been changed.` }, { status: 503 });
  } catch (error) {
    return NextResponse.json({ error: error instanceof Error ? error.message : 'Purchase bill extraction failed.' }, { status: 500 });
  }
}
