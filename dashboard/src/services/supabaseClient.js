import { createClient } from '@supabase/supabase-js';

// Default / fallback keys - can be set via .env (VITE_SUPABASE_URL, VITE_SUPABASE_ANON_KEY)
const SUPABASE_URL = import.meta.env.VITE_SUPABASE_URL || 'https://xpphmiajwjkcxtxitcex.supabase.co';
const SUPABASE_ANON_KEY = import.meta.env.VITE_SUPABASE_ANON_KEY || 'sb_publishable_7cqahorS_JAw4601eqpQkA_xPgA3YZL';

export const supabase = (SUPABASE_URL && SUPABASE_ANON_KEY)
  ? createClient(SUPABASE_URL, SUPABASE_ANON_KEY)
  : null;

export const isSupabaseConfigured = () => Boolean(supabase);

export async function fetchDriverProfiles(driverIds) {
  if (!supabase || driverIds.length === 0) return {};
  let { data, error } = await supabase
    .from('users')
    .select('id, full_name, avatar_url')
    .in('id', driverIds);
  if (error && String(error.message || '').includes('avatar_url')) {
    ({ data, error } = await supabase
      .from('users')
      .select('id, full_name')
      .in('id', driverIds));
  }
  if (error) throw error;
  return Object.fromEntries((data || []).map((profile) => [profile.id, profile]));
}
