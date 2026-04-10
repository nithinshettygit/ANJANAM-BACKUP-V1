# Android Release Update Checklist

Before releasing an update, verify:

- [ ] Package name unchanged (`com.anjanam.app`) in:
  - `android/app/build.gradle.kts` (`applicationId`, `namespace`)
  - `android/app/src/main/AndroidManifest.xml` deep-link scheme values
  - `android/app/src/main/kotlin/com/anjanam/app/MainActivity.kt` package
- [ ] Signing key unchanged (same `key.properties` + same keystore file/key alias as previous Play release)
- [ ] `versionCode` increased for this release (or CI `BUILD_NUMBER` is higher than last release)
- [ ] Update installs over previous APK/AAB locally without uninstall
- [ ] Debug and release builds are not mixed during update testing

Recommended release commands:

```bash
flutter clean
flutter pub get
flutter build apk --release
flutter build appbundle --release
```

Important developer note:

- Installing a debug APK over a release APK (or release over debug) can fail because the signing keys are different.
- Always validate update behavior using release artifacts signed with the production keystore.
