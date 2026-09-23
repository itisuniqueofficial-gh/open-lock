import 'package:flutter_test/flutter_test.dart';
import 'package:openlock/src/features/auth/services/pin_auth_service.dart';
import 'package:openlock/src/features/auth/services/pin_hasher.dart';
import 'package:openlock/src/features/enforcement/models/lock_config.dart';

/// Guards the cross-language contract between the Dart lock logic and its Kotlin
/// mirror (PinVerifier / LockActivity). These constants are hardcoded on both
/// sides; if the Dart side drifts, the native lock screen would reject a valid
/// PIN. Changing any value here must be matched in the Kotlin sources.
void main() {
  test('PBKDF2 parameters match the native PinVerifier contract', () {
    // Kotlin: ConfigStore.pinIterations() default 120000; PinVerifier uses it.
    expect(PinHasher.iterations, 120000);
    expect(PinHasher.keyLengthBits, 256);
    expect(PinHasher.saltLength, 16);

    final map = const LockConfig().toNativeMap(pinHash: 'H', pinSalt: 'S');
    // The iteration count pushed to native must equal the Dart hasher's.
    expect(map['pinIterations'], PinHasher.iterations);
  });

  test('minimum PIN length matches LockActivity.MIN_PIN', () {
    expect(PinAuthService.minPinLength, 6);
  });

  test('escalating cooldown matches LockActivity.cooldownSeconds', () {
    // Kotlin mirror: 30s at the 5th failure, doubling, capped at 15 min (900s).
    expect(PinAuthService.maxFreeAttempts, 5);
    expect(PinAuthService.cooldownFor(4), Duration.zero);
    expect(PinAuthService.cooldownFor(5), const Duration(seconds: 30));
    expect(PinAuthService.cooldownFor(6), const Duration(seconds: 60));
    expect(PinAuthService.cooldownFor(7), const Duration(seconds: 120));
    expect(PinAuthService.cooldownFor(50), const Duration(minutes: 15));
  });
}
