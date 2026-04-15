# Sync or Sink — Supabase Backend

## Setup

1. Copy `.env.example` to `.env` and fill in your credentials
2. Install the [Supabase CLI](https://supabase.com/docs/guides/cli)
3. Run `supabase start` to launch local dev environment
4. Run `supabase db reset` to apply migrations and seed data

## Schema

- **users** — Player profiles (auto-created on signup via trigger)
- **sessions** — Game sessions with status tracking
- **session_participants** — Join table for players in sessions
- **challenges** — Would You Rather question prompts
- **session_rounds** — Links sessions to challenges per round
- **scores** — Player answers, response times, and points

## Auth

- Email/password signup
- Google OAuth
- Apple OAuth
- JWT-based with 1-hour expiry
- Deep link callback: `syncorsink://login-callback`

## Realtime

Subscriptions enabled on: `sessions`, `session_participants`, `session_rounds`, `scores`

## RLS Policies

All tables have Row-Level Security enabled. Key rules:
- Profiles are publicly readable, self-editable
- Sessions are publicly readable, host-editable
- Scores are visible to session participants only
- Challenges are read-only for authenticated users
