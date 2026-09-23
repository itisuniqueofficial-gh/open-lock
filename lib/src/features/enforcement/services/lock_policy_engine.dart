import 'package:openlock/src/features/enforcement/models/relock_policy.dart';

/// The single, pure decision at the heart of the monitor service: given a
/// locked app's session state, is it locked *right now*?
///
/// The native service records, per locked package, when it was last unlocked
/// ([unlockedAt]), when it last left the foreground ([leftAppAt]), and — once
/// globally — when the screen last went off ([screenOffAt]). Every poll it
/// asks this engine whether to throw up the lock screen.
///
/// Keeping this logic in one small, exhaustively-tested pure function means
/// the tricky relock semantics never drift between platforms.
abstract final class LockPolicyEngine {
  /// Returns true when the app must be locked.
  ///
  /// - [unlockedAt] is null until the user has authenticated at least once in
  ///   the current session, so a null value is always locked.
  /// - [leftAppAt] / [screenOffAt] are null when they have not happened since
  ///   the last unlock.
  static bool isLocked({
    required RelockPolicy policy,
    required DateTime now,
    DateTime? unlockedAt,
    DateTime? leftAppAt,
    DateTime? screenOffAt,
  }) {
    // Never unlocked in this session → locked.
    if (unlockedAt == null) return true;

    // A screen-off that happened after the unlock re-locks in every mode:
    // an off screen is unambiguously "the user walked away".
    if (screenOffAt != null && screenOffAt.isAfter(unlockedAt)) {
      return true;
    }

    // Did the app leave the foreground after we unlocked it?
    final leftAfterUnlock = leftAppAt != null && leftAppAt.isAfter(unlockedAt);

    switch (policy.mode) {
      case RelockMode.immediately:
        // Any departure re-locks.
        return leftAfterUnlock;

      case RelockMode.onScreenOff:
        // Only the screen-off check above matters; app switches don't relock.
        return false;

      case RelockMode.afterTimeout:
        // Still in the app → unlocked. Away → locked once the timeout elapses.
        if (!leftAfterUnlock) return false;
        return now.difference(leftAppAt).abs() >= policy.timeout;
    }
  }
}
