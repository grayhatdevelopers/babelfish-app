import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:audio_recorder/pages/main_page.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:noise_meter/noise_meter.dart';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:waveform_flutter/waveform_flutter.dart';
import 'package:audio_recorder/models/cloning_sentences.dart';
import 'package:audio_recorder/utils.dart';
import '../services/voice_cloning_service.dart';
import '../services/vad_service.dart';
import 'package:path_provider/path_provider.dart';

class VoiceCloningScreen extends StatefulWidget {
  const VoiceCloningScreen({super.key});

  @override
  VoiceCloningScreenState createState() => VoiceCloningScreenState();
}

class VoiceCloningScreenState extends State<VoiceCloningScreen> {
  FlutterSoundRecorder? _audioRecorder;
  bool _isRecording = false;
  String _recordingStatus = 'Not Recording';
  final int _sampleRate = 44100;
  int _currentSentenceIndex = 0;
  late String _audioFile; // Changed to late
  bool _isComplete = false;
  VoiceCloningState _voiceCloningState = VoiceCloningState.recording;
  final ErrorLogger _errorLogger = ErrorLogger();

  late NoiseMeter _noiseMeter;
  StreamSubscription<NoiseReading>? _noiseSubscription;
  double _decibel = 0.0;
  String _feedback = "Initializing...";

  final RecorderController _recorderController = RecorderController();

  // VAD Integration
  final VadService _vadService = VadService.instance;
  StreamSubscription<void>? _speechStartSubscription;
  StreamSubscription<void>? _realSpeechStartSubscription;
  StreamSubscription<List<double>>? _speechEndSubscription;
  StreamSubscription<Map<String, dynamic>>? _frameProcessedSubscription;
  StreamSubscription<void>? _vadMisfireSubscription;
  StreamSubscription<String>? _vadErrorSubscription;

  // Waveform data
  final StreamController<Amplitude> _amplitudeController =
      StreamController<Amplitude>.broadcast();
  Stream<Amplitude> get amplitudeStream => _amplitudeController.stream;
  bool _vadDetectedSpeech = false;

  String get _currentSentence =>
      _currentSentenceIndex < VoiceCloningSentences.sentences.length
          ? VoiceCloningSentences.sentences[_currentSentenceIndex]
          : "";

  @override
  void initState() {
    super.initState();
    _initAudioFile(); // Add this line
    _checkAndRequestPermissions();
    _initializeVAD();
  }

  Future<void> _initAudioFile() async {
    final tempDir = await getTemporaryDirectory();
    _audioFile = '${tempDir.path}/voice_cloning.wav';

    // Ensure the file exists and is writable
    final file = File(_audioFile);
    if (!await file.exists()) {
      await file.create(recursive: true);
    }
  }

  Future<void> _checkAndRequestPermissions() async {
    try {
      final status = await Permission.microphone.status;

      if (status.isDenied) {
        await Permission.microphone.request();
      }

      if (await Permission.microphone.isGranted) {
        _initializeRecorder();
      } else {
        _showErrorDialog(
            'Microphone permission is required to use this feature');
        if (kDebugMode) {
          _initializeRecorder();
        }
      }
    } catch (e) {
      _showErrorDialog('Failed to check microphone permissions');
    }
  }

  Future<void> _initializeRecorder() async {
    try {
      _audioRecorder = FlutterSoundRecorder();
      await _audioRecorder!.openRecorder();
      await _audioRecorder!
          .setSubscriptionDuration(const Duration(milliseconds: 100));
      _noiseMeter = NoiseMeter();
      setState(() {});
    } catch (e) {
      _showErrorDialog('Failed to initialize recorder.');
    }
  }

  /// Initialize VAD service and set up event listeners
  Future<void> _initializeVAD() async {
    try {
      final success = await _vadService.initialize(isDebug: kDebugMode);
      if (success) {
        _setupVADListeners();
        debugPrint('VAD initialized successfully');
      } else {
        debugPrint('Failed to initialize VAD');
      }
    } catch (e) {
      debugPrint('VAD initialization error: $e');
    }
  }

  /// Set up VAD event listeners
  void _setupVADListeners() {
    _speechStartSubscription = _vadService.onSpeechStart.listen((_) {
      setState(() {
        _vadDetectedSpeech = true;
        _feedback = "Speech Detected";
      });
    });

    _realSpeechStartSubscription = _vadService.onRealSpeechStart.listen((_) {
      setState(() {
        _feedback = "Real Speech Detected";
      });
    });

    _speechEndSubscription = _vadService.onSpeechEnd.listen((samples) {
      setState(() {
        _vadDetectedSpeech = false;
        _feedback = "Speech Ended";
      });
    });

    _frameProcessedSubscription =
        _vadService.onFrameProcessed.listen((frameData) {
      // Convert frame data to amplitude for waveform
      final frame = frameData['frame'] as List<double>? ?? [];
      if (frame.isNotEmpty) {
        final amplitude =
            frame.fold<double>(0.0, (sum, sample) => sum + sample.abs()) /
                frame.length;
        _amplitudeController.add(Amplitude(current: amplitude * 100, max: 100));
      }
    });

    _vadMisfireSubscription = _vadService.onVadMisfire.listen((_) {
      setState(() {
        _feedback = "VAD Misfire";
      });
    });

    _vadErrorSubscription = _vadService.onError.listen((error) {
      _showErrorDialog('VAD Error: $error');
    });
  }

  void _nextSentence() {
    if (_currentSentenceIndex < VoiceCloningSentences.sentences.length - 1) {
      setState(() {
        _currentSentenceIndex++;
        _recordingStatus = 'Ready for next sentence';
        _feedback = "Initializing...";
      });
    } else {
      setState(() {
        _isComplete = true;
        _recordingStatus = 'Voice cloning complete!';
      });
      // Here you could implement logic to send the recording to your server
    }
  }

  void _startRecording() async {
    if (_audioRecorder == null) {
      _initializeRecorder();
      if (_audioRecorder == null) {
        _showErrorDialog('Recorder is not initialized.');
        return;
      }
    }

    try {
      // Only start a new recording if we're at the beginning
      if (_currentSentenceIndex == 0) {
        // For Android compatibility, ensure we're using the correct codec and settings
        await _audioRecorder!.startRecorder(
          toFile: _audioFile,
          codec: Codec.pcm16WAV,
          audioSource: AudioSource.microphone,
          sampleRate: _sampleRate,
          bitRate: 16 * 1000, // 16 kbps
          numChannels: 1, // Mono recording for better compatibility
        );
      }

      await _recorderController.record();

      // Start VAD listening
      if (_vadService.isInitialized) {
        await _vadService.startListening();
      }

      _noiseSubscription = _noiseMeter.noise.listen((NoiseReading reading) {
        setState(() {
          _decibel = reading.meanDecibel;
          if (!_vadDetectedSpeech) {
            _feedback = _getFeedbackFromDecibel(_decibel);
          }
        });
      });

      setState(() {
        _isRecording = true;
        _recordingStatus =
            'Recording sentence ${_currentSentenceIndex + 1} of ${VoiceCloningSentences.sentences.length}';
      });
    } catch (e) {
      _showErrorDialog('Failed to start recording: ${e.toString()}');
      setState(() {
        _isRecording = false;
        _recordingStatus = 'Error';
      });
    }
  }

  void _pauseRecording() async {
    if (_audioRecorder == null) {
      _showErrorDialog('Recorder is not initialized.');
      return;
    }
    try {
      await _recorderController.pause();
      _noiseSubscription?.cancel();

      // Stop VAD listening
      if (_vadService.isListening) {
        await _vadService.stopListening();
      }

      setState(() {
        _isRecording = false;
        _vadDetectedSpeech = false;
      });

      if (_currentSentenceIndex >= VoiceCloningSentences.sentences.length - 1) {
        await _audioRecorder!.stopRecorder();
        setState(() {
          _isComplete = true;
          _recordingStatus = 'Voice cloning complete!';
        });
        await _submitVoiceCloning();
      } else {
        _nextSentence();
      }
    } catch (e) {
      _showErrorDialog('Failed to pause recording.');
    }
  }

  String _getFeedbackFromDecibel(double decibel) {
    if (decibel > 80) {
      return "Too Loud";
    } else if (decibel < 40) {
      return "Too Quiet";
    } else {
      return "Good Level";
    }
  }

  void _showErrorDialog(String message,
      {ErrorSeverity severity = ErrorSeverity.medium,
      String source = 'VoiceCloning',
      dynamic error}) {
    _errorLogger.logError(message,
        severity: severity, source: source, error: error);

    ErrorLogger.showError(context, message, technicalError: error);
  }

  Future<void> _submitVoiceCloning() async {
    setState(() {
      _voiceCloningState = VoiceCloningState.generating;
    });

    try {
      final success = await VoiceCloningService.submitVoiceCloning(_audioFile);
      if (success) {
        setState(() {
          _voiceCloningState = VoiceCloningState.complete;
        });
        _showSuccessDialog('Voice cloning submitted successfully!');
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const TranslationApp()),
          );
        }
      } else {
        throw Exception('Voice cloning failed');
      }
    } catch (e) {
      setState(() {
        _voiceCloningState = VoiceCloningState.error;
      });

      _errorLogger.logError('Voice cloning submission failed',
          severity: ErrorSeverity.high, source: 'VoiceCloning', error: e);

      _showRetryDialog('Voice cloning failed. Would you like to try again?',
          error: e);
    }
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Success'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showRetryDialog(String message, {dynamic error}) {
    _errorLogger.logError(message,
        severity: ErrorSeverity.high, source: 'VoiceCloning', error: error);

    ErrorLogger.showErrorDialog(
      context,
      'Voice Cloning Error',
      message,
      technicalError: error,
      onRetry: () {
        setState(() {
          _currentSentenceIndex = 0;
          _isComplete = false;
          _voiceCloningState = VoiceCloningState.recording;
          _recordingStatus = 'Ready to start';
        });
      },
      onDismiss: _handleSkip,
    );
  }

  void _handleSkip() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const TranslationApp()),
    );
  }

  @override
  void dispose() {
    _noiseSubscription?.cancel();
    _audioRecorder?.closeRecorder();
    _audioRecorder = null;
    _recorderController.dispose();

    // Clean up VAD subscriptions
    _speechStartSubscription?.cancel();
    _realSpeechStartSubscription?.cancel();
    _speechEndSubscription?.cancel();
    _frameProcessedSubscription?.cancel();
    _vadMisfireSubscription?.cancel();
    _vadErrorSubscription?.cancel();
    _amplitudeController.close();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Voice Cloning'),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              LinearProgressIndicator(
                value: (_currentSentenceIndex + 1) /
                    VoiceCloningSentences.sentences.length,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(Colors.grey.shade700),
              ),
              const SizedBox(height: 20),
              Text(
                'Sentence ${_currentSentenceIndex + 1} of ${VoiceCloningSentences.sentences.length}',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _isRecording ? Colors.blue : Colors.grey.shade300,
                    width: 2,
                  ),
                ),
                child: Text(
                  _currentSentence,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Colors.black),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                _recordingStatus,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 20),
              if (!_isComplete) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_vadDetectedSpeech) ...[
                      Icon(
                        Icons.mic,
                        color: Colors.green,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                    ],
                    Text(
                      _feedback,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _vadDetectedSpeech
                            ? Colors.green
                            : _feedback == "Too Loud"
                                ? Colors.red
                                : _feedback == "Too Quiet"
                                    ? Colors.orange
                                    : Colors.green,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.8,
                  height: 100,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      color: Colors.grey.shade400,
                      child: _isRecording
                          ? AnimatedWaveList(stream: amplitudeStream)
                          : Container(
                              width: MediaQuery.of(context).size.width * 0.8,
                              height: 100,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Text(
                                  'Waveform will appear when recording',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: _isRecording ? _pauseRecording : _startRecording,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 30, vertical: 15),
                    textStyle: const TextStyle(fontSize: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    backgroundColor:
                        _isRecording ? Colors.red : Colors.grey[700],
                  ),
                  child:
                      Text(_isRecording ? 'Stop Recording' : 'Start Recording'),
                ),
              ] else ...[
                Icon(
                  _voiceCloningState == VoiceCloningState.complete
                      ? Icons.check_circle
                      : _voiceCloningState == VoiceCloningState.error
                          ? Icons.error_rounded
                          : Icons.access_time,
                  color: _voiceCloningState == VoiceCloningState.complete
                      ? Colors.green
                      : _voiceCloningState == VoiceCloningState.error
                          ? Colors.red
                          : Colors.black,
                  size: 64,
                ),
                const SizedBox(height: 20),
                Text(
                  _voiceCloningState == VoiceCloningState.generating
                      ? 'Submitting voice clone...'
                      : _voiceCloningState == VoiceCloningState.error
                          ? 'Voice cloning failed!'
                          : 'Voice cloning complete!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: _voiceCloningState == VoiceCloningState.error
                        ? Colors.red
                        : Colors.black,
                  ),
                ),
                const SizedBox(height: 20),
                if (_voiceCloningState == VoiceCloningState.generating)
                  const CircularProgressIndicator()
                else if (_voiceCloningState == VoiceCloningState.complete)
                  const Text(
                    'Voice Cloned!',
                    style: TextStyle(fontSize: 16),
                  )
                else if (_voiceCloningState == VoiceCloningState.error)
                  const Text(
                    'Please try again',
                    style: TextStyle(fontSize: 16, color: Colors.red),
                  ),
              ],
              const SizedBox(height: 20),
              const Text(
                'Tip: Speak clearly and maintain a consistent volume for best results.',
                style: TextStyle(fontSize: 14, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 20),
              GestureDetector(
                onTap: _handleSkip,
                child: const Text(
                  "Proceed without cloning voice",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
