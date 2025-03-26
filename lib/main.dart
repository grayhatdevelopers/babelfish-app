import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
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

class TranslationApp extends StatefulWidget {
  const TranslationApp({super.key});

  @override
  TranslationAppState createState() => TranslationAppState();
}

class TranslationAppState extends State<TranslationApp> {
  bool isExpandedTop = false;
  bool isExpandedBottom = false;
  bool isWebSocketConnected = false;
  String topLanguage = 'Français';
  String bottomLanguage = 'Italiano';
  double heightTop = 0;
  double heightBottom = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        heightTop = MediaQuery.of(context).size.height * 0.5;
        heightBottom = MediaQuery.of(context).size.height * 0.5;
      });
    });
  }

  void _toggleSectionExpansion(isTop) {
    setState(() {
      isExpandedTop = isTop;
      isExpandedBottom = !isTop;
      MediaQuery.of(context).size.height * 1;
      if (isExpandedTop) {
        heightTop = MediaQuery.of(context).size.height * 1;
        heightBottom = MediaQuery.of(context).size.height * 0;
      } else if (isExpandedBottom) {
        heightTop = MediaQuery.of(context).size.height * 0;
        heightBottom = MediaQuery.of(context).size.height * 1;
      }
      if (isExpandedTop || isExpandedBottom) {
        _connectWebSocket();
      } else {
        _disconnectWebSocket();
      }
    });
  }

  void _stopRecording() {
    heightBottom = MediaQuery.of(context).size.height * 0.5;
    heightTop = MediaQuery.of(context).size.height * 0.5;
    _disconnectWebSocket();
  }

  void _connectWebSocket() {
    if (!isWebSocketConnected) {
      print("Connecting to WebSocket and starting audio engine...");
      isWebSocketConnected = true;
    }
  }

  void _disconnectWebSocket() {
    if (isWebSocketConnected) {
      print("Disconnecting WebSocket and stopping audio engine...");
      isWebSocketConnected = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onVerticalDragUpdate: (details) {
          if (details.primaryDelta! > 30) {
            _toggleSectionExpansion(true);
          } else if (details.primaryDelta! < -30) {
            _toggleSectionExpansion(false);
          } else {
            _stopRecording();
          }
        },
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: heightTop,
              color: Colors.blue,
              alignment: Alignment.center,
              child: Text(
                topLanguage,
                style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: heightBottom,
              color: Colors.green,
              alignment: Alignment.center,
              child: Text(
                bottomLanguage,
                style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
