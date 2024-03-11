import 'package:flutter_secure_storage/flutter_secure_storage.dart' as ss;

class SecureStorage {
  final _storage = const ss.FlutterSecureStorage();

  const SecureStorage();

  String _namespacedKey(String namespace, String key) => '${namespace}_$key';

  Future<void> write({required String namespace, required String key, required String? value}) async {
    await _storage.write(key: _namespacedKey(namespace, key), value: value);
  }

  Future<String?> read({required String namespace, required String key}) async {
    return await _storage.read(key: _namespacedKey(namespace, key));
  }

  Future<void> delete({required String namespace, required String key}) async {
    await _storage.delete(key: _namespacedKey(namespace, key));
  }
}
