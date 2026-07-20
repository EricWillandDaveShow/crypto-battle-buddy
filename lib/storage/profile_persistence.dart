import 'storage_backend.dart';

class ProfilePersistence {
  static const _key = 'selected_profile';
  final StorageBackend backend;

  ProfilePersistence({required this.backend});

  Future<void> save(String profileName) async {
    await backend.writeString(_key, profileName);
  }

  Future<String?> load() async {
    return backend.readString(_key);
  }
}
