# Casa Care

Home services marketplace app (React + Supabase).

## Cursor Cloud specific instructions

### Project overview

Single-page React frontend (`casa-care-app.jsx`) backed by a Supabase PostgreSQL database. The schema is defined in `supabase/migrations/001_casa_care_schema.sql`. There is no separate backend service; all server logic is handled by Supabase (auth, RLS, triggers).

### Running the app

```bash
npm run dev      # Vite dev server at http://localhost:5173
npm run build    # Production build to dist/
npm run lint     # ESLint
```

### Environment variables

The app reads Supabase credentials from Vite env vars. Create a `.env.local` to connect to a real Supabase project:

```
VITE_SUPABASE_URL=https://<project-ref>.supabase.co
VITE_SUPABASE_ANON_KEY=<anon-key>
```

Without these, the app renders all UI but Supabase API calls (auth, data) will fail with network errors — this is expected.

### Gotchas

- The original `casa-care-app.jsx` was written for Create React App (`process.env.REACT_APP_*`). It has been adapted to Vite (`import.meta.env.VITE_*`). If new env vars are added, use the `VITE_` prefix.
- The Supabase client constructor requires a valid URL format and a JWT-like anon key; plain placeholder strings like `'YOUR_SUPABASE_URL'` will crash `createClient`. The current fallbacks (`https://placeholder.supabase.co`) are intentional — they pass validation but won't connect.
- Phone OTP auth (the only auth method) requires a configured SMS provider (Twilio/Vonage) in the Supabase dashboard. Without it, the auth flow won't work even with valid Supabase credentials.
- The SQL migration file uses some MySQL-isms (`DATE_FORMAT`, `RAND`, `LPAD`, `CAST ... AS CHAR`) in the `service_requests.ticket_id` default. These will fail on a real Supabase (PostgreSQL) database; use PostgreSQL equivalents if running the migration.
