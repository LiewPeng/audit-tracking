# Audit Tracker — SFRS(I) & SSA

A single-page app for running audit tests on Excel workbooks (financial statements, trial balances, general-ledger listings) and tracking the issues found as a team. Issues are ranked by risk and priority, linked to the exact sheet and cells, and mapped to Singapore Standards on Auditing (SSA) and SFRS(I) paragraphs.

Users sign in with a username and password. Data is stored in Supabase and shared by everyone on the team; changes made by one person appear for the others automatically.

## Features

- **Sign-in and user management** — usernames and passwords handled by Supabase Auth. Administrators add users, set their initial password, reset passwords, change roles and remove users from the **Users** page. Everyone can change their own name and password under **Account**.
- **File uploader** — drag-and-drop `.xlsx`, `.xlsm`, `.xls` or `.csv`. Files are parsed in the browser with [SheetJS](https://sheetjs.com/); the extracted cells and results are saved to Supabase.
- **18 audit tests** — footing of totals, balance sheet equation, hard-coded totals, formula errors, numbers stored as text, duplicates, round sums, weekend/holiday postings, period-end cut-off, missing descriptions, items ≥ performance materiality, manual/adjusting entries, related-party indicators, debits vs credits (per journal), Benford's law, year-on-year fluctuations, negative asset balances and going concern indicators.
- **Issue tracker** — amount, risk category, risk level and P1–P3 priority (risk + amount vs materiality + fraud indicator); filter, sort, add manual issues, assign owners, track status and notes, copy to CSV. Each issue records who created and last updated it.
- **Where to find it** — every issue names the file ▸ sheet ▸ cells and opens the workbook viewer with those cells highlighted.
- **Standards library** — SSA and SFRS(I) paragraphs cited by each issue, highlighted in the References view.

Paragraph texts are paraphrased summaries for working use, not the authoritative wording. Check them against the official SSAs (isca.org.sg) and SFRS(I) (acra.gov.sg). SSA 240 (Revised) and SSA 570 (Revised 2024) apply to periods beginning on or after 15 December 2026 and use different paragraph numbering.

## Users and roles

| Role | Can do |
| --- | --- |
| Administrator | Everything an auditor can, plus add/edit/remove users, reset passwords and clear the workspace |
| Auditor | Upload workbooks, run tests, add and update issues, edit engagement settings |

Initial accounts (all with the password `password` — change these after first sign-in):

| Username | Role |
| --- | --- |
| `priya` | Administrator |
| `dan` | Auditor |
| `marcus` | Auditor |

Usernames map to Supabase Auth emails of the form `username@audit-tracker.local`; the app adds the suffix automatically, so people only type their username.

## Supabase

Project: `https://benltlfjobsgmpdsqmyp.supabase.co`. The app uses the **publishable** key, which is safe to ship in the browser — all access is controlled by Row Level Security.

| Table | Contents |
| --- | --- |
| `auth.users` | Supabase's built-in user accounts and hashed passwords |
| `public.profiles` | One row per team member: username, full name, role |
| `public.engagement` | Single row of shared settings: entity, period end, materiality thresholds |
| `public.workbooks` | Uploaded workbooks: extracted cells (`sheets` JSON), test summary, uploader |
| `public.issues` | Issues: code (AT-001…), location, amount, risk, status, owner, notes, standards, audit trail |

Security model:

- Only signed-in users **with a profile** can read or write data. Profiles are created only by the admin user functions, so an account created any other way gets no access.
- Users can't change their own role; role changes and password resets go through `admin_*` database functions that check the caller is an administrator.
- The schema is in [`supabase/migrations`](supabase/migrations); the initial accounts are in [`supabase/seed_users.sql`](supabase/seed_users.sql).

Recommended settings in the Supabase dashboard (**Authentication → Sign In / Providers**): turn off **Allow new users to sign up**, since accounts are created by administrators in the app.

## Deploy to Vercel

This is a static site — there is no build step.

1. In Vercel, choose **Add New → Project** and import `LiewPeng/audit-tracking`.
2. Framework preset: **Other**. Leave Build Command and Output Directory empty (Root Directory `./`).
3. Click **Deploy**.

Every push to `main` redeploys automatically. `vercel.json` adds security headers and a Content Security Policy that allows only SheetJS (cdnjs), supabase-js (jsDelivr), Google Fonts and this Supabase project.

## Run locally

Serve the folder (sign-in needs a real `http://` origin, not `file://`):

```bash
npx serve .
```

## Files

| File | Purpose |
| --- | --- |
| `index.html` | The whole app (HTML, CSS, JS) |
| `vercel.json` | Vercel config: clean URLs, security headers, CSP |
| `supabase/migrations/` | Database schema, RLS policies and user-management functions |
| `supabase/seed_users.sql` | Creates the initial accounts |
| `.gitignore` | Ignores local Vercel/OS files |
