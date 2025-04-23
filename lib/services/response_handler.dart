import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

class ResponseHandler {
  static handleReponse(dynamic message, Function(String) onTextReceived,
      Function(Uint8List) onAudioReceived) {
    if (message is String) {
      // Handle JSON messages
      Map<String, dynamic> response = jsonDecode(message);
      if (response['type'] == 'TS') {
        // Handle real-time transcription
        if (kDebugMode) {
          print("Translationxw: ${response['text']}");
        }
        onTextReceived(response['text']);
      } else if (response['type'] == 'audio') {
        Float32List preprocessedAudioData =
            Float32List.fromList(response['audio_data']);
        Uint8List audioData = _convertFloat32ToPCM16(preprocessedAudioData);
        onAudioReceived(audioData);
        //_playAudio(audioData);
      }
    } else if (message is Uint8List) {
      // Handle raw audio data
      Float32List preprocessedAudioData = message.buffer.asFloat32List();
      Uint8List audioData = _convertFloat32ToPCM16(preprocessedAudioData);
      onAudioReceived(audioData);
      //_playAudio(audioData);
    }
  }

  static Uint8List _convertFloat32ToPCM16(Float32List float32Data) {
    // Convert Float32List to Uint8List
    final int len = float32Data.length;
    final Int16List int16Data = Int16List(len);

    for (int i = 0; i < len; i++) {
      final double sample = float32Data[i];
      int16Data[i] = (sample * 32767).toInt().clamp(-32768, 32767);
    }

    return Uint8List.view(int16Data.buffer);
  }
}
