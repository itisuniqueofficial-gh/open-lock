import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

/// Abstraction over the encrypted-config file on disk so the config repository
/// is testable with an in-memory fake.
abstract interface class IConfigFileStore {
  Future<Uint8List?> read();
  Future<void> write(Uint8List bytes);
  Future<void> delete();
}

/// Stores the encrypted config blob in the app's private documents directory.
final class DocumentsConfigFileStore implements IConfigFileStore {
  const DocumentsConfigFileStore();

  static const String _fileName = 'openlock_config.bin';

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  @override
  Future<Uint8List?> read() async {
    final file = await _file();
    if (!file.existsSync()) return null;
    return file.readAsBytes();
  }

  @override
  Future<void> write(Uint8List bytes) async {
    final file = await _file();
    await file.writeAsBytes(bytes, flush: true);
  }

  @override
  Future<void> delete() async {
    final file = await _file();
    if (file.existsSync()) await file.delete();
  }
}
