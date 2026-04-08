# Android Release Checklist (Play Store)

## 1) Required local files

- `android/key.properties` (copy from `android/key.properties.example`)
- keystore file referenced by `storeFile` in `android/key.properties`
- `android/app/google-services.json` (Firebase Android app config)
- `tool/web_build.env` with:
  - `SUPABASE_URL`
  - `SUPABASE_ANON_KEY`
  - optional `SUPABASE_FUNCTIONS_BASE_URL`
  - optional `RAZORPAY_KEY_ID` (`rzp_live_...` only for release)

## 2) Android SDK health

- `flutter doctor`
- if needed:
  - install Android command-line tools
  - run `flutter doctor --android-licenses`

## 3) Build commands

- APK (release):  
  `.\scripts\build_android_release.ps1`
- APK split by ABI (release):  
  `.\scripts\build_android_release.ps1 -SplitPerAbi`
- App Bundle (Play Store):  
  `.\scripts\build_android_release.ps1 -Bundle`

## 4) Output paths

- APK output: `build/app/outputs/flutter-apk/`
- AAB output: `build/app/outputs/bundle/release/`

## 5) Final checks before upload

- Ensure no test keys or debug-only API keys
- Verify notifications and deep links on a release build
- Complete one real payment in production and confirm backend verification
- Confirm legal links (privacy/terms/refund/support) are reachable
