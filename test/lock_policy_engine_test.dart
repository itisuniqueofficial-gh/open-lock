import 'package:flutter_test/flutter_test.dart';
import 'package:openlock/src/features/enforcement/models/relock_policy.dart';
import 'package:openlock/src/features/enforcement/services/lock_policy_engine.dart';

void main() {
  final now = DateTime(2026, 7, 8, 12, 0);
  final unlocked = DateTime(2026, 7, 8, 11, 59);

  test('never unlocked is always locked', () {
    for (final mode in RelockMode.values) {
      expect(
        LockPolicyEngine.isLocked(
          policy: RelockPolicy(mode: mode),
          now: now,
          unlockedAt: null,
        ),
        isTrue,
        reason: '$mode with no unlock should be locked',
      );
    }
  });

  group('immediately', () {
    const policy = RelockPolicy(mode: RelockMode.immediately);

    test('unlocked and still in the app → unlocked', () {
      expect(
        LockPolicyEngine.isLocked(
          policy: policy,
          now: now,
          unlockedAt: unlocked,
        ),
        isFalse,
      );
    });

    test('left the app after unlock → locked', () {
      expect(
        LockPolicyEngine.isLocked(
          policy: policy,
          now: now,
          unlockedAt: unlocked,
          leftAppAt: DateTime(2026, 7, 8, 11, 59, 30),
        ),
        isTrue,
      );
    });

    test('a departure that predates the unlock does not relock', () {
      expect(
        LockPolicyEngine.isLocked(
          policy: policy,
          now: now,
          unlockedAt: unlocked,
          leftAppAt: DateTime(2026, 7, 8, 11, 0),
        ),
        isFalse,
      );
    });
  });

  group('onScreenOff', () {
    const policy = RelockPolicy(mode: RelockMode.onScreenOff);

    test('stays unlocked across app switches', () {
      expect(
        LockPolicyEngine.isLocked(
          policy: policy,
          now: now,
          unlockedAt: unlocked,
          leftAppAt: DateTime(2026, 7, 8, 11, 59, 30),
        ),
        isFalse,
      );
    });

    test('relocks after the screen turns off', () {
      expect(
        LockPolicyEngine.isLocked(
          policy: policy,
          now: now,
          unlockedAt: unlocked,
          screenOffAt: DateTime(2026, 7, 8, 11, 59, 45),
        ),
        isTrue,
      );
    });
  });

  group('afterTimeout', () {
    const policy = RelockPolicy(
      mode: RelockMode.afterTimeout,
      timeout: Duration(minutes: 5),
    );

    test('in the app → unlocked', () {
      expect(
        LockPolicyEngine.isLocked(
          policy: policy,
          now: now,
          unlockedAt: unlocked,
        ),
        isFalse,
      );
    });

    test('away but within the timeout → unlocked', () {
      expect(
        LockPolicyEngine.isLocked(
          policy: policy,
          now: DateTime(2026, 7, 8, 12, 2),
          unlockedAt: unlocked,
          leftAppAt: DateTime(2026, 7, 8, 12, 0),
        ),
        isFalse,
      );
    });

    test('away past the timeout → locked', () {
      expect(
        LockPolicyEngine.isLocked(
          policy: policy,
          now: DateTime(2026, 7, 8, 12, 6),
          unlockedAt: unlocked,
          leftAppAt: DateTime(2026, 7, 8, 12, 0),
        ),
        isTrue,
      );
    });

    test('exactly at the timeout boundary → locked', () {
      expect(
        LockPolicyEngine.isLocked(
          policy: policy,
          now: DateTime(2026, 7, 8, 12, 5),
          unlockedAt: unlocked,
          leftAppAt: DateTime(2026, 7, 8, 12, 0),
        ),
        isTrue,
      );
    });

    test('screen off relocks even before the timeout', () {
      expect(
        LockPolicyEngine.isLocked(
          policy: policy,
          now: DateTime(2026, 7, 8, 12, 1),
          unlockedAt: unlocked,
          leftAppAt: DateTime(2026, 7, 8, 12, 0),
          screenOffAt: DateTime(2026, 7, 8, 12, 0, 30),
        ),
        isTrue,
      );
    });
  });
}
