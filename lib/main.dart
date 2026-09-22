import 'dart:async';
import 'package:audio_recorder/models/api_response.dart';
import 'package:audio_recorder/models/language_model.dart';
import 'package:audio_recorder/models/websocket_config.dart';
// import 'package:audio_recorder/pages/login_page.dart';
import 'package:audio_recorder/pages/main_page.dart';
import 'package:audio_recorder/services/storage_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// Create a stream controller to broadcast language changes
final languageChangeController = StreamController<String>.broadcast();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Make sure storage is ready before initializing
  await StorageService.initialize();

  // Initialize API and WebSocket URLs
  await OmniAPI.initializeBaseUrl();
  await WebSocketConfig.initializeServerUrl();

  // Initialize language preference
  await initializeLanguagePreference();

  // Listen for language changes and update currentLanguage
  languageChangeController.stream.listen((languageCode) {
    if (kDebugMode) {
      print("LANGUAGE CHANGE DETECTED: $languageCode");
    }
    if (Languages.languages.containsKey(languageCode)) {
      currentLanguage = Languages.languages[languageCode]!;
    }
  });

  runApp(const LanguageAwareApp());
}

// Initialize the language model based on stored preference
Future<void> initializeLanguagePreference() async {
  // Debug current language preferences
  await StorageService.debugLanguagePreferences();

  final bottomLanguage = await StorageService.getBottomLanguage();
  if (kDebugMode) {
    print("MAIN: Initializing language with: $bottomLanguage");
  }

  if (bottomLanguage != null &&
      Languages.languages.containsKey(bottomLanguage)) {
    currentLanguage = Languages.languages[bottomLanguage]!;
    if (kDebugMode) {
      print("MAIN: Set current language to: ${currentLanguage.name}");
    }
  } else {
    // Default to English if no language is set or the saved language doesn't exist
    currentLanguage = Languages.languages['en']!;
    if (kDebugMode) {
      print("MAIN: Defaulting to English");
    }
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Babelfish',
      themeMode: ThemeMode.dark, // Set default theme mode to dark
      debugShowCheckedModeBanner: false,
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
          surface: Colors.black,
          dynamicSchemeVariant: DynamicSchemeVariant.monochrome,
        ),
      ),
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.light,
          dynamicSchemeVariant: DynamicSchemeVariant.monochrome,
        ),
      ),
      home: TranslationApp(),
    );
  }
}

// Add a stateful wrapper that rebuilds when language changes
class LanguageAwareApp extends StatefulWidget {
  const LanguageAwareApp({super.key});

  @override
  State<LanguageAwareApp> createState() => _LanguageAwareAppState();
}

class _LanguageAwareAppState extends State<LanguageAwareApp> {
  late StreamSubscription<String> _languageSubscription;

  @override
  void initState() {
    super.initState();
    // Listen for language changes and trigger rebuild
    _languageSubscription = languageChangeController.stream.listen((_) {
      if (mounted) {
        setState(() {
          // This will rebuild with the new language
          if (kDebugMode) {
            print(
                "APP REBUILD TRIGGERED - CURRENT LANGUAGE: ${currentLanguage.name}");
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _languageSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MyApp();
  }
}
