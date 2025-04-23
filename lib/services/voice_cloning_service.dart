import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:uuid/uuid.dart';
import '../services/api_service.dart';

class VoiceCloningService {
  final OmniAPI _api;
  final _uuid = const Uuid();

  VoiceCloningService() : _api = OmniAPI();

  Future<bool> submitVoiceCloning(String audioFilePath) async {
    try {
      final userUuid = _uuid.v4();
      final (audioData, response) = await postVoiceClone(
        endpoint: _api,
        filePath: audioFilePath,
        uuid: userUuid,
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return true;
      } else {
        throw APIError('Failed to submit voice cloning: ${response.statusCode}');
      }
    } catch (e) {
      throw APIError('Voice cloning submission failed: $e');
    }
  }
}