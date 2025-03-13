import 'package:flutter/material.dart';

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:audio_recorder/response_handler.dart';
import 'package:audio_recorder/websocket_service.dart';
import 'package:flutter/services.dart';
import 'package:realtime_audio/realtime_audio.dart';

class TranslationApp extends StatefulWidget {
  const TranslationApp({super.key});

  @override
  TranslationAppState createState() => TranslationAppState();
}

class TranslationAppState extends State<TranslationApp> {
  String targetLanguage = 'es';
  List<String> languages = ['en', 'es', 'fr', 'de', 'zh', 'ja'];
  String translatedText = '';
  List<String> translatedSentences = [];
  bool isRecording = false;
  String serverUrl = '';
  String userID = 'ronaldo';

  static const _printTimeDifferences = false;

  RealtimeAudio? audioEngine;
  List<StreamSubscription<dynamic>>? _subscriptions;
  RealtimeAudioState _state = const RealtimeAudioState();

  WebsocketService? _websocketService;

  bool isWebSocketConnected = false;

  bool isInitialized = false;

  double _playerVolume = -96.0;
  double _recorderVolume = -96.0;

  double get _playerVolumeT => 1.0 - (_playerVolume / -96.0).clamp(0.0, 1.0);
  double get _recorderVolumeT =>
      1.0 - (_recorderVolume / -96.0).clamp(0.0, 1.0);

  List<Uint8List>? _previewData;

  double _sampleRate = 0.0; // Default value

  @override
  void initState() {
    super.initState();
  }

  void _togglePreviewRecording() {
    if (_previewData == null) {
      _previewData = [];
    } else {
      _previewData = null;
    }

    setState(() {});
  }

  void _toggleRecording() async {
    setState(() {
      isRecording = !isRecording;
    });
    if (!isInitialized) {
      await createAudioEngine(recorderEnabled: true);
    }
    if (!isWebSocketConnected) {
      _connectWebSocket();
    }
    if (isRecording) {
      startPlayer();
      _togglePreviewRecording();
    } else {
      stopPlayer();
      _togglePreviewRecording();
    }
  }

  //DateTime? _lastRecorderChunk;
  DateTime? _lastPlayerChunk;

  void _handleRecorderChunk(Uint8List chunk) {
    if (_previewData == null) return;
    print('Sending chunk to server');
    _websocketService?.sendData(_sampleRate, 'ronaldo', targetLanguage, chunk);
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

  void _processText(String text) {
    translatedSentences.add(text);
    setState(() {
      translatedText += '$text ';
    });
  }

  void _connectWebSocket() {
    _websocketService = WebsocketService();
    isWebSocketConnected = _websocketService?.connect(serverUrl) ?? false;
    _websocketService?.sendMessage('client');
    _websocketService?.sendMessage(userID);

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
      // Handle the received message here
    });
  }

  Future<void> createAudioEngine({bool recorderEnabled = false}) async {
    if (!await getPermission()) {
      await requestPermission();
    }
    print('Creating audio engine');
    final audioEngineNew = RealtimeAudio(recorderEnabled: recorderEnabled);
    await audioEngineNew.isInitialized;

    if (recorderEnabled) {
      _websocketService = WebsocketService();
      isWebSocketConnected = _websocketService?.connect(serverUrl) ?? false;
    }

    _websocketService?.sendMessage('client');
    _websocketService?.sendMessage(userID);

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
      // Handle the received message here
    });

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
  }

  void destroyAudioEngine() {
    for (final subscription in _subscriptions ?? const []) {
      subscription.cancel();
    }
    audioEngine?.dispose();
    audioEngine = null;

    // Close WebSocket connection
    _websocketService?.close();
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

  Future<void> startPlayer() async {
    print('Starting player');
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

  @override
  void dispose() {
    destroyAudioEngine();
    super.dispose();
  }

  void _clearText() {
    setState(() {
      translatedText = '';
      translatedSentences.clear();
    });
  }

  void _showUrlDialog() {
    TextEditingController urlController = TextEditingController();
    TextEditingController userController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Enter Server URL"),
        content: Column(
          children: [
            TextField(
              controller: urlController,
              decoration: InputDecoration(hintText: "Enter URL here"),
            ),
            TextField(
              controller: userController,
              decoration: InputDecoration(hintText: "Enter user id here"),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Babelfish"),
        leading: IconButton(
          icon: Icon(Icons.settings),
          onPressed: _showUrlDialog,
        ),
        actions: [
          DropdownButton<String>(
            value: targetLanguage,
            onChanged: (String? newValue) {
              setState(() {
                targetLanguage = newValue!;
              });
            },
            items: languages.map<DropdownMenuItem<String>>((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value.toUpperCase()),
              );
            }).toList(),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 24),
            ProgressIndicator(
                t: _state.duration / math.max(1, _state.durationTotal)),
            const SizedBox(height: 16),
            ProgressIndicator(t: _playerVolumeT),
            const SizedBox(height: 16),
            ProgressIndicator(t: _recorderVolumeT),
            const SizedBox(height: 24),
            // ElevatedButton(
            //   onPressed: startPlayer,
            //   child: const Text('Start Player'),
            // ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    translatedText,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
            SizedBox(height: 20),
            Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: Icon(
                    isRecording ? Icons.mic_off : Icons.mic,
                    size: 60,
                    color: isRecording ? Colors.red : Colors.grey,
                  ),
                  onPressed: _toggleRecording,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(width: 100),
                    IconButton(
                        onPressed: _clearText,
                        icon: Icon(
                          Icons.clear,
                          color: Colors.grey[300],
                        )),
                  ],
                ),
              ],
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class ProgressIndicator extends StatelessWidget {
  const ProgressIndicator({
    super.key,
    required this.t,
  });

  final double t;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return SizedBox(
      height: 8,
      child: LayoutBuilder(builder: (context, constraints) {
        return Stack(
          alignment: AlignmentDirectional.centerStart,
          children: [
            Container(
              height: double.infinity,
              width: double.infinity,
              decoration: ShapeDecoration(
                  shape: const StadiumBorder(),
                  color: colors.surfaceContainerHigh),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOutCubicEmphasized,
              height: double.infinity,
              width: constraints.maxWidth * t,
              decoration: ShapeDecoration(
                  shape: const StadiumBorder(), color: colors.primary),
            ),
          ],
        );
      }),
    );
  }
}
