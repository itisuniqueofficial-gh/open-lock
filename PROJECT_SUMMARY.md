# OpenLock — Project Summary

> Generated from a static inspection of the repository source and configuration at the commit noted below. Every claim is traceable to a file path. Items that could not be verified from the source are explicitly marked **Not verified** or **Not found**. This document adds nothing to the project except itself; it does not modify source, build, or manifest files.

---

## 0. Revision Notes — Rebrand, Hardening & Automation

This section records the changes applied **on top of** base commit `89e74dc`
(the original analysis below in §§2–24 describes the pre-change baseline; where a
statement has been superseded it is annotated *"(updated in §0)"* conceptually —
this section is authoritative for current state). All changes are uncommitted
working-tree edits.

### CURRENT IMPLEMENTATION (after this revision)

**Identity / rebrand**
- Application id + namespace: `dev.abdullah.openlock` → **`com.itisuniqueofficial.openlock`** (`android/app/build.gradle.kts`).
- Kotlin sources moved `…/kotlin/dev/abdullah/openlock/` → `…/kotlin/com/itisuniqueofficial/openlock/`; all 11 `package` declarations updated (via `git mv`, history preserved).
- Launcher/app label → **"Open Lock"** (`AndroidManifest.xml`), `MaterialApp.title` (`app.dart`), `AppInfo.name`.
- Maintainer **It Is Unique Official**, developer **Jaydatt Khodave**, site `openlock.itisuniqueofficial.com`, dev site `jaydatt.pages.dev` — surfaced on the rewritten **About** screen and stored once in `AppInfo`.
- Native user-visible strings rebranded (monitor notification, device-admin explanation/disable text). Update service repointed to `itisuniqueofficial-gh/open-lock` (`di.dart`).
- `LockActivity` task affinity → `com.itisuniqueofficial.openlock.lock`.

**Preserved for backward compatibility (deliberately NOT renamed)** — see §29:
- MethodChannel `openlock/enforcement`; EncryptedSharedPreferences store `openlock_enforcement`; notification channels `openlock_monitor` / `openlock_intruder`; secure-storage keys `openlock_*`; backup envelope `"app":"openlock"` + `.olbackup`; secure-storage key `openlock_update_autocheck`; Dart package name `openlock`. The `secure-suite-core` git dependency URL is a **functional dependency** and is left unchanged (rebranding it would break `flutter pub get`).

**Icons / UI**
- Removed all emoji-based UI (native `LockActivity`): the 🔒 header, ⌫/✓ keypad glyphs, and ●/○ PIN dots are now vector drawables (`ic_lock_shield.xml`, `ic_backspace.xml`, `ic_check.xml`) and programmatically-drawn circular dot views. The Flutter UI already used Material icons.
- About screen redesigned with clean info rows (no emoji), maintainer/developer/website.

**Security & privacy hardening**
- `FLAG_SECURE` now set on **`MainActivity`** (not just `LockActivity`), keeping PIN entry, the locked-app list, intruder photos, and settings out of screenshots/Recents.
- `ConfigStore` keystore handling is now **fail-closed**: on `EncryptedSharedPreferences` failure it clears the corrupt keyset and retries once; if that still fails it uses a **non-persistent in-memory** store — it never writes the PIN verifier/config to plaintext prefs (the old silent `MODE_PRIVATE` plaintext fallback was removed).
- `android:allowBackup="false"` + `android:fullBackupContent="false"` added to the manifest.

**Functional gaps fixed**
- **`lockNewApps` now enforced.** It is forwarded in `LockConfig.toNativeMap`; the monitor service registers a dynamic `ACTION_PACKAGE_ADDED` receiver that adds genuinely-new installs to a native-owned additive `autoLockedPackages` set, unioned into the locked set in `tick()` and counted in `BootReceiver`. The app picker merges these for display and can clear them (`getAutoLockedPackages` / `removeAutoLocked` channel methods).
- **"Pattern" unlock claim removed** from `pubspec.yaml` description and README (implementation is PIN + biometric; no pattern exists).
- **Version single-sourced & un-staled:** `AppInfo.version` `1.1.0` → **`1.5.0`** to mirror `pubspec.yaml` `1.5.0+7`; documented that both bump together.
- **Forgot-PIN:** no insecure bypass added; the absence of recovery is now documented as an intentional limitation (README §Limitations).

**CI/CD**
- `.github/workflows/ci.yml` rewritten: on every push + PR → format check (`dart format --set-exit-if-changed`), `dart analyze --fatal-infos`, `flutter test`, debug APK build, artifact upload.
- `.github/workflows/release.yml` rewritten: on `v*` tags / manual dispatch → format+analyze+test, decode keystore from secrets, build **signed** universal + per-ABI APKs **and an AAB**, verify signature + package id + versionName (`apksigner`/`aapt`), delete signing material (`if: always()`), generate changelog from git history, publish a GitHub Release with artifacts named `Open-Lock-vX.Y.Z-*`.
- Secret names: `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_PASSWORD`, `ANDROID_KEY_ALIAS`. `.gitignore` already blocks `key.properties`, `*.jks`, `*.keystore`.
- Conformance test added (`test/native_conformance_test.dart`) locking down the Dart-side constants the Kotlin mirror depends on (PBKDF2 iterations, min PIN, cooldown schedule).

**Git remote / repository:** the project now lives in **`github.com/itisuniqueofficial-gh/open-lock`** (private). The rebranded tree, generated launcher icons, and CI/CD workflows are pushed there. Signing secrets (`ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_PASSWORD`, `ANDROID_KEY_ALIAS`) must be added by the maintainer in repo Settings → Secrets before tagging a release; they are not committed and cannot be generated here.

### RECOMMENDED FUTURE IMPROVEMENTS (not implemented here)
- Add JVM unit tests for the Kotlin mirror (`LockLogic`, `PinVerifier`) to fully close the dual-implementation drift gap (only Dart-side conformance constants are asserted now).
- Verify the downloaded update APK's signature/hash before install (the update download lives in the external `core_update` package).
- Consider Argon2id (or higher PBKDF2 iterations) for the unlock verifier to harden against offline brute-force of a short numeric PIN.
- Encrypt intruder photos at rest.

---


## 1. Project Identity

| Field | Value | Source |
|---|---|---|
| Repository | `github.com/itisuniqueofficial-gh/open-lock` (private) | `git remote -v` |
| GitHub | https://github.com/itisuniqueofficial-gh/open-lock | task brief |
| Project / display name | Open Lock | `pubspec.yaml` desc, manifest `android:label`, `AppInfo.name` |
| Package / application ID | `com.itisuniqueofficial.openlock` | `android/app/build.gradle.kts` (`namespace`, `applicationId`), Kotlin package |
| Dart package name (internal, unchanged) | `openlock` | `pubspec.yaml` `name:` (used by all `package:openlock/...` imports) |
| Maintainer | It Is Unique Official | `AppInfo.maintainer`, About screen, README |
| Developer | Jaydatt Khodave | `AppInfo.developer`, About screen, README |
| App website | https://openlock.itisuniqueofficial.com | `AppInfo.website`, About, README |
| Developer website | https://jaydatt.pages.dev | `AppInfo.developerWebsite`, About, README |
| Analyzed base commit | `89e74dc450d67d5bf2424defadd7deeddcc6d26f` | `git rev-parse HEAD` (changes below are uncommitted working-tree edits) |
| Branch | `main` | `git rev-parse --abbrev-ref HEAD` |
| License | MIT © 2026 It Is Unique Official | `LICENSE`, `README.md` |
| Primary languages | Dart (Flutter app) + Kotlin (native Android layer) | `lib/`, `android/app/src/main/kotlin/` |
| Build system | Flutter + Gradle (Kotlin DSL) | `pubspec.yaml`, `android/**/*.gradle.kts` |
| App version | `1.5.0+7` (versionName 1.5.0, versionCode 7) | `pubspec.yaml`; mirrored in `AppInfo.version` |

---

## 2. Executive Summary

OpenLock is an **offline Android app-locker** built as a **Flutter application with a native Kotlin enforcement layer**. It is not a pure-native Android project: the UI, configuration, schedules, authentication logic, and backup/restore are written in Dart; the always-on cross-app locking is implemented in Kotlin because it must run reliably from the background.

The two halves communicate over a single `MethodChannel` named `openlock/enforcement` (`lib/src/core/services/method_channel_enforcement_bridge.dart` ⇄ `android/.../EnforcementPlugin.kt`). The Flutter side is the source of truth for configuration; it pushes an "enforcement subset" (locked packages, relock policy, schedules, PIN verifier hash, feature flags) into native `EncryptedSharedPreferences`, which a foreground service reads.

Cross-app locking uses **`UsageStatsManager` polling + an overlay `Activity`**, explicitly **not** an `AccessibilityService` (confirmed: no accessibility service is declared or implemented anywhere in the repo). A persistent foreground service (`OpenLockMonitorService.kt`) polls the foreground app every 300 ms and launches a native `LockActivity` over any locked app. The PIN is verified against a salted **PBKDF2-HMAC-SHA256** verifier, with the identical algorithm implemented in both Dart (`pin_hasher.dart`) and Kotlin (`PinVerifier.kt`) so the lock screen works entirely offline.

Optional features include focus schedules, biometric unlock, an intruder log with silent front-camera capture, a decoy "app has stopped" cover, a randomized keypad, device-admin uninstall protection, an encrypted `.olbackup` export/import, and an in-app GitHub update check.

---

## 3. Project Structure

```
openlock/
├── analysis_options.yaml            # flutter_lints
├── pubspec.yaml / pubspec.lock      # Dart deps (incl. git core_* packages)
├── README.md / RELEASING.md / LICENSE
├── .metadata                        # Flutter project metadata (stable channel)
├── .github/
│   ├── CODEOWNERS
│   ├── pull_request_template.md
│   └── workflows/
│       ├── ci.yml                   # analyze + test + debug APK
│       └── release.yml              # signed APKs → GitHub Release on tags
├── assets/icon/                     # launcher icon PNGs
├── android/
│   ├── build.gradle.kts / settings.gradle.kts / gradle.properties
│   ├── gradle/wrapper/gradle-wrapper.properties   # Gradle 8.14
│   └── app/
│       ├── build.gradle.kts         # SDK/Java/signing/deps
│       └── src/
│           ├── debug/AndroidManifest.xml     # INTERNET (dev only)
│           ├── profile/AndroidManifest.xml
│           └── main/
│               ├── AndroidManifest.xml
│               ├── kotlin/dev/abdullah/openlock/   # 11 native files
│               └── res/                             # styles, colors, device_admin.xml
├── lib/
│   ├── main.dart
│   └── src/
│       ├── app.dart
│       ├── core/                    # di, router, interfaces, services, shell, storage keys, theme
│       └── features/
│           ├── apps/                # app picker + filter
│           ├── auth/                # PIN, biometric, unlock/setup/change
│           ├── backup/             # .olbackup codec + screen
│           ├── enforcement/         # LockConfig, relock policy, config repo, lock policy, uninstall guard
│           ├── intruder/            # intruder log
│           ├── onboarding/          # intro + permissions checklist
│           ├── schedules/           # focus schedules
│           └── settings/            # settings, relock, about, change PIN
└── test/                            # 11 unit test files + 2 widget tests + helpers/fakes.dart
```

Tracked files: **111** (`git ls-files`). Native Kotlin sources: **11**. Dart sources (lib + test): **60**.

---

## 4. Technology Stack

### 4.1 Android / build toolchain

| Component | Value | Source |
|---|---|---|
| Android Gradle Plugin | `8.11.1` | `android/settings.gradle.kts` |
| Kotlin plugin | `2.2.20` (`org.jetbrains.kotlin.android`) | `android/settings.gradle.kts` |
| Flutter Gradle plugin loader | `1.0.0` | `android/settings.gradle.kts` |
| Gradle wrapper | `8.14` (`gradle-8.14-all.zip`) | `android/gradle/wrapper/gradle-wrapper.properties` |
| Java source/target | `17` | `android/app/build.gradle.kts` |
| Kotlin `jvmTarget` | `17` | `android/app/build.gradle.kts` |
| `compileSdk` | `flutter.compileSdkVersion` (delegated, not pinned) | `android/app/build.gradle.kts` |
| `targetSdk` | `flutter.targetSdkVersion` (delegated) | `android/app/build.gradle.kts` |
| `minSdk` | `maxOf(24, flutter.minSdkVersion)` → effectively **24** | `android/app/build.gradle.kts` |
| Core library desugaring | enabled, `desugar_jdk_libs:2.1.4` | `android/app/build.gradle.kts` |
| Flutter channel | `stable` | `.metadata` |
| Dart SDK constraint | `>=3.3.0 <4.0.0` | `pubspec.yaml` |
| Flutter constraint | `>=3.19.0` | `pubspec.yaml` |
| CI Flutter version | `3.41.3` (stable) | `.github/workflows/*.yml` |

The exact `compileSdk`/`targetSdk` integers are resolved by the Flutter Gradle plugin at build time and are **not pinned in the repo** (delegated to the installed Flutter SDK). A comment notes `minSdk` is floored at 24 because `EncryptedSharedPreferences` (AndroidKeyStore AES) needs API 23+.

### 4.2 Native Android AndroidX dependencies (`android/app/build.gradle.kts`)

| Dependency | Version | Purpose |
|---|---|---|
| `androidx.security:security-crypto` | `1.1.0-alpha06` | `EncryptedSharedPreferences` config/intruder store |
| `androidx.biometric:biometric` | `1.1.0` | Fingerprint/face prompt on the native lock screen |
| `androidx.core:core-ktx` | `1.13.1` | Kotlin core extensions |
| `com.android.tools:desugar_jdk_libs` | `2.1.4` | Core-library desugaring |

---

## 5. Application Architecture

**Overall shape: a feature-first Flutter app (Riverpod + go_router) over a thin, testable platform-abstraction seam, paired with a native Kotlin enforcement layer that duplicates the pure decision logic.**

- **UI / state:** Flutter with **Riverpod** providers/notifiers. `AsyncNotifier`/`Notifier` classes own feature state (e.g. `ConfigController`, `SessionNotifier`, `PermissionsController`, `PreventUninstallController`, `IntruderController`). No MVVM/MVP framework is imposed; the pattern is *feature module + Riverpod notifier + pure service classes*.
- **Navigation:** **go_router** with a `redirect` guard driven by `AuthStatus` (`unknown → needsSetup → locked → unlocked`) and a `StatefulShellRoute` bottom-nav shell (`lib/src/core/router/app_router.dart`, `lib/src/core/shell/home_shell.dart`).
- **Composition root / DI:** `lib/src/core/di.dart` wires all leaf providers. Every platform dependency is behind an interface (`IEnforcementBridge`, `IBiometricAuth`, `IConfigFileStore`, `IKeyDerivation`, `Clock`, `ISecureStorage`) so tests inject in-memory fakes (`test/helpers/fakes.dart`) with no platform channels.
- **Shared "Secure Suite" packages:** `core_crypto`, `core_storage`, `core_security`, `core_theme`, `core_ui`, `core_update` are pulled as **git dependencies** from `github.com/MalicKAbdullah/secure-suite-core` (pinned ref `2e656ff…`). Locally they are resolved as path deps via a gitignored `pubspec_overrides.yaml` (see `pubspec.lock`, §13 note).
- **Cross-language mirroring:** The two most correctness-sensitive pieces of logic exist **twice**, once in Dart (the tested source of truth) and once in Kotlin (the runtime enforcer):
  - Relock decision: `LockPolicyEngine` (Dart) ⇄ `LockLogic.isLocked` (Kotlin).
  - Schedule evaluation: `LockScheduleEvaluator` (Dart) ⇄ `LockLogic.scheduledLockedPackages`/`isScheduleActive` (Kotlin).
  - Uninstall-screen guard: `UninstallGuard` (Dart) ⇄ `LockLogic.shouldGuardUninstall` (Kotlin).
  - PIN hashing: `PinHasher` (Dart) ⇄ `PinVerifier` (Kotlin).

  This is a deliberate design choice (documented in the class headers), and a source of maintenance risk: the two implementations must be kept byte-for-byte in step by hand.

**Data flow for a config change:** UI → `ConfigController._apply()` → `ConfigRepository.save()` (encrypts to a file) → `pushToNative()` → `IEnforcementBridge.pushConfig()` → `EnforcementPlugin.pushConfig` → `ConfigStore.saveConfig()` (native `EncryptedSharedPreferences`). The monitor service only ever **reads** that store.

---

## 6. Core Features (implemented, evidenced)

| Feature | Evidence |
|---|---|
| Lock chosen installed apps behind a PIN | `app_picker_screen.dart`, `ConfigController.toggleApp`, `OpenLockMonitorService.tick` |
| Auto-lock newly installed apps (`lockNewApps` flag) | `lock_config.dart` — **see §17 note: flag stored but not enforced natively** |
| Relock policy: immediately / after 1·5·15·30 min / on screen off | `relock_policy.dart`, `LockPolicyEngine`, `LockLogic.isLocked` |
| Focus schedules (time-window locking, weekday/overnight/all-day) | `lock_schedule.dart`, `LockScheduleEvaluator`, `LockLogic` |
| PIN unlock with escalating cooldown | `pin_auth_service.dart`, `LockActivity.kt` |
| Optional biometric (fingerprint) unlock | `biometric_service.dart`, `LockActivity.triggerBiometric` |
| Intruder log + silent front-camera capture | `IntruderCapture.kt`, `intruder_log_screen.dart` |
| Decoy "app has stopped" cover (long-press reveals real lock) | `LockActivity.buildDecoyView`, `fakeCoverEnabled` |
| Randomized keypad (anti-shoulder-surf) | `LockActivity.buildKeypad`, `randomizeKeypad` |
| Device-admin uninstall protection + best-effort screen guard | `OpenLockDeviceAdminReceiver.kt`, `PreventUninstallController`, `UninstallGuard` |
| Encrypted `.olbackup` export/import | `backup_codec.dart`, `backup_screen.dart` |
| In-app GitHub update check | `di.dart` (`GithubUpdateService`), `settings_screen.dart` `_UpdateSection` |
| Restart guard after reboot / app update | `BootReceiver.kt` |
| Guided permissions checklist | `permissions_screen.dart`, `EnforcementPlugin` permission methods |

---

## 7. App-Locking Architecture (lock lifecycle)

The mechanism is **`UsageStatsManager` + overlay activity + foreground service** — **not** an AccessibilityService (none exists in the repo).

| # | Step | Responsible mechanism | File |
|---|---|---|---|
| 1 | User selects an app to lock | Flutter UI toggles `lockedPackages` | `app_picker_screen.dart`, `ConfigController.toggleApp` |
| 2 | Lock state persisted | AES-256-GCM config file + push to native `EncryptedSharedPreferences` | `ConfigRepository`, `ConfigStore` |
| 3 | Monitoring starts | Foreground service started from onboarding / boot | `PermissionsController.startService`, `OpenLockMonitorService.onStartCommand` |
| 4 | Foreground app detected | `UsageStatsManager.queryEvents` polled every **300 ms**, 10 s look-back | `OpenLockMonitorService.foregroundApp` |
| 5 | Lock screen triggered | `startActivity(LockActivity)` with `FLAG_ACTIVITY_NEW_TASK|NO_ANIMATION` | `OpenLockMonitorService.launchLock` |
| 6 | Original app hidden | `LockActivity` (`singleInstance`, `excludeFromRecents`, `FLAG_SECURE`) drawn on top; overlay permission exempts background-activity-start | `AndroidManifest.xml`, `LockActivity.onCreate` |
| 7 | Auth UI appears | Native keypad + auto-triggered `BiometricPrompt` | `LockActivity.buildLockView`, `triggerBiometric` |
| 8 | PIN/biometric entered | `PinVerifier.verify` (PBKDF2) or biometric callback | `LockActivity.onSubmit` |
| 9 | Success / failure | Success → `LockSession.markUnlocked` + `finish()`; failure → cooldown / intruder capture | `LockActivity.unlockAndFinish`, `onWrongPin` |
| 10 | App allowed / blocked | Unlocked packages tracked in-memory for the session | `LockSession` (in-memory `ConcurrentHashMap`) |
| 11 | User leaves the app | Departure timestamp recorded per package | `OpenLockMonitorService.tick` (`leftAppAt`) |
| 12 | Relock decision | `LockLogic.isLocked` (immediately / timeout / screen-off) | `LockLogic`, `LockSession` |
| 13 | Monitoring continues | Poller reposts every 300 ms; `START_STICKY` | `OpenLockMonitorService.poller` |

**Session model:** unlock state lives only in memory (`LockSession`) and is **not persisted** — a reboot re-locks everything (documented in `LockSession.kt`).

**Debounce:** a `RELAUNCH_GUARD_MS = 1500` ms guard prevents stacking multiple lock screens for the same package.

**Visible limitations (from code + README):**
- **Poll-and-launch race:** 300 ms polling means a locked app is briefly foreground before the lock screen appears (`POLL_INTERVAL_MS = 300`).
- **Class-name dependence** for the uninstall guard: `foregroundApp()` relies on `event.className`, which may be null/renamed on some OEMs/newer Android (documented in `README.md` "Honest limits" and `UninstallGuard`/`LockLogic` headers).
- **OEM battery killing:** mitigated only by an optional battery-exemption request; no other keep-alive.

---

## 8. Authentication Architecture

| Aspect | Implementation | Source |
|---|---|---|
| PIN format | Numeric string, **min 6 digits**, max 12 on the native pad | `pin_auth_service.dart` (`minPinLength=6`), `LockActivity` (`MIN_PIN=6`, `pin.length >= 12`) |
| Hashing | **PBKDF2-HMAC-SHA256**, 256-bit output, **120000 iterations**, 16-byte random salt, Base64 | `pin_hasher.dart`, `PinVerifier.kt`, `lock_config.dart` (`pinIterations: 120000`) |
| Storage of verifier | `flutter_secure_storage` (`openlock_pin_hash`, `openlock_pin_salt`); mirrored into native `EncryptedSharedPreferences` at push time | `storage_keys.dart`, `pin_auth_service.verifier`, `lock_config.toNativeMap` |
| Raw PIN | **Never stored** — only the salted hash | `pin_hasher.dart` header, tests |
| Comparison | Constant-time-ish over the Base64 strings (early-return on length mismatch) | `PinHasher._constantTimeEquals`, `PinVerifier.constantTimeEquals` |
| Retry / lockout (app-open) | Escalating cooldown: 30 s at the 5th failure, doubling, capped at 15 min | `pin_auth_service.cooldownFor`, mirrored in `LockActivity.cooldownSeconds` |
| Retry / lockout (lock screen) | Same escalating cooldown in the native activity | `LockActivity.startCooldown` |
| Biometric (app-open) | `local_auth` `biometricOnly`, `stickyAuth`; convenience gate only, no key material | `biometric_service.dart`, `LocalAuthBiometric` |
| Biometric (lock screen) | AndroidX `BiometricPrompt`, `BIOMETRIC_STRONG|WEAK`, auto-prompt on each appearance, PIN fallback | `LockActivity.triggerBiometric` |
| Change PIN | Verifies old PIN then re-hashes with a fresh salt | `pin_auth_service.changePin`, `change_pin_screen.dart` |
| Re-auth gate (disable uninstall protection) | `verifyPin` (does **not** touch the cooldown counter) or biometric | `pin_auth_service.verifyPin`, `settings_screen._authenticateForDisable` |
| Forgot/reset PIN | **Not found** — no recovery path exists; `eraseAll()` exists but is not wired to a UI reset flow | `pin_auth_service.eraseAll` (searched; no caller in UI) |

**Why authentication could fail (from code):** if the native `pinIterations`/algorithm ever drift from the Dart side, the lock screen's PBKDF2 output won't match (both hardcode `120000`); if the Keystore fails and `ConfigStore` falls back to plain prefs (see §10), a mismatch or reset of the pushed verifier is possible. No runtime bug was reproduced.

---

## 9. Android System Integration

### Permissions declared (`android/app/src/main/AndroidManifest.xml`)

| Permission | Purpose (per manifest comments/README) |
|---|---|
| `PACKAGE_USAGE_STATS` | Detect the foreground app (special access) |
| `SYSTEM_ALERT_WINDOW` | Draw + background-start the lock screen |
| `INTERNET` | In-app update check (GitHub) — see §10/§15 |
| `REQUEST_INSTALL_PACKAGES` | Install the downloaded update APK |
| `FOREGROUND_SERVICE` / `FOREGROUND_SERVICE_SPECIAL_USE` | Persistent monitor service |
| `POST_NOTIFICATIONS` | Ongoing "protection active" + intruder notices |
| `RECEIVE_BOOT_COMPLETED` | Restart the monitor after reboot |
| `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` | Reliability on aggressive ROMs |
| `USE_BIOMETRIC` | Fingerprint/face unlock |
| `CAMERA` | Silent intruder photo (optional) |
| `QUERY_ALL_PACKAGES` | Enumerate launchable apps for the picker |

### Components

| Component | Type | Exported | Notes |
|---|---|---|---|
| `MainActivity` | Activity (`FlutterFragmentActivity`) | **true** (LAUNCHER) | `singleTop`, `taskAffinity=""`; hosts the MethodChannel. No `FLAG_SECURE` (see §10). |
| `LockActivity` | Activity | **false** | `singleInstance`, `taskAffinity="…​.lock"`, `excludeFromRecents`, `showWhenLocked`, `turnScreenOn`, `FLAG_SECURE` set in code |
| `OpenLockMonitorService` | Service | **false** | `foregroundServiceType="specialUse"` with declared subtype |
| `OpenLockDeviceAdminReceiver` | Receiver | **true** | Guarded by `BIND_DEVICE_ADMIN`; `DEVICE_ADMIN_ENABLED` filter |
| `BootReceiver` | Receiver | **true** | `BOOT_COMPLETED` + `MY_PACKAGE_REPLACED` |

- **UsageStats:** `EnforcementPlugin.hasUsageAccess` uses `AppOpsManager.OPSTR_GET_USAGE_STATS`; polling via `UsageStatsManager.queryEvents`.
- **Overlay:** `Settings.canDrawOverlays`; request via `ACTION_MANAGE_OVERLAY_PERMISSION`.
- **Device admin:** `device_admin.xml` declares only `force-lock` "to satisfy the policy schema"; the receiver overrides only `onDisableRequested`. It never locks/wipes. Deactivation is auth-gated (`PreventUninstallController.disableWithAuth`).
- **Accessibility Service:** **Not found / not used** (intentional, per README).

---

## 10. Security & Privacy

Format: **FACT** (what the code does) → **RISK** → **RECOMMENDATION**. Nothing below is a claimed exploit beyond what the source supports.

**A. PIN storage**
- FACT: Only a PBKDF2-HMAC-SHA256 verifier + salt is stored; 120000 iterations; raw PIN never persisted (`pin_hasher.dart`, `PinVerifier.kt`).
- RISK: 120k PBKDF2-SHA256 iterations is modest for a short numeric PIN; an attacker with the extracted verifier + salt could brute-force a 6-digit PIN offline relatively cheaply.
- RECOMMENDATION: Consider a memory-hard KDF (Argon2id, already available via `core_crypto` and used for backups) for the unlock verifier, or increase iterations, balanced against on-unlock latency.

**B. EncryptedSharedPreferences fallback**
- FACT: `ConfigStore.createPrefs` catches Keystore failures and falls back to **plaintext** `getSharedPreferences(MODE_PRIVATE)` so the service "still functions rather than crashing" (`ConfigStore.kt`).
- RISK: In that rare fallback path the pushed config **including the PIN verifier hash + salt and locked-app list** would be stored unencrypted in app-private prefs.
- RECOMMENDATION: On Keystore failure, fail closed (refuse to persist the verifier) or surface an explicit degraded-security state rather than silently writing plaintext.

**C. Recents / screenshot exposure of the main app**
- FACT: `FLAG_SECURE` is set **only** on `LockActivity` (`LockActivity.kt:48`). `MainActivity` (which hosts the unlock PIN pad, settings, and the **intruder log with photos**) sets no `FLAG_SECURE` and is not `excludeFromRecents`.
- RISK: The app-open PIN entry, intruder photos, and locked-app list can appear in the Recents thumbnail and be screenshotted.
- RECOMMENDATION: Apply `FLAG_SECURE` to the Flutter `MainActivity` (or gate it on sensitive screens) to match the protection already given to `LockActivity`.

**D. "Offline-only" claim vs. network code**
- FACT: `README.md` states "Offline-only. **No network code**, nothing to leak," yet the app declares `INTERNET` + `REQUEST_INSTALL_PACKAGES` and ships `GithubUpdateService` performing a GitHub release lookup + APK download-and-install (`di.dart`, `settings_screen.dart` `_UpdateSection`).
- RISK: The blanket "no network code" statement is inaccurate; the update path also introduces sideloading of an APK.
- RECOMMENDATION: Reword the privacy claim to "no telemetry/accounts; the only network use is an optional update check," and verify the update download integrity/signature before install. (README elsewhere does describe the update feature, so this is an internal inconsistency.)

**E. `QUERY_ALL_PACKAGES`**
- FACT: Declared to enumerate launchable apps (`installedApps()` filters to `CATEGORY_LAUNCHER`).
- RISK: Broad, Play-policy-sensitive permission; also functionally the picker only needs launchable apps.
- RECOMMENDATION: Where possible rely on the `<queries>` LAUNCHER intent (already declared) instead of the full `QUERY_ALL_PACKAGES`, to reduce policy risk.

**F. Backups**
- FACT: `.olbackup` = JSON envelope with AES-256-GCM ciphertext under an **Argon2id**-derived key from a user passphrase (min 8 chars); key zeroized after use (`backup_codec.dart`).
- RISK: 8-character minimum passphrase; no explicit KDF-parameter storage in the envelope (relies on `core_crypto` defaults + stored salt).
- RECOMMENDATION: Enforce a stronger passphrase policy and embed KDF parameters in the envelope for forward compatibility.

**G. Config at rest**
- FACT: Full config encrypted AES-256-GCM under a random 256-bit key in secure storage; key is independent of the PIN so config survives PIN changes (`config_repository.dart`). Corrupt/unreadable config degrades to `LockConfig.empty` rather than crashing.
- RISK: Silent fallback to empty config on decrypt failure means a corrupted store **silently disables all locking**.
- RECOMMENDATION: Distinguish "no config yet" from "decrypt failed" and warn the user in the latter case.

**H. Intruder photos**
- FACT: Stored in app-private `filesDir/intruders/*.jpg`; deletable individually or in bulk (`IntruderCapture.kt`, `ConfigStore.deleteIntruder/clearIntruders`).
- RISK: Photos are unencrypted at the filesystem level (app-private only); auto-backup behavior not explicitly configured (see below).
- RECOMMENDATION: Consider encrypting captured photos and explicitly disabling cloud/auto-backup for them.

**I. Backup manifest flags**
- FACT: The manifest sets no `android:allowBackup` and no `android:dataExtractionRules`/`fullBackupContent`; `android:debuggable` is not set (no override); no cleartext-traffic config present.
- RISK: With `allowBackup` unspecified, the platform default (historically `true`) may allow ADB/cloud backup of app-private data on some API levels.
- RECOMMENDATION: Explicitly set `android:allowBackup="false"` (or precise data-extraction rules) for a security app.

**J. Logging**
- FACT: No `print(...)` in Dart and no `android.util.Log` calls in Kotlin were found (grep across `lib/` and `android/`).
- Positive: no obvious sensitive-data logging.

---

## 11. Data & Storage

| Mechanism | Technology | File / class | Data | Security |
|---|---|---|---|---|
| Secure key/value | `flutter_secure_storage` (AndroidKeyStore) | `di.dart`, `storage_keys.dart` | Config-encryption key, PIN hash+salt, failed attempts, lockout, biometric flag, onboarding flag, update-autocheck | Hardware-backed where available |
| Encrypted config file | AES-256-GCM (`core_crypto`) blob on disk | `config_repository.dart`, `DocumentsConfigFileStore` (`openlock_config.bin`) | Full `LockConfig` (locked apps, schedules, flags) | Random 256-bit key in secure storage |
| Native enforcement store | `EncryptedSharedPreferences` (AES256-SIV/GCM) | `ConfigStore.kt` (`openlock_enforcement`) | Enforcement subset + PIN verifier + intruder log | Falls back to plaintext prefs on Keystore failure (see §10-B) |
| In-memory session | `ConcurrentHashMap` | `LockSession.kt` | Per-package unlock timestamps | Not persisted (reboot clears) |
| Intruder photos | JPEG files | `IntruderCapture.kt` (`filesDir/intruders/`) | Front-camera captures | App-private, unencrypted files |
| Encrypted backup | JSON envelope, AES-256-GCM + Argon2id | `backup_codec.dart` (`.olbackup`) | Exported `LockConfig` | Passphrase-derived key, zeroized |

**Serialization:** JSON throughout (`LockConfig.toJson/fromJson`, `RelockPolicy`, `LockSchedule`; native side uses `org.json`). **Migration:** backup envelope has a `formatVersion` (currently `1`) with newer-version rejection; the on-disk config has no explicit version field (relies on tolerant `fromJson` defaults).

---

## 12. Important Components

| Area | File | Responsibility |
|---|---|---|
| Flutter entry | `lib/main.dart`, `lib/src/app.dart` | `ProviderScope` + `MaterialApp.router` |
| DI / composition | `lib/src/core/di.dart` | All provider wiring |
| Routing / auth gate | `lib/src/core/router/app_router.dart` | `AuthStatus` redirect + nav shell |
| Native bridge (Dart) | `lib/src/core/services/method_channel_enforcement_bridge.dart` | `openlock/enforcement` client |
| Native bridge (Kotlin) | `android/.../EnforcementPlugin.kt` | Config push, app enumeration, permissions, service/admin control, intruder log |
| Monitor service | `android/.../OpenLockMonitorService.kt` | Foreground app polling + lock triggering |
| Lock screen | `android/.../LockActivity.kt` | Native PIN pad, biometric, cooldown, decoy |
| Lock decision (Dart/Kotlin) | `lock_policy_engine.dart` / `LockLogic.kt` | Relock + schedule + uninstall-guard logic |
| Session state | `android/.../LockSession.kt` | In-memory unlock timestamps |
| PIN hashing | `pin_hasher.dart` / `PinVerifier.kt` | PBKDF2 verifier (mirrored) |
| App-open auth | `pin_auth_service.dart`, `biometric_service.dart` | Setup/unlock/change/cooldown |
| Config model/repo | `lock_config.dart`, `config_repository.dart`, `config_providers.dart` | Source-of-truth config + encryption + native push |
| Schedules | `lock_schedule.dart`, `lock_schedule_evaluator.dart` | Focus windows |
| Backup | `backup_codec.dart`, `backup_screen.dart` | `.olbackup` export/import |
| Config store (native) | `android/.../ConfigStore.kt` | EncryptedSharedPreferences + intruder log |
| Intruder capture | `android/.../IntruderCapture.kt` | Silent Camera2 capture |
| Boot restart | `android/.../BootReceiver.kt` | Restart monitor after reboot/update |
| Device admin | `android/.../OpenLockDeviceAdminReceiver.kt`, `res/xml/device_admin.xml` | Uninstall protection |
| Permissions UI | `permissions_screen.dart`, `permissions_providers.dart` | Guided checklist |

---

## 13. Dependency Inventory

Resolved versions from `pubspec.lock` (constraints from `pubspec.yaml`). Direct = declared in `pubspec.yaml`.

| Dependency | Resolved version | Constraint | Purpose | Direct/Transitive |
|---|---|---|---|---|
| `flutter_riverpod` | 2.6.1 | `^2.5.1` | State management | Direct |
| `go_router` | 14.8.1 | `^14.2.0` | Navigation | Direct |
| `uuid` | 4.5.3 | `^4.4.0` | Schedule IDs, intruder IDs | Direct |
| `intl` | 0.19.0 | `^0.19.0` | Formatting | Direct |
| `path_provider` | 2.1.6 | `^2.1.3` | Documents dir for config/backup | Direct |
| `cryptography` | 2.9.0 | `^2.7.0` | PBKDF2 PIN hashing | Direct |
| `local_auth` | 2.3.0 | `^2.3.0` | Biometric prompt (app-open) | Direct |
| `flutter_secure_storage` | 9.2.4 | `^9.2.2` | Secure key/value | Direct |
| `core_crypto` | git `2e656ff…` (path `0.0.1` locally) | git ref | AES-GCM cipher, Argon2id KDF | Direct (git) |
| `core_storage` | git `2e656ff…` | git ref | `ISecureStorage` impl | Direct (git) |
| `core_security` | git `2e656ff…` | git ref | Shared security utilities | Direct (git) |
| `core_theme` | git `2e656ff…` | git ref | Shared theming | Direct (git) |
| `core_ui` | git `2e656ff…` | git ref | Shared widgets (`VaultButton`, etc.) | Direct (git) |
| `core_update` | git `2e656ff…` | git ref | GitHub update service | Direct (git) |
| `flutter_lints` | 3.0.2 | `^3.0.0` | Lints | Dev |
| `fake_async` | 1.3.3 | `^1.3.1` | Deterministic time in tests | Dev |
| `flutter_launcher_icons` | 0.14.4 | `^0.14.1` | Icon generation | Dev |

**`pubspec.lock` note (discrepancy):** the committed lock resolves the `core_*` packages as **local path** deps (`../../packages/core_*`, source `path`, version `0.0.1`), whereas `pubspec.yaml` declares them as **git** deps. This means the committed lock was generated with the local `pubspec_overrides.yaml` active (that file is gitignored and absent from the repo). A clean `flutter pub get` will re-resolve them from git and rewrite the lock (observed during this analysis).

---

## 14. Build Configuration

- **Build types:** `release` and (implicit) `debug`. `release` signs with the release keystore only if `android/key.properties` exists, else falls back to debug signing (`android/app/build.gradle.kts`). No `minifyEnabled`/`shrinkResources` or ProGuard/R8 rules are configured — **no `proguard-rules.pro` file exists** (R8 not customized).
- **Product flavors:** **None**.
- **Signing:** Release keystore + password sourced from `key.properties` (gitignored; created by CI from secrets). `**/*.keystore`, `**/*.jks`, `android/key.properties` are gitignored.
- **Lint/analysis:** `analysis_options.yaml` includes `package:flutter_lints/flutter.yaml`; CI runs `dart analyze --fatal-infos` (zero tolerance).
- **Expected build:** `flutter pub get` → `flutter build apk` (debug/release), or `flutter run` on a device. Release split-per-ABI in CI.

### Build validation performed during this analysis (results are factual)

Environment: Flutter **3.47.4** (Dart 3.13.3), Java (OpenJDK) 25, on Linux. Note this is **newer** than the repo's CI Flutter (3.41.3).

| Command | Result |
|---|---|
| `flutter pub get` | **Succeeded** (git `core_*` deps resolved; rewrote the tracked `pubspec.lock` and `analysis_options.yaml`, both **restored afterward** — see §22) |
| `dart analyze --fatal-infos` | **"No issues found!"** — matches CI's zero-tolerance gate |
| `flutter test` | **68 test cases passed; 3 test files failed to load** |

The 3 load failures are a **compilation error inside the git dependency `core_theme`** under the newer local Flutter SDK: `core_theme/lib/src/app_theme.dart:73: Error: Method not found: 'CupertinoPageTransitionsBuilder'`. This affects only the 3 test files that transitively import the theme/UI layer (`prevent_uninstall_controller_test.dart`, `widget/app_picker_test.dart`, `widget/onboarding_permissions_test.dart`). It is **not** a defect in OpenLock's own source; it is a Flutter-SDK/dependency version skew. All pure-logic and service tests pass. A full APK build (`flutter build apk`) was **not** attempted.

---

## 15. Testing

Test suite: **11 unit test files + 2 widget tests + `helpers/fakes.dart`** (`test/`). ~77 `test`/`testWidgets` declarations; 68 executed and passed in this environment (see §14 for the 3 that failed to compile against the local SDK).

| Test file | Covers |
|---|---|
| `pin_hasher_test.dart` | PBKDF2 correctness, salt uniqueness, determinism |
| `pin_auth_service_test.dart` | Setup, unlock, attempts, cooldown escalation/cap, change PIN, reset |
| `lock_policy_engine_test.dart` | All relock modes incl. boundary + screen-off |
| `lock_schedule_evaluator_test.dart` | Same-day/overnight/all-day windows, union, DST-safety |
| `lock_config_test.dart` | JSON round-trip, `toNativeMap` subset, defaults |
| `config_repository_test.dart` | Encrypted round-trip, "bytes are not plaintext" |
| `backup_codec_test.dart` | Round-trip, wrong passphrase, invalid/unsupported format |
| `uninstall_guard_test.dart` | Package-installer + Settings class-name matching |
| `app_list_filter_test.dart` | Sort/search/locked-count |
| `prevent_uninstall_controller_test.dart` | Device-admin enable/auth-gated disable/config push |
| `widget/app_picker_test.dart` | Renders apps + toggles lock |
| `widget/onboarding_permissions_test.dart` | Onboarding + permissions checklist rendering |

**Notable gaps (Not found):**
- **No tests for the native Kotlin layer** (`LockLogic`, `PinVerifier`, `OpenLockMonitorService`, `LockActivity`, `IntruderCapture`) — the runtime enforcer and the code that must stay in lockstep with Dart is untested in-repo. The mirroring correctness is only asserted on the Dart side.
- No instrumentation/`androidTest` or integration tests (`test/` is unit/widget only; README notes real locking "cannot be exercised in an emulator or automated test").
- No tests for `biometric_service.dart`, backup **screen** I/O, or the update flow.
- No coverage configuration; **no coverage percentage is claimed**.

---

## 16. CI/CD

Two GitHub Actions workflows (`.github/workflows/`):

**`ci.yml`** — name `CI`; triggers on push to `main` and all PRs; `concurrency` cancels in-progress.
- Steps: checkout → JDK 17 (temurin) → Flutter 3.41.3 (stable, cached) → `flutter pub get` → `dart analyze --fatal-infos` → `flutter test` → `flutter build apk --debug`.

**`release.yml`** — name `Release`; triggers **only** on `v*` tags + manual `workflow_dispatch` (never on PRs, so fork PRs cannot access secrets); `permissions: contents: write`.
- Restores keystore from `KEYSTORE_BASE64`, writes `android/key.properties` from `KEYSTORE_PASSWORD`/`KEY_PASSWORD`/`KEY_ALIAS`, builds `flutter build apk --release` + `--split-per-abi`, collects universal/arm64-v8a/armeabi-v7a/x86_64 APKs into `dist/`, verifies signature with `apksigner`, **removes signing material (`if: always()`)**, uploads artifacts, and publishes a GitHub Release with auto-generated notes on tags.

Signing secrets are referenced by name only (`RELEASING.md`); **no secret values are present in the repo**. Versioning: tags `vMAJOR.MINOR.PATCH` expected to match `pubspec.yaml`.

---

## 17. Feature Matrix

### Implemented (evidenced in code)
- Per-app locking via UsageStats + overlay; native PIN lock screen with cooldown.
- Relock policies (immediately / after timeout / on screen-off).
- Focus schedules (same-day / overnight / all-day, weekday sets).
- PBKDF2 PIN auth (Dart + Kotlin mirror); change PIN.
- Biometric unlock (app-open and lock screen).
- Intruder log + silent Camera2 capture + notifications.
- Decoy cover; randomized keypad.
- Device-admin uninstall protection with auth-gated deactivation + best-effort screen guard.
- Encrypted `.olbackup` export/import.
- Boot/update restart of the monitor.
- In-app GitHub update check + download-and-install.
- Guided permissions checklist.

### Partially Implemented
- **`lockNewApps` ("Lock newly installed apps automatically")**: the flag exists in `LockConfig` and is settable (`ConfigController.setLockNewApps`), but it is **excluded from `toNativeMap`** and there is **no package-added receiver or native logic** enforcing it. As shipped, toggling it has no runtime effect on the native monitor. *(Verified: no `PACKAGE_ADDED` receiver; `lockNewApps` not read in Kotlin.)*
- **Backup UX**: export/import work against a single fixed file in app storage; there is no share-sheet/file-picker (`backup_screen.dart` comment acknowledges this as future work).
- **PIN reset/recovery**: `eraseAll()` exists but is not wired to any "forgot PIN" UI flow.

### Configuration / Permission Dependent
- All cross-app locking requires **Usage Access + Overlay** (`PermissionStates.canEnforce`); the monitor also needs the foreground-service to be running.
- Uninstall protection requires the user to grant **device admin**; the screen guard is OEM/Android-version dependent.
- Intruder photos require **camera** permission (records a photo-less entry otherwise).
- Notification visibility requires **POST_NOTIFICATIONS** (Android 13+).
- Background reliability depends on **battery-optimization exemption**.

### Not Found (commonly expected in app-lockers, absent here)
- Pattern unlock (README mentions "pattern" but **no pattern implementation exists** — auth is numeric PIN + biometric only). **Documentation vs. code discrepancy.**
- Fake-crash *auto* variants beyond the decoy; app-specific per-app relock timeouts.
- Cloud sync (by design — offline).
- Multi-user/profile locking, time-based auto-disable, fingerprint-per-app.
- ProGuard/R8 obfuscation rules.

---

## 18. Known Limitations (evidence-backed)

1. **Poll-and-launch race** (300 ms) allows a brief glimpse of a locked app before the overlay appears — `OpenLockMonitorService`.
2. **Uninstall screen guard is best-effort** and OEM/Android-version dependent; may over-trigger on unrelated app-info screens — `UninstallGuard`/`LockLogic`, README "Honest limits."
3. **Dual-implementation drift risk**: relock/schedule/PIN logic is hand-mirrored in Dart and Kotlin with no native tests to catch divergence.
4. **`lockNewApps` is inert** at runtime (see §17).
5. **Main app has no `FLAG_SECURE`** — Recents/screenshot exposure of PIN entry and intruder photos (§10-C).
6. **Silent plaintext fallback** for the native store on Keystore failure (§10-B); **silent empty-config fallback** on decrypt failure (§10-G).
7. **"No network code" privacy claim is inaccurate** given the update feature (§10-D); README also advertises "pattern" unlock that is not implemented.
8. **`AppInfo.version` (1.1.0) is stale** vs. `pubspec.yaml` (1.4.1+6), so backup envelopes record the wrong app version.
9. **Committed `pubspec.lock` reflects local path deps**, not the git refs in `pubspec.yaml` (§13).
10. **Silent camera capture is device-dependent** and unverifiable without hardware (documented in `IntruderCapture.kt`).

---

## 19. Production Improvement Areas

Prioritized by security/reliability impact. Recommendations are **not** implemented in the current code.

### Critical
- **Set `FLAG_SECURE` on `MainActivity`** (and/or sensitive Flutter screens) to stop Recents/screenshot leakage of PIN entry, intruder photos, and the locked-app list.
- **Do not fall back to plaintext prefs** on Keystore failure (`ConfigStore`); fail closed for the PIN verifier.
- **Set `android:allowBackup="false"`** (or precise data-extraction rules) so app-private lock data/photos aren't exposed to ADB/cloud backup.

### High
- **Add native (JVM) tests** for `LockLogic`, `PinVerifier`, and the config parsing, or extract the shared logic into a single cross-compiled source to eliminate Dart↔Kotlin drift.
- **Correct the privacy documentation** ("no network code") and **verify update APK integrity** before install (`REQUEST_INSTALL_PACKAGES`).
- **Implement or remove `lockNewApps`** and the "pattern" claim to match documentation.
- **Strengthen the unlock KDF** (Argon2id or higher iterations) for the short numeric PIN.

### Medium
- Surface a **decrypt-failure warning** instead of silently reverting to an empty (unprotected) config.
- **Fix `AppInfo.version`** to track `pubspec.yaml` (single source of truth).
- Add **integration/instrumentation coverage** for the service→lock-screen path where feasible.
- Reduce reliance on `QUERY_ALL_PACKAGES` where the LAUNCHER `<queries>` intent suffices.

### Low
- Add a **"forgot PIN"/reset** UX around the existing `eraseAll()`.
- Add a **file-picker/share-sheet** backup flow.
- Consider **encrypting intruder photos** at rest.
- Regenerate/commit a `pubspec.lock` consistent with the published git deps.

---

## 20. Recommended Future Architecture (recommendations only — not current state)

- **Single source of truth for shared logic:** Replace the hand-mirrored Dart/Kotlin logic with one implementation. Options: move the decision logic entirely native and have Flutter call it, or generate the Kotlin from the Dart, or cover both with a shared conformance test vector set. This directly removes limitation §18-3.
- **Version-stamped, migratable persistence:** Add an explicit `schemaVersion` to the on-disk config (as the backup envelope already has) with forward-migration handling.
- **Fail-closed security posture:** Treat Keystore/decrypt failures as security events (warn + block) rather than silent degradation.
- **Formalize the update channel:** Signature-verify downloaded APKs and clearly separate the "offline core" from the "optional online update" in both code and docs.
- **Broaden automated verification:** Introduce JVM unit tests for the native layer and, where possible, instrumented tests for the lock path.

Each item above is a proposal; none is present in commit `89e74dc`.

---

## 21. Important File Reference

| Area | File | Purpose |
|---|---|---|
| Application (Flutter) | `lib/main.dart`, `lib/src/app.dart` | Bootstrap |
| Application (native host) | `android/.../MainActivity.kt` | `FlutterFragmentActivity` + channel host |
| DI | `lib/src/core/di.dart` | Composition root |
| Routing | `lib/src/core/router/app_router.dart` | Auth-gated navigation |
| Bridge | `lib/src/core/services/method_channel_enforcement_bridge.dart`, `android/.../EnforcementPlugin.kt` | Flutter↔native |
| Lock engine (Dart) | `lib/src/features/enforcement/services/lock_policy_engine.dart` | Relock decision |
| Lock engine (native) | `android/.../LockLogic.kt`, `android/.../OpenLockMonitorService.kt` | Runtime enforcement |
| Lock screen | `android/.../LockActivity.kt` | Overlay PIN/biometric UI |
| Authentication | `lib/src/features/auth/services/pin_auth_service.dart`, `pin_hasher.dart`, `android/.../PinVerifier.kt` | PIN + verifier |
| Storage | `lib/src/features/enforcement/services/config_repository.dart`, `android/.../ConfigStore.kt` | Encrypted config |
| Backup | `lib/src/features/backup/services/backup_codec.dart` | `.olbackup` codec |
| Permissions | `lib/src/features/onboarding/screens/permissions_screen.dart` | Guided setup |
| Build | `android/app/build.gradle.kts`, `android/settings.gradle.kts`, `pubspec.yaml` | Toolchain/deps |
| CI/CD | `.github/workflows/ci.yml`, `.github/workflows/release.yml` | Pipeline |
| Manifest | `android/app/src/main/AndroidManifest.xml`, `res/xml/device_admin.xml` | Components/permissions |

---

## 22. Build & Run Instructions

Commands below are taken from `README.md`, `RELEASING.md`, and the CI workflows.

```sh
# Install Dart/Flutter deps (resolves git core_* packages)
flutter pub get

# Run on a connected Android device (recommended over an emulator)
flutter run

# Static analysis (CI's zero-tolerance gate)
dart analyze --fatal-infos      # or: flutter analyze

# Tests
flutter test

# Debug / release APKs
flutter build apk --debug
flutter build apk --release      # falls back to debug signing without android/key.properties
```

Release (maintainers): bump `pubspec.yaml`, push a `vX.Y.Z` tag; the `Release` workflow builds signed universal + per-ABI APKs and publishes a GitHub Release (`RELEASING.md`).

**Verified in this analysis:** `flutter pub get`, `dart analyze --fatal-infos` (clean), and `flutter test` (68 pass; 3 files fail to compile against the newer local SDK — see §14). `flutter build apk` was not run.

---

## 23. Analysis Methodology

This summary was produced by **static inspection** of the repository at commit `89e74dc450d67d5bf2424defadd7deeddcc6d26f` (branch `main`). All 11 Kotlin sources, all 13 test files, every Gradle/manifest/CI/resource config file, and the large majority of the 48 `lib/` Dart sources were read directly; the full 111-file tree was enumerated. Read-only validation (`flutter pub get`, `dart analyze`, `flutter test`) was executed and its **actual** results recorded (§14). The two tracked files that `flutter pub get` regenerated (`pubspec.lock`, `analysis_options.yaml`) were restored via `git checkout` so the working tree's only intentional change is this document. Claims are cited by file path; anything not confirmable from source is marked "Not found"/"Not verified."

---

## 24. Final Technical Notes

OpenLock is a **coherent, well-structured, offline-first Flutter+Kotlin app-locker** with a clean interface seam, strong test coverage of its **pure Dart logic**, encrypted-at-rest configuration, and a realistic, self-documented understanding of the limits of the UsageStats-based technique. Its main gaps are (1) the untested, hand-mirrored native enforcement layer that risks Dart↔Kotlin drift, (2) a few security hardening items — notably the absence of `FLAG_SECURE` on the main app, the plaintext-prefs Keystore fallback, and unspecified `allowBackup`, and (3) documentation that overstates "no network code" and advertises unimplemented "pattern" unlock plus an inert `lockNewApps` toggle. None of these are blocking defects in the core lock path, and all are addressable without architectural change. The project builds its dependency graph cleanly and passes analysis and its logic test suite; a fully reproducible build additionally requires a Flutter SDK compatible with the pinned `core_*` packages (the repo's CI uses Flutter 3.41.3).
