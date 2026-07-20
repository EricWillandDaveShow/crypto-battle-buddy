// lib/storage/storage_backend_selector_io.dart
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'storage_backend.dart';

class IoFileStorageBackend implements StorageBackend {
  Directory? _dir;
  final Future<void> Function(File file)? _deleteFileOverride;
  final Set<String> _deletedKeys = <String>{};

  IoFileStorageBackend({
    Directory? storageDirectory,
    Future<void> Function(File file)? deleteFileOverride,
  })  : _dir = storageDirectory,
        _deleteFileOverride = deleteFileOverride;

  static final RegExp _validKeyPattern = RegExp(r'^[A-Za-z0-9_-]+$');

  void _validateKey(String key) {
    if (key.isEmpty || !_validKeyPattern.hasMatch(key)) {
      throw ArgumentError.value(
        key,
        'key',
        'Storage keys may contain only letters, numbers, underscores, and hyphens.',
      );
    }
  }

  String _comparablePath(String path) {
    final absolute = Directory(path).absolute.path;
    return Platform.isWindows ? absolute.toLowerCase() : absolute;
  }

  Future<Directory> _ensureDir() async {
    final existing = _dir;
    if (existing != null) {
      if (!await existing.exists()) {
        await existing.create(recursive: true);
      }
      return existing;
    }
    final baseDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${baseDir.path}/cbb_storage');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _dir = dir;
    return dir;
  }

  File _fileForKey(Directory dir, String key) {
    _validateKey(key);
    final storageDir = dir.absolute;
    final target = File(
      '${storageDir.path}${Platform.pathSeparator}$key.json',
    ).absolute;
    if (_comparablePath(target.parent.path) !=
        _comparablePath(storageDir.path)) {
      throw ArgumentError.value(
        key,
        'key',
        'Storage target must be a direct child of the storage directory.',
      );
    }
    return target;
  }

  @override
  Future<void> writeString(String key, String value) async {
    _validateKey(key);
    final dir = await _ensureDir();
    final file = _fileForKey(dir, key);
    try {
      await file.writeAsString(value, flush: true);
      _deletedKeys.remove(key);
    } catch (_) {}
  }

  @override
  Future<String?> readString(String key) async {
    _validateKey(key);
    if (_deletedKeys.contains(key)) return null;
    final dir = await _ensureDir();
    final file = _fileForKey(dir, key);
    try {
      if (!await file.exists()) return null;
      return file.readAsString();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> deleteString(String key) async {
    _validateKey(key);
    _deletedKeys.add(key);
    try {
      final dir = await _ensureDir();
      final file = _fileForKey(dir, key);
      if (await file.exists()) {
        final deleteFileOverride = _deleteFileOverride;
        if (deleteFileOverride == null) {
          await file.delete();
        } else {
          await deleteFileOverride(file);
        }
      }
    } catch (_) {
      // Keep the key blocked for this runtime if physical deletion fails.
    }
  }
}

StorageBackend createBackend() => IoFileStorageBackend();
