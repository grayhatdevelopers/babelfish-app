import 'package:audio_recorder/services/storage_service.dart';

class WebSocketConfig {
  static String serverUrl =
      'ws://ec2-51-21-138-103.eu-north-1.compute.amazonaws.com:8001/ws/client';

  static Future<void> initializeServerUrl() async {
    final savedUrl = await StorageService.getWebsocketUrl();
    if (savedUrl != null && savedUrl.isNotEmpty) {
      serverUrl = savedUrl;
    }
  }
}
