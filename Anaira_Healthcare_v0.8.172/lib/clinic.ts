'use client';
const ACTIVE_CLINIC_KEY = 'anaira-clinic-active-id';
export function getActiveClinicId(): string | null {
  if (typeof window === 'undefined') return null;
  return window.localStorage.getItem(ACTIVE_CLINIC_KEY);
}
export function setActiveClinicId(id: string) {
  if (typeof window !== 'undefined') window.localStorage.setItem(ACTIVE_CLINIC_KEY, id);
}
