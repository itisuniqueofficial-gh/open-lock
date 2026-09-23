import 'package:core_crypto/core_crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openlock/src/features/enforcement/models/lock_config.dart';
import 'package:openlock/src/features/enforcement/models/relock_policy.dart';
import 'package:openlock/src/features/enforcement/services/config_repository.dart';

import 'helpers/fakes.dart';

void main() {
  late ConfigRepository repo;
  late FakeSecureStorage storage;
  late FakeConfigFileStore fileStore;

  setUp(() {
    storage = FakeSecureStorage();
    fileStore = FakeConfigFileStore();
    repo = ConfigRepository(
      storage: storage,
      cipher: const CipherService(),
      fileStore: fileStore,
    );
  });

  test('load before any save returns the empty config', () async {
    final config = await repo.load();
    expect(config.lockedPackages, isEmpty);
  });

  test('save then load round-trips through encryption at rest', () async {
    const original = LockConfig(
      lockedPackages: {'com.social'},
      relock: RelockPolicy(mode: RelockMode.afterTimeout),
      intruderThreshold: 7,
    );
    await repo.save(original);

    // A fresh repository (same fakes) proves it reads from the encrypted blob.
    final reopened = ConfigRepository(
      storage: storage,
      cipher: const CipherService(),
      fileStore: fileStore,
    );
    final restored = await reopened.load();
    expect(restored.lockedPackages, {'com.social'});
    expect(restored.relock.mode, RelockMode.afterTimeout);
    expect(restored.intruderThreshold, 7);
  });

  test('persisted bytes are not plaintext', () async {
    await repo.save(const LockConfig(lockedPackages: {'com.secret.app'}));
    final bytes = await fileStore.read();
    final asString = String.fromCharCodes(bytes!);
    expect(asString.contains('com.secret.app'), isFalse);
  });
}
