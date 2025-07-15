import 'package:audio_recorder/services/storage_service.dart';

class WebSocketConfig {
  static String serverUrl = 'ws://jenny.coldpeak.co/ws/client';

  static Future<void> initializeServerUrl() async {
    final savedUrl = await StorageService.getWebsocketUrl();
    if (savedUrl != null && savedUrl.isNotEmpty) {
      serverUrl = savedUrl;
    }
  }
}
