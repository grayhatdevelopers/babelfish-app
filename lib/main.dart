import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_sfsymbols/flutter_sfsymbols.dart';

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

  String translatedText = '';
  List<String> translatedSentences = [];

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

      if (isExpandedTop) {
        heightTop = MediaQuery.of(context).size.height * 1;
        heightBottom = MediaQuery.of(context).size.height * 0;
        _connectWebSocket();
      } else if (isExpandedBottom) {
        heightTop = MediaQuery.of(context).size.height * 0;
        heightBottom = MediaQuery.of(context).size.height * 1;
        _connectWebSocket();
      }
    });
  }

  void _stopRecording() {
    heightBottom = MediaQuery.of(context).size.height * 0.5;
    heightTop = MediaQuery.of(context).size.height * 0.5;
    //_disconnectWebSocket();
  }

  void _connectWebSocket(isTop) {
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
          setState(() {
            // Adjust the heights based on the drag delta
            heightTop += details.primaryDelta!;
            heightBottom -= details.primaryDelta!;

            // Ensure the heights stay within valid bounds
            if (heightTop < 0) {
              heightTop = 0;
              heightBottom = MediaQuery.of(context).size.height;
            } else if (heightBottom < 0) {
              heightBottom = 0;
              heightTop = MediaQuery.of(context).size.height;
            }
          });
        },
        onVerticalDragEnd: (details) {
          final dragDistance =
              heightTop - MediaQuery.of(context).size.height * 0.5;
          final threshold = MediaQuery.of(context).size.height * 0.3;

          setState(() {
            if (dragDistance.abs() > threshold) {
              _toggleSectionExpansion(dragDistance > 0);
            } else {
              // Reset to default position if drag distance is less than threshold
              heightTop = MediaQuery.of(context).size.height * 0.5;
              heightBottom = MediaQuery.of(context).size.height * 0.5;
            }
          });
        },
        child: Column(
          children: [
            _topSection(),
            _bottomSection(),
          ],
        ),
      ),
    );
  }

  Widget _topSection() {
    return AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: heightTop,
        color: Colors.blue,
        alignment: Alignment.center,
        child: _topLanguageIndicators());
  }

  Widget _bottomSection() {
    return AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: heightBottom,
        color: Colors.green,
        alignment: Alignment.center,
        child: _bottomLanguageIndicators());
  }

  Widget _topLanguageIndicators() {
    return Opacity(
      opacity: heightTop / MediaQuery.of(context).size.height >= 0.5
          ? 1.0
          : heightTop / (MediaQuery.of(context).size.height * 0.5),
      child: Column(
        children: [
          Spacer(),
          Text(
            topLanguage,
            style: const TextStyle(
                fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          Spacer(),
          Text(
            'Swipe down to translate to Francais',
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w300, color: Colors.white),
          ),
          const Icon(
            SFSymbols.chevron_compact_down,
            size: 40,
          ),
        ],
      ),
    );
  }

  Widget _bottomLanguageIndicators() {
    return Opacity(
      opacity: heightBottom / MediaQuery.of(context).size.height >= 0.5
          ? 1.0
          : heightBottom / (MediaQuery.of(context).size.height * 0.5),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            SFSymbols.chevron_compact_up,
            size: 40,
          ),
          const Text(
            'Swipe up to translate to Italian',
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w300, color: Colors.white),
          ),
          Spacer(),
          Text(
            bottomLanguage,
            style: const TextStyle(
                fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          Spacer(),
        ],
      ),
    );
  }

  void _processText(String text) {
    translatedSentences.add(text);
    setState(() {
      translatedText += '$text ';
    });
  }
}
