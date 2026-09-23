import 'dart:convert';
import 'dart:typed_data';

import 'package:core_crypto/core_crypto.dart';
import 'package:core_storage/core_storage.dart';
import 'package:openlock/src/core/interfaces/config_file_store.dart';
import 'package:openlock/src/core/storage_keys.dart';
import 'package:openlock/src/features/enforcement/models/lock_config.dart';

/// Loads and persists the [LockConfig] encrypted at rest.
///
/// The config JSON is encrypted with AES-256-GCM under a random 256-bit key
/// generated on first use and held in platform secure storage
/// (EncryptedSharedPreferences / Keychain). The key never derives from the PIN,
/// so config survives a PIN change and stays readable while the app runs.
final class ConfigRepository {
  ConfigRepository({
    required ISecureStorage storage,
    required CipherService cipher,
    required IConfigFileStore fileStore,
  })  : _storage = storage,
        _cipher = cipher,
        _fileStore = fileStore;

  final ISecureStorage _storage;
  final CipherService _cipher;
  final IConfigFileStore _fileStore;

  Future<Uint8List> _key() async {
    final existing = await _storage.read(key: OpenLockKeys.configKey);
    if (existing != null) return Uint8List.fromList(base64Decode(existing));
    final key = await _cipher.generateSalt(); // 32 secure-random bytes
    await _storage.write(key: OpenLockKeys.configKey, value: base64Encode(key));
    return key;
  }

  Future<LockConfig> load() async {
    final bytes = await _fileStore.read();
    if (bytes == null) return LockConfig.empty;
    try {
      final key = await _key();
      final plaintext = await _cipher.decrypt(
        payload: EncryptedPayload.fromBytes(bytes),
        keyBytes: key,
      );
      return LockConfig.fromJson(jsonDecode(plaintext) as Map<String, dynamic>);
    } catch (_) {
      // Corrupt or unreadable — fall back to a clean slate rather than crash.
      return LockConfig.empty;
    }
  }

  Future<void> save(LockConfig config) async {
    final key = await _key();
    final salt = await _cipher.generateSalt();
    final payload = await _cipher.encrypt(
      plaintext: jsonEncode(config.toJson()),
      keyBytes: key,
      salt: salt,
    );
    await _fileStore.write(payload.toBytes());
  }

  Future<void> deleteAll() => _fileStore.delete();
}
