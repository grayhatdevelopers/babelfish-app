import 'package:flutter/material.dart';
import 'dart:async';

class ErrorLogger {
  static final ErrorLogger _instance = ErrorLogger._internal();
  factory ErrorLogger() => _instance;
  ErrorLogger._internal();

  // Stream controller to broadcast errors app-wide
  final _errorController = StreamController<ErrorEvent>.broadcast();
  Stream<ErrorEvent> get errorStream => _errorController.stream;

  // Log an error and broadcast it
  void logError(String message,
      {ErrorSeverity severity = ErrorSeverity.medium,
      String? source,
      dynamic error}) {
    final errorEvent = ErrorEvent(
      message: message,
      timestamp: DateTime.now(),
      severity: severity,
      source: source ?? 'Unknown',
      error: error,
    );

    print(
        'ERROR [${errorEvent.severity}] ${errorEvent.source}: ${errorEvent.message}');
    if (error != null) {
      print('Error details: $error');
    }

    _errorController.add(errorEvent);
  }

  // Show a toast/snackbar error
  static void showError(BuildContext context, String message,
      {Duration duration = const Duration(seconds: 4)}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[700],
        behavior: SnackBarBehavior.floating,
        duration: duration,
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  // Show an error dialog
  static Future<void> showErrorDialog(
      BuildContext context, String title, String message,
      {VoidCallback? onRetry, VoidCallback? onDismiss}) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          if (onDismiss != null)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                onDismiss();
              },
              child: const Text('Dismiss'),
            ),
          if (onRetry != null)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[700],
              ),
              onPressed: () {
                Navigator.of(context).pop();
                onRetry();
              },
              child: const Text('Retry', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
    );
  }

  // Display a persistent error overlay
  static Widget errorOverlay({
    required String errorMessage,
    VoidCallback? onDismiss,
    Color backgroundColor = const Color(0xDDC62828),
  }) {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(8),
      color: backgroundColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                errorMessage,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
            if (onDismiss != null)
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: onDismiss,
              ),
          ],
        ),
      ),
    );
  }

  void dispose() {
    _errorController.close();
  }
}

class ErrorEvent {
  final String message;
  final DateTime timestamp;
  final ErrorSeverity severity;
  final String source;
  final dynamic error;

  ErrorEvent({
    required this.message,
    required this.timestamp,
    required this.severity,
    required this.source,
    this.error,
  });
}

enum ErrorSeverity { low, medium, high, critical }
