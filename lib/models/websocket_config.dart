import 'package:audio_recorder/services/storage_service.dart';

class WebSocketConfig {
  static String serverUrl =
      'ws://ec2-13-51-78-136.eu-north-1.compute.amazonaws.com:8080/ws/client';

  static Future<void> initializeServerUrl() async {
    final savedUrl = await StorageService.getWebsocketUrl();
    if (savedUrl != null && savedUrl.isNotEmpty) {
      serverUrl = savedUrl;
    }
  }
}
