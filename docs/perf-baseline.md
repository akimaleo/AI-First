# Performance Baseline — Sync or Sink Beta (GUSAA-43)

This doc is the source of truth for the two performance metrics the beta
sign-off ([GUSAA-15](/GUSAA/issues/GUSAA-15)) commits the team to:

- **App startup**: < 2 s — `main()` to first paint of the home screen.
- **Capture the Moment**: < 8 s end-to-end — user tap on the shutter to the
  modified selfie's first frame on the result/hero screen.

The instrumentation that produces these numbers ships with the app and is
gated to be cheap in release builds — see "Implementation notes" below.

## Reproduction protocol

### 1. Build a release IPA / APK

```bash
# iOS — release build, signed for the test device
flutter build ipa \
  --release \
  --dart-define=SUPABASE_URL=$STAGING_SUPABASE_URL \
  --dart-define=SUPABASE_ANON_KEY=$STAGING_SUPABASE_ANON_KEY \
  --dart-define=SENTRY_DSN=$STAGING_SENTRY_DSN \
  --dart-define=SENTRY_ENVIRONMENT=staging

# Android — release APK
flutter build apk \
  --release \
  --dart-define=SUPABASE_URL=$STAGING_SUPABASE_URL \
  --dart-define=SUPABASE_ANON_KEY=$STAGING_SUPABASE_ANON_KEY \
  --dart-define=SENTRY_DSN=$STAGING_SENTRY_DSN \
  --dart-define=SENTRY_ENVIRONMENT=staging
```

Use the same staging backend for both devices so AI pipeline latency is
comparable run-to-run.

### 2. Prepare the device

- Plug into power, full charge, brightness ~50 %, no other apps in the
  foreground rotation (clear recents).
- Enable airplane mode briefly to clear background sync, then re-enable
  Wi-Fi. Do **not** test on cellular — variance dominates.
- Cold-kill the app between every startup measurement (swipe away on iOS,
  Force Stop in Android settings).

### 3. Capture startup samples (≥ 10 cold starts per device)

For each of the 10 runs:

1. Cold-kill the app.
2. Tap the icon. Let the home screen settle.
3. Open Settings (gear icon, top-right of home), **long-press the App
   version row** to open the hidden Performance screen.
4. Read the most-recent `Startup` row and write it down.
5. Repeat.

### 4. Capture "Capture the Moment" samples (≥ 10 runs per device)

The metric covers tap-to-rendered including the AI transform. Run each
sample inside a single solo game so the prompt picker behaves like the
real flow:

1. From home, tap **Solo Play**.
2. Play through to the moment that triggers the camera.
3. Frame the selfie, tap shutter. Do not move the device.
4. Wait until the result screen has the modified selfie on screen.
5. Open Settings → long-press App version → read the most-recent
   `Capture the Moment` row.
6. Tap **Done** on the result screen, replay the round, repeat.

If the AI transform fell back to the unmodified selfie (banner shows
"AI transform didn't finish in time"), the perf row will be tagged
`used_fallback=true`. Treat fallback samples as outliers — record them
separately and re-run until you have ten non-fallback samples.

### 5. Compute and record p50 / p95

The Performance screen shows live p50 / p95 across all buffered samples
(default buffer = 50). Record the values **after** all 10 runs but
**before** running anything else that might pollute the buffer. If you
need to clear earlier samples, use the trash icon in the screen's app
bar.

## Targets

| Metric              | Target  | Source                                    |
| ------------------- | ------- | ----------------------------------------- |
| App startup p95     | < 2 s   | Beta sign-off ([GUSAA-15](/GUSAA/issues/GUSAA-15)) |
| Capture the Moment p95 | < 8 s | Beta sign-off ([GUSAA-15](/GUSAA/issues/GUSAA-15)) |

The AI step alone has its own latency budget (P50 ~4 s, P95 ~9 s) — see
[`docs/ai-selfie-pipeline.md`](./ai-selfie-pipeline.md). The capture
metric is wider because it includes the camera roll-up, screen
transition, and image fetch from the Replicate CDN.

## Results

Fill in this table when you run the protocol on the target devices.
Build commit goes in the SHA column so future regressions can be diff-bisected.

| Device     | OS version | Build SHA | Metric              | p50 | p95 | Pass? |
| ---------- | ---------- | --------- | ------------------- | --- | --- | ----- |
| iPhone 12  | TBD        | TBD       | App startup         | TBD | TBD | TBD   |
| iPhone 12  | TBD        | TBD       | Capture the Moment  | TBD | TBD | TBD   |
| Pixel 6    | TBD        | TBD       | App startup         | TBD | TBD | TBD   |
| Pixel 6    | TBD        | TBD       | Capture the Moment  | TBD | TBD | TBD   |

If either p95 column is over the target, append a "Findings" subsection
below explaining the regression and link a follow-up ticket.

### Findings

_(Empty until a metric misses the target. When that happens, document the
suspected root cause + link the follow-up ticket here so the next person
picking up the baseline doesn't re-investigate from scratch.)_

## Implementation notes

The instrumentation lives in:

- `lib/shared/services/perf_recorder.dart` — in-memory ring buffer with
  p50 / p95 helpers. Pure Dart, ChangeNotifier-based so the debug screen
  stays in sync.
- `lib/shared/services/perf_instrumentation.dart` — records into the
  buffer, emits a Dart `Timeline` event (visible in DevTools' Performance
  view), and adds a Sentry breadcrumb so a recorded duration travels with
  the next crash report.
- `lib/main.dart` calls `PerfInstrumentation.markAppStart()` as the first
  line of `main()` and `lib/features/home/home_screen.dart` completes the
  measurement in the home screen's first post-frame callback.
- `lib/providers/camera_provider.dart` stamps `tapAt` when the user taps
  the shutter, and
  `lib/features/capture/capture_result_screen.dart` records the
  Capture-the-Moment latency in the `onSelfieLoaded` callback fired by
  `SelfieImage` once the modified bytes have painted.

### Release-mode safety

- The recorder is a list-append plus an O(N) trim with N≤50.
- Sentry breadcrumbs are only added when a DSN is configured; the
  Sentry SDK already throttles them.
- Timeline events are no-ops outside the DevTools timeline.
- The hidden debug screen is only reachable via long-press; nothing is
  rendered or computed on the hot path for it.

### Where to read raw samples

- **In-app**: Settings → long-press App version → Performance.
- **DevTools (debug builds)**: Performance tab → look for
  `app_startup_complete` and `capture_moment_complete` instant events.
- **Sentry (release builds with DSN)**: any captured event includes the
  most recent `app.startup` and `capture.moment` breadcrumbs in the
  Breadcrumbs panel.

## Out of scope (filed separately if a regression hits)

- Web / desktop perf — mobile only for the MVP.
- Optimization work itself — if a metric misses target, log it in
  "Findings" and open a follow-up ticket against [GUSAA-15](/GUSAA/issues/GUSAA-15).
- AI pipeline tuning — owned by the AI selfie service contract in
  [`docs/ai-selfie-pipeline.md`](./ai-selfie-pipeline.md).
