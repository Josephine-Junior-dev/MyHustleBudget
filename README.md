# MyHustleBudget

**Your Hustle. Your Money. Your Growth.**

A mobile-first business money tracker for boda boda operators, mama mboga, small shops, food vendors, and other small businesses in Kenya.

## Frontend
- Plain HTML, CSS, and JavaScript.
- Supabase Auth for sign-up/sign-in.
- Uses the dedicated PostgreSQL schema `myhustlebudget`.
- Includes dashboard, income/expense transactions, debts/payments, budgets, savings goals, reports and CSV export.

## Configure Supabase
1. Open `app.js`.
2. Replace `PASTE_YOUR_SUPABASE_PROJECT_URL_HERE` with your Supabase Project URL.
3. Replace `PASTE_YOUR_SUPABASE_PUBLISHABLE_OR_ANON_KEY_HERE` with your Supabase publishable key (or legacy anon key).
4. **Never use the service-role key in frontend code.**
5. In Supabase API settings, make sure `myhustlebudget` is listed under Exposed schemas.
6. Verify grants and test RLS policies for every table before using real financial data.

The Supabase client is configured with `db.schema = 'myhustlebudget'`, so the app queries tables inside that schema.

## Expected database tables
- `profiles(id, full_name, business_type, created_at)`
- `businesses(id, user_id, business_name, business_type, currency, created_at)`
- `transactions(id, user_id, business_id, transaction_type, category, description, amount, transaction_date, payment_method, created_at)`
- `debts(id, user_id, business_id, person_name, debt_type, original_amount, due_date, description, status, created_at)`
- `debt_payments(id, user_id, debt_id, amount, payment_date, notes, created_at)`
- `budgets(id, user_id, business_id, category, budget_amount, period, created_at)`
- `savings(id, user_id, business_id, goal_name, target_amount, saved_amount, target_date, created_at)`

Product/stock tables are not yet exposed in the first frontend version.

## Publish on GitHub Pages
Repository **Settings → Pages → Deploy from a branch → main → / (root) → Save**.
