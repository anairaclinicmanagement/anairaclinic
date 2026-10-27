export type PatientRecord = { id: string; clinic_id?: string; uhid: string; first_name: string; middle_name?: string|null; last_name?: string|null; full_name: string; phone?: string|null; gender?: string|null; date_of_birth?: string|null; created_at?: string; address?: unknown; allergies?: string[]; medical_alerts?: string|null };
export function patientFromRow(row: any): PatientRecord {
  const full_name = [row.first_name, row.middle_name, row.last_name].filter(Boolean).join(' ').trim() || row.full_name || 'Unnamed patient';
  return { ...row, full_name };
}
export function patientNamePayload(fullName: string) {
  const parts = fullName.trim().split(/\s+/).filter(Boolean);
  return { first_name: parts[0] || '', middle_name: parts.length > 2 ? parts.slice(1, -1).join(' ') : null, last_name: parts.length > 1 ? parts[parts.length - 1] : null };
}
export function newUhid() { return `AC-${new Date().getFullYear()}-${crypto.randomUUID().slice(0, 8).toUpperCase()}`; }
