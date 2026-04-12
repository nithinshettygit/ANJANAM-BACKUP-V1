# Android Release & Play Store Checklist

## Update compatibility (do not break existing installs)

These **must stay stable** across all future releases on the same Play listing:

| Item | Rule |
|------|------|
| **applicationId** | Never change `com.anjanam.app` (see `android/app/build.gradle.kts`). A new id = new app listing; users cannot update in place. |
| **Release signing** | Always sign Play uploads with the **same** keystore + alias as the first production release. Different key → `INSTALL_FAILED_UPDATE_INCOMPATIBLE`. |
| **versionCode** | Must **strictly increase** for every upload (`pubspec.yaml` `+` number, or `BUILD_NUMBER` env in CI). Reusing or lowering it is rejected by Play or breaks updates. |
| **versionName** | Human-readable string; can be any non-decreasing marketing version (e.g. `1.0.1`). |

Verify in repo:

- [ ] `namespace` / `applicationId` = `com.anjanam.app` in `android/app/build.gradle.kts`
- [ ] `package com.anjanam.app` in `MainActivity.kt`
- [ ] Deep-link `android:scheme` values still match your auth / product URLs (`AndroidManifest.xml`, `lib/core/config/auth_redirect_config.dart` if used)
- [ ] Local **release** install over the **previous Play build** (same signing) succeeds without uninstall

**Never commit:** `android/key.properties`, `*.jks`, `*.keystore`. Use `key.properties.example` only as a template.

---

## Backend / Supabase (before or with the build)

- [ ] All new SQL migrations applied to **production** in order (`supabase db push` / your pipeline). Old app versions should keep working until you rely on new RPC/columns in the client.
- [ ] Edge Functions used by this app version are **deployed** (e.g. `verify_payment`, `create_payment_order`, Razorpay webhooks).
- [ ] Razorpay **live** keys in Supabase secrets for production.
- [ ] **Staging-only:** after a DB backup, optional full test-data wipe: run `ecommerce_app/supabase/scripts/pre_production_data_cleanup.sql` in the SQL Editor (never add that file under `migrations/` as an auto-run).

---

## Play Console (store listing, not only the binary)

- [ ] **Data safety** form completed and consistent with app behaviour (payments, account, device ids, etc.).
- [ ] **Privacy policy** URL live and referenced in listing (required for many regions / payments).
- [ ] **Content rating** questionnaire up to date.
- [ ] **Target API** meets Google’s current requirement (comes from Flutter SDK; upgrade Flutter when Play mandates a higher target).

---

## Build commands (after checklist above)

```bash
flutter clean
flutter pub get
flutter build apk --release
flutter build appbundle --release
```

Release builds require `android/key.properties` (copy from `key.properties.example`). CI should inject secrets, not commit them.

**Testing note:** Installing a **debug** APK over a **Play-signed release** install (or the reverse) usually fails — different signatures. Always validate **in-store updates** using release AAB/APK signed with the **upload/production** keystore.

---

## Optional hardening (when Play or Flutter requires)

- **16 KB page size** (newer device requirement): use a recent Flutter / AGP version and re-test release builds when Google announces enforcement.
- After enabling new shrinking rules, run a **release** smoke test: login, catalog, checkout, Razorpay, push open.
