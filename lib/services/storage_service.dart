import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart'; // Added for kDebugMode
import '../main.dart'; // Import for languageChangeController

class StorageService {
  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'auth_token';
  static const _embeddingsKey = 'embeddings_exist';
  static const _usernameKey = 'username';
  static const _languageKey = 'language';
  // Added key for top language
  static const _topLanguageKey = 'top_language';
  // Added key for full sentence mode
  static const _fullSentenceKey = 'full_sentence_mode';
  // New keys for credentials
  static const _savedEmailKey = 'saved_email';
  static const _savedPasswordKey = 'saved_password';
  // Constants for API URL
  static const _apiUrlKey = 'api_base_url';
  // Constants for WebSocket URL
  static const _websocketUrlKey = 'websocket_url';

  // Add constants for preserving language preferences during logout
  static const _preservedTopLanguageKey = 'preserved_top_language';
  static const _preservedBottomLanguageKey = 'preserved_bottom_language';
  static const _preservedFullSentenceKey = 'preserved_full_sentence_mode';

  // This method ensures storage is initialized and ready to use
  static Future<void> initialize() async {
    try {
      // Test storage by reading a value
      await _storage.read(key: _languageKey);
      if (kDebugMode) {
        print("STORAGE: Successfully initialized");
      }
    } catch (e) {
      if (kDebugMode) {
        print("STORAGE: Error initializing - $e");
      }
      // Handle initialization errors
      // Most platforms don't require special initialization,
      // but this method provides a hook for future needs
    }
  }

  static Future<void> saveToken(
    String username,
    String token,
    bool embeddings,
    String language,
  ) async {
    // Save authentication info
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _embeddingsKey, value: embeddings.toString());
    await _storage.write(key: _usernameKey, value: username);

    if (kDebugMode) {
      print("STORAGE: Token saved for user: $username");
      print(
          "STORAGE: Checking existing language preferences before setting defaults");
    }

    // Check if we already have language preferences saved before overwriting
    final existingBottomLang = await _storage.read(key: _languageKey);

    // Only set the bottom language if it's not already set
    if (existingBottomLang == null) {
      if (kDebugMode) {
        print(
            "STORAGE: No existing bottom language found, setting to: $language");
      }
      await saveBottomLanguagePreference(language);
    } else if (kDebugMode) {
      print("STORAGE: Keeping existing bottom language: $existingBottomLang");
    }

    // Also check for existing top language preference
    final existingTopLang = await _storage.read(key: _topLanguageKey);

    // Set default top language to English if not already set
    if (existingTopLang == null) {
      if (kDebugMode) {
        print(
            "STORAGE: No existing top language found, setting to default: en");
      }
      await saveTopLanguagePreference('en');
    } else if (kDebugMode) {
      print("STORAGE: Keeping existing top language: $existingTopLang");
    }
  }

  static Future<String?> getUsername() async {
    return await _storage.read(key: _usernameKey);
  }

  static Future<String?> getLanguage() async {
    final lang = await _storage.read(key: _languageKey);
    if (kDebugMode) {
      print("STORAGE: Retrieved language: $lang from key $_languageKey");
    }
    return lang;
  }

  // Added method to make it more explicit that this is for bottom language
  static Future<String?> getBottomLanguage() async {
    final lang = await _storage.read(key: _languageKey);
    if (kDebugMode) {
      print("STORAGE: Retrieved bottom language: $lang from key $_languageKey");
    }
    return lang;
  }

  // Get top language preference
  static Future<String?> getTopLanguage() async {
    final lang = await _storage.read(key: _topLanguageKey);
    if (kDebugMode) {
      print("STORAGE: Retrieved top language: $lang from key $_topLanguageKey");
    }
    return lang;
  }

  // Updated method name for clarity and consistency
  static Future<void> saveBottomLanguagePreference(String language) async {
    if (kDebugMode) {
      print(
          "STORAGE: Saving bottom language preference: $language to key $_languageKey");
    }
    await _storage.write(key: _languageKey, value: language);

    // Verify the save
    final saved = await _storage.read(key: _languageKey);
    if (kDebugMode) {
      print("STORAGE: Verified saved bottom language: $saved");
    }

    // Notify listeners that bottom language has changed
    languageChangeController.add(language);
  }

  // This method is now deprecated - use saveBottomLanguagePreference instead
  @Deprecated('Use saveBottomLanguagePreference instead for clarity')
  static Future<void> saveLanguagePreference(String language) async {
    return saveBottomLanguagePreference(language);
  }

  // Add method to save top language preference
  static Future<void> saveTopLanguagePreference(String language) async {
    if (kDebugMode) {
      print(
          "STORAGE: Saving top language preference: $language to key $_topLanguageKey");
    }
    await _storage.write(key: _topLanguageKey, value: language);

    // Verify the save
    final saved = await _storage.read(key: _topLanguageKey);
    if (kDebugMode) {
      print("STORAGE: Verified saved top language: $saved");
    }

    // Only notify listeners if we're currently using the top language
    // This would need to be enhanced with knowledge of which section is active
    // but for now we'll just notify so the language model stays updated
    languageChangeController.add(language);
  }

  // Add methods for fullSentence mode
  static Future<void> saveFullSentenceMode(bool enabled) async {
    await _storage.write(key: _fullSentenceKey, value: enabled.toString());
  }

  static Future<bool> getFullSentenceMode() async {
    final value = await _storage.read(key: _fullSentenceKey);
    return value == 'true'; // Default to false if not set
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
    // Before deleting, save the current language preferences
    final topLanguage = await _storage.read(key: _topLanguageKey);
    final bottomLanguage = await _storage.read(key: _languageKey);
    final fullSentenceMode = await _storage.read(key: _fullSentenceKey);

    if (topLanguage != null) {
      await _storage.write(key: _preservedTopLanguageKey, value: topLanguage);
    }

    if (bottomLanguage != null) {
      await _storage.write(
          key: _preservedBottomLanguageKey, value: bottomLanguage);
    }

    if (fullSentenceMode != null) {
      await _storage.write(
          key: _preservedFullSentenceKey, value: fullSentenceMode);
    }

    // Now delete the authentication related data
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _embeddingsKey);
    await _storage.delete(key: _usernameKey);
    await _storage.delete(key: _languageKey);
    await _storage.delete(key: _topLanguageKey);
    await _storage.delete(key: _fullSentenceKey);
  }

  // Restore previously saved language preferences when logging in
  static Future<void> restoreLanguagePreferences() async {
    final preservedTopLanguage =
        await _storage.read(key: _preservedTopLanguageKey);
    final preservedBottomLanguage =
        await _storage.read(key: _preservedBottomLanguageKey);
    final preservedFullSentenceMode =
        await _storage.read(key: _preservedFullSentenceKey);

    if (preservedTopLanguage != null) {
      await saveTopLanguagePreference(preservedTopLanguage);
    }

    if (preservedBottomLanguage != null) {
      await saveBottomLanguagePreference(preservedBottomLanguage);
    }

    if (preservedFullSentenceMode != null) {
      await saveFullSentenceMode(preservedFullSentenceMode == 'true');
    }
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

  // Add a utility method to debug the current language preferences
  static Future<void> debugLanguagePreferences() async {
    if (kDebugMode) {
      final bottomLang = await getBottomLanguage();
      final topLang = await getTopLanguage();
      final preservedBottom =
          await _storage.read(key: _preservedBottomLanguageKey);
      final preservedTop = await _storage.read(key: _preservedTopLanguageKey);

      print("==== LANGUAGE PREFERENCES DEBUG ====");
      print("Current Bottom Language: $bottomLang");
      print("Current Top Language: $topLang");
      print("Preserved Bottom Language: $preservedBottom");
      print("Preserved Top Language: $preservedTop");
      print("===================================");
    }
  }
}
