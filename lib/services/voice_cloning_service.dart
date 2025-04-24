import 'package:audio_recorder/models/api_response.dart';
import 'package:audio_recorder/services/storage_service.dart';
import '../services/api_service.dart';

class VoiceCloningService {
  final OmniAPI _api;

  VoiceCloningService() : _api = OmniAPI();

  Future<bool> submitVoiceCloning(String audioFilePath) async {
    try {
      final username = await StorageService.getUsername();
      if (username == null) {
        throw APIError('User not authenticated');
      }

      final (audioData, response) = await postVoiceClone(
        endpoint: _api,
        filePath: audioFilePath,
        uuid: username, // Using username instead of UUID
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return true;
      } else {
        throw APIError(
            'Failed to submit voice cloning: ${response.statusCode}');
      }
    } catch (e) {
      throw ('$e');
    }
  }
}

enum VoiceCloningState { recording, generating, complete, error }
