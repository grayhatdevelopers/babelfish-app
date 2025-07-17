import 'package:audio_recorder/models/language_model.dart';
import 'package:audio_recorder/models/websocket_config.dart';
import 'package:audio_recorder/pages/login_page.dart';
import 'package:audio_recorder/services/storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_sfsymbols/flutter_sfsymbols.dart';

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:audio_recorder/services/response_handler.dart';
import 'package:audio_recorder/services/websocket_service.dart';
import 'package:realtime_audio/realtime_audio.dart';

class TranslationApp extends StatefulWidget {
  const TranslationApp({super.key});

  @override
  TranslationAppState createState() => TranslationAppState();
}

class TranslationAppState extends State<TranslationApp> {
  bool isExpandedTop = false;
  bool isExpandedBottom = false;
  bool isWebSocketConnected = false;
  // Default languages set to English for both (will be overridden by stored preferences)
  String topLanguage = 'en';
  String bottomLanguage = 'en';
  double heightTop = 100;
  double heightBottom = 100;

  // Add fullSentence feature
  bool fullSentence = true;
  List<String> translatedSentences = [];
  String translatedText = '';

  // Add original transcript tracking
  String originalText = '';
  bool showOriginalText = true; // Toggle to show/hide original text

  String serverUrl = WebSocketConfig.serverUrl;
  String? userID = 'ronaldo'; // Changed to nullable
  String? tokenJWT = ''; // Changed to nullable

  bool isRecording = false;

  RealtimeAudio? audioEngine;
  List<StreamSubscription<dynamic>>? _subscriptions;
  // ignore: unused_field
  RealtimeAudioState _state = const RealtimeAudioState();

  WebsocketService? _websocketService;

  bool isInitialized = false;
  bool _isLayoutInitialized = false;

  double _playerVolume = -96.0;
  double _recorderVolume = -96.0;

  // ignore: unused_element
  double get _playerVolumeT => 1.0 - (_playerVolume / -96.0).clamp(0.0, 1.0);
  // ignore: unused_element
  double get _recorderVolumeT =>
      1.0 - (_recorderVolume / -96.0).clamp(0.0, 1.0);

  List<Uint8List>? _previewData;

  double _sampleRate = 0.0; // Default value

  static const _printTimeDifferences = false;

  // Add constants for text animation
  static const Duration textAnimationDuration = Duration(milliseconds: 300);
  static const Curve textAnimationCurve = Curves.easeInOut;

  // For handling timing of player updates
  DateTime? _lastPlayerChunk;

  @override
  void initState() {
    super.initState();
    _initializeUser();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final screenHeight = MediaQuery.of(context).size.height;
        if (screenHeight > 0) {
          setState(() {
            heightTop = screenHeight * 0.5;
            heightBottom = screenHeight * 0.5;
          });
        } else {
          setState(() {
            heightTop = 300;
            heightBottom = 300;
          });
        }
      }
    });
  }

  Future<void> _initializeUser() async {
    final (token, _, username, language) = await StorageService.getStoredData();
    if (kDebugMode) {
      print("INIT USER - Username: $username, Saved Language: $language");
    }
    if (username != null && mounted) {
      setState(() {
        userID = username;
        tokenJWT = token;
      });
    }

    // Load top language preference
    final topLangPreference = await StorageService.getTopLanguage();
    if (mounted) {
      setState(() {
        // Use the saved top language preference, or default to English if not set
        topLanguage = topLangPreference ?? 'en';
        if (kDebugMode) {
          print("TOP LANGUAGE SET TO: $topLanguage");
        }
      });
    }

    // For consistency, also load bottom language preference directly using the new method
    final bottomLangPreference = await StorageService.getBottomLanguage();
    if (mounted) {
      setState(() {
        // Use saved bottom language or default to English if not set
        bottomLanguage = bottomLangPreference ?? 'en';
        if (kDebugMode) {
          print("BOTTOM LANGUAGE LOADED DIRECTLY: $bottomLanguage");
        }
      });
    }

    // Load full sentence mode preference
    final savedFullSentenceMode = await StorageService.getFullSentenceMode();
    if (mounted) {
      setState(() {
        fullSentence = savedFullSentenceMode;
        if (kDebugMode) {
          print("FULL SENTENCE MODE: $fullSentence");
        }
      });
    }

    // Load show original text preference - Default to true if not set
    final savedShowOriginalText = await StorageService.getShowOriginalText();
    if (mounted) {
      setState(() {
        showOriginalText = savedShowOriginalText;
        if (kDebugMode) {
          print("SHOW ORIGINAL TEXT: $showOriginalText");
        }
      });
    }

    // Ensure the language preferences are saved
    await StorageService.saveBottomLanguagePreference(bottomLanguage);
    await StorageService.saveTopLanguagePreference(topLanguage);

    // Ensure the original text display is enabled by default
    if (showOriginalText == false) {
      setState(() {
        showOriginalText = true;
      });
      await StorageService.saveShowOriginalText(true);
    }
  }

  @override
  void dispose() {
    destroyAudioEngine();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLayoutInitialized) {
      heightTop = MediaQuery.of(context).size.height * 0.5;
      heightBottom = MediaQuery.of(context).size.height * 0.5;
      _isLayoutInitialized = true;
    }
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
              _stopRecording();
            }
          });
        },
        child: Stack(
          children: [
            Column(
              children: [
                _topSection(),
                _bottomSection(),
              ],
            ),
            if (!isExpandedTop && !isExpandedBottom)
              AnimatedPositioned(
                duration: const Duration(
                    milliseconds:
                        300), // Match the sections' animation duration
                top: heightTop - 4, // Center the 5px separator
                left: 0,
                right: 0,
                child: Opacity(
                  opacity: (1 -
                          (((heightTop / MediaQuery.of(context).size.height) -
                                      0.5)
                                  .abs() *
                              2))
                      .clamp(0.0, 1.0),
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.grey[200]?.withAlpha(150) ??
                          Colors.grey.withAlpha(150),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withAlpha(200),
                          blurRadius: 4,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            Positioned(
              top: 40,
              right: 16,
              child: IconButton(
                  onPressed: _showSettingsDialog, icon: Icon(Icons.settings)),
            ),
          ],
        ),
      ),
    );
  }

  void _togglePreviewRecording() {
    if (_previewData == null) {
      _previewData = [];
    } else {
      _previewData = null;
    }

    setState(() {});
  }

  void _toggleSectionExpansion(isTop) {
    setState(() {
      print("Toggling expansion - isTop: $isTop");
      if (isExpandedTop) {
        heightTop = MediaQuery.of(context).size.height * 1;
        heightBottom = MediaQuery.of(context).size.height * 0;
      } else if (isExpandedBottom) {
        heightTop = MediaQuery.of(context).size.height * 0;
        heightBottom = MediaQuery.of(context).size.height * 1;
      }
      if (isExpandedTop && isTop) return;
      if (isExpandedBottom && !isTop) return;

      isExpandedTop = isTop;
      isExpandedBottom = !isTop;

      // Update the currentLanguage based on which section is active
      if (isExpandedTop && Languages.languages.containsKey(topLanguage)) {
        currentLanguage = Languages.languages[topLanguage]!;
        if (kDebugMode) {
          print(
              "ACTIVE LANGUAGE SWITCHED TO TOP: ${currentLanguage.name} (${currentLanguage.code})");
        }
      } else if (isExpandedBottom &&
          Languages.languages.containsKey(bottomLanguage)) {
        currentLanguage = Languages.languages[bottomLanguage]!;
        if (kDebugMode) {
          print(
              "ACTIVE LANGUAGE SWITCHED TO BOTTOM: ${currentLanguage.name} (${currentLanguage.code})");
        }
      }

      if (isRecording) {
        _toggleRecording();
      }
      _toggleRecording();
    });
  }

  void _processText(String text, String? original) {
    translatedSentences.add(text);

    // Only log in debug mode
    if (kDebugMode && original != null) {
      print('Original text: $original');
      print('Translated text: $text');
    }

    setState(() {
      if (fullSentence) {
        translatedText = text; // Replace with full sentence

        // Set original text when available
        if (original != null && original.isNotEmpty) {
          originalText = original;
        }
      } else {
        translatedText += '$text '; // Append text as before

        // Also append original text if available
        if (original != null && original.isNotEmpty) {
          originalText += '$original ';
        }
      }
    });
  }

  void _resetTexts() {
    setState(() {
      translatedText = '';
      originalText = '';
      translatedSentences = [];
    });
  }

  void _stopRecording() {
    heightBottom = MediaQuery.of(context).size.height * 0.5;
    heightTop = MediaQuery.of(context).size.height * 0.5;
    isExpandedTop = false;
    isExpandedBottom = false;
    _resetTexts();
    if (isRecording) {
      _toggleRecording();
    }
  }

  Widget _topSection() {
    return GestureDetector(
      onLongPress: () => _showLanguageSelector(true),
      child: AnimatedContainer(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: Languages.languages[topLanguage]!.colors,
            begin: Languages.languages[topLanguage]!.flagOrientation ==
                    FlagOrientation.horizontal
                ? Alignment.centerLeft
                : Alignment.topCenter,
            end: Languages.languages[topLanguage]!.flagOrientation ==
                    FlagOrientation.horizontal
                ? Alignment.centerRight
                : Alignment.bottomCenter,
          ),
        ),
        duration: const Duration(milliseconds: 300),
        height: heightTop,
        alignment: Alignment.center,
        child: isExpandedTop ? _textDisplayTop() : _topLanguageIndicators(),
      ),
    );
  }

  Widget _bottomSection() {
    return GestureDetector(
      onLongPress: () => _showLanguageSelector(false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: Languages.languages[bottomLanguage]!.colors,
            begin: Languages.languages[bottomLanguage]!.flagOrientation ==
                    FlagOrientation.horizontal
                ? Alignment.centerLeft
                : Alignment.topCenter,
            end: Languages.languages[bottomLanguage]!.flagOrientation ==
                    FlagOrientation.horizontal
                ? Alignment.centerRight
                : Alignment.bottomCenter,
          ),
        ),
        height: heightBottom,
        alignment: Alignment.center,
        child: isExpandedBottom
            ? _textDisplayBottom()
            : _bottomLanguageIndicators(),
      ),
    );
  }

  Widget _textDisplayTop() {
    return Column(
      children: [
        const SizedBox(height: 80), // Add space at the top for better centering
        // Translated text with bold styling centered in the top half
        Expanded(
          flex: 3,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Main translated text
                AnimatedSwitcher(
                  duration: textAnimationDuration,
                  child: Text(
                    translatedText,
                    key: ValueKey<String>(translatedText),
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black),
                    textAlign: TextAlign.center,
                  ),
                ),
                // Original text underneath with less opacity
                if (showOriginalText && originalText.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  AnimatedSwitcher(
                    duration: textAnimationDuration,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 8.0),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.02),
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: Text(
                        "You said: \"$originalText\"",
                        key: ValueKey<String>(originalText),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w300, // Lighter weight
                          fontStyle: FontStyle.italic,
                          color: Colors.black
                              .withValues(alpha: 0.4), // Lower opacity
                          letterSpacing: 0.2,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        Expanded(
          flex: 1,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                Languages.languages[bottomLanguage]!.upText,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w300,
                    color: Colors.black),
              ),
              const Icon(
                SFSymbols.chevron_compact_up,
                size: 40,
                color: Colors.black,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _textDisplayBottom() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(height: 50),
        const Icon(
          SFSymbols.chevron_compact_down,
          size: 40,
          color: Colors.black,
        ),
        Text(
          Languages.languages[topLanguage]!.downText,
          style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w300, color: Colors.black),
        ),
        // Main content area with both translated and original text
        Expanded(
          flex: 3,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Main translated text
                  AnimatedSwitcher(
                    duration: textAnimationDuration,
                    child: Text(
                      translatedText,
                      key: ValueKey<String>(translatedText),
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  // Original text underneath with less opacity
                  if (showOriginalText && originalText.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    AnimatedSwitcher(
                      duration: textAnimationDuration,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16.0, vertical: 8.0),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.02),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: Text(
                          "You said: \"$originalText\"",
                          key: ValueKey<String>(originalText),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w300, // Lighter weight
                            fontStyle: FontStyle.italic,
                            color: Colors.black
                                .withValues(alpha: 0.4), // Lower opacity
                            letterSpacing: 0.2,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        const Spacer(),
      ],
    );
  }

  Widget _topLanguageIndicators() {
    return Opacity(
      opacity: heightTop / MediaQuery.of(context).size.height >= 0.5
          ? 1.0
          : heightTop / (MediaQuery.of(context).size.height * 0.5),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Spacer(),
          Text(
            Languages.languages[topLanguage]!.name,
            style: const TextStyle(
                fontSize: 36, fontWeight: FontWeight.bold, color: Colors.black),
          ),
          Spacer(),
          Text(
            Languages.languages[topLanguage]!.downText,
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w300, color: Colors.black),
          ),
          SizedBox(height: 4),
          const Icon(
            SFSymbols.chevron_compact_down,
            size: 36,
            color: Colors.black,
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
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            SFSymbols.chevron_compact_up,
            size: 36,
            color: Colors.black,
          ),
          SizedBox(height: 4),
          Text(
            Languages.languages[bottomLanguage]!.upText,
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w300, color: Colors.black),
          ),
          Spacer(),
          Text(
            Languages.languages[bottomLanguage]!.name,
            style: const TextStyle(
                fontSize: 36, fontWeight: FontWeight.bold, color: Colors.black),
          ),
          Spacer(),
        ],
      ),
    );
  }

  // Fixed version of _showLanguageSelector method
  void _showLanguageSelector(bool isTop) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Select Language',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: Languages.languages.length,
                  itemBuilder: (context, index) {
                    String langCode = Languages.languages.keys.elementAt(index);
                    LanguageModel language = Languages.languages[langCode]!;

                    return ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                            gradient: language.flagOrientation ==
                                    FlagOrientation.circle
                                ? RadialGradient(
                                    colors: language.colors,
                                    center: Alignment.center,
                                    radius: 0.8,
                                  )
                                : LinearGradient(
                                    colors: language.colors,
                                    begin: language.flagOrientation ==
                                            FlagOrientation.horizontal
                                        ? Alignment.centerLeft
                                        : Alignment.topCenter,
                                    end: language.flagOrientation ==
                                            FlagOrientation.horizontal
                                        ? Alignment.centerRight
                                        : Alignment.bottomCenter,
                                  ),
                            shape: BoxShape.rectangle,
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      title: Text(
                        language.name,
                        style: TextStyle(color: Colors.white),
                      ),
                      onTap: () async {
                        // Store old language for logging
                        final oldLanguage =
                            isTop ? topLanguage : bottomLanguage;

                        if (isTop) {
                          setState(() {
                            topLanguage = langCode;
                          });

                          // Save the chosen top language preference with debug logging
                          if (kDebugMode) {
                            print(
                                "SAVING TOP LANGUAGE PREFERENCE: $langCode (was: $oldLanguage)");
                          }
                          await StorageService.saveTopLanguagePreference(
                              langCode);

                          // Verify the save worked
                          String? savedTopLang =
                              await StorageService.getTopLanguage();
                          if (kDebugMode) {
                            print("VERIFIED SAVED TOP LANGUAGE: $savedTopLang");
                          }

                          // Update current language if top section is active
                          if (isExpandedTop &&
                              Languages.languages.containsKey(langCode)) {
                            currentLanguage = Languages.languages[langCode]!;
                            if (kDebugMode) {
                              print(
                                  "UPDATED CURRENT LANGUAGE TO: ${currentLanguage.name} (TOP ACTIVE)");
                            }
                          }
                        } else {
                          setState(() {
                            bottomLanguage = langCode;
                          });

                          // Save the chosen bottom language preference with debug logging
                          if (kDebugMode) {
                            print(
                                "SAVING BOTTOM LANGUAGE PREFERENCE: $langCode (was: $oldLanguage)");
                          }
                          await StorageService.saveBottomLanguagePreference(
                              langCode);

                          // Verify the save worked
                          String? savedLang =
                              await StorageService.getBottomLanguage();
                          if (kDebugMode) {
                            print("VERIFIED SAVED LANGUAGE: $savedLang");
                          }

                          // Update current language if bottom section is active
                          if (isExpandedBottom &&
                              Languages.languages.containsKey(langCode)) {
                            currentLanguage = Languages.languages[langCode]!;
                            if (kDebugMode) {
                              print(
                                  "UPDATED CURRENT LANGUAGE TO: ${currentLanguage.name} (BOTTOM ACTIVE)");
                            }
                          }
                        }
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _handleRecorderChunk(Uint8List chunk) {
    if (_previewData == null) return;
    if (kDebugMode) {
      print('Sending chunk to server');
    }
    if (_websocketService != null &&
        (_websocketService?.isWebSocketConnected ?? false)) {
      String targetLanguage = isExpandedTop ? topLanguage : bottomLanguage;

      // Save language preference each time we record in that language
      // and ensure currentLanguage is up to date
      if (isExpandedTop) {
        if (kDebugMode) {
          print("RECORDING WITH TOP LANGUAGE: $topLanguage");
        }
        StorageService.saveTopLanguagePreference(topLanguage);

        // Update current language if needed
        if (currentLanguage.code != topLanguage &&
            Languages.languages.containsKey(topLanguage)) {
          currentLanguage = Languages.languages[topLanguage]!;
          if (kDebugMode) {
            print("UPDATED CURRENT LANGUAGE TO: ${currentLanguage.name}");
          }
        }
      } else {
        if (kDebugMode) {
          print("RECORDING WITH BOTTOM LANGUAGE: $bottomLanguage");
        }
        StorageService.saveBottomLanguagePreference(bottomLanguage);

        // Update current language if needed
        if (currentLanguage.code != bottomLanguage &&
            Languages.languages.containsKey(bottomLanguage)) {
          currentLanguage = Languages.languages[bottomLanguage]!;
          if (kDebugMode) {
            print("UPDATED CURRENT LANGUAGE TO: ${currentLanguage.name}");
          }
        }
      }

      _websocketService?.sendData(
          _sampleRate, userID ?? 'ronaldo', targetLanguage, chunk);
    }
  }

  void _handlePlayerState(RealtimeAudioState state) {
    if (_printTimeDifferences) {
      if (_lastPlayerChunk != null) {
        final diff = DateTime.now().difference(_lastPlayerChunk!);
        if (kDebugMode) {
          print("Player time: ${diff.inMilliseconds}ms");
        }
      }
      _lastPlayerChunk = DateTime.now();
    }
    setState(() => _state = state);
  }

  Future<void> startPlayer() async {
    if (kDebugMode) {
      print('Starting player');
    }
    audioEngine?.start();
  }

  Future<void> pausePlayer() async => audioEngine?.pause();
  Future<void> resumePlayer() async => audioEngine?.resume();
  Future<void> stopPlayer() async => audioEngine?.stop();

  Future<bool> getPermission() async {
    final permission = await RealtimeAudio.getRecordPermission();
    if (kDebugMode) {
      print(permission);
    }
    return permission == RealtimeAudioRecordPermission.granted;
  }

  Future<void> requestPermission() async {
    final permission = await RealtimeAudio.requestRecordPermission();
    if (kDebugMode) {
      print(permission);
    }
  }

  Future<void> createAudioEngine({bool recorderEnabled = false}) async {
    try {
      if (!await getPermission()) {
        await requestPermission();
      }
      if (!await getPermission()) {
        throw Exception('Permission not granted');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to get permission. Please try again.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
      if (kDebugMode) {
        print('Error getting permission: $e');
      }
      return;
    }
    if (await _connectWebSocket()) {
      if (kDebugMode) {
        print('Creating audio engine');
      }
      try {
        final audioEngineNew = RealtimeAudio(recorderEnabled: recorderEnabled);
        await audioEngineNew.isInitialized;

        setState(() {
          audioEngine = audioEngineNew;
          _state = audioEngine!.state;
          _sampleRate = audioEngineNew.recorderSampleRate.toDouble();
          _subscriptions = [
            audioEngine!.stateStream.listen(_handlePlayerState),
            audioEngine!.recorderVolumeStream
                .listen((event) => setState(() => _recorderVolume = event)),
            audioEngine!.playerVolumeStream
                .listen((event) => setState(() => _playerVolume = event)),
            audioEngine!.recorderStream.listen(_handleRecorderChunk),
          ];
        });

        isInitialized = true;
      } catch (e) {
        if (kDebugMode) {
          print('Error creating audio engine: $e');
        }
        isInitialized = false;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('Failed to initialize audio engine. Please try again.'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } else {
      isInitialized = false;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Failed to connect to the server. Please check your connection and try again.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
      _stopRecording();
    }
  }

  Future<void> destroyAudioEngine() async {
    // First stop the audio engine
    await stopPlayer();

    // Cancel all subscriptions
    for (final subscription in _subscriptions ?? const []) {
      await subscription.cancel();
    }
    _subscriptions?.clear();

    // Dispose audio engine
    await audioEngine?.dispose();
    audioEngine = null;

    // Close WebSocket connection
    if (_websocketService != null) {
      await _websocketService!.close();
      _websocketService = null;
    }
    isInitialized = false;
  }

  Future<void> clearQueue() async {
    final resp = await audioEngine?.clearQueue();
    if (kDebugMode) {
      print(resp);
    }
    if (kDebugMode) {
      print(
          "Stopped at: ${resp?.chunk?.elapsed}, chunk: ${resp?.chunk?.chunkElapsed}");
    }
  }

  Future<bool> _connectWebSocket() async {
    _websocketService = WebsocketService();
    isWebSocketConnected = await _websocketService?.connect(serverUrl) ?? false;
    if (_websocketService?.isWebSocketConnected ?? false) {
      if (kDebugMode) {
        print("WebSocket connected debug message");
      }
      _websocketService?.sendMessage(userID ?? 'ronaldo');

      _websocketService?.startListening((message) {
        ResponseHandler.handleReponse(message, (message, originalText) {
          if (kDebugMode) {
            print('Message from Server: $message');
          }
          _processText(message, originalText);
        }, (audioData) {
          _previewData?.add(audioData);
          audioEngine?.queueChunk(audioData);
        });
      });
      return true;
    }
    return false;
  }

  void _toggleRecording() async {
    if (isRecording) {
      setState(() {
        isRecording = false;
      });
      await stopPlayer();
      _togglePreviewRecording();
      await destroyAudioEngine();
    } else {
      if (!isInitialized) {
        await createAudioEngine(recorderEnabled: true);
      }
      if (!isWebSocketConnected) {
        await _connectWebSocket();
      }

      // Save language preferences at the start of recording
      if (isExpandedTop) {
        if (kDebugMode) {
          print("SAVING TOP LANGUAGE AT START OF RECORDING: $topLanguage");
        }
        await StorageService.saveTopLanguagePreference(topLanguage);
      } else {
        if (kDebugMode) {
          print(
              "SAVING BOTTOM LANGUAGE AT START OF RECORDING: $bottomLanguage");
        }
        await StorageService.saveBottomLanguagePreference(bottomLanguage);
      }

      setState(() {
        isRecording = true;
      });
      await startPlayer();
      _togglePreviewRecording();
    }
  }

  void _showSettingsDialog() {
    TextEditingController urlController =
        TextEditingController(text: serverUrl);
    TextEditingController userController = TextEditingController(text: userID);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Settings"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: urlController,
              decoration: InputDecoration(
                hintText: "Enter URL here",
                labelText: "Server URL",
              ),
            ),
            TextField(
              controller: userController,
              decoration: InputDecoration(
                hintText: "Enter UserID here",
                labelText: "User ID",
              ),
            ),
            const SizedBox(height: 15),
            SwitchListTile(
              title: Text("Full Sentence Mode"),
              subtitle: Text("Show complete sentences instead of word-by-word"),
              value: fullSentence,
              onChanged: (value) async {
                setState(() {
                  fullSentence = value;
                });

                // Save the full sentence mode preference
                await StorageService.saveFullSentenceMode(value);
                if (kDebugMode) {
                  print("SAVED FULL SENTENCE MODE: $value");
                }

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(fullSentence
                        ? 'Full sentence mode enabled'
                        : 'Word-by-word mode enabled'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
            SwitchListTile(
              title: Text("Show Original Text"),
              subtitle: Text(
                  "Display your spoken language underneath the translation"),
              value: showOriginalText,
              onChanged: (value) async {
                setState(() {
                  showOriginalText = value;
                });

                // Save the preference
                await StorageService.saveShowOriginalText(value);
                if (kDebugMode) {
                  print("SAVED SHOW ORIGINAL TEXT: $value");
                }

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(value
                        ? 'Original text display enabled'
                        : 'Original text display disabled'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                await StorageService.deleteToken();
                await StorageService.deleteCredentials();
                if (mounted) {
                  Navigator.pushAndRemoveUntil(
                    // ignore: use_build_context_synchronously
                    context,
                    MaterialPageRoute(
                        builder: (context) => const LoginScreen()),
                    (route) => false,
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                minimumSize: const Size(double.infinity, 40),
              ),
              child: const Text(
                'Logout',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              setState(() {
                serverUrl = urlController.text;
                userID = userController.text;
              });
              // Save WebSocket URL to storage
              await StorageService.saveWebsocketUrl(serverUrl);
              WebSocketConfig.serverUrl = serverUrl;

              // Save both language preferences when settings are updated
              await StorageService.saveBottomLanguagePreference(bottomLanguage);
              await StorageService.saveTopLanguagePreference(topLanguage);

              if (kDebugMode) {
                print(
                    "SAVED LANGUAGES FROM SETTINGS DIALOG - Top: $topLanguage, Bottom: $bottomLanguage");
              }

              Navigator.pop(context);
            },
            child: Text("OK"),
          ),
        ],
      ),
    );
  }
}
