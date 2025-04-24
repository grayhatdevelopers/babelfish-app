import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StorageService {
  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'auth_token';
  static const _embeddingsKey = 'embeddings_exist';
  static const _usernameKey = 'username';
  static const _languageKey = 'language';

  static Future<void> saveToken(
    String username,
    String token,
    bool embeddings,
    String language,
  ) async {
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _embeddingsKey, value: embeddings.toString());
    await _storage.write(key: _usernameKey, value: username);
    await _storage.write(key: _languageKey, value: language);
  }

  static Future<String?> getUsername() async {
    return await _storage.read(key: _usernameKey);
  }

  static Future<String?> getLanguage() async {
    return await _storage.read(key: _languageKey);
  }

  static Future<(String?, String?, String?, String?)> getStoredData() async {
    return (
      await _storage.read(key: _tokenKey),
      await _storage.read(key: _embeddingsKey),
      await _storage.read(key: _usernameKey),
      await _storage.read(key: _languageKey)
    );
  }

  static Future<void> deleteToken() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _embeddingsKey);
    await _storage.delete(key: _usernameKey);
    await _storage.delete(key: _languageKey);
  }
}
