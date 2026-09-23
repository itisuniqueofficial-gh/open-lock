import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Salted PBKDF2-HMAC-SHA256 hashing of the unlock PIN.
///
/// The raw PIN is never stored. We keep only `hash = PBKDF2(pin, salt)` plus
/// the random [saltLength]-byte salt. The identical algorithm is implemented
/// natively (Kotlin `PBKDF2WithHmacSHA256`) so the on-top LockActivity can
/// verify the PIN entirely offline without any Dart runtime — the verifier
/// hash and salt are the only PIN-derived values that ever cross the bridge.
///
/// PBKDF2 (rather than a bare digest) makes brute-forcing the short numeric
/// PIN costly, and choosing a standard both platforms ship natively guarantees
/// the Dart and Kotlin hashes match byte-for-byte.
final class PinHasher {
  const PinHasher();

  /// Iteration count. Deliberately in a comment-worthy constant so the Kotlin
  /// side stays in lockstep — changing one without the other breaks unlock.
  static const int iterations = 120000;
  static const int keyLengthBits = 256;
  static const int saltLength = 16;

  static final Pbkdf2 _pbkdf2 = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: iterations,
    bits: keyLengthBits,
  );

  /// A fresh cryptographically-random salt.
  Uint8List newSalt([Random? random]) {
    final rng = random ?? Random.secure();
    return Uint8List.fromList(
      List<int>.generate(saltLength, (_) => rng.nextInt(256)),
    );
  }

  /// Base64 PBKDF2 hash of [pin] under [salt].
  Future<String> hash({required String pin, required Uint8List salt}) async {
    final key = await _pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(pin)),
      nonce: salt,
    );
    final bytes = await key.extractBytes();
    return base64Encode(bytes);
  }

  /// Constant-time-ish comparison of a freshly computed hash against
  /// [expectedHash]. Returns true when [pin] matches.
  Future<bool> verify({
    required String pin,
    required Uint8List salt,
    required String expectedHash,
  }) async {
    final actual = await hash(pin: pin, salt: salt);
    return _constantTimeEquals(actual, expectedHash);
  }

  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }
}
