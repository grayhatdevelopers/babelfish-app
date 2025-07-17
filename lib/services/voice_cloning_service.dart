import 'package:audio_recorder/models/api_response.dart';
import 'package:audio_recorder/services/storage_service.dart';
import 'package:audio_recorder/utils.dart';
import 'package:flutter/foundation.dart';
import '../services/api_service.dart';

class VoiceCloningService {
  static Future<bool> submitVoiceCloning(String audioFilePath) async {
    try {
      final username = await StorageService.getUsername();
      if (username == null) {
        throw APIError('User not authenticated');
      }

      final (audioData, response) = await postVoiceClone(
        filePath: audioFilePath,
        uuid: username, // Using username instead of UUID
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return true;
      } else {
        throw APIError(
            'Failed to submit voice cloning: ${response.statusCode}');
      }
    } catch (error) {
      if (kDebugMode) {
        ErrorLogger().logError('Voice cloning service error',
            severity: ErrorSeverity.high,
            source: 'Voice Cloning Service',
            error: error);
      }
      throw ('$error');
    }
  }
}

enum VoiceCloningState { recording, generating, complete, error }
