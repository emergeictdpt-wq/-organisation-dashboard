/* ============================================================================
   Supabase client configuration
   ----------------------------------------------------------------------------
   1. Create a project at https://supabase.com
   2. Go to: Project Settings -> Data API  (or "API" on older dashboards)
   3. Copy the "Project URL" and the "anon public" key and paste them below.
      Never paste the "service_role" key here — that key must stay server-side.
   ============================================================================ */
const SUPABASE_URL = 'https://azqthzjzfldobylhfffr.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImF6cXRoemp6Zmxkb2J5bGhmZmZyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODc3OTk0ODksImV4cCI6MjEwMzM3NTQ4OX0.0YQupg-sJWMOG_PBskmSDs9b3i8j5Brnef_JO-PCsjU';

if (SUPABASE_URL.includes('https://azqthzjzfldobylhfffr.supabase.co') || SUPABASE_ANON_KEY.includes('eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImF6cXRoemp6Zmxkb2J5bGhmZmZyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODc3OTk0ODksImV4cCI6MjEwMzM3NTQ4OX0.0YQupg-sJWMOG_PBskmSDs9b3i8j5Brnef_JO-PCsjU')) {
  console.warn(
    '[Supabase] supabase-config.js still has placeholder values. ' +
    'Edit SUPABASE_URL and SUPABASE_ANON_KEY at the top of that file.'
  );
}

const supabaseClient = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
  auth: {
    persistSession: true,
    autoRefreshToken: true,
    detectSessionInUrl: true
  }
});
