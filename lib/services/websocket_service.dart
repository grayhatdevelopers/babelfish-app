import 'dart:async';
import 'dart:io';

import 'package:audio_recorder/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:convert';

enum WebSocketErrorType {
  connectionFailed,
  connectionTimeout,
  connectionClosed,
  messageSendFailed,
  serverError,
  unknown
}

class WebSocketError {
  final WebSocketErrorType type;
  final String message;

  WebSocketError(this.type, this.message);

  @override
  String toString() => message;
}

class WebsocketService {
  WebSocketChannel? _channel;
  bool isWebSocketConnected = false;
  StreamSubscription? _subscription;
  WebSocketError? lastError;

  // Stream controller to broadcast error events
  final StreamController<WebSocketError> _errorStreamController =
      StreamController<WebSocketError>.broadcast();

  // Expose the error stream
  Stream<WebSocketError> get errorStream => _errorStreamController.stream;

  Future<bool> connect(String url) async {
    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));
      if (_channel != null) {
        try {
          // Add timeout to prevent hanging
          await _channel!.ready.timeout(
            const Duration(seconds: 365000),
            onTimeout: () {
              lastError = WebSocketError(WebSocketErrorType.connectionTimeout,
                  'Connection timed out after 30 seconds');
              _errorStreamController.add(lastError!);
              throw TimeoutException('WebSocket connection timed out');
            },
          );
          isWebSocketConnected = true;
          return true;
        } catch (e) {
          if (kDebugMode) {
            print("Failed to establish WebSocket connection: $e");
            ErrorLogger().logError('Failed to establish WebSocket connection',
                severity: ErrorSeverity.high,
                source: 'WebSocket Service',
                error: e);
          }
          // Clean up the channel on failure
          _channel?.sink
              .close(WebSocketStatus.normalClosure, 'Connection failed');
          _channel = null;
          isWebSocketConnected = false;

          if (e is TimeoutException) {
            // Already handled in the timeout callback
          } else {
            lastError = WebSocketError(WebSocketErrorType.connectionFailed,
                'Failed to establish connection: ${e.toString()}');
            _errorStreamController.add(lastError!);
          }
          return false;
        }
      }
      lastError = WebSocketError(WebSocketErrorType.connectionFailed,
          'Could not create WebSocket channel');
      _errorStreamController.add(lastError!);
      return false;
    } on WebSocketChannelException catch (e) {
      if (kDebugMode) {
        print("WebSocket connection failed: $e");
        ErrorLogger().logError('WebSocket channel exception',
            severity: ErrorSeverity.high,
            source: 'WebSocket Service',
            error: e);
      }
      isWebSocketConnected = false;
      lastError = WebSocketError(WebSocketErrorType.connectionFailed,
          'WebSocket connection failed: ${e.toString()}');
      _errorStreamController.add(lastError!);
      return false;
    } catch (e) {
      if (kDebugMode) {
        print("Unexpected error during WebSocket connection: $e");
        ErrorLogger().logError('Unexpected WebSocket error',
            severity: ErrorSeverity.critical,
            source: 'WebSocket Service',
            error: e);
      }
      isWebSocketConnected = false;
      lastError = WebSocketError(
          WebSocketErrorType.unknown, 'Unexpected error: ${e.toString()}');
      _errorStreamController.add(lastError!);
      return false;
    }
  }

  void startListening(Function(dynamic) onMessageReceived) {
    if (_channel != null) {
      _subscription = _channel!.stream.listen(
        (message) {
          onMessageReceived(message);
        },
        onDone: () {
          if (kDebugMode) {
            print("Channel closed");
          }
          isWebSocketConnected = false;
          lastError = WebSocketError(WebSocketErrorType.connectionClosed,
              'WebSocket connection closed');
          _errorStreamController.add(lastError!);
        },
        onError: (error) {
          if (kDebugMode) {
            print("Error: $error");
            ErrorLogger().logError('WebSocket stream error',
                severity: ErrorSeverity.high,
                source: 'WebSocket Service',
                error: error);
          }
          isWebSocketConnected = false;
          lastError = WebSocketError(WebSocketErrorType.serverError,
              'Server error: ${error.toString()}');
          _errorStreamController.add(lastError!);
        },
      );
    }
  }

  Future<void> close() async {
    try {
      if (_subscription != null) {
        await _subscription!.cancel();
        _subscription = null;
      }

      if (_channel != null) {
        await _channel!.sink.close(WebSocketStatus.normalClosure);
        _channel = null;
        if (kDebugMode) {
          print("WebSocket closed");
        }
      }

      isWebSocketConnected = false;
    } catch (e) {
      if (kDebugMode) {
        print("Error closing WebSocket: $e");
      }
      lastError = WebSocketError(WebSocketErrorType.unknown,
          'Error closing WebSocket: ${e.toString()}');
      _errorStreamController.add(lastError!);
    }
  }

  void sendMessage(String message) {
    try {
      if (_channel != null) {
        _channel!.sink.add(message);
      } else {
        lastError = WebSocketError(WebSocketErrorType.messageSendFailed,
            'Cannot send message: WebSocket not connected');
        _errorStreamController.add(lastError!);
      }
    } catch (e) {
      if (kDebugMode) {
        print("Failed to send message: $e");
      }
      lastError = WebSocketError(WebSocketErrorType.messageSendFailed,
          'Failed to send message: ${e.toString()}');
      _errorStreamController.add(lastError!);
    }
  }

  void sendData(double sampleRate, String userID, String targetLanguage,
      Uint8List chunk) {
    if (_channel != null) {
      try {
        // Create metadata JSON
        Map<String, dynamic> metadata = {
          'sampleRate': sampleRate, // Use actual sample rate
          'userID': userID,
          'targetLanguage': targetLanguage
        };

        String metadataJson = jsonEncode(metadata);

        // Convert metadata to bytes
        Uint8List metadataBytes = utf8.encode(metadataJson);
        Uint8List metadataLength = Uint8List(4)
          ..buffer
              .asByteData()
              .setUint32(0, metadataBytes.length, Endian.little);

        // Concatenate metadata length, metadata, and audio chunk
        Uint8List payload =
            Uint8List.fromList(metadataLength + metadataBytes + chunk);

        // Send to WebSocket server
        _channel!.sink.add(payload);
      } catch (e) {
        if (kDebugMode) {
          print("Failed to send chunk with metadata: $e");
        }
        lastError = WebSocketError(WebSocketErrorType.messageSendFailed,
            'Failed to send audio data: ${e.toString()}');
        _errorStreamController.add(lastError!);
      }
    } else {
      lastError = WebSocketError(WebSocketErrorType.messageSendFailed,
          'Cannot send audio data: WebSocket not connected');
      _errorStreamController.add(lastError!);
    }
  }

  // Call this when disposing the service
  void dispose() {
    _errorStreamController.close();
  }
}
