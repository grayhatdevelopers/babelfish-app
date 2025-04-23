import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:noise_meter/noise_meter.dart';
import 'package:audio_waveforms/audio_waveforms.dart';

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
  final String _audioFilePath = 'audio_record.aac';

  late NoiseMeter _noiseMeter;
  StreamSubscription<NoiseReading>? _noiseSubscription;
  double _decibel = 0.0;
  String _feedback = "Initializing...";

  final RecorderController _recorderController = RecorderController();

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

  void _startRecording() async {
    if (_audioRecorder == null) {
      _showErrorDialog('Recorder is not initialized.');
      return;
    }
    try {
      await _audioRecorder!.startRecorder(
        toFile: _audioFilePath,
        codec: Codec.aacADTS,
        audioSource: AudioSource.microphone,
        sampleRate: _sampleRate,
      );

      await _recorderController.record();

      _noiseSubscription = _noiseMeter.noise.listen((NoiseReading reading) {
        setState(() {
          _decibel = reading.meanDecibel;
          _feedback = _getFeedbackFromDecibel(_decibel);
        });
      });

      setState(() {
        _isRecording = true;
        _recordingStatus = 'Recording...';
      });
    } catch (e) {
      _showErrorDialog('Failed to start recording.');
      setState(() {
        _isRecording = false;
        _recordingStatus = 'Error';
      });
    }
  }

  void _stopRecording() async {
    if (_audioRecorder == null) {
      _showErrorDialog('Recorder is not initialized.');
      return;
    }
    try {
      await _audioRecorder!.stopRecorder();
      await _recorderController.stop();
      _noiseSubscription?.cancel();

      setState(() {
        _isRecording = false;
        _recordingStatus = 'Recording Stopped';
        _decibel = 0.0;
        _feedback = 'Stopped';
      });
    } catch (e) {
      _showErrorDialog('Failed to stop recording.');
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
        title: const Text('Babelfish'),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Text(
                _recordingStatus,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 20),
              Text(
                'Decibel: ${_decibel.toStringAsFixed(2)} dB',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 10),
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
                      size: Size(MediaQuery.of(context).size.width * 0.8, 100),
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
                onPressed: _isRecording ? _stopRecording : _startRecording,
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  textStyle: const TextStyle(fontSize: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  backgroundColor: _isRecording ? Colors.red : Colors.blue,
                ),
                child:
                    Text(_isRecording ? 'Stop Recording' : 'Start Recording'),
              ),
              const SizedBox(height: 20),
              const Text(
                'Tip: Speak clearly and maintain a consistent volume for best results.',
                style: TextStyle(fontSize: 14, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
