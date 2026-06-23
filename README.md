# Green Day

A calm, judgment-free MVP that helps people understand gambling patterns, track bet-free progress, and reach for immediate support when an urge appears.

## Run locally

Requirements: Node.js 20 or newer.

```bash
npm install
npm run dev
```

Open the URL shown by Vite. The project starts in demo mode with realistic mock data. Use the pre-filled login form, or create a new account to see onboarding.

## Production build

```bash
npm run build
npm run preview
```

## Connect Supabase

1. Create a Supabase project.
2. Run `supabase/schema.sql` in the Supabase SQL editor.
3. Copy `.env.example` to `.env.local`.
4. Add the project URL and anonymous key.
5. Enable email/password authentication in Supabase.

Without those environment variables, the app intentionally uses mock data and browser storage. With them, authentication, profiles, check-ins, notification preferences and subscription status use Supabase.

## Stripe Checkout

Deploy `create-checkout` and `stripe-webhook` from `supabase/functions`, then configure:

```text
STRIPE_SECRET_KEY
STRIPE_WEBHOOK_SECRET
STRIPE_PRICE_MONTHLY
STRIPE_PRICE_SEMIANNUAL
STRIPE_PRICE_ANNUAL
STRIPE_PRICE_LIFETIME
SUPABASE_SERVICE_ROLE_KEY
```

Point Stripe webhooks to the deployed `stripe-webhook` function. Checkout automatically offers Apple Pay and Google Pay on eligible browsers/devices when enabled in Stripe. Subscription access is never granted by the client; production status comes from the signed webhook.

## Push notifications

Generate VAPID keys, set `VITE_VAPID_PUBLIC_KEY`, and deploy `send-scheduled-notifications`. Its server secrets are:

```text
VAPID_SUBJECT
VAPID_PUBLIC_KEY
VAPID_PRIVATE_KEY
CRON_SECRET
```

Schedule that function every minute with Supabase Cron and send `x-cron-secret`. It compares each member’s two notification times in their selected timezone. Clicking a push opens `/?page=journal&quick=true`.

## Included in the MVP

- Email/password login and onboarding flows
- Responsive dashboard and progress metrics
- 60-second urge reset with private reflection
- Daily mood, urge, trigger and relapse check-ins
- Mood, urge, savings and trigger reports using Recharts
- Judgment-free relapse history
- Anonymous community feed and support reactions
- Aggregated, privacy-first community insights
- English, Brazilian Portuguese and Spanish language selector
- Supabase schema with row-level security
- Stripe Checkout, verified subscription webhook and Premium gates
- PWA manifest, offline shell, web push registration and timezone-aware scheduler
- Complete profile, recovery, notification and light/dark appearance settings
- Goal creation, editing, progress tracking, completion and Free/Premium limits

## Project structure

```text
src/
  data/       Demo data
  lib/        Supabase client and future service adapters
  App.tsx     Product screens and interactions
  i18n.ts     Language dictionaries
  styles.css  Design system and responsive layouts
supabase/
  schema.sql  Tables, constraints and RLS policies
```

## Safety note

Green Day is a self-management aid, not medical or financial advice. A production release should include region-aware links to professional gambling support and crisis services.
