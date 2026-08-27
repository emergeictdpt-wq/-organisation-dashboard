# Wiring the Organisation Dashboard to Supabase

This turns `login.html` and `workbench.html` from mockup/localStorage demos into a
real app backed by Supabase: real accounts, real sign-in, and every imported
Excel/CSV file stored in a real database instead of the browser.

## What changed in the code

- **`login.html`** — no more hardcoded demo email/password. It now calls
  Supabase Auth (`signInWithPassword` / `signUp`) and has a toggle to switch
  between "Sign in" and "Create account".
- **`workbench.html`** — no more `localStorage`. Every import, edit-save, and
  delete now reads/writes two Supabase tables (`workbooks` and
  `workbook_sheets`). The page redirects to `login.html` if there's no active
  session, and "Log out" ends the real Supabase session.
- **`supabase-config.js`** *(new)* — the only file with your project's URL and
  public API key. Both HTML files load it.
- **`supabase/schema.sql`** *(new)* — creates the tables, the auto-profile
  trigger, and the security rules. Run it once inside Supabase.

Nothing else in the two HTML files (styling, the spreadsheet grid, filters,
sorting, export-to-xlsx) was touched — only the storage/auth plumbing.

---

## Step 1 — Create a Supabase project

1. Go to https://supabase.com and sign in (or create a free account).
2. Click **New project**.
3. Pick an organization, name the project (e.g. `emerge-dashboard`), set a
   database password (save it somewhere safe — you won't need it for this
   guide, but you will if you ever connect a raw Postgres client), choose a
   region close to your users, and click **Create new project**.
4. Wait ~1–2 minutes for it to finish provisioning.

## Step 2 — Run the database schema

1. In your new project, open the **SQL Editor** (left sidebar).
2. Click **New query**.
3. Open `supabase/schema.sql` from this project, copy the whole file, and
   paste it into the query editor.
4. Click **Run**.
5. Go to **Table Editor** (left sidebar) and confirm you now see three
   tables: `profiles`, `workbooks`, `workbook_sheets` — each should show a
   green "RLS enabled" tag.

This script:
- Creates `profiles` (one row per user), auto-populated whenever someone
  signs up, via a trigger on `auth.users`.
- Creates `workbooks` (one row per imported file — its label, file name,
  active sheet, sort/filter/column-width state).
- Creates `workbook_sheets` (one row per sheet inside a workbook, holding the
  actual grid data as JSON).
- Turns on **Row Level Security** so each signed-in user can only see and
  edit their own workbooks — nobody can query someone else's imported data,
  even though everyone shares the same tables.

## Step 3 — Turn on email/password sign-ups

1. Go to **Authentication → Providers**.
2. Confirm **Email** is enabled (it is by default).
3. Go to **Authentication → Settings** (or **Sign In / Providers → Email**,
   depending on your dashboard version):
   - If you want people to start using the workbench immediately after
     signing up, turn **Confirm email** OFF.
   - If you want them to verify their email first, leave it ON — they'll get
     a confirmation email and `login.html` will tell them to check their
     inbox before signing in.
4. (Optional but recommended for a small internal team) Under
   **Authentication → URL Configuration**, set the **Site URL** to wherever
   you'll host this app (e.g. `https://your-domain.org` or
   `http://localhost:8000` while testing).

## Step 4 — Get your API keys

1. Go to **Project Settings → Data API** (older dashboards call this
   **Settings → API**).
2. Copy the **Project URL** (looks like `https://xxxxxxxx.supabase.co`).
3. Copy the **anon public** key (a long string starting with `eyJ...`).
   Do **not** copy the `service_role` key — that one must never be placed in
   a browser-side file like this.

## Step 5 — Configure the app

1. Open `supabase-config.js` in this project.
2. Replace the two placeholder values:

   ```js
   const SUPABASE_URL = 'https://xxxxxxxx.supabase.co';
   const SUPABASE_ANON_KEY = 'eyJ....your-anon-key....';
   ```
3. Save the file. Both `login.html` and `workbench.html` load this file
   automatically — you only edit credentials in one place.

## Step 6 — Serve the files over HTTP (not file://)

Supabase Auth's session handling needs the page to be served over `http(s)://`,
not opened directly as a local file. Any static server works, for example:

```bash
cd "Organisation Dashboard"
python3 -m http.server 8000
```

Then open `http://localhost:8000/login.html` in your browser.

## Step 7 — Create your first account

1. On the login page, click **Create an account**.
2. Fill in your name, work email, and a password, then submit.
   - If email confirmation is **off**, you're signed in immediately and
     redirected to the Excel Import Desk (`workbench.html`).
   - If email confirmation is **on**, check your inbox, click the
     confirmation link, then come back and sign in normally.
3. Back in Supabase, check **Table Editor → profiles** — you should see a
   new row with your email, created automatically by the trigger.

## Step 8 — Test the workbench end to end

1. From the Excel Import Desk, drag in a `.xlsx`/`.xls`/`.csv` file.
2. It should import, and shortly after show "Saved …" in the footer — that's
   the app writing to `workbooks` and `workbook_sheets` in Supabase.
3. In Supabase **Table Editor**, open `workbooks` — you should see one row
   for the file you imported, and `workbook_sheets` should have one row per
   sheet in that file.
4. Edit a cell, click **Save changes**, and refresh `workbook_sheets` in
   Supabase — the `data` column for that sheet should reflect your edit.
5. Reload the workbench page — under "continue where you left off" you
   should see the file listed; click it to reopen it with all your data and
   edits intact.
6. Click **Log out**, confirm you're bounced to `login.html`, and confirm
   that trying to open `workbench.html` directly (typing the URL) redirects
   you back to `login.html` since there's no session.

## Step 9 — Invite teammates (real user creation)

You now have two ways for teammates to get accounts:

- **Self-service** — point them at `login.html` and have them click
  **Create an account**, same as Step 7.
- **Admin-created** — in Supabase, go to **Authentication → Users → Add
  user**, enter their email, and either set a temporary password yourself or
  send them an invite email. The `profiles` row is created automatically the
  same way either method.

Each person's imported files are private to them automatically — that's
what the Row Level Security policies in `schema.sql` enforce.

## Step 10 — Deploy

Host the folder (`index.html`, `login.html`, `workbench.html`,
`supabase-config.js`) on any static host — Netlify, Vercel, GitHub Pages, S3 +
CloudFront, or your own web server. No backend server is needed: the browser
talks to Supabase directly using the anon key, and Row Level Security is what
keeps that safe. Just remember to set the **Site URL** (Step 3) to your real
domain once you deploy.

---

## Troubleshooting

| Symptom | Likely cause |
|---|---|
| Login page spins forever / console shows a Supabase error | `supabase-config.js` still has placeholder URL/key, or you're opening the file with `file://` instead of `http://` |
| "Could not reach Supabase…" banner in the workbench | Network issue, wrong URL/key, or the tables/RLS weren't created — re-run `schema.sql` |
| Sign-up succeeds but nothing happens | Email confirmation is ON — check the account's inbox for the confirmation link |
| Imported file doesn't appear in Supabase tables | Open the browser console for the exact error; most often it's an RLS policy mismatch — confirm you ran the full `schema.sql`, including the `alter table ... enable row level security` and `create policy` statements |
| Two people importing files with the same file name overwrite each other | They shouldn't — `owner_id` scopes every row to the signed-in user, and `workbooks.id` is a random UUID generated per import, not derived from the file name |
