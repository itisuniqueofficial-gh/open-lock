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

---

## GitHub-first automation architecture

Everything below runs on GitHub — no local build/sign/release is required.

```
edit → commit → PR → CI (guards + build/test) → merge to main → CI
                                                        │
                                            push tag vX.Y.Z
                                                        ↓
                          release.yml: validate → sign → build APK+AAB →
                          verify (signature/package/label/version/versionCode)
                          → changelog → GitHub Release + artifacts
```

### Workflows

| Workflow | Trigger | Purpose |
| --- | --- | --- |
| [`ci.yml`](.github/workflows/ci.yml) | push to `main`, every PR | `guards` job (no old ids/secrets, icon + release config + package/label present) and `verify` job (icons, `dart format`, `dart analyze --fatal-infos`, `flutter test`, debug APK build + package/label check, artifact upload, 14-day retention) |
| [`release.yml`](.github/workflows/release.yml) | `v*` tags, manual dispatch | tag↔`pubspec` version check, format/analyze/test, sign, build universal+split APKs and AAB, verify signature/package/label/versionName/versionCode, verify AAB, changelog, GitHub Release |

PR checks are handled by `ci.yml` (it runs on `pull_request`); no separate
`pr.yml` is needed. Least-privilege permissions: CI is `contents: read`,
release is `contents: write`. Concurrency groups prevent duplicate CI runs; the
release group never cancels an in-progress build.

### Dependency automation

[`.github/dependabot.yml`](.github/dependabot.yml) opens **weekly** update PRs
for GitHub Actions, Dart/Flutter (`pub`), and Gradle. Updates are **not**
auto-merged — each PR runs CI and is reviewed. Dependabot **security alerts**
and **automated security fixes** are enabled on the repository.

### Security scanning

- **Enabled now:** Dependabot alerts + automated security fixes; CI hygiene
  guards (blocks committed keystores/`key.properties` and old identifiers);
  GitHub push protection for secrets (native).
- **Requires GitHub Advanced Security** (private repo) **or a public repo:**
  CodeQL code scanning and PR dependency-review. They are intentionally **not**
  committed as workflows because they fail without GHAS. To enable once GHAS is
  on (Settings → Code security), add `.github/workflows/codeql.yml`:

  ```yaml
  name: CodeQL
  on:
    push: { branches: [main] }
    pull_request: { branches: [main] }
    schedule: [{ cron: "0 3 * * 1" }]
  permissions: { contents: read, security-events: write }
  jobs:
    analyze:
      runs-on: ubuntu-latest
      steps:
        - uses: actions/checkout@v4
        - uses: github/codeql-action/init@v3
          with: { languages: java-kotlin, build-mode: none }
        - uses: github/codeql-action/analyze@v3
  ```

  (Dart is not a CodeQL-supported language; `java-kotlin` covers the native
  Android layer.)

## Rollback strategy

Tags and published artifacts are **immutable** — never force-push a tag or
replace a published APK/AAB. To roll back a bad release:

1. Fix forward: bump `pubspec.yaml` to the next patch (e.g. `1.5.0+7` →
   `1.5.1+8`) and mirror `AppInfo.version`.
2. Merge the fix to `main` (CI must pass).
3. Tag the new patch:
   ```sh
   git tag v1.5.1 && git push origin v1.5.1
   ```
4. Optionally mark the bad GitHub Release as *pre-release* or edit its notes to
   point users at the fixed version. Do not delete published binaries that
   users may already depend on unless they are actively harmful.

```
v1.5.0  →  problem found  →  v1.5.1 (corrected patch)
```

## Branch protection (manual)

Branch-protection APIs are unavailable on this private repo's current plan
(HTTP 403 "Upgrade to GitHub Pro or make this repository public"). Once
available (GitHub Pro, GitHub Team/Enterprise, or a public repo), configure in
**Settings → Branches → Add rule** (or **Rules → Rulesets**) for `main`:

- Require a pull request before merging.
- Require status checks to pass: **`Repository hygiene`** and
  **`Format · Analyze · Test · Build`**.
- Require branches to be up to date before merging.
- Block force pushes and branch deletion.

The release process is tag-based and is unaffected by these branch rules.
