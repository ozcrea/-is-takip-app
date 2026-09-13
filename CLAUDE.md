# Atölye İş Takip Sistemi — CLAUDE.md

Static frontend (`index.html`) + Supabase (Postgres/PostgREST/Auth/Edge
Functions) + Vercel (auto-deploys `main`). No CI for SQL or Edge
Functions — the user always runs SQL manually in the Supabase SQL
Editor; assume no live DB access in this session unless told otherwise.

## 1. Workflow: SQL and schema changes need approval first

Before running any SQL or making any schema change, always show the
SQL/plan first and wait for explicit approval before the user runs it.
Never assume a previously-described plan was already approved unless
the user says so explicitly. Number new schema files sequentially as
`schema_vNN.sql` and send the file to the user — they run it manually.

## 2. Testing: full suite, zero failures, before every commit

After any code change, run the full Playwright regression suite and
confirm zero failures before committing/merging/deploying. Never
commit with an unverified or still-running test suite. See "Local test
harness" below for how the suite is structured and run.

## 3. Price calculation: `recordPrice()` field requirements

Any Supabase query whose results feed `recordPrice()` MUST select
`job_types.price_eur` AND `job_types.is_variable_price`. Missing
either field silently makes fixed-price jobs compute/display as €0
(the ternary falls through to the wrong branch or reads `undefined`).
This exact bug has recurred 3+ times across different reports —
whenever you add or touch a report query, explicitly check both
fields are present in its `select(...)` string.

```js
recordPrice(r) // = base + regiestunde*RATE + extra_arbeit_price
// base = job_types.is_variable_price ? (custom_price||0) : (job_types.price_eur||0)
```

## 4. Role separation — do not conflate these three

- **Admin** (full add/edit/delete rights everywhere): logs in ONLY via
  the separate `/admin` page (`admin/index.html`), with its own real
  Supabase Auth username/password (`signInWithPassword`, redirects to
  `/` on success). This page and its login flow must never be merged
  with, replaced by, or routed through any other login mechanism
  (this exact mistake was made and reverted once already — see
  schema_v33.sql / the git history around it for the full story).
- **Chef** (`employees.is_chef_viewer = true`, `is_admin = false`):
  VIEW-ONLY. Reports and the read-only "Alle Einträge" table only,
  reached via the Chef-Panel screens (`renderLandingBossLogin`,
  `renderBossPin`). Never give Chef the admin's day-records
  add/edit/delete panel — that panel is gated strictly on
  `currentEmployee.is_admin && currentEmployee.hidden_from_login`
  (`isHiddenAdmin` in `renderEmployeeDay`). Do not weaken that gate to
  include `is_chef_viewer`.
- **Regular employees**: can only add/edit/delete their OWN records,
  and only for the SAME calendar day (Europe/Berlin). This is enforced
  in RLS (`records_delete_recent`, `records_update_*` policies), not
  just hidden in the UI — never rely on UI-only restriction for this.

## 5. Timezone handling

Always use Europe/Berlin timezone-aware date comparisons for any
"is this today / this month" logic, in both RLS policies and report
queries:

- SQL: `(created_at::timestamptz at time zone 'Europe/Berlin')::date`.
  Never assume a `timestamp`-typed column is `timestamptz` — cast
  explicitly (`::timestamptz`) when in doubt; the wrong assumption
  silently flips the comparison direction (this caused the critical
  "employees can't delete their own same-day record" bug — see
  schema_v31.sql).
- JS: never build month/day boundaries with
  `new Date(y, m, 0/1).toISOString().slice(0,10)` — for positive-UTC
  offsets (Germany is always UTC+1/+2) this silently shifts dates back
  a day. Use the `monthBounds(year, month0)` helper instead.

## 6. Silent failures on delete/update

`.delete()` and `.update()` calls do NOT throw when RLS blocks them —
PostgREST returns HTTP success with 0 rows affected. Always pass
`{ count: 'exact' }` and check the returned `count`; show a real error
toast when `count` is falsy/0. Never let a 0-row delete/update present
as a success message to the user.

## 7. Branch (Filiale) attribution

A record's branch must be resolved PER DAY, using the employee's
`daily_hours` entry for that specific date — never a single
last-write-wins value applied across a whole date range (two reports
showing different numbers for the same period was a real, confirmed
bug caused by exactly this). Always reuse the shared
`buildDayBranchMap(hoursRows)` / `resolveRecordBranch(r, dayBranchMap)`
helpers (defined near `OWNER_AKT_TO_BRANCH`) in any new report — do not
write parallel/duplicate branch-resolution logic.

## 8. Brand style (for any UI work)

- Dark background `#16181B`, blue accent `#6FA3D8`, orange accent
  `#F5A623`.
- Monospace font for data/code-like elements: prices, job codes, AKT
  numbers.

## Local test harness (for running the regression suite)

Two mock files, edited in parallel for any change touching auth,
job types, or records shape:
- `mock-supabase.js` (Node-side)
- `site/mock-supabase.browser.js` (browser-loaded; differs slightly —
  e.g. `auth_user_id` values simulate real Supabase Auth sessions)

Regenerate the browser test copy after any `index.html` change: copy
`index.html` to `site/index.html`, then replace the real Supabase
`<script type="module"> import { createClient } ...` bootstrap with the
mock bootstrap (`<script src="/mock-supabase.browser.js">` +
`window.__supabaseMock.createMockClient(...)`). Serve it with
`python3 -m http.server 8935` from the `site` directory (this dies on
container restarts — restart it before running tests if
`curl localhost:8935/index.html` doesn't return 200).

Run every `testN.js` / `test_*.js` file in the scratchpad directory
(numbered sequentially; `test3.js` is deliberately excluded — a known
pre-existing mock quirk unrelated to app code) and grep for
`FAIL|PAGE EXCEPTION`. Zero matches required before committing.

## Git workflow

Work on `claude/index-v5-completion-x58g7t`, commit, push, then merge
`--no-ff` into `main` and push `main` (Vercel auto-deploys `main`).
Never push straight to `main` without going through the feature
branch first.
