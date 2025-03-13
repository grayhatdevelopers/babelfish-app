import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'dart:convert';

class WebsocketService {
  WebSocketChannel? _channel;

  bool connect(String url) {
    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));
      return true;
    } catch (e) {
      if (kDebugMode) {
        print("Failed to connect to WebSocket server: $e");
      }
      return false;
    }
  }

  void startListening(Function(dynamic) onMessageReceived) {
    if (_channel != null) {
      _channel!.stream.listen((message) {
        onMessageReceived(message);
      }, onDone: () {
        if (kDebugMode) {
          print("Channel closed");
        }
      }, onError: (error) {
        if (kDebugMode) {
          print("Error: $error");
        }
      });
    }
  }

  void close() {
    if (_channel != null) {
      _channel!.sink.close(status.goingAway);
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
