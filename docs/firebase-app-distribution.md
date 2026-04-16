# Firebase App Distribution

CI publishes every successful `main` build to Firebase App Distribution via the `distribute-android` job in `.github/workflows/ci.yml`. Testers receive an install link on their device once the upload finishes.

## One-time setup

1. **Create a Firebase project** (or reuse an existing one) and register the Android app with package name `com.kawa.sink`. Download `google-services.json` — the same file the `build-android` job already decodes from `GOOGLE_SERVICES_JSON_BASE64`.
2. **Enable App Distribution** in the Firebase console and create a tester group (default expected name: `internal-testers`). Invite testers by email.
3. **Create a service account** with the `Firebase App Distribution Admin` role:
   - Firebase console → Project settings → Service accounts → Manage service account permissions
   - Google Cloud console → IAM & Admin → Service accounts → Create service account
   - Grant role `Firebase App Distribution Admin`, then create a JSON key and download it.
4. **Base64-encode the JSON key**:
   ```bash
   base64 -w0 firebase-service-account.json
   ```

## GitHub configuration

Add these repository secrets (Settings → Secrets and variables → Actions → Secrets):

| Secret                                | Purpose                                                      |
| ------------------------------------- | ------------------------------------------------------------ |
| `FIREBASE_ANDROID_APP_ID`             | Firebase Android App ID, e.g. `1:1234567890:android:abcdef`. |
| `FIREBASE_SERVICE_ACCOUNT_JSON_BASE64`| Base64-encoded service account JSON key.                     |
| `GOOGLE_SERVICES_JSON_BASE64`         | Base64-encoded `google-services.json` (already used by `build-android`). |
| `SUPABASE_URL`                        | Supabase project URL injected at build time.                 |
| `SUPABASE_ANON_KEY`                   | Supabase anon key injected at build time.                    |

Add this repository variable (Settings → Secrets and variables → Actions → Variables):

| Variable                   | Purpose                                                            |
| -------------------------- | ------------------------------------------------------------------ |
| `FIREBASE_TESTER_GROUPS`   | Comma-separated tester group aliases. Defaults to `internal-testers`. |

## How the pipeline runs

1. Push to `main` triggers `analyze` → `test`.
2. On success, `build-android` produces `app-release.apk` and uploads it as the `android-apk` artifact.
3. `distribute-android` downloads that artifact and uses `wzieba/Firebase-Distribution-Github-Action@v1` to push it to Firebase App Distribution with release notes containing commit SHA, branch, and actor.

Release notes include the commit SHA so testers can correlate a build to source.

## Troubleshooting

- **`FIREBASE_ANDROID_APP_ID` missing**: the job fails fast before upload. Add the secret.
- **`PERMISSION_DENIED` from App Distribution**: confirm the service account has `Firebase App Distribution Admin` on the correct project.
- **Tester group unknown**: verify the alias in Firebase Console → App Distribution → Testers & groups matches `FIREBASE_TESTER_GROUPS`.
- **APK rejected (unsigned)**: CI signs the release APK with the Flutter debug keys (see `android/app/build.gradle.kts`). App Distribution accepts these for internal testing but replace with a real release keystore before widening the tester audience.
