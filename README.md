# Sync or Sink

A cross-platform multiplayer "Would You Rather" game built with Flutter. Challenge friends with invite links, compete in real time, and climb the leaderboard.

## Features

- **Solo mode** — play through rounds of "Would You Rather" at your own pace
- **Multiplayer challenges** — create a game and share a 6-character invite code
- **Real-time gameplay** — see opponent status and scores update live via Supabase Realtime
- **Speed-based scoring** — faster answers earn more points (100 / 75 / 50 / 25)
- **Deep linking** — join games directly from shared links (`syncorsink://join/{code}`)
- **Waiting room** — ready-up system with host controls

## Tech Stack

| Layer            | Technology                          |
| ---------------- | ----------------------------------- |
| Framework        | Flutter 3.16+                       |
| State management | Riverpod 2 (Notifier pattern)       |
| Routing          | GoRouter                            |
| Backend          | Supabase (Auth, PostgreSQL, Realtime)|
| Deep links       | app_links                           |
| Sharing          | share_plus                          |

## Project Structure

```
lib/
├── main.dart                       # Supabase init, app entry point
├── app.dart                        # MaterialApp + theme config
├── router/
│   └── app_router.dart             # Route definitions and deep link handling
├── features/
│   ├── home/                       # Home screen (solo / create / join)
│   ├── game/                       # Solo gameplay screen
│   └── multiplayer/                # Waiting room, multiplayer game, results
├── providers/
│   ├── supabase_provider.dart      # Supabase client + service providers
│   ├── game_provider.dart          # Solo game state
│   └── multiplayer_provider.dart   # Multiplayer state + realtime subscriptions
└── shared/
    ├── models/                     # Challenge, GameSession, Score
    └── services/
        └── supabase_service.dart   # Database operations + realtime helpers

supabase/
├── migrations/                     # PostgreSQL schema (users, sessions, challenges, scores)
├── seed/                           # Sample challenge data
└── config.toml                     # Supabase CLI config
```

## Getting Started

### Prerequisites

- Flutter SDK >= 3.16.0
- Supabase CLI (for local development)

### Local Development

1. **Clone the repo**

   ```bash
   git clone <repo-url>
   cd sync_or_sink
   ```

2. **Start Supabase locally**

   ```bash
   supabase start
   ```

   This runs the local Supabase stack and applies migrations + seed data automatically.

3. **Run the app**

   The app reads Supabase connection details from environment variables. Pass them with `--dart-define`:

   ```bash
   flutter run \
     --dart-define=SUPABASE_URL=http://localhost:54321 \
     --dart-define=SUPABASE_ANON_KEY=<your-local-anon-key>
   ```

   Or omit them to use the built-in defaults pointing to `localhost:54321`.

4. **Code generation** (if you modify Riverpod providers)

   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```

## Database Schema

| Table                    | Purpose                                  |
| ------------------------ | ---------------------------------------- |
| `users`                  | Player profiles (auto-created on signup) |
| `sessions`               | Game session state                       |
| `session_participants`   | Players in a session                     |
| `challenges`             | "Would You Rather" question prompts      |
| `session_rounds`         | Links sessions to challenges per round   |
| `scores`                 | Player answers, response times, points   |

Row-Level Security is enabled on all tables.

## Scoring

| Response time | Points |
| ------------- | ------ |
| < 2 seconds   | 100    |
| 2–5 seconds   | 75     |
| 5–10 seconds  | 50     |
| > 10 seconds  | 25     |

## License

Private — all rights reserved.
