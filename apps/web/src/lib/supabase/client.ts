import { createBrowserClient } from "@supabase/ssr";

// Singleton-style: reuses the same Supabase instance across components, preventing duplicate realtime connections
export function createClient() {
  return createBrowserClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
  );
}
