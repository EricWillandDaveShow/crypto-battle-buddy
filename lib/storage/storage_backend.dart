// lib/storage/storage_backend.dart
import 'storage_backend_selector_stub.dart'
    if (dart.library.io) 'storage_backend_selector_io.dart';

abstract class StorageBackend {
  Future<void> writeString(String key, String value);
  Future<String?> readString(String key);
  Future<void> deleteString(String key);
}

class MemoryStorageBackend implements StorageBackend {
  final Map<String, String> _mem = {};

  @override
  Future<void> writeString(String key, String value) async {
    _mem[key] = value;
  }

  @override
  Future<String?> readString(String key) async {
    return _mem[key];
  }

  @override
  Future<void> deleteString(String key) async {
    _mem.remove(key);
  }
}

StorageBackend createStorageBackend() {
  // createBackend() is provided by the conditional import above.
  return createBackend();
}
