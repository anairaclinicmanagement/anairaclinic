import type { Metadata } from 'next';
import './globals.css';
import AppShell from '@/components/AppShell';
export const metadata: Metadata = { title: 'Anaira Clinic Management System', description: 'Standalone offline-first clinic management by Anaira.' };
export default function RootLayout({children}:{children:React.ReactNode}) { return <html lang="en"><body><AppShell>{children}</AppShell></body></html>; }
