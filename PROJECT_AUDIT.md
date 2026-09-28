# Open Lock architecture and lifecycle audit

Date: 2026-09-28

This audit covers the existing Flutter/Kotlin implementation and the reliability
changes in this branch. Open Lock remains a Flutter application with its
existing native lock activity, PIN/biometric authentication, schedules, intruder
log, backups, device-admin option, update checker, and app picker.

## Baseline findings

### Flutter

- Riverpod `ConfigController` persisted the full `LockConfig` in encrypted
  Flutter storage and projected the native subset through
  `openlock/enforcement`.
- The native bridge already carried locked packages, relock policy, schedules,
  feature flags, and the salted PBKDF2 verifier. This was the correct seam for
  a UI-independent enforcement layer.
- The first-run setup could race the config provider: the PIN was created and
  pushed before the policy was guaranteed to be loaded. Native configuration
  changes also updated Flutter state before native persistence/channel success.
- The permission screen reported Usage Access and overlay only. There was no
  selectable enforcement method and no Accessibility permission state.

### Android

- `OpenLockMonitorService` was the only enforcement source. It ran as a
  foreground service, queried UsageStats over a ten-second window every 300 ms,
  and read encrypted preferences repeatedly through every tick.
- There was no AccessibilityService, no manifest package receiver, and the
  dynamic package receiver existed only while the monitor service was alive.
  Lock New Apps therefore depended on a running service.
- The boot receiver started the UsageStats service without making the selected
  method or actual permission state authoritative.
- LockActivity had a short launch debounce, but there was no shared native
  foreground/lock state machine. A lock activity transition could be mistaken
  for leaving the protected app, causing a valid unlock to relock immediately.
  The biometric prompt could also be retriggered by lifecycle resume.
- A missing native verifier fell through to `unlockAndFinish()`, which was an
  authentication bypass if native configuration was unavailable.
- `ConfigStore` parsed encrypted preferences on every service getter, including
  the high-frequency poll path.

## Implemented architecture

```text
Flutter UI
  -> validated LockConfig + encrypted Flutter persistence
  -> MethodChannel push (only after native acceptance)
  -> native EncryptedSharedPreferences projection

Native projection
  -> LockEnforcementManager (one policy/state owner)
       |-- OpenLockAccessibilityService (window-state events)
       |-- OpenLockMonitorService (UsageStats, selected fallback only)
       |-- BootReceiver (recovery/start-if-authorized)
       |-- PackagePolicyReceiver (Lock New Apps)
       `-- LockActivity (one authentication transaction)
```

`LockEnforcementManager` owns the current package transition, departure
timestamps, screen-off timestamp, selected source, active lock package, launch
debounce, and the hand-off to `LockSession`. `LockSession` owns the in-memory
authentication state (`LOCKED`, `AUTHENTICATING`, `AUTHENTICATED`, `UNLOCKED`,
or `RELOCK_REQUIRED`). Authentication is intentionally not persisted: process
death and reboot require a fresh unlock.

### Accessibility mode

- The user chooses it in Protection setup and enables it in Android Settings.
- The service observes only `TYPE_WINDOW_STATE_CHANGED`, with generic feedback,
  a 100 ms notification timeout, no content retrieval, and no gestures.
- Events are sent directly to the manager. No Flutter isolate, foreground
  monitor service, wake lock, or persistent Open Lock notification is needed.
- Android reconnects the service according to its Accessibility lifecycle. The
  service reloads the encrypted native projection through the manager.

### Usage Access mode

- The user chooses it and grants Usage Access plus overlay access.
- The native foreground service is started only in this mode and only when a
  PIN, enforcement work, Usage Access, and overlay permission are present.
- It uses one-second boundary-based UsageStats queries, deduplicates the last
  foreground package, and uses `START_STICKY` for Android lifecycle recovery.
- The foreground notification is mandatory for this implementation and is not
  suppressed. If permission is revoked, the service stops and the UI reports
  the actual disabled state.

### Lock New Apps

`PackagePolicyReceiver` handles `PACKAGE_ADDED` and `PACKAGE_REMOVED` with the
package data scheme. Genuine installs are added to the native encrypted
`autoLockedPackages` set when Lock New Apps and the native verifier are present;
updates are ignored, removed packages are cleaned up, and Flutter is not
required. Android's force-stop rules remain an explicit platform boundary.

### Reboot and update recovery

`BootReceiver` handles `BOOT_COMPLETED` and `MY_PACKAGE_REPLACED`. It loads the
persisted native projection and starts Usage mode only after checking the
selected method, PIN/work, Usage Access, and overlay state. It never grants a
special access permission. An enabled Accessibility service is left for Android
to reconnect; its disabled state is reported when the UI resumes. No Direct Boot
storage was introduced because the enforcement state is not required before the
user unlocks the device and the encrypted store must not be moved into
device-protected plaintext storage.

## Permission truth model

Android is queried each time the permission screen builds or resumes:

- Usage Access: `AppOpsManager.OPSTR_GET_USAGE_STATS`.
- Overlay: `Settings.canDrawOverlays`.
- Accessibility: enabled service list and the secure enabled-service setting.
- Notifications: `NotificationManagerCompat.areNotificationsEnabled`.
- Battery exemption: `PowerManager.isIgnoringBatteryOptimizations`.
- Selected source running: actual Accessibility enabled state or the native
  Usage Access service state.

A stored preference never substitutes for any of these checks. The UI calls a
system Settings intent for each special access and verifies state after resume.

## Security and lifecycle notes

- PINs and biometric secrets are not logged or persisted. Native lock-screen
  verification uses the existing PBKDF2 verifier projection; a missing
  projection fails closed instead of unlocking.
- `LockActivity` is `singleTask`, excluded from Recents, `FLAG_SECURE`, and
  guarded by one manager-owned active target. The manager will bring the same
  activity forward rather than create a second authentication screen.
- Lock Activity events are not treated as the protected app leaving the
  foreground. A successful PIN marks the package unlocked; Home/back marks it
  `RELOCK_REQUIRED`; screen-off timestamps force relock under every policy.
- Native ConfigStore uses encrypted preferences, caches projections in memory,
  invalidates caches when another component commits a change, and durably
  commits low-frequency configuration changes. A keystore failure remains
  fail-closed and non-persistent.
- Device Admin remains only the existing optional uninstall-protection feature.
  Its live state is checked, and native state is cleared when Android reports
  that the admin was disabled. It is not used as a background keep-alive.
- The existing app picker excludes Open Lock itself, so there is no separate
  self-lock policy to persist. The native manager always excludes its own
  package and therefore cannot enter an Open Lock authentication loop.

## Android limits not hidden by this implementation

- Android can stop an app/service, revoke Usage Access or Accessibility, and
  apply OEM background restrictions. No supported API can make Open Lock
  impossible to kill or guarantee execution forever.
- UsageStats detection has a short poll window. Accessibility delivery can vary
  by OEM and Android version. Device Admin does not defeat ADB, Safe Mode, or a
  factory reset.
- The AccessibilityService is a legitimate app-lock feature only; it does not
  automate other apps, read unrelated content, or bypass system permission UI.

## Verification matrix

### Automated in CI

- `dart format --set-exit-if-changed .`
- `dart analyze --fatal-infos`
- `flutter test`
- `flutter build apk --release`
- `flutter build appbundle --release`

The repository workflows already validate package id, label, assets, signing
inputs, release version, APK signature, and AAB validity.

### Physical-device / instrumentation required

| Scenario | Expected result |
|---|---|
| Fresh install | Setup reports both supported methods and their real states. |
| Accessibility enable/disable | Events enforce while enabled; UI says unavailable after disable. |
| Usage Access/overlay enable/disable | Service starts only when both are granted; revocation stops protection. |
| Close Flutter UI | Native enforcement continues. |
| Rapid app switching | One manager state and at most one LockActivity. |
| PIN/biometric success/failure | Success opens the app; failure remains locked and cooldown is native. |
| Home/back from lock | Target is marked relock-required. |
| Screen off/on | Authenticated package relocks according to the native state. |
| Lock New Apps | Package receiver adds a new app while Flutter is closed. |
| Reboot/update | Native projection survives; Usage mode starts only when authorized; Accessibility reconnects when enabled. |
| Process/service death | Android lifecycle reconnects the selected component; no uncontrolled restart loop is added. |
| Device Admin | Actual admin state drives the UI and native uninstall-guard flag. |
| Schedules/intruder/backup/restore/update | Existing features remain on their existing Flutter/native seams. |

A physical device is required for Accessibility, Usage Access, overlay,
reboot, OEM battery, Device Admin, camera, and biometric rows; host unit tests
cannot honestly simulate those Android services.
