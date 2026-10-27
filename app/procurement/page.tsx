'use client';
import AdvancedOperations from '@/components/AdvancedOperations';

/**
 * Procurement coordination work queue.
 * This route is a work-item register, not a full purchase-order/GRN/accounting engine.
 */
export default function ProcurementPage() {
  return <AdvancedOperations initialModule="procurement" />;
}
