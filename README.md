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

Open Lock uses the standard, Play-acceptable technique for cross-app locking —
**Usage Access + an overlay**, never an accessibility service:

1. A lightweight **foreground service** watches which app is in the foreground
   using Android's `UsageStatsManager`.
2. When a **locked** app comes to the front and isn't in an unlocked session
   (per your relock policy and schedules), Open Lock launches a native **lock
   screen** over it.
3. The lock screen verifies your PIN against a stored **verifier hash** (never
   the raw PIN) entirely on-device, or accepts your **fingerprint**.
4. A **boot receiver** restarts the guard after a reboot.

The main app (app picker, schedules, settings, onboarding) is Flutter; the
on-top lock screen is native Kotlin for reliability.

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

- It relies on `UsageStatsManager` reporting the foreground activity's class
  name; some OEM skins and newer Android releases name or restrict these
  screens differently, so the overlay may not always fire in time (there is an
  inherent poll-and-launch race).
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
| **Usage access** (`PACKAGE_USAGE_STATS`) | Detect the foreground app so a locked app can be caught. |
| **Display over other apps** (`SYSTEM_ALERT_WINDOW`) | Show the lock screen over a locked app and launch it from the background. |
| **Foreground service** (`FOREGROUND_SERVICE` / `_SPECIAL_USE`) | Keep the guard running with an ongoing notification. |
| **Notifications** (`POST_NOTIFICATIONS`) | Show the "protection active" notice (Android 13+). |
| **Device administrator** (`BIND_DEVICE_ADMIN`) | Optional — only if you enable **Prevent uninstall**. |
| **Ignore battery optimization** | Optional — keeps the guard alive on aggressive OEM ROMs. |
| **Camera** | Optional — silent intruder snapshots if enabled. |
| **Run at boot** (`RECEIVE_BOOT_COMPLETED`) | Restart protection after a reboot. |
| **Install packages** (`REQUEST_INSTALL_PACKAGES`) / **Internet** | Optional in-app update download from GitHub. |
| **Query all packages** (`QUERY_ALL_PACKAGES`) | List launchable apps you can choose to lock; read locally only. |

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
  `flutter test`, and a debug APK build (uploaded as an artifact).
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
- **Kotlin** — foreground monitor service, native lock activity, device-admin
  and boot receivers.
- **Riverpod** (state) · **go_router** (navigation) · **local_auth** / AndroidX
  **BiometricPrompt** (fingerprint) · **UsageStatsManager** + overlay
  (enforcement) · **DevicePolicyManager** (uninstall protection).

## Limitations

- **No PIN recovery.** There is intentionally no "forgot PIN" bypass — a
  recovery path would be a lock bypass. If you forget your PIN, the app's data
  must be cleared (which also clears your locks).
- **Reliability is best-effort.** App-lock timing depends on `UsageStatsManager`
  polling and can be affected by OEM background restrictions and battery
  optimization. There is an inherent brief window before the lock screen
  appears. Open Lock is a strong deterrent, not an unbreakable guarantee.
- **Auto-lock of new apps** depends on the monitor running and the OS
  delivering package-install broadcasts.
- **Package migration.** This build's application id is
  `com.itisuniqueofficial.openlock`. Installing it over a build that used the
  previous id is treated by Android as a separate app; data is not migrated.

## License

[MIT](LICENSE) © 2026 It Is Unique Official.
