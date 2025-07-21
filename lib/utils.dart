import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';

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
      {Duration duration = const Duration(seconds: 4),
      dynamic technicalError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[700],
        behavior: SnackBarBehavior.floating,
        duration: duration,
        action: SnackBarAction(
          label: 'Details',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            if (kDebugMode && technicalError != null) {
              showTechnicalErrorDialog(context, technicalError);
            }
          },
        ),
      ),
    );
  }

  // Show an error dialog
  static Future<void> showErrorDialog(
      BuildContext context, String title, String message,
      {VoidCallback? onRetry,
      VoidCallback? onDismiss,
      dynamic technicalError}) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          if (kDebugMode && technicalError != null)
            TextButton(
              onPressed: () {
                showTechnicalErrorDialog(context, technicalError);
              },
              child: const Text('Technical Details'),
            ),
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
    VoidCallback? onShowDetails,
    Color backgroundColor = const Color(0xDDC62828),
    dynamic technicalError,
  }) {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(8),
      color: backgroundColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    errorMessage,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
                if (kDebugMode && technicalError != null)
                  IconButton(
                    icon: const Icon(Icons.code, color: Colors.white),
                    onPressed: onShowDetails,
                    tooltip: 'Show Technical Details',
                  ),
                if (onDismiss != null)
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: onDismiss,
                    tooltip: 'Dismiss',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Show technical error details for debugging
  static Future<void> showTechnicalErrorDialog(
      BuildContext context, dynamic error) async {
    String errorDetails = '';

    if (error is Exception || error is Error) {
      errorDetails = error.toString();
    } else if (error is Map) {
      errorDetails = const JsonEncoder.withIndent('  ').convert(error);
    } else {
      errorDetails = error.toString();
    }

    return showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          padding: const EdgeInsets.all(16),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.9,
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.code, size: 24),
                  const SizedBox(width: 8),
                  const Text(
                    'Technical Error Details',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Error Information:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        width: double.infinity,
                        child: SelectableText(
                          errorDetails,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
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
