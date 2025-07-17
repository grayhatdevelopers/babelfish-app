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
  // Constants for API URL
  static const _apiUrlKey = 'api_base_url';
  // Constants for WebSocket URL
  static const _websocketUrlKey = 'websocket_url';
  // Constants for language preferences
  static const _topLanguageKey = 'top_language';
  static const _bottomLanguageKey = 'bottom_language';
  // Constants for app settings
  static const _fullSentenceModeKey = 'full_sentence_mode';
  static const _showOriginalTextKey = 'show_original_text';

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

  // Save API URL
  static Future<void> saveApiUrl(String url) async {
    await _storage.write(key: _apiUrlKey, value: url);
  }

  // Get API URL
  static Future<String?> getApiUrl() async {
    return await _storage.read(key: _apiUrlKey);
  }

  // Save WebSocket URL
  static Future<void> saveWebsocketUrl(String url) async {
    await _storage.write(key: _websocketUrlKey, value: url);
  }

  // Get WebSocket URL
  static Future<String?> getWebsocketUrl() async {
    return await _storage.read(key: _websocketUrlKey);
  }

  // Language preference methods
  static Future<void> saveTopLanguagePreference(String language) async {
    await _storage.write(key: _topLanguageKey, value: language);
  }

  static Future<String?> getTopLanguage() async {
    return await _storage.read(key: _topLanguageKey);
  }

  static Future<void> saveBottomLanguagePreference(String language) async {
    await _storage.write(key: _bottomLanguageKey, value: language);
  }

  static Future<String?> getBottomLanguage() async {
    return await _storage.read(key: _bottomLanguageKey);
  }

  // App settings methods
  static Future<void> saveFullSentenceMode(bool enabled) async {
    await _storage.write(key: _fullSentenceModeKey, value: enabled.toString());
  }

  static Future<bool> getFullSentenceMode() async {
    final value = await _storage.read(key: _fullSentenceModeKey);
    return value == 'true';
  }

  static Future<void> saveShowOriginalText(bool enabled) async {
    await _storage.write(key: _showOriginalTextKey, value: enabled.toString());
  }

  static Future<bool> getShowOriginalText() async {
    final value = await _storage.read(key: _showOriginalTextKey);
    return value != 'false'; // Default to true if not set
  }
}
