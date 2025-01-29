/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_SUPABASE_PROJECT_ID: string;
  readonly VITE_SUPABASE_URL: string;
  // Add other env vars here
}

interface ImportMeta {
  readonly env: ImportMetaEnv
} 