import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'settings_storage.dart';

SettingsStorage createStorage(String namespace) =>
    FileSettingsStorage(namespace: namespace);

/// Whole-record storage in the platform application-support directory.
/// The controller serializes writes. A failed replacement leaves the old record.
class FileSettingsStorage implements SettingsStorage {
  FileSettingsStorage({
    required this.namespace,
    Future<Directory> Function()? directory,
  }) : _directory = directory ?? getApplicationSupportDirectory;

  final String namespace;
  final Future<Directory> Function() _directory;
  static int _nextTemporary = 0;

  Future<File> _recordFile() async {
    final directory = await _directory();
    return File(
      '${directory.path}${Platform.pathSeparator}textus-settings'
      '${Platform.pathSeparator}$namespace.json',
    );
  }

  @override
  Future<String?> read() async {
    final file = await _recordFile();
    try {
      return await file.readAsString();
    } on FileSystemException catch (error) {
      if (error.osError?.errorCode == 2) return null;
      rethrow;
    }
  }

  @override
  Future<void> write(String record) async {
    final file = await _recordFile();
    await file.parent.create(recursive: true);
    final temporary = File('${file.path}.pending.$pid.${_nextTemporary++}');
    try {
      await temporary.writeAsString(record, flush: true);
      await temporary.rename(file.path);
    } catch (_) {
      try {
        if (await temporary.exists()) await temporary.delete();
      } on FileSystemException {
        // Preserve the write failure. A leftover owned temporary is never read.
      }
      rethrow;
    }
  }
}
