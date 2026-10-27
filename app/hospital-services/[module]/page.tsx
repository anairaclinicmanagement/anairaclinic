import HospitalWorkbench from '@/components/HospitalWorkbench';
export default async function HospitalModulePage({params}:{params:Promise<{module:string}>}){const {module}=await params;return <HospitalWorkbench moduleKey={module}/>}
