import 'package:audio_recorder/models/api_response.dart';
import 'package:audio_recorder/models/websocket_config.dart';
import 'package:audio_recorder/pages/login_page.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await OmniAPI.initializeBaseUrl();
  await WebSocketConfig.initializeServerUrl();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Babelfish',
      themeMode: ThemeMode.dark, // Set default theme mode to dark
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
      home: LoginScreen(),
    );
  }
}
