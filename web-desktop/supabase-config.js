// Supabase Configuration — Expense OS
// ============================================================
// Live Supabase Project Credentials
// ============================================================

const SUPABASE_URL = "https://gtwirhvswhslljbfvnoe.supabase.co";
const SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd0d2lyaHZzd2hzbGxqYmZ2bm9lIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODU3NjQyOTAsImV4cCI6MjEwMTM0MDI5MH0.b9oppdNo7S6RYizvaC5ZgRWuSjceqZMFXT63mXid1tQ";

const isSupabaseConfigured = Boolean(
  SUPABASE_URL && 
  SUPABASE_ANON_KEY && 
  !SUPABASE_URL.includes("YOUR_") && 
  !SUPABASE_ANON_KEY.includes("YOUR_")
);

// Capture the CDN library reference IMMEDIATELY before any getter overwrites it
let _supabaseCdnLib = null;

// Check if window.supabase is still the raw CDN library (not yet overwritten by a getter)
const _supaDesc = Object.getOwnPropertyDescriptor(window, 'supabase');
if (_supaDesc && !_supaDesc.get && _supaDesc.value && typeof _supaDesc.value.createClient === 'function') {
  _supabaseCdnLib = _supaDesc.value;
} else if (window.supabase && typeof window.supabase.createClient === 'function') {
  _supabaseCdnLib = window.supabase;
} else if (window.supabaseJS && typeof window.supabaseJS.createClient === 'function') {
  _supabaseCdnLib = window.supabaseJS;
}
// Store a safe backup reference for other scripts
if (_supabaseCdnLib) window._supabaseCdnRef = _supabaseCdnLib;

function getSupabaseClient() {
  if (!isSupabaseConfigured) return null;
  if (window._supabaseInstance) return window._supabaseInstance;

  let creator = null;
  if (_supabaseCdnLib && typeof _supabaseCdnLib.createClient === 'function') {
    creator = _supabaseCdnLib.createClient;
  } else if (window.supabaseJS && typeof window.supabaseJS.createClient === 'function') {
    creator = window.supabaseJS.createClient;
  } else if (typeof createClient === 'function') {
    creator = createClient;
  }

  if (creator) {
    try {
      window._supabaseInstance = creator(SUPABASE_URL, SUPABASE_ANON_KEY);
      return window._supabaseInstance;
    } catch(e) {
      console.warn('Supabase client creation error:', e);
    }
  }
  return null;
}

// Expose getSupabaseClient and supabaseClient globally
window.getSupabaseClient = getSupabaseClient;

try {
  let _cachedClient = null;
  Object.defineProperty(window, 'supabaseClient', {
    get: function() {
      if (_cachedClient) return _cachedClient;
      _cachedClient = getSupabaseClient();
      return _cachedClient;
    },
    configurable: true
  });

  Object.defineProperty(window, 'supabase', {
    get: function() {
      if (_cachedClient) return _cachedClient;
      _cachedClient = getSupabaseClient();
      return _cachedClient;
    },
    configurable: true
  });
} catch(e) {}
