import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:vad/vad.dart';
import 'package:permission_handler/permission_handler.dart';

/// Service class to handle Voice Activity Detection (VAD) functionality
class VadService {
  static VadService? _instance;
  static VadService get instance => _instance ??= VadService._();

  VadService._();

  VadHandlerBase? _vadHandler;
  bool _isInitialized = false;
  bool _isListening = false;

  // Stream controllers for VAD events
  final StreamController<void> _speechStartController =
      StreamController<void>.broadcast();
  final StreamController<void> _realSpeechStartController =
      StreamController<void>.broadcast();
  final StreamController<List<double>> _speechEndController =
      StreamController<List<double>>.broadcast();
  final StreamController<Map<String, dynamic>> _frameProcessedController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<void> _vadMisfireController =
      StreamController<void>.broadcast();
  final StreamController<String> _errorController =
      StreamController<String>.broadcast();

  // Public streams
  Stream<void> get onSpeechStart => _speechStartController.stream;
  Stream<void> get onRealSpeechStart => _realSpeechStartController.stream;
  Stream<List<double>> get onSpeechEnd => _speechEndController.stream;
  Stream<Map<String, dynamic>> get onFrameProcessed =>
      _frameProcessedController.stream;
  Stream<void> get onVadMisfire => _vadMisfireController.stream;
  Stream<String> get onError => _errorController.stream;

  bool get isInitialized => _isInitialized;
  bool get isListening => _isListening;

  /// Initialize the VAD service
  Future<bool> initialize({bool isDebug = false}) async {
    try {
      // Check microphone permission
      final status = await Permission.microphone.status;
      if (status.isDenied) {
        final result = await Permission.microphone.request();
        if (!result.isGranted) {
          _errorController.add('Microphone permission denied');
          return false;
        }
      }

      // Create VAD handler
      _vadHandler = VadHandler.create(isDebug: isDebug);

      // Set up event listeners
      _setupEventListeners();

      _isInitialized = true;
      if (isDebug) {
        debugPrint('VAD Service initialized successfully');
      }
      return true;
    } catch (e) {
      _errorController.add('Failed to initialize VAD: ${e.toString()}');
      debugPrint('VAD initialization error: $e');
      return false;
    }
  }

  /// Set up event listeners for VAD events
  void _setupEventListeners() {
    if (_vadHandler == null) return;

    _vadHandler!.onSpeechEnd.listen((List<double> samples) {
      debugPrint('VAD: Speech ended, samples: ${samples.length}');
      _speechEndController.add(samples);
    });

    _vadHandler!.onSpeechStart.listen((_) {
      debugPrint('VAD: Speech detected');
      _speechStartController.add(null);
    });

    _vadHandler!.onRealSpeechStart.listen((_) {
      debugPrint('VAD: Real speech start detected');
      _realSpeechStartController.add(null);
    });

    _vadHandler!.onVADMisfire.listen((_) {
      debugPrint('VAD: Misfire detected');
      _vadMisfireController.add(null);
    });

    _vadHandler!.onFrameProcessed.listen((frameData) {
      // Add frame data to stream
      _frameProcessedController.add({
        'isSpeech': frameData.isSpeech,
        'notSpeech': frameData.notSpeech,
        'frame': frameData.frame,
      });
    });

    _vadHandler!.onError.listen((String message) {
      debugPrint('VAD Error: $message');
      _errorController.add(message);
    });
  }

  /// Start VAD listening with configurable parameters
  Future<bool> startListening({
    double positiveSpeechThreshold =
        0.9, // Increased from 0.8 for better precision
    double negativeSpeechThreshold =
        0.2, // Reduced from 0.3 for better silence detection
    int preSpeechPadFrames =
        2, // Increased from 1 for better speech beginning detection
    int redemptionFrames =
        12, // Increased from 10 for better speech continuation
    int frameSamples = 1536,
    int minSpeechFrames = 2,
    bool submitUserSpeechOnPause = true,
    String model = 'legacy',
  }) async {
    if (!_isInitialized || _vadHandler == null) {
      _errorController.add('VAD service not initialized');
      return false;
    }

    if (_isListening) {
      debugPrint('VAD is already listening');
      return true;
    }

    try {
      await _vadHandler!.startListening(
        positiveSpeechThreshold: positiveSpeechThreshold,
        negativeSpeechThreshold: negativeSpeechThreshold,
        preSpeechPadFrames: preSpeechPadFrames,
        redemptionFrames: redemptionFrames,
        frameSamples: frameSamples,
        minSpeechFrames: minSpeechFrames,
        submitUserSpeechOnPause: submitUserSpeechOnPause,
        model: model,
      );

      _isListening = true;
      debugPrint('VAD listening started');
      return true;
    } catch (e) {
      _errorController.add('Failed to start VAD listening: ${e.toString()}');
      debugPrint('VAD start listening error: $e');
      return false;
    }
  }

  /// Stop VAD listening
  Future<bool> stopListening() async {
    if (!_isInitialized || _vadHandler == null) {
      _errorController.add('VAD service not initialized');
      return false;
    }

    if (!_isListening) {
      debugPrint('VAD is not listening');
      return true;
    }

    try {
      await _vadHandler!.stopListening();
      _isListening = false;
      debugPrint('VAD listening stopped');
      return true;
    } catch (e) {
      _errorController.add('Failed to stop VAD listening: ${e.toString()}');
      debugPrint('VAD stop listening error: $e');
      return false;
    }
  }

  /// Pause VAD listening
  Future<bool> pauseListening() async {
    if (!_isInitialized || _vadHandler == null) {
      _errorController.add('VAD service not initialized');
      return false;
    }

    if (!_isListening) {
      debugPrint('VAD is not listening');
      return true;
    }

    try {
      await _vadHandler!.pauseListening();
      _isListening = false;
      debugPrint('VAD listening paused');
      return true;
    } catch (e) {
      _errorController.add('Failed to pause VAD listening: ${e.toString()}');
      debugPrint('VAD pause listening error: $e');
      return false;
    }
  }

  /// Dispose the VAD service and clean up resources
  Future<void> dispose() async {
    try {
      if (_isListening) {
        await stopListening();
      }

      await _vadHandler?.dispose();
      _vadHandler = null;

      // Close stream controllers
      await _speechStartController.close();
      await _realSpeechStartController.close();
      await _speechEndController.close();
      await _frameProcessedController.close();
      await _vadMisfireController.close();
      await _errorController.close();

      _isInitialized = false;
      debugPrint('VAD Service disposed');
    } catch (e) {
      debugPrint('Error disposing VAD service: $e');
    }
  }

  /// Get current VAD status information
  Map<String, dynamic> getStatus() {
    return {
      'isInitialized': _isInitialized,
      'isListening': _isListening,
      'hasHandler': _vadHandler != null,
    };
  }
}
