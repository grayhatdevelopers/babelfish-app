import 'dart:async';
import 'package:audio_recorder/pages/main_page.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:noise_meter/noise_meter.dart';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:audio_recorder/models/cloning_sentences.dart';
import '../services/voice_cloning_service.dart';

class VoiceCloningScreen extends StatefulWidget {
  const VoiceCloningScreen({super.key});

  @override
  _VoiceCloningScreenState createState() => _VoiceCloningScreenState();
}

class _VoiceCloningScreenState extends State<VoiceCloningScreen> {
  FlutterSoundRecorder? _audioRecorder;
  bool _isRecording = false;
  String _recordingStatus = 'Not Recording';
  final int _sampleRate = 44100;
  int _currentSentenceIndex = 0;
  String _audioFile = 'voice_cloning.aac';
  bool _isComplete = false;
  bool _isSubmitting = false;

  late NoiseMeter _noiseMeter;
  StreamSubscription<NoiseReading>? _noiseSubscription;
  double _decibel = 0.0;
  String _feedback = "Initializing...";

  final RecorderController _recorderController = RecorderController();
  final VoiceCloningService _voiceCloningService = VoiceCloningService();

  String get _currentSentence =>
      _currentSentenceIndex < VoiceCloningSentences.sentences.length
          ? VoiceCloningSentences.sentences[_currentSentenceIndex]
          : "";

  @override
  void initState() {
    super.initState();
    _checkAndRequestPermissions();
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
      _showErrorDialog('Recorder is not initialized.');
      return;
    }

    try {
      // Only start a new recording if we're at the beginning
      if (_currentSentenceIndex == 0) {
        await _audioRecorder!.startRecorder(
          toFile: _audioFile,
          codec: Codec.aacADTS,
          audioSource: AudioSource.microphone,
          sampleRate: _sampleRate,
        );
      }

      await _recorderController.record();

      _noiseSubscription = _noiseMeter.noise.listen((NoiseReading reading) {
        setState(() {
          _decibel = reading.meanDecibel;
          _feedback = _getFeedbackFromDecibel(_decibel);
        });
      });

      setState(() {
        _isRecording = true;
        _recordingStatus =
            'Recording sentence ${_currentSentenceIndex + 1} of ${VoiceCloningSentences.sentences.length}';
      });
    } catch (e) {
      _showErrorDialog('Failed to start recording.');
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

      setState(() {
        _isRecording = false;
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

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
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

  Future<void> _submitVoiceCloning() async {
    setState(() {
      _isSubmitting = true;
    });

    try {
      final success = await _voiceCloningService.submitVoiceCloning(_audioFile);
      if (success) {
        _showSuccessDialog(
            'Voice cloning submitted successfully!'); // Navigate to main page after dialog is dismissed
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const TranslationApp()),
          );
        }
      }
    } catch (e) {
      _showErrorDialog('Failed to submit voice cloning: $e');
    } finally {
      setState(() {
        _isSubmitting = false;
      });
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
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
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
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _isRecording ? Colors.blue : Colors.grey.shade300,
                    width: 2,
                  ),
                ),
                child: Text(
                  _currentSentence,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w500),
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
                Text(
                  _feedback,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _feedback == "Too Loud"
                        ? Colors.red
                        : _feedback == "Too Quiet"
                            ? Colors.orange
                            : Colors.green,
                  ),
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.8,
                  height: 100,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      color: Colors.grey.shade200,
                      child: AudioWaveforms(
                        size:
                            Size(MediaQuery.of(context).size.width * 0.8, 100),
                        recorderController: _recorderController,
                        enableGesture: true,
                        waveStyle: WaveStyle(
                          showMiddleLine: false,
                          waveThickness: 1.0,
                          extendWaveform: true,
                          waveColor: Colors.blue,
                          spacing: 2.0,
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
                const Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 64,
                ),
                const SizedBox(height: 20),
                Text(
                  _isSubmitting
                      ? 'Submitting voice clone...'
                      : 'Voice cloning complete!',
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                if (_isSubmitting)
                  const CircularProgressIndicator()
                else
                  Text(
                    'Recording saved as: $_audioFile',
                    style: const TextStyle(fontSize: 16),
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
