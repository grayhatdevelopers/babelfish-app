import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StorageService {
  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'auth_token';
  static const _embeddingsKey = 'embeddings_exist';
  static const _usernameKey = 'username';
  static const _languageKey = 'language';
  // New keys for credentials
  static const _savedEmailKey = 'saved_email';
  static const _savedPasswordKey = 'saved_password';

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

  // New functions for handling credentials
  static Future<void> saveCredentials(String email, String password) async {
    await _storage.write(key: _savedEmailKey, value: email);
    await _storage.write(key: _savedPasswordKey, value: password);
  }

  static Future<(String?, String?)> getCredentials() async {
    final email = await _storage.read(key: _savedEmailKey);
    final password = await _storage.read(key: _savedPasswordKey);
    return (email, password);
  }

  static Future<void> deleteCredentials() async {
    await _storage.delete(key: _savedEmailKey);
    await _storage.delete(key: _savedPasswordKey);
  }
}
