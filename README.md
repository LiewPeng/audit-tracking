# Audit Tracker — SFRS(I) & SSA

A single-page app for running audit tests on Excel workbooks (financial statements, trial balances, general-ledger listings) and tracking the issues found. Issues are ranked by risk and priority, linked to the exact sheet and cells, and mapped to Singapore Standards on Auditing (SSA) and SFRS(I) paragraphs.

Everything runs in the browser. Uploaded files are parsed client-side with [SheetJS](https://sheetjs.com/) and all data is kept in the browser's `localStorage` — nothing is sent to a server.

## Features

- **File uploader** — drag-and-drop `.xlsx`, `.xlsm`, `.xls` or `.csv`; tests run automatically.
- **18 audit tests** — footing of totals, balance sheet equation, hard-coded totals, formula errors, numbers stored as text, duplicates, round sums, weekend/holiday postings, period-end cut-off, missing descriptions, items ≥ performance materiality, manual/adjusting entries, related-party indicators, debits vs credits (per journal), Benford's law, year-on-year fluctuations, negative asset balances and going concern indicators.
- **Issue tracker** — amount, risk category, risk level and P1–P3 priority (risk + amount vs materiality + fraud indicator); filter, sort, add manual issues, track status/owner/notes, copy to CSV.
- **Where to find it** — every issue names the file ▸ sheet ▸ cells and opens the workbook viewer with those cells highlighted.
- **Standards library** — SSA and SFRS(I) paragraphs cited by each issue, highlighted in the References view.

Paragraph texts are paraphrased summaries for working use, not the authoritative wording. Check them against the official SSAs (isca.org.sg) and SFRS(I) (acra.gov.sg). SSA 240 (Revised) and SSA 570 (Revised 2024) apply to periods beginning on or after 15 December 2026 and use different paragraph numbering.

## Deploy to Vercel

This is a static site — there is no build step.

1. In Vercel, choose **Add New → Project** and import `LiewPeng/audit-tracking`.
2. Framework preset: **Other**. Leave Build Command and Output Directory empty (Root Directory `./`).
3. Click **Deploy**.

Or from the command line:

```bash
npm i -g vercel
vercel        # preview
vercel --prod # production
```

`vercel.json` adds security headers and a Content Security Policy that allows only SheetJS from cdnjs and Google Fonts.

## Run locally

Open `index.html` in a browser, or serve the folder:

```bash
npx serve .
```

## Files

| File | Purpose |
| --- | --- |
| `index.html` | The whole app (HTML, CSS, JS) |
| `vercel.json` | Vercel config: clean URLs, security headers, CSP |
| `.gitignore` | Ignores local Vercel/OS files |
