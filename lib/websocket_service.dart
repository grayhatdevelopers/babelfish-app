import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:convert';

class WebsocketService {
  WebSocketChannel? _channel;
  bool isWebSocketConnected = false;
  StreamSubscription? _subscription;

  Future<bool> connect(String url) async {
    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));
      if (_channel != null) {
        try {
          // Add timeout to prevent hanging
          await _channel!.ready.timeout(
            const Duration(seconds: 3),
            onTimeout: () {
              throw TimeoutException('WebSocket connection timed out');
            },
          );
          isWebSocketConnected = true;
          return true;
        } catch (e) {
          if (kDebugMode) {
            print("Failed to establish WebSocket connection: $e");
          }
          // Clean up the channel on failure
          _channel?.sink.close();
          _channel = null;
          isWebSocketConnected = false;
          return false;
        }
      }
      return false;
    } on WebSocketChannelException catch (e) {
      if (kDebugMode) {
        print("WebSocket connection failed: $e");
      }
      isWebSocketConnected = false;
      return false;
    } catch (e) {
      if (kDebugMode) {
        print("Unexpected error during WebSocket connection: $e");
      }
      isWebSocketConnected = false;
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
        },
        onError: (error) {
          if (kDebugMode) {
            print("Error: $error");
          }
          isWebSocketConnected = false;
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
    }
  }

  void sendMessage(String message) {
    try {
      if (_channel != null) {
        _channel!.sink.add(message);
      }
    } catch (e) {
      if (kDebugMode) {
        print("Failed to send chunk with metadata: $e");
      }
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
      }
    }
  }
}
