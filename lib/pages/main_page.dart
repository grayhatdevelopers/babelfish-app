import 'package:audio_recorder/models/language_model.dart';
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
  String topLanguage = 'fr';
  String bottomLanguage = 'it';
  double heightTop = 100;
  double heightBottom = 100;

  String serverUrl =
      'ws://ec2-13-50-56-128.eu-north-1.compute.amazonaws.com:8001/ws/client';
  String? userID = 'ronaldo'; // Changed to nullable
  String? tokenJWT = ''; // Changed to nullable

  bool isRecording = false;

  String translatedText = '';
  List<String> translatedSentences = [];

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
    if (username != null && mounted) {
      setState(() {
        userID = username;
        tokenJWT = token;
        bottomLanguage = language ?? 'it';
      });
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
                  onPressed: _showUrlDialog, icon: Icon(Icons.settings)),
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
      isExpandedTop = isTop;
      isExpandedBottom = !isTop;

      if (isExpandedTop) {
        heightTop = MediaQuery.of(context).size.height * 1;
        heightBottom = MediaQuery.of(context).size.height * 0;
      } else if (isExpandedBottom) {
        heightTop = MediaQuery.of(context).size.height * 0;
        heightBottom = MediaQuery.of(context).size.height * 1;
      }
      if (isRecording) {
        _toggleRecording();
      }
      _toggleRecording();
    });
  }

  void _stopRecording() {
    heightBottom = MediaQuery.of(context).size.height * 0.5;
    heightTop = MediaQuery.of(context).size.height * 0.5;
    isExpandedTop = false;
    isExpandedBottom = false;
    translatedSentences = [];
    translatedText = '';
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
        Spacer(),
        Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              translatedText,
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        Spacer(),
        Text(
          Languages.languages[bottomLanguage]!.upText,
          style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w300, color: Colors.black),
        ),
        const Icon(
          SFSymbols.chevron_compact_up,
          size: 40,
          color: Colors.black,
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
        Spacer(),
        Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              translatedText,
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        Spacer(),
      ],
    );
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
          const Icon(
            SFSymbols.chevron_compact_down,
            size: 40,
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
        children: [
          const Icon(
            SFSymbols.chevron_compact_up,
            size: 40,
            color: Colors.black,
          ),
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

  // Add this method to the TranslationAppState class
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
                      onTap: () {
                        setState(() {
                          if (isTop) {
                            topLanguage = langCode;
                          } else {
                            bottomLanguage = langCode;
                          }
                        });
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

  void _processText(String text) {
    translatedSentences.add(text);
    setState(() {
      translatedText += '$text ';
    });
  }

  //DateTime? _lastRecorderChunk;
  DateTime? _lastPlayerChunk;

  void _handleRecorderChunk(Uint8List chunk) {
    if (_previewData == null) return;
    if (kDebugMode) {
      print('Sending chunk to server');
    }
    if (_websocketService != null &&
        (_websocketService?.isWebSocketConnected ?? false)) {
      _websocketService?.sendData(_sampleRate, 'ronaldo',
          isExpandedTop ? topLanguage : bottomLanguage, chunk);
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
        ResponseHandler.handleReponse(message, (message) {
          if (kDebugMode) {
            print('Message from Server: $message');
          }
          _processText(message);
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
      setState(() {
        isRecording = true;
      });
      await startPlayer();
      _togglePreviewRecording();
    }
  }

  void _showUrlDialog() {
    TextEditingController urlController =
        TextEditingController(text: serverUrl);
    TextEditingController userController = TextEditingController(text: userID);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Enter Server URL"),
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
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                serverUrl = urlController.text;
                userID = userController.text;
              });
              Navigator.pop(context);
            },
            child: Text("OK"),
          ),
        ],
      ),
    );
  }
}
