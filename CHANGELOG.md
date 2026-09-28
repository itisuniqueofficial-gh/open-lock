# Changelog

## Unreleased

### Reliability and native enforcement

- Added a user-selectable native enforcement method: Accessibility Service or
  Usage Access.
- Added an event-driven AccessibilityService that observes only window-state
  changes and does not retrieve window content.
- Centralized foreground transitions, relock policy, schedules, authentication
  state, and LockActivity deduplication in `LockEnforcementManager`.
- Removed the 300 ms native polling loop. Usage Access mode now uses a
  deduplicated one-second query from the last UsageStats event boundary and is
  the only mode that starts the foreground service notification.
- Added native package-added/package-removed handling for Lock New Apps so the
  Flutter UI does not need to remain open.
- Persisted the selected enforcement method in the encrypted Flutter/native
  configuration projection and made native configuration updates transactional.
- Added reboot and package-replacement recovery that starts Usage Access mode
  only when the selected method, persisted policy, and actual Android
  permissions are available. Accessibility is never enabled programmatically.
- Cached native configuration projections to avoid repeated encrypted disk
  reads during foreground detection.
- Prevented missing-native-verifier authentication bypasses and tightened
  duplicate lock-screen and biometric prompt handling.

### Setup and documentation

- Protection setup now explains both methods, their actual status, required
  permissions, battery considerations, and the Usage Access notification.
- Updated README and project summary with lifecycle behavior, Android limits,
  Play-compatible permission use, and low-resource considerations.

Platform-dependent behavior still requires physical-device verification. Android
may stop components or revoke permissions, and OEM battery policies can affect
background reliability.
