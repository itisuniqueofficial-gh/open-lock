# Releasing

Open Lock ships **signed APKs and an AAB** to GitHub Releases automatically via
the [`Release`](.github/workflows/release.yml) workflow.

## Cut a release

1. Bump the version in `pubspec.yaml` (e.g. `version: 1.5.0+7`) and, to keep the
   About screen / backup metadata in sync, the mirrored constant in
   `lib/src/core/app_info.dart` (`AppInfo.version`). Commit via a PR (since
   `main` is protected).
2. Create and push a matching tag:

   ```sh
   git tag v1.5.0
   git push origin v1.5.0
   ```

3. The workflow runs formatting, analysis, and tests, then builds signed APKs
   (universal + `arm64-v8a` + `armeabi-v7a` + `x86_64`) and a signed AAB,
   verifies the signature / package id / version, and publishes a **GitHub
   Release** for the tag with generated notes. Most phones want the
   `arm64-v8a` APK; grab `universal` if unsure. The `.aab` is for Play Store
   upload.

You can also run it manually: **Actions → Release → Run workflow** (with an
optional version label).

## Release artifacts

Each tagged release attaches:

```
Open-Lock-vX.Y.Z-universal.apk
Open-Lock-vX.Y.Z-arm64-v8a.apk
Open-Lock-vX.Y.Z-armeabi-v7a.apk
Open-Lock-vX.Y.Z-x86_64.apk
Open-Lock-vX.Y.Z-release.aab
```

## Signing

Release builds are signed with a keystore stored as **encrypted repository
secrets** (never in the repo, never printed in logs):

| Secret | Purpose |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | The base64-encoded release keystore (`.jks`/`.keystore`) |
| `ANDROID_KEYSTORE_PASSWORD` | Keystore (store) password |
| `ANDROID_KEY_PASSWORD` | Key password |
| `ANDROID_KEY_ALIAS` | Key alias |

At build time the workflow decodes the keystore to `android/app/release.keystore`,
writes `android/key.properties`, builds, verifies, and then deletes both
(`if: always()`). Locally, `flutter build apk --release` falls back to debug
signing unless you create your own `android/key.properties`.

To produce `ANDROID_KEYSTORE_BASE64` from a keystore:

```sh
base64 -w0 my-release-key.jks > keystore.b64   # paste contents into the secret
```

> ⚠️ Keep the keystore and its passwords backed up somewhere safe. Losing them
> means you can never ship an update that installs over an existing release
> build.

## Versioning

Tags are `vMAJOR.MINOR.PATCH` and must match the `version:` in `pubspec.yaml`.
The Android `versionCode` (the `+N` build number) must increase monotonically
for every published release. The release workflow verifies that the built
APK's `versionName` matches `pubspec.yaml` before publishing.

## How CI works (every push / PR)

[`.github/workflows/ci.yml`](.github/workflows/ci.yml) runs on every push and
pull request: checkout → JDK 17 → Flutter (pinned) → `flutter pub get` → verify
launcher icons present → `dart format --set-exit-if-changed` → `dart analyze
--fatal-infos` → `flutter test` → build debug APK → upload the APK artifact.
A failing format check, analyzer issue, or test fails the build.

## Troubleshooting

- **Release fails at "Restore signing keystore":** the signing secrets are not
  set. Add all four `ANDROID_*` secrets (above) in repo Settings → Secrets.
- **`versionName` mismatch failure:** the built APK's `versionName` must equal
  `pubspec.yaml`'s `version` (minus the `+build`). Bump `pubspec.yaml` and tag
  the matching `vX.Y.Z`.
- **Package-id verification failure:** the APK must report
  `com.itisuniqueofficial.openlock`.
- **Wrong Flutter version:** CI pins a known-compatible Flutter version; do not
  bump it casually — the shared `core_*` packages track a specific SDK.
- **Duplicate release:** re-running a tag will not duplicate; delete the tag and
  GitHub Release first if you must rebuild the same version.
