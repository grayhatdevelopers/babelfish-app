import 'package:audio_recorder/models/language_model.dart';
import 'package:audio_recorder/models/websocket_config.dart';
import 'package:audio_recorder/pages/login_page.dart';
import 'package:audio_recorder/services/storage_service.dart';
import 'package:audio_recorder/services/vad_service.dart';
import 'package:audio_recorder/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_sfsymbols/flutter_sfsymbols.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:audio_recorder/services/response_handler.dart';
import 'package:audio_recorder/services/websocket_service.dart';
import 'package:realtime_audio/realtime_audio.dart';

// Import WebSocketErrorType directly
import 'package:audio_recorder/services/websocket_service.dart'
    show WebSocketErrorType, WebSocketError;

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

  // Connection state variables
  bool isConnecting = false;
  bool isListening = false;

  // Add fullSentence feature
  bool fullSentence = true;
  List<String> translatedSentences = [];
  String translatedText = '';

  // Add original transcript tracking
  String originalText = '';
  String spokenText = ''; // Add spoken language text variable
  bool showOriginalText = true; // Toggle to show/hide original text
  bool showSpokenText = true; // Toggle to show/hide spoken language text

  String serverUrl = WebSocketConfig.serverUrl;
  String? userID = 'ronaldo'; // Changed to nullable
  String? tokenJWT = ''; // Changed to nullable

  bool isRecording = false;

  RealtimeAudio? audioEngine;
  List<StreamSubscription<dynamic>>? _subscriptions;
  // ignore: unused_field
  RealtimeAudioState _state = const RealtimeAudioState();

  WebsocketService? _websocketService;

  // VAD Integration
  final VadService _vadService = VadService.instance;
  StreamSubscription<void>? _speechStartSubscription;
  StreamSubscription<void>? _realSpeechStartSubscription;
  StreamSubscription<List<double>>? _speechEndSubscription;
  StreamSubscription<Map<String, dynamic>>? _frameProcessedSubscription;
  StreamSubscription<void>? _vadMisfireSubscription;
  StreamSubscription<String>? _vadErrorSubscription;

  bool _vadDetectedSpeech = false;
  bool _vadInitialized = false;
  final List<Uint8List> _pendingAudioChunks = [];

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

  // Audio playback control variables
  bool _isPlayingTranslation = false;
  bool _hasTranslationToPlay = false;
  List<Uint8List> _lastTranslationAudio = [];
  String _lastTranslatedText = '';

  // Add variables for error handling
  String? _websocketErrorMessage;
  Timer? _errorDisplayTimer;
  bool _showErrorOverlay = false;
  final ErrorLogger _errorLogger = ErrorLogger();
  dynamic _technicalErrorDetails;

  // Add variables for text editing
  bool _isEditingOriginalText = false;
  TextEditingController _originalTextController = TextEditingController();
  FocusNode _originalTextFocusNode = FocusNode();

  // In TranslationAppState class, add these variables after the other boolean state variables

  // Toggle listening mode
  bool _isToggleListeningActive = false;

  bool _stoppingListeningOnly = false;

  @override
  void initState() {
    super.initState();
    _initializeUser();
    _initializeVAD();
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
    // final savedFullSentenceMode = await StorageService.getFullSentenceMode();
    // if (mounted) {
    //   setState(() {
    //     fullSentence = savedFullSentenceMode;
    //     if (kDebugMode) {
    //       print("FULL SENTENCE MODE: $fullSentence");
    //     }
    //   });
    // }

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

    // Load show spoken text preference - Default to true if not set
    final savedShowSpokenText = await StorageService.getShowSpokenText();
    if (mounted) {
      setState(() {
        showSpokenText = savedShowSpokenText;
        if (kDebugMode) {
          print("SHOW SPOKEN TEXT: $showSpokenText");
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

    // Ensure the spoken text display is enabled by default
    if (showSpokenText == false) {
      setState(() {
        showSpokenText = true;
      });
      await StorageService.saveShowSpokenText(true);
    }
  }

  /// Initialize VAD service and set up event listeners
  Future<void> _initializeVAD() async {
    try {
      final success = await _vadService.initialize(isDebug: kDebugMode);
      if (success) {
        _setupVADListeners();
        setState(() {
          _vadInitialized = true;
        });
        if (kDebugMode) {
          print('VAD initialized successfully in main page');
        }
      } else {
        if (kDebugMode) {
          print('Failed to initialize VAD in main page');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('VAD initialization error in main page: $e');
      }
    }
  }

  /// Set up VAD event listeners
  void _setupVADListeners() {
    _speechStartSubscription = _vadService.onSpeechStart.listen((_) {
      setState(() {
        _vadDetectedSpeech = true;
        
        // Update toggle UI if in toggle mode
        if (_isToggleListeningActive) {
          // Force rebuild of toggle button to show speech detection
          setState(() {});
        }
      });
      if (kDebugMode) {
        print('VAD: Speech detected - will start sending audio chunks');
      }
      // Send any pending chunks when speech is detected
      _sendPendingChunks();
    });

    _realSpeechStartSubscription = _vadService.onRealSpeechStart.listen((_) {
      if (kDebugMode) {
        print('VAD: Real speech detected');
      }
    });

    _speechEndSubscription = _vadService.onSpeechEnd.listen((samples) {
      setState(() {
        _vadDetectedSpeech = false;
        
        // Update toggle UI if in toggle mode
        if (_isToggleListeningActive) {
          // Force rebuild of toggle button to update speech detection status
          setState(() {});
        }
      });
      if (kDebugMode) {
        print('VAD: Speech ended - will stop sending audio chunks');
      }
      
      // Process any final audio chunks for translation
      if (_pendingAudioChunks.isNotEmpty &&
          _websocketService != null &&
          (_websocketService?.isWebSocketConnected ?? false)) {
        // Send any remaining chunks to complete the translation
        _sendPendingChunks();
      }

      // Clear pending chunks after sending them
      _pendingAudioChunks.clear();
    });

    _frameProcessedSubscription =
        _vadService.onFrameProcessed.listen((frameData) {
      // We can use this for additional processing if needed
    });

    _vadMisfireSubscription = _vadService.onVadMisfire.listen((_) {
      if (kDebugMode) {
        print('VAD: Misfire detected');
      }
    });

    _vadErrorSubscription = _vadService.onError.listen((error) {
      if (kDebugMode) {
        print('VAD Error: $error');
      }
      _showError('VAD Error: $error');
    });
  }

  /// Send pending audio chunks when speech is detected
  void _sendPendingChunks() {
    if (_pendingAudioChunks.isNotEmpty &&
        _websocketService != null &&
        (_websocketService?.isWebSocketConnected ?? false)) {
      String targetLanguage = isExpandedTop ? topLanguage : bottomLanguage;

      if (kDebugMode) {
        print('Sending ${_pendingAudioChunks.length} pending audio chunks');
      }

      for (final chunk in _pendingAudioChunks) {
        // Ensure we're calling the correct method with proper parameters
        _websocketService!
            .sendData(_sampleRate, userID ?? 'ronaldo', targetLanguage, chunk);
      }

      _pendingAudioChunks.clear();
    }
  }

  @override
  void dispose() {
    destroyAudioEngine();
    _websocketService?.dispose(); // Dispose the WebSocket service properly
    _errorDisplayTimer?.cancel();

    // Clean up VAD subscriptions
    _speechStartSubscription?.cancel();
    _realSpeechStartSubscription?.cancel();
    _speechEndSubscription?.cancel();
    _frameProcessedSubscription?.cancel();
    _vadMisfireSubscription?.cancel();
    _vadErrorSubscription?.cancel();

    // Clean up text editing controllers
    _originalTextController.dispose();
    _originalTextFocusNode.dispose();

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
      body: Stack(
        children: <Widget>[
          // Main content with gesture detector
          GestureDetector(
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
              children: <Widget>[
                Column(
                  children: <Widget>[
                    _topSection(),
                    _bottomSection(),
                  ],
                ),
                if (!isExpandedTop && !isExpandedBottom)
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 300),
                    top: heightTop - 4,
                    left: 0,
                    right: 0,
                    child: Opacity(
                      opacity: (1 -
                              (((heightTop /
                                              MediaQuery.of(context)
                                                  .size
                                                  .height) -
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
                    onPressed: _showSettingsDialog,
                    icon: const Icon(Icons.settings),
                  ),
                ),
              ],
            ),
          ),

          // Enhanced Error overlay
          if (_showErrorOverlay && _websocketErrorMessage != null)
            Positioned(
              top: 60,
              left: 0,
              right: 0,
              child: enhancedErrorOverlay(
                errorMessage: _websocketErrorMessage!,
                onDismiss: () {
                  setState(() {
                    _showErrorOverlay = false;
                  });
                },
                technicalError: _technicalErrorDetails,
                onShowDetails: _technicalErrorDetails != null
                    ? () {
                        showEnhancedTechnicalErrorDialog(
                            context, _technicalErrorDetails);
                      }
                    : null,
              ),
            ),
            
          // Speech detection indicator
          if (_isToggleListeningActive && _vadDetectedSpeech)
            Positioned(
              bottom: 80,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.mic, color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Speech Detected',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
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
        const SizedBox(height: 80),

        // Connection/Listening Status
        if (isConnecting || isListening) ...[
          SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SpinKitPulse(
                        color: Colors.black,
                        size: 20.0,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        isConnecting ? 'Connecting...' : 'I am listening...',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                  // VAD Status Indicator
                  if (isListening && _vadInitialized) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _vadDetectedSpeech ? Icons.mic : Icons.mic_off,
                          color:
                              _vadDetectedSpeech ? Colors.green : Colors.grey,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _vadDetectedSpeech
                              ? 'Speech detected'
                              : 'Waiting for speech...',
                          style: TextStyle(
                            fontSize: 12,
                            color:
                                _vadDetectedSpeech ? Colors.green : Colors.grey,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],

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
                // Spoken language text with medium opacity
                if (showSpokenText && spokenText.isNotEmpty) ...[
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
                        "Spoken: \"$spokenText\"",
                        key: ValueKey<String>(spokenText),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                          color: Colors.black.withValues(alpha: 0.6),
                          letterSpacing: 0.2,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
                // Original text underneath with less opacity - Now with edit capability
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
                      child: _isEditingOriginalText
                          ? Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withOpacity(0.05),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.blue.withOpacity(0.3),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: TextField(
                                      controller: _originalTextController,
                                      focusNode: _originalTextFocusNode,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w400,
                                        color:
                                            Colors.black.withValues(alpha: 0.9),
                                      ),
                                      decoration: InputDecoration(
                                        hintText: "Edit what you said...",
                                        hintStyle: TextStyle(
                                          color: Colors.grey.withOpacity(0.6),
                                          fontStyle: FontStyle.italic,
                                        ),
                                        border: InputBorder.none,
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                      onSubmitted: (_) =>
                                          _submitOriginalTextEdit(),
                                      maxLines: 3,
                                      minLines: 1,
                                    ),
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon:
                                          Icon(Icons.close, color: Colors.red),
                                      onPressed: () => setState(() {
                                        _isEditingOriginalText = false;
                                      }),
                                      iconSize: 20,
                                      padding: EdgeInsets.zero,
                                      constraints: BoxConstraints(),
                                      tooltip: 'Cancel',
                                    ),
                                    const SizedBox(width: 4),
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Colors.green.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: IconButton(
                                        icon: Icon(Icons.check,
                                            color: Colors.green),
                                        onPressed: _submitOriginalTextEdit,
                                        iconSize: 20,
                                        padding: const EdgeInsets.all(4),
                                        constraints: BoxConstraints(),
                                        tooltip: 'Apply & Retranslate',
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            )
                          : GestureDetector(
                              onTap: _toggleOriginalTextEditing,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Expanded(
                                    child: Text(
                                      "You said: \"$originalText\"",
                                      key: ValueKey<String>(originalText),
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w300,
                                        fontStyle: FontStyle.italic,
                                        color:
                                            Colors.black.withValues(alpha: 0.4),
                                        letterSpacing: 0.2,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.edit,
                                          size: 14,
                                          color: Colors.blue,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Edit',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.blue,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        // Repeat button section for top display
        if (_hasTranslationToPlay && _lastTranslatedText.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: ElevatedButton.icon(
                    onPressed:
                        _isPlayingTranslation ? null : _playTranslationAudio,
                    icon: Icon(
                      _isPlayingTranslation ? Icons.volume_up : Icons.replay,
                      size: 18,
                    ),
                    label: Text(
                      _isPlayingTranslation ? 'Playing...' : 'Repeat',
                      style: const TextStyle(fontSize: 12),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black.withValues(alpha: 0.1),
                      foregroundColor: Colors.black,
                      elevation: 1,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        
        // Toggle button section for top display
        if (isExpandedTop) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: ElevatedButton.icon(
                    onPressed: _toggleListening,
                    icon: Icon(
                      _isToggleListeningActive ? Icons.mic_off : Icons.mic,
                      size: 18,
                      color: Colors.white,
                    ),
                    label: Text(
                      _isToggleListeningActive
                          ? 'Stop Listening & Translate'
                          : 'Start Listening',
                      style: const TextStyle(fontSize: 12, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isToggleListeningActive
                          ? _vadDetectedSpeech
                              ? Colors.green.withOpacity(
                                  0.8) // Active and speech detected
                              : Colors.red
                                  .withOpacity(0.8) // Active but no speech
                          : Colors.blue.withOpacity(0.8), // Not active
                      elevation: 2,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        
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

        // Connection/Listening Status
        if (isConnecting || isListening) ...[
          const SizedBox(height: 20),
          SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SpinKitPulse(
                        color: Colors.black,
                        size: 20.0,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        isConnecting ? 'Connecting...' : 'I am listening...',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                  // VAD Status Indicator
                  if (isListening && _vadInitialized) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _vadDetectedSpeech ? Icons.mic : Icons.mic_off,
                          color:
                              _vadDetectedSpeech ? Colors.green : Colors.grey,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _vadDetectedSpeech
                              ? 'Speech detected'
                              : 'Waiting for speech...',
                          style: TextStyle(
                            fontSize: 12,
                            color:
                                _vadDetectedSpeech ? Colors.green : Colors.grey,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],

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
                  // Spoken language text with medium opacity
                  if (showSpokenText && spokenText.isNotEmpty) ...[
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
                          "Spoken: \"$spokenText\"",
                          key: ValueKey<String>(spokenText),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                            color: Colors.black.withValues(alpha: 0.6),
                            letterSpacing: 0.2,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                  // Original text underneath with less opacity - Now with edit capability
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
                        child: _isEditingOriginalText
                            ? Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.withOpacity(0.05),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.blue.withOpacity(0.3),
                                          width: 1.5,
                                        ),
                                      ),
                                      child: TextField(
                                        controller: _originalTextController,
                                        focusNode: _originalTextFocusNode,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w400,
                                          color: Colors.black
                                              .withValues(alpha: 0.9),
                                        ),
                                        decoration: InputDecoration(
                                          hintText: "Edit what you said...",
                                          hintStyle: TextStyle(
                                            color: Colors.grey.withOpacity(0.6),
                                            fontStyle: FontStyle.italic,
                                          ),
                                          border: InputBorder.none,
                                          contentPadding: EdgeInsets.zero,
                                        ),
                                        onSubmitted: (_) =>
                                            _submitOriginalTextEdit(),
                                        maxLines: 3,
                                        minLines: 1,
                                      ),
                                    ),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: Icon(Icons.close,
                                            color: Colors.red),
                                        onPressed: () => setState(() {
                                          _isEditingOriginalText = false;
                                        }),
                                        iconSize: 20,
                                        padding: EdgeInsets.zero,
                                        constraints: BoxConstraints(),
                                        tooltip: 'Cancel',
                                      ),
                                      const SizedBox(width: 4),
                                      Container(
                                        decoration: BoxDecoration(
                                          color: Colors.green.withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: IconButton(
                                          icon: Icon(Icons.check,
                                              color: Colors.green),
                                          onPressed: _submitOriginalTextEdit,
                                          iconSize: 20,
                                          padding: const EdgeInsets.all(4),
                                          constraints: BoxConstraints(),
                                          tooltip: 'Apply & Retranslate',
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              )
                            : GestureDetector(
                                onTap: _toggleOriginalTextEditing,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        "You said: \"$originalText\"",
                                        key: ValueKey<String>(originalText),
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w300,
                                          fontStyle: FontStyle.italic,
                                          color: Colors.black
                                              .withValues(alpha: 0.4),
                                          letterSpacing: 0.2,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.edit,
                                            size: 14,
                                            color: Colors.blue,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Edit',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.blue,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        // Repeat button section for bottom display
        if (_hasTranslationToPlay && _lastTranslatedText.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: ElevatedButton.icon(
                    onPressed:
                        _isPlayingTranslation ? null : _playTranslationAudio,
                    icon: Icon(
                      _isPlayingTranslation ? Icons.volume_up : Icons.replay,
                      size: 18,
                    ),
                    label: Text(
                      _isPlayingTranslation ? 'Playing...' : 'Repeat',
                      style: const TextStyle(fontSize: 12),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black.withValues(alpha: 0.1),
                      foregroundColor: Colors.black,
                      elevation: 1,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        
        // Toggle button section for bottom display
        if (isExpandedBottom) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: ElevatedButton.icon(
                    onPressed: _toggleListening,
                    icon: Icon(
                      _isToggleListeningActive ? Icons.mic_off : Icons.mic,
                      size: 18,
                      color: Colors.white,
                    ),
                    label: Text(
                      _isToggleListeningActive
                          ? 'Stop Listening & Translate'
                          : 'Start Listening',
                      style: const TextStyle(fontSize: 12, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isToggleListeningActive
                          ? _vadDetectedSpeech
                              ? Colors.green.withOpacity(
                                  0.8) // Active and speech detected
                              : Colors.red
                                  .withOpacity(0.8) // Active but no speech
                          : Colors.blue.withOpacity(0.8), // Not active
                      elevation: 2,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        
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

// Fixed version of _showLanguageSelector method with debug logs shown on screen
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

                          // Show debug log on screen
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Saving top language preference: $langCode',
                                  style: TextStyle(fontSize: 12),
                                ),
                                duration: Duration(seconds: 2),
                                backgroundColor: Colors.blue.withOpacity(0.8),
                              ),
                            );
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

                          // Show debug log on screen
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Saving bottom language preference: $langCode',
                                  style: TextStyle(fontSize: 12),
                                ),
                                duration: Duration(seconds: 2),
                                backgroundColor: Colors.blue.withOpacity(0.8),
                              ),
                            );
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
                        
                        // Important: Do NOT automatically start listening after language selection
                        // Let the user explicitly press the Start Listening button
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
    
    // If we're in stopping mode, don't process new audio chunks
    if (_stoppingListeningOnly) {
      if (kDebugMode) {
        print('Ignoring audio chunk as stopping flag is active');
      }
      return;
    }

    // Check if we're actively listening - only process audio if toggle listening is active
    if (!_isToggleListeningActive && !isExpandedTop && !isExpandedBottom) {
      if (kDebugMode) {
        print('Ignoring audio chunk as toggle listening is not active');
      }
      return;
    }

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

    // Critical check: make sure WebSocket is properly connected before attempting to send audio
    bool websocketReady = _websocketService != null &&
        _websocketService!.isWebSocketConnected &&
        !(_websocketService!.lastError != null &&
            _websocketService!.lastError!.type
                .toString()
                .contains('connection'));
                          
    // VAD-based chunk handling
    if (_vadInitialized && websocketReady) {
      String targetLanguage = isExpandedTop ? topLanguage : bottomLanguage;

      if (_vadDetectedSpeech) {
        // Speech is detected, send the chunk immediately
        if (kDebugMode) {
          print('VAD: Sending chunk to server (speech detected)');
        }
        
        // Ensure we're calling the correct method with proper parameters
        _websocketService!
            .sendData(_sampleRate, userID ?? 'ronaldo', targetLanguage, chunk);
      } else {
        // No speech detected, buffer the chunk for potential later sending
        _pendingAudioChunks.add(chunk);

        // Keep only the last few chunks to avoid memory issues
        if (_pendingAudioChunks.length > 10) {
          _pendingAudioChunks.removeAt(0);
        }

        if (kDebugMode) {
          print(
              'VAD: Buffering chunk (no speech detected), buffer size: ${_pendingAudioChunks.length}');
        }
      }
    } else if (!_vadInitialized && websocketReady) {
      // Fallback: if VAD is not initialized, send all chunks (original behavior)
      if (kDebugMode) {
        print(
            'VAD not initialized, sending chunk to server directly (fallback)');
      }
      
      String targetLanguage = isExpandedTop ? topLanguage : bottomLanguage;
      _websocketService!
          .sendData(_sampleRate, userID ?? 'ronaldo', targetLanguage, chunk);
    } else if (!websocketReady) {
      // WebSocket is not connected - store the error and try to reconnect
      if (kDebugMode) {
        print(
            'WebSocket not ready, cannot send audio. Attempting to reconnect...');
      }

      // Attempt to reconnect in the background
      _reconnectWebSocket();
    }
  }

  // Add a method to attempt WebSocket reconnection
  Future<void> _reconnectWebSocket() async {
    // Only attempt reconnection if not already connected
    if (_websocketService == null || !_websocketService!.isWebSocketConnected) {
      if (kDebugMode) {
        print('Attempting to reconnect WebSocket...');
      }

      // Create new WebSocket service if needed
      if (_websocketService == null) {
        _websocketService = WebsocketService();
      }

      // Try to connect
      final connected = await _websocketService!.connect(serverUrl);

      if (connected) {
        if (kDebugMode) {
          print('WebSocket reconnected successfully');
        }

        isWebSocketConnected = true;
        _websocketService!.startListening((message) {
          ResponseHandler.handleReponse(message,
              (message, spokenText, originalText) {
            if (kDebugMode) {
              print('Message from Server: $message');
            }
            _processText(message, spokenText, originalText);
          }, (audioData) {
            _previewData?.add(audioData);
            _handleTranslationAudio(audioData);
          });
        });

        // Clear any error message related to connection
        setState(() {
          if (_websocketErrorMessage?.contains('connection') ?? false) {
            _showErrorOverlay = false;
            _websocketErrorMessage = null;
          }
        });
      } else {
        if (kDebugMode) {
          print('WebSocket reconnection failed');
        }
      }
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
    // Cancel subscriptions
    _subscriptions?.forEach((subscription) async {
      await subscription.cancel();
    });
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

  // Enhanced error overlay widget with better styling
  Widget enhancedErrorOverlay({
    required String errorMessage,
    required VoidCallback onDismiss,
    dynamic technicalError,
    VoidCallback? onShowDetails,
  }) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with error icon and title
          Row(
            children: [
              Icon(
                Icons.error_outline,
                color: Colors.red.shade600,
                size: 24,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Connection Error',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade800,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, color: Colors.red.shade600),
                onPressed: onDismiss,
                splashRadius: 20,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Error message
          Text(
            errorMessage,
            style: TextStyle(
              fontSize: 14,
              color: Colors.red.shade700,
              height: 1.4,
            ),
          ),

          // Technical details button if available
          if (technicalError != null && onShowDetails != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                const Spacer(),
                TextButton.icon(
                  onPressed: onShowDetails,
                  icon: Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Colors.red.shade600,
                  ),
                  label: Text(
                    'Technical Details',
                    style: TextStyle(
                      color: Colors.red.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.red.shade50,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                      side: BorderSide(color: Colors.red.shade200),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // Enhanced technical error dialog
  void showEnhancedTechnicalErrorDialog(
      BuildContext context, dynamic technicalError) {
    String errorDetails = '';
    String errorType = 'Unknown Error';

    if (technicalError is WebSocketError) {
      errorType = technicalError.type.toString().split('.').last;
      errorDetails = '''
Error Type: ${technicalError.type.toString().split('.').last}
Message: ${technicalError.message}
''';
    } else if (technicalError is Exception) {
      errorType = technicalError.runtimeType.toString();
      errorDetails = technicalError.toString();
    } else {
      errorDetails = technicalError.toString();
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.7,
              maxWidth: MediaQuery.of(context).size.width * 0.9,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.bug_report,
                        color: Colors.red.shade600,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Technical Error Details',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.red.shade800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              errorType,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.red.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Content
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.code,
                                color: Colors.grey.shade600,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Error Information',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SelectableText(
                            errorDetails,
                            style: TextStyle(
                              fontSize: 13,
                              fontFamily: 'monospace',
                              color: Colors.grey.shade800,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Actions
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: errorDetails));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text(
                                  'Error details copied to clipboard'),
                              backgroundColor: Colors.green.shade600,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                        icon: Icon(
                          Icons.copy,
                          size: 16,
                          color: Colors.grey.shade600,
                        ),
                        label: Text(
                          'Copy',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showError(String errorMessage,
      {Duration duration = const Duration(seconds: 5),
      ErrorSeverity severity = ErrorSeverity.medium,
      String source = 'WebSocket',
      dynamic error}) {
    // Log the error through our centralized error logger
    _errorLogger.logError(errorMessage,
        severity: severity, source: source, error: error);

    setState(() {
      _websocketErrorMessage = errorMessage;
      _showErrorOverlay = true;
      _technicalErrorDetails = error;
    });

    // Auto-hide the error after duration
    _errorDisplayTimer?.cancel();
    _errorDisplayTimer = Timer(duration, () {
      if (mounted) {
        setState(() {
          _showErrorOverlay = false;
        });
      }
    });
  }

  Future<bool> _connectWebSocket() async {
    _websocketService = WebsocketService();

    // Listen for WebSocket errors
    _websocketService!.errorStream.listen((error) {
      String userFriendlyMessage;
      ErrorSeverity severity;

      switch (error.type) {
        case WebSocketErrorType.connectionFailed:
          userFriendlyMessage =
              'Failed to connect to the server. Please check your internet connection and try again.';
          severity = ErrorSeverity.high;
          break;
        case WebSocketErrorType.connectionTimeout:
          userFriendlyMessage =
              'Connection timed out. The server is taking too long to respond.';
          severity = ErrorSeverity.high;
          break;
        case WebSocketErrorType.connectionClosed:
          userFriendlyMessage =
              'Connection closed unexpectedly. Please try reconnecting.';
          severity = ErrorSeverity.medium;
          break;
        case WebSocketErrorType.messageSendFailed:
          userFriendlyMessage =
              'Failed to send message to the server. Please check your connection.';
          severity = ErrorSeverity.medium;
          break;
        case WebSocketErrorType.serverError:
          userFriendlyMessage =
              'Server error occurred. Please try again later.';
          severity = ErrorSeverity.high;
          break;
        default:
          userFriendlyMessage =
              'An unexpected error occurred: ${error.message}';
          severity = ErrorSeverity.medium;
          break;
      }

      _showError(
        userFriendlyMessage,
        severity: severity,
        source: 'WebSocket',
        error: error,
      );
    });

    isWebSocketConnected = await _websocketService?.connect(serverUrl) ?? false;
    if (_websocketService?.isWebSocketConnected ?? false) {
      if (kDebugMode) {
        print("WebSocket connected debug message");
      }
      _websocketService?.sendMessage(userID ?? 'ronaldo');

      _websocketService?.startListening((message) {
        ResponseHandler.handleReponse(message,
            (message, spokenText, originalText) {
          if (kDebugMode) {
            print('Message from Server: $message');
          }
          _processText(message, spokenText, originalText);
        }, (audioData) {
          _previewData?.add(audioData);
          _handleTranslationAudio(audioData); // Use controlled audio handling
        });
      });
      return true;
    } else {
      // If connection failed and we don't have an error message yet (fallback)
      if (!_showErrorOverlay) {
        _showError(
            'Failed to connect to the server. Please check your internet connection and try again.');
      }
      return false;
    }
  }

  void _toggleRecording() async {
    if (isRecording) {
      setState(() {
        isRecording = false;
      });
      
      if (!_stoppingListeningOnly) {
        // Only stop player if we're not in "stop listening only" mode
        await stopPlayer();
        _togglePreviewRecording();
        await destroyAudioEngine();
      } else {
        // If we're just stopping listening but want to keep translations playing,
        // don't touch the audio engine or player
        if (kDebugMode) {
          print('Toggling recording state only, keeping playback active');
        }
        _togglePreviewRecording();
      }
    } else {
      _stoppingListeningOnly = false;
      
      if (!isInitialized) {
        await createAudioEngine(recorderEnabled: true);
      }
      if (!isWebSocketConnected) {
        final connected = await _connectWebSocket();
        if (!connected) {
          // Don't proceed with recording if connection failed
          return;
        }
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
        content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setInnerState) {
          return SingleChildScrollView(
            child: Column(
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
                  
                // Text Settings Section with Divider
                Divider(height: 32, thickness: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    "Text Display Settings",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                // Full sentence mode
                SwitchListTile(
                  title: Text("Full Sentence Mode"),
                  subtitle:
                      Text("Show complete sentences instead of word-by-word"),
                  value: fullSentence,
                  onChanged: (value) async {
                    setInnerState(() {
                      fullSentence = value;
                    });
                    setState(() {
                      fullSentence = value;
                    });
                  },
                ),
                SwitchListTile(
                  title: Text("Show Original Text"),
                  subtitle: Text(
                      "Display your spoken language underneath the translation"),
                  value: showOriginalText,
                  onChanged: (value) async {
                    setInnerState(() {
                      showOriginalText = value;
                    });
                    setState(() {
                      showOriginalText = value;
                    });
                  },
                ),
                SwitchListTile(
                  title: Text("Show Spoken Language Text"),
                  subtitle: Text("Display text in the spoken language"),
                  value: showSpokenText,
                  onChanged: (value) async {
                    setInnerState(() {
                      showSpokenText = value;
                    });
                    setState(() {
                      showSpokenText = value;
                    });
                  },
                ),
                  
                // Account Section with Divider
                Divider(height: 32, thickness: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    "Account",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
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
          );
        }),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              // Save server and user settings
              setState(() {
                serverUrl = urlController.text;
                userID = userController.text;
              });
              await StorageService.saveWebsocketUrl(serverUrl);
              WebSocketConfig.serverUrl = serverUrl;

              // Save language preferences
              await StorageService.saveBottomLanguagePreference(bottomLanguage);
              await StorageService.saveTopLanguagePreference(topLanguage);
              
              // Save text display settings
              await StorageService.saveFullSentenceMode(fullSentence);
              await StorageService.saveShowOriginalText(showOriginalText);
              await StorageService.saveShowSpokenText(showSpokenText);

              if (kDebugMode) {
                print(
                    "SAVED LANGUAGES - Top: $topLanguage, Bottom: $bottomLanguage");
              }

              Navigator.pop(context);
              
              // Show confirmation
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Settings saved successfully'),
                  duration: Duration(seconds: 2),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: Text("Save"),
          ),
        ],
      ),
    );
  }

  // Fixed toggle listening button - fix setState error
  void _toggleListening() async {
    if (_isToggleListeningActive) {
      // Stop listening
      setState(() {
        _isToggleListeningActive =
            false; // Correctly set to false when stopping
      });

      // Stop VAD listening
      if (_vadInitialized && _vadService.isListening) {
        await _vadService.stopListening();
        if (kDebugMode) {
          print('VAD listening stopped by toggle');
        }
      }

      // Process any pending audio before stopping the recorder
      if (_pendingAudioChunks.isNotEmpty &&
          _websocketService != null &&
          (_websocketService?.isWebSocketConnected ?? false)) {
        if (kDebugMode) {
          print(
              'Processing ${_pendingAudioChunks.length} final audio chunks before stopping');
        }

        // Send pending chunks to ensure final words are processed
        _sendPendingChunks();
        
        // Wait a moment for server to process the final audio chunks
        await Future.delayed(Duration(milliseconds: 500));
      }

      // Stop recording in a way that preserves ongoing playback
      if (isRecording) {
        // Set recording flag to false but don't call _toggleRecording which might stop playback
        setState(() {
          isRecording = false;
        });

        // Instead of stopping everything, just set a flag to prevent sending more audio chunks
        // This allows current translations to continue playing
        _stoppingListeningOnly = true;

        if (kDebugMode) {
          print('Flagged recording to stop, but keeping playback active');
        }
      }

      // Reset listening states but don't affect translation playback
      setState(() {
        isConnecting = false;
        isListening = false;
        _vadDetectedSpeech = false;
      });

      // Show confirmation
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Listening stopped - translating...'),
          duration: Duration(seconds: 1),
          backgroundColor: Colors.orange,
        ),
      );
    } else {
      // Reset texts when starting a new listening session
      _resetTexts();
      
      // Important: Clear all previous state
      _pendingAudioChunks.clear();
      _vadDetectedSpeech = false;
      
      // Clear the stopping flag when starting listening again
      _stoppingListeningOnly = false;

      // Start listening
      setState(() {
        _isToggleListeningActive = true;
        isConnecting = true;
      });

      // Initialize audio engine if needed
      if (!isInitialized) {
        await createAudioEngine(recorderEnabled: true);
      } else {
        // Re-initialize if already initialized to ensure clean state
        await destroyAudioEngine();
        await createAudioEngine(recorderEnabled: true);
      }

      // Connect to WebSocket if needed
      if (!isWebSocketConnected || _websocketService == null) {
        final connected = await _connectWebSocket();
        if (!connected) {
          setState(() {
            _isToggleListeningActive = false;
            isConnecting = false;
          });

          // Show error message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Connection failed. Please try again.'),
              duration: Duration(seconds: 2),
              backgroundColor: Colors.red,
            ),
          );

          return;
        }
      }

      // Start VAD listening with fresh state
      if (_vadInitialized) {
        // Force stop any existing VAD session
        await _vadService.stopListening();
        await Future.delayed(Duration(milliseconds: 100));

        // Start new VAD session
        await _vadService.startListening();
        if (kDebugMode) {
          print('VAD listening started by toggle');
        }
      }

      // Update listening state
      setState(() {
        isConnecting = false;
        isListening = true;
      });

      // Start recording if not already
      if (!isRecording) {
        _toggleRecording();
      }

      // Show confirmation
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Listening started'),
          duration: Duration(seconds: 1),
          backgroundColor: Colors.green,
        ),
      );
    }
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

      // Important: Do NOT automatically start connection process
      // Let the user explicitly press the Start Listening button

      // Stop any ongoing recording/listening when switching sections
      if (isRecording || isListening) {
        _stopRecording();
      }
    });
  }

  void _startConnectionProcess() async {
    setState(() {
      isConnecting = true;
      isListening = false;
    });

    // Initialize audio engine and connect WebSocket
    if (!isInitialized) {
      await createAudioEngine(recorderEnabled: true);
    }
    if (!isWebSocketConnected) {
      final connected = await _connectWebSocket();
      if (!connected) {
        setState(() {
          isConnecting = false;
        });
        return;
      }
    }

    // Start VAD listening if initialized
    if (_vadInitialized && _vadService.isInitialized) {
      await _vadService.startListening();
      if (kDebugMode) {
        print('VAD listening started');
      }
    }

    // Connection successful, now start listening
    setState(() {
      isConnecting = false;
      isListening = true;
    });

    // Start recording
    if (!isRecording) {
      _toggleRecording();
    }
  }

  void _processText(String text, String? spoken, String? original) {
    // Only log in debug mode
    if (kDebugMode) {
      if (original != null) {
        print('Original text: $original');
      }
      if (spoken != null) {
        print('Spoken language text: $spoken');
      }
      print('Translated text: $text');
    }

    setState(() {
      if (fullSentence) {
        translatedText = text; // Replace with full sentence
        _lastTranslatedText = text; // Store for repeat functionality

        // Set spoken text when available
        if (spoken != null && spoken.isNotEmpty) {
          spokenText = spoken;
        }

        // Set original text when available
        if (original != null && original.isNotEmpty) {
          originalText = original;
          _originalTextController.text = original;
        }
      } else {
        translatedText += '$text '; // Append text as before
        _lastTranslatedText = translatedText; // Store for repeat functionality

        // Also append spoken text if available
        if (spoken != null && spoken.isNotEmpty) {
          spokenText += '$spoken ';
        }

        // Also append original text if available
        if (original != null && original.isNotEmpty) {
          originalText += '$original ';
          _originalTextController.text = originalText;
        }
      }
    });
  }

  // Method to play translation audio
  void _playTranslationAudio() {
    if (kDebugMode) {
      print(
          'Repeat button pressed - hasTranslation: $_hasTranslationToPlay, audioChunks: ${_lastTranslationAudio.length}, isPlaying: $_isPlayingTranslation, audioEngine: ${audioEngine != null ? "initialized" : "null"}');
    }

    if (_hasTranslationToPlay &&
        _lastTranslationAudio.isNotEmpty &&
        !_isPlayingTranslation &&
        audioEngine != null) {
      setState(() {
        _isPlayingTranslation = true;
      });

      if (kDebugMode) {
        print(
            'Playing ${_lastTranslationAudio.length} audio chunks for repeat');
      }

      // Play all stored audio chunks
      for (final audioChunk in _lastTranslationAudio) {
        audioEngine!.queueChunk(audioChunk);
      }

      // Set a timer to reset the playing state after audio finishes
      // Estimate duration based on audio data length (rough calculation)
      final estimatedDuration = Duration(
          milliseconds:
              (_lastTranslationAudio.length * 100).clamp(1000, 10000));

      Timer(estimatedDuration, () {
        if (mounted) {
          setState(() {
            _isPlayingTranslation = false;
          });
        }
      });
    } else {
      if (kDebugMode) {
        print('Cannot play repeat audio - conditions not met');
      }
    }
  }

  // Method to handle incoming translation audio
  void _handleTranslationAudio(Uint8List audioData) {
    if (kDebugMode) {
      print(
          'Received audio chunk: ${audioData.length} bytes, audioEngine: ${audioEngine != null ? "initialized" : "null"}');
    }

    // Check if audio engine is available
    if (audioEngine == null) {
      if (kDebugMode) {
        print('Audio engine is null - cannot play audio');
      }
      return;
    }

    if (!_isPlayingTranslation) {
      // Start new translation playback
      setState(() {
        _isPlayingTranslation = true;
        _hasTranslationToPlay = true;
        _lastTranslationAudio = [audioData]; // Initialize with first chunk
      });

      if (kDebugMode) {
        print('Starting new translation playback');
      }

      // Play the first audio chunk
      audioEngine!.queueChunk(audioData);

      // Set a timer to reset the playing state
      Timer(const Duration(milliseconds: 3000), () {
        if (mounted) {
          setState(() {
            _isPlayingTranslation = false;
          });
        }
      });
    } else {
      // Translation is already playing - add chunk to storage AND play it
      _lastTranslationAudio.add(audioData);

      if (kDebugMode) {
        print('Adding chunk to existing translation playback');
      }

      // Continue playing subsequent chunks of the same translation
      audioEngine!.queueChunk(audioData);
    }
  }

  void _resetTexts() {
    setState(() {
      translatedText = '';
      originalText = '';
      spokenText = '';
      translatedSentences = [];
      _originalTextController.clear();
      _isEditingOriginalText = false;
    });
  }

  // Add method to handle original text editing submission
  void _submitOriginalTextEdit() {
    if (_isEditingOriginalText) {
      final correctedText = _originalTextController.text.trim();
      if (correctedText.isNotEmpty && correctedText != originalText) {
        setState(() {
          originalText = correctedText;
          _isEditingOriginalText = false;
          // Show loading state for retranslation with animation
          translatedText = '🔄 Retranslating...';
        });

        // Send corrected text for retranslation (now async)
        _retranslateText(correctedText);

        if (kDebugMode) {
          print('Original text corrected and retranslating: $correctedText');
        }
      } else {
        setState(() {
          _isEditingOriginalText = false;
        });
      }
    }
  }

  // Add method to handle retranslation with automatic reconnection
  Future<void> _retranslateText(String correctedText) async {
    // Check if WebSocket is connected, if not, try to reconnect
    if (_websocketService == null || !_websocketService!.isWebSocketConnected) {
      if (kDebugMode) {
        print(
            'WebSocket not connected, attempting to reconnect for retranslation...');
      }

      setState(() {
        translatedText = '🔄 Reconnecting...';
      });

      // Try to reconnect
      final connected = await _connectWebSocket();
      if (!connected) {
        setState(() {
          translatedText = '⚠️ Connection failed - please try again';
        });

        // Reset after a delay
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              translatedText = '';
            });
          }
        });
        return;
      }

      // Update UI to show retranslating after successful reconnection
      setState(() {
        translatedText = '🔄 Retranslating...';
      });
    }

    if (_websocketService != null && _websocketService!.isWebSocketConnected) {
      // Send the corrected text to the websocket for retranslation
      // Using the message format expected by the server
      final message = {
        'type': 'retranslatetext',
        'text': correctedText,
        'targetLanguage': isExpandedTop ? topLanguage : bottomLanguage,
        'userID': userID ?? 'ronaldo',
      };

      // Convert the message to JSON string
      final messageJson = jsonEncode(message);
      _websocketService!.sendMessage(messageJson);

      if (kDebugMode) {
        print('Sent retranslation request: $messageJson');
      }
    } else {
      // Final fallback: show error message
      setState(() {
        translatedText = '⚠️ Connection error - please try again';
      });

      // Reset after a delay with animation
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            translatedText = '';
          });
        }
      });
    }
  }

  // Add method to toggle editing mode
  void _toggleOriginalTextEditing() {
    setState(() {
      _isEditingOriginalText = !_isEditingOriginalText;
      if (_isEditingOriginalText) {
        _originalTextController.text = originalText;
        // Focus the text field when entering edit mode
        Future.delayed(const Duration(milliseconds: 100), () {
          _originalTextFocusNode.requestFocus();
        });
      }
    });
  }

  void _stopRecording() {
    heightBottom = MediaQuery.of(context).size.height * 0.5;
    heightTop = MediaQuery.of(context).size.height * 0.5;
    isExpandedTop = false;
    isExpandedBottom = false;

    // Stop VAD listening
    if (_vadInitialized && _vadService.isListening) {
      _vadService.stopListening();
      if (kDebugMode) {
        print('VAD listening stopped');
      }
    }

    // Reset connection states
    setState(() {
      isConnecting = false;
      isListening = false;
      _vadDetectedSpeech = false;
    });

    // Clear pending chunks
    _pendingAudioChunks.clear();

    _resetTexts();
    if (isRecording) {
      _toggleRecording();
    }
  }
}
