# Observability — Sentry crash & error reporting

This is the runbook for the Flutter client's crash + error reporting pipeline.
The wiring lives in `lib/shared/services/sentry_service.dart` and is bootstrapped
from `lib/main.dart`.

Tracked under [GUSAA-42](/GUSAA/issues/GUSAA-42); required for the
[GUSAA-15](/GUSAA/issues/GUSAA-15) beta sign-off.

## What is reported

- Uncaught Dart errors (via `Sentry.captureException`).
- Flutter framework errors (via a `FlutterError.onError` hook that forwards to
  Sentry; the default console presenter is preserved in debug builds).
- Performance traces at a sample rate of `0.2` (one in five sessions).

What is **not** reported, by design:

- Screenshots (`attachScreenshot: false`).
- View hierarchy dumps (`attachViewHierarchy: false`).
- The user object beyond `id`. Email, IP, and username are dropped in
  `beforeSend` even if the SDK auto-populated them.
- Any string matching a Supabase JWT, `Bearer …` header, email address, or
  `data:image/...;base64,…` payload — the latter to keep selfie bytes out of
  Sentry. See `scrubSensitiveText` / `scrubSensitiveValue` for the full filter
  list.
- Sensitive map keys (`access_token`, `refresh_token`, `authorization`,
  `apikey`, `image`, `modifiedImagePath`, `originalImagePath`, …) are replaced
  with `[redacted]` regardless of value type.

## DSN provisioning

The DSN is a build-time secret. The app reads it from
`--dart-define=SENTRY_DSN=<dsn>`. **It is not stored in `.env`**, because dart
defines are baked into the compiled binary — the `.env` file is only used by
the Supabase tooling.

1. Project owner creates a Sentry project (`sync-or-sink-flutter`) under the
   shared Sentry org.
2. Copy the DSN from **Settings → Projects → Client Keys (DSN)**.
3. Store it in 1Password under `Sync or Sink / Sentry DSN (Flutter)`.
4. CI reads the secret from the `SENTRY_DSN_FLUTTER` GitHub Actions secret and
   forwards it as `--dart-define=SENTRY_DSN=…` during the release build.
5. Local engineers can opt in by exporting `SENTRY_DSN` and passing it
   explicitly:

   ```sh
   flutter run --dart-define=SENTRY_DSN=$SENTRY_DSN \
               --dart-define=SENTRY_ENVIRONMENT=dev
   ```

   When `SENTRY_DSN` is empty, `initSentry` is a no-op and the app starts
   normally. This is the default for local dev.

### Rotation

1. Generate a new key in Sentry: **Settings → Projects → Client Keys (DSN) →
   New Key**. Mark the old key inactive.
2. Update the 1Password entry and the `SENTRY_DSN_FLUTTER` GitHub Actions
   secret.
3. Trigger a release build so testers/users pick up the new DSN. Old binaries
   keep working until they are uninstalled or upgraded — the Sentry key stays
   accepting events for ~30 days after deactivation by default.
4. Once the new key is in use everywhere, delete the inactive key in Sentry.

## Environments

`--dart-define=SENTRY_ENVIRONMENT=…` controls the `environment` tag. If it is
not set, the resolver defaults to `dev` in debug builds and `prod` otherwise.
Use `dev`, `beta`, or `prod` — those are the values the Sentry alert routing
expects.

## Release tagging

Release identifiers are auto-populated by `sentry_flutter` from `package_info`,
formatted as `<package>@<version>+<buildNumber>`. The version segment matches
`pubspec.yaml`'s `version:` field, so bumping `version: 0.1.0+1` to
`version: 0.2.0+12` automatically opens a new release in Sentry.

When you cut a release branch, ensure the `version:` line is bumped before
building so events show up under the right release.

## Smoke test

The home screen exposes a debug-only bug icon (`Key('sentry-smoke-test')`) that
calls `triggerSentrySmokeTest()`. This throws a `StateError` synchronously —
the same path uncaught Flutter errors take — and the resulting event must
appear in the Sentry project within 60 s.

To verify a freshly provisioned DSN end-to-end:

```sh
flutter run --dart-define=SENTRY_DSN=$SENTRY_DSN \
            --dart-define=SENTRY_ENVIRONMENT=dev
```

Then tap the bug icon in the app bar and confirm the event lands in Sentry.

The button is gated by `kDebugMode`; release builds do not ship it.

## Triaging a new event

1. Open the event in Sentry. Confirm `environment` matches where it came from
   (`dev`, `beta`, or `prod`) — beta-only crashes during the
   [GUSAA-15](/GUSAA/issues/GUSAA-15) sprint should be tagged P1.
2. Look at the `release` tag. If it is older than the current `pubspec.yaml`
   version, the user is on a stale build — note that in the linked issue.
3. Check breadcrumbs and the stack trace. Anything that looks like a Supabase
   token, email, or selfie payload is a scrubber leak — file a ticket against
   `lib/shared/services/sentry_service.dart` and add a regression test in
   `test/sentry_service_test.dart` before patching.
4. File a Paperclip issue under the active sprint, link the Sentry event, and
   assign to the owning engineer. Use priority `critical` for crashes that
   block beta sign-off, otherwise `high`.
5. After a fix lands, mark the Sentry issue **Resolved in next release** so it
   re-opens if the regression slips into a later build.

## Related

- [GUSAA-15](/GUSAA/issues/GUSAA-15) — beta sprint that gates on this.
- [GUSAA-11](/GUSAA/issues/GUSAA-11) — AI selfie pipeline; the privacy
  boundary for image bytes.
- `lib/shared/services/sentry_service.dart` — implementation.
- `test/sentry_service_test.dart` — scrubber regression tests.
