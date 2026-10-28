# BUILD TYPESCRIPT EDGE FUNCTION EXCLUSION FIX v0.8.116

## Root cause
Next.js TypeScript checking was picking up Supabase Edge Function files under a nested `anaira_v0816_patch/supabase/functions/...` path. Those functions intentionally use Deno URL imports (`https://esm.sh/...` and `jsr:`), which are not resolvable by the Next.js/Node TypeScript build.

## Fix
Updated `tsconfig.json` exclude patterns to exclude `**/supabase/functions/**` regardless of whether the app is at the repository root or nested one directory down. Supabase Edge Functions remain in the project and can still be deployed with the Supabase CLI; this only keeps Next.js `tsc` from type-checking Deno-specific files.

## Verification
JSON parse and ZIP integrity checked. A full `next build` was not run in this environment because project dependencies are not installed.
