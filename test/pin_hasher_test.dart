import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:openlock/src/features/auth/services/pin_hasher.dart';

void main() {
  const hasher = PinHasher();

  test('verifies the correct PIN', () async {
    final salt = hasher.newSalt();
    final hash = await hasher.hash(pin: '123456', salt: salt);
    expect(
      await hasher.verify(pin: '123456', salt: salt, expectedHash: hash),
      isTrue,
    );
  });

  test('rejects the wrong PIN', () async {
    final salt = hasher.newSalt();
    final hash = await hasher.hash(pin: '123456', salt: salt);
    expect(
      await hasher.verify(pin: '000000', salt: salt, expectedHash: hash),
      isFalse,
    );
  });

  test('same PIN with a different salt yields a different hash', () async {
    final salt1 = hasher.newSalt();
    final salt2 = hasher.newSalt();
    final h1 = await hasher.hash(pin: '424242', salt: salt1);
    final h2 = await hasher.hash(pin: '424242', salt: salt2);
    expect(h1, isNot(equals(h2)));
  });

  test('hash is deterministic for the same PIN + salt', () async {
    final salt = Uint8List.fromList(List.generate(16, (i) => i));
    final h1 = await hasher.hash(pin: '654321', salt: salt);
    final h2 = await hasher.hash(pin: '654321', salt: salt);
    expect(h1, equals(h2));
  });

  test('newSalt produces unique 16-byte salts', () {
    final salts = List.generate(50, (_) => hasher.newSalt());
    for (final s in salts) {
      expect(s.length, PinHasher.saltLength);
    }
    final distinct = salts.map((s) => s.join(',')).toSet();
    expect(distinct.length, salts.length);
  });
}
