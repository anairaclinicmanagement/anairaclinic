import type { Metadata } from 'next';
import './globals.css';
import AppShell from '@/components/AppShell';
export const metadata: Metadata = { title: 'Anaira Clinic Management', description: 'Anaira Clinic Management — Powered by Anaira Graphics & Digital Solution.' };
export default function RootLayout({children}:{children:React.ReactNode}) { return <html lang="en"><body><AppShell>{children}</AppShell></body></html>; }
