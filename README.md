# Open Lock

**Lock any app behind your PIN or fingerprint — offline.**

Open Lock lets you pick the apps that matter and guards them behind a PIN or
fingerprint, with focus schedules, device-admin uninstall protection, and an
intruder log. Everything runs on-device.

![License](https://img.shields.io/badge/License-MIT-D97706?style=flat-square)
![Platform](https://img.shields.io/badge/Platform-Android-D97706?style=flat-square)
![Built with Flutter](https://img.shields.io/badge/Built%20with-Flutter-027DFD?style=flat-square)

- **Maintained by:** It Is Unique Official
- **Developed by:** Jaydatt Khodave
- **Website:** https://openlock.itisuniqueofficial.com
- **Developer:** https://jaydatt.pages.dev
- **GitHub:** https://github.com/itisuniqueofficial-gh/open-lock

---

## Private by design

Open Lock works **offline**. Your lock settings and any intruder photos are
encrypted on your device — no account, no cloud sync, no ads, no analytics, no
tracking. The **only** network access is an optional check for a newer release
on GitHub (see [Privacy & Security](#privacy--security)); it can be turned off
in Settings.

## Features

**Lock what matters**
- Pick any installed app from a searchable list with icons and lock it behind
  your **PIN or fingerprint**.
- **Lock newly installed apps automatically** — new installs are caught by the
  background monitor and locked (see [Limitations](#limitations)).
- Choose when apps relock: **the moment you leave**, after **1 / 5 / 15 /
  30 min**, or **when the screen turns off**.

**Focus schedules**
- Lock a chosen set of apps during **time windows** — e.g. social apps 9–5 on
  weekdays, games during study time — enforced by the background guard.
- Same-day, overnight, and all-day windows.

**Uninstall protection**
- Optional **Prevent uninstall** uses Android's device-administrator API so the
  app can't be casually removed. Turning it back off is **auth-gated** (PIN or
  fingerprint). See [honest limits](#uninstall-protection) below.

**Stay in control**
- **Intruder log** — after too many wrong attempts, Open Lock can silently take
  a front-camera photo and log the time and app.
- **Anti-shoulder-surfing** — optional randomized keypad.
- Escalating **cooldown** after repeated wrong guesses.
- Optional **decoy cover** — a fake "app has stopped" dialog; a long-press
  reveals the real unlock.

**Yours to keep**
- **Encrypted backup & restore** (`.olbackup`) protected by a passphrase you
  choose.
- Change your PIN and toggle fingerprint unlock from Settings.

## How it works

Open Lock uses one of two user-selected, Android-supported enforcement
methods:

- **Accessibility Service:** event-driven window-state notifications identify
  foreground package transitions. The service requests only
  `typeWindowStateChanged`, does not retrieve window content, and is never
  enabled silently.
- **Usage Access:** `UsageStatsManager` is queried from a native foreground
  service once per second from the last query boundary. Android requires an
  ongoing notification for this mode, and the lock activity uses the user's
  overlay permission to appear over the protected app.

Both methods feed one native `LockEnforcementManager`. It reads the persisted
policy without starting Flutter, applies relock and schedule rules, prevents
duplicate lock activities, and launches the native authentication screen. The
lock screen verifies your PIN against a stored **verifier hash** (never the raw
PIN) entirely on-device, or accepts your **fingerprint**. Flutter manages
configuration, onboarding, app selection, logs, and settings; it is not a
foreground-app monitor.

A boot receiver and native package receiver restore supported behavior after a
reboot/update and enforce Lock New Apps even when the Flutter UI is closed.
Android may still revoke permissions, stop components, or apply OEM battery
restrictions; Open Lock reports those actual states instead of pretending
protection is active.

> Cross-app locking is **Android-only by platform design**. Real lock behavior
> requires granting the permissions below on a **physical device**; it cannot
> be fully exercised in an emulator or automated test.

## Uninstall protection

The optional **Prevent uninstall** toggle (Settings → Security) is built on
Android's **device administrator** API:

- Enabling it launches the system "activate device admin" dialog. While Open
  Lock is an active device admin, Android refuses to uninstall it.
- Turning it back off is **auth-gated** — device admin is only deactivated
  after a successful **PIN or fingerprint** check inside the app.
- **Best-effort screen guard.** While protection is on, the monitor also
  watches for the OS screens used to disable it (device-admin deactivation,
  App info / uninstall, the package-installer dialog) and throws up the lock
  screen first.

### Honest limits

The screen guard is **best-effort and Android-version / OEM dependent** — do
not treat it as unbreakable:

- In Usage Access mode it relies on `UsageStatsManager` reporting foreground
  events, so there can be a short poll-and-launch window. Accessibility mode is
  event-driven but still depends on Android delivering accessibility events.
  OEM skins and newer Android releases may restrict or alter either source.
- Because the App-info screen doesn't reveal which app is being viewed, the
  guard is intentionally broad and may also prompt when you open another app's
  info page.
- Device admin blocks the normal uninstall flow, but a determined user with
  **ADB, Safe Mode, or a factory reset** can still remove any non-system app.
  This is a deterrent against casual removal, not a guarantee against a
  technical adversary with physical access.

## Privacy & Security

- **Offline core.** No accounts, no telemetry, no ads. The only network use is
  an optional GitHub release check (toggle in Settings).
- **Your PIN is never stored.** Open Lock keeps only a salted
  **PBKDF2-HMAC-SHA256** verifier hash. The same algorithm runs in Dart and in
  native Kotlin so the lock screen can check your PIN offline, byte-for-byte
  identically.
- **Encrypted at rest.** Your full config is encrypted with **AES-256-GCM**
  under a random key held in Android's Keystore (`flutter_secure_storage`). The
  subset the native guard needs lives in **EncryptedSharedPreferences**. If the
  Keystore is unavailable, Open Lock **fails closed** — it does not write the
  verifier to plaintext.
- **Screenshot / Recents protection.** Both the main app and the lock screen
  set `FLAG_SECURE`, keeping sensitive content out of screenshots and the
  Recents preview.
- **Backups off by default.** `android:allowBackup="false"` — app-private data
  is not included in system/cloud backups.
- **Encrypted backups.** `.olbackup` files are encrypted with a separate
  passphrase (Argon2id-derived key).
- **Intruder photos stay on the device**, in app-private storage.

## Permissions — and why

| Permission | Why |
| --- | --- |
| **Accessibility Service** (`BIND_ACCESSIBILITY_SERVICE`) | Optional user-selected event source; receives only window-state changes to detect a protected app opening. It does not read window content. |
| **Usage access** (`PACKAGE_USAGE_STATS`) | Optional user-selected source; lets the native Usage Access mode detect the foreground app. |
| **Display over other apps** (`SYSTEM_ALERT_WINDOW`) | Required by Usage Access mode to present the lock activity over the protected app. Not required by the selected Accessibility path on supported Android versions. |
| **Foreground service** (`FOREGROUND_SERVICE` / `_SPECIAL_USE`) | Used only by Usage Access mode because Android requires background execution to be user-visible. |
| **Notifications** (`POST_NOTIFICATIONS`) | Allows the Usage Access service notification on Android 13+; it is not used to hide or suppress required system visibility. |
| **Device administrator** (`BIND_DEVICE_ADMIN`) | Optional — only if you enable **Prevent uninstall**. |
| **Ignore battery optimization** | Optional — keeps the guard alive on aggressive OEM ROMs. |
| **Camera** | Optional — silent intruder snapshots if enabled. |
| **Run at boot** (`RECEIVE_BOOT_COMPLETED`) | Restart protection after a reboot. |
| **Install packages** (`REQUEST_INSTALL_PACKAGES`) / **Internet** | Optional in-app update download from GitHub. |
| **Query all packages** (`QUERY_ALL_PACKAGES`) | List launchable apps you can choose to lock; read locally only. |

## Protection setup

Open Lock's **Protection setup** page reports live Android state and guides the
user through:

1. Choose **Accessibility Service** or **Usage Access**.
2. Use **Grant** to open the relevant Android Settings page, then return to
   verify the actual permission.
3. Select apps to lock.
4. Configure the PIN and optional biometric authentication.
5. Review optional battery optimization and security protections.

Accessibility is the lower-resource, event-driven option and does not start an
Open Lock foreground service. Usage Access is a supported fallback where the
user prefers it, but it uses a one-second native poll and a required foreground
service notification. The two methods are not claimed to have identical timing
or lifecycle behavior.

## Getting started

**Prerequisites:** [Flutter SDK](https://docs.flutter.dev/get-started/install)
and Android Studio.

```sh
git clone https://github.com/itisuniqueofficial-gh/open-lock.git
cd open-lock
flutter pub get
flutter run   # on a connected Android device (recommended over an emulator)
```

Run the checks the way CI does:

```sh
dart format --output=none --set-exit-if-changed .
dart analyze --fatal-infos
flutter test
```

Build:

```sh
flutter build apk --debug
flutter build apk --release        # split per ABI: add --split-per-abi
flutter build appbundle --release  # AAB for the Play Store
```

> The shared `core_*` packages are pulled from the
> [secure-suite-core](https://github.com/MalicKAbdullah/secure-suite-core)
> repository (a functional dependency). Local development can resolve them by
> path via a gitignored `pubspec_overrides.yaml`.

## Continuous integration & releases

- **CI** ([`.github/workflows/ci.yml`](.github/workflows/ci.yml)) runs on every
  push and pull request: formatting check, `dart analyze --fatal-infos`,
  `flutter test`, debug and release APK builds, and a release AAB build
  (uploaded as artifacts).
- **Release** ([`.github/workflows/release.yml`](.github/workflows/release.yml))
  runs on `v*` tags (and manual dispatch): it builds **signed** universal +
  per-ABI APKs and an AAB, verifies the signature / package id / version,
  generates release notes, and publishes a GitHub Release with the artifacts.

Signing uses GitHub Secrets (`ANDROID_KEYSTORE_BASE64`,
`ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_PASSWORD`, `ANDROID_KEY_ALIAS`) — see
[`RELEASING.md`](RELEASING.md). Keystores and `key.properties` are gitignored
and never committed.

## Built with

- **Flutter** & **Dart** — UI, configuration, schedules, and pure-Dart lock
  logic.
- **Kotlin** — native enforcement manager, Accessibility/Usage Access sources,
  lock activity, package/boot receivers, and device-admin integration.
- **Riverpod** (state) · **go_router** (navigation) · **local_auth** / AndroidX
  **BiometricPrompt** (fingerprint) · **UsageStatsManager** + Accessibility
  events (enforcement) · **DevicePolicyManager** (uninstall protection).

## Limitations

- **No PIN recovery.** There is intentionally no "forgot PIN" bypass — a
  recovery path would be a lock bypass. If you forget your PIN, the app's data
  must be cleared (which also clears your locks).
- **Reliability is best-effort within Android's supported APIs.** Accessibility
  depends on Android delivering window-state events. Usage Access has a short
  poll-and-launch window and requires its foreground service. OEM background
  restrictions and battery optimization can affect either method.
- **Auto-lock of new apps** is handled by a native package receiver, but Android
  may withhold package broadcasts after the user force-stops an app. Newly
  installed packages are added to a native encrypted set and do not require
  Flutter to be open.
- Android can stop applications and users can revoke special access. Open Lock
  cannot be completely invisible, impossible to kill, guaranteed to run forever,
  or identical to a system app.
- **Package migration.** This build's application id is
  `com.itisuniqueofficial.openlock`. Installing it over a build that used the
  previous id is treated by Android as a separate app; data is not migrated.

## License

[MIT](LICENSE) © 2026 It Is Unique Official.
