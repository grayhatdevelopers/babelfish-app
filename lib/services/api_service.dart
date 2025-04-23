import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:http_parser/http_parser.dart';

class APIError implements Exception {
  final int? statusCode;
  final String message;

  APIError(this.message, [this.statusCode]);

  static APIError unknown() => APIError('Unknown error occurred');
  static APIError errorCode(int code) => APIError('Error code: $code', code);

  @override
  String toString() =>
      'APIError: $message${statusCode != null ? ' (Status: $statusCode)' : ''}';
}

class FileError implements Exception {
  final String message;
  FileError(this.message);

  static FileError readingError() => FileError('Error reading file');

  @override
  String toString() => 'FileError: $message';
}

class OmniAPI {
  String baseUrl = 'http://34.31.82.234:8800';
  final Map<String, String> headers;

  OmniAPI({
    this.headers = const {'Content-Type': 'application/json'},
  });

  Uri get voiceCloneEndpoint => Uri.parse('$baseUrl/voice-clone');
}

Future<(Uint8List, http.Response)> postVoiceClone({
  required OmniAPI endpoint,
  required String filePath,
  required String uuid,
  Duration timeout = const Duration(seconds: 10),
}) async {
  try {
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileError('File does not exist at path: $filePath');
    }

    final audioData = await file.readAsBytes();
    final fileName = path.basename(filePath);
    final mimeType = 'audio/wav';
    final boundary = 'Boundary-${DateTime.now().millisecondsSinceEpoch}';

    final request = http.MultipartRequest('POST', endpoint.voiceCloneEndpoint)
      ..headers.addAll({
        'Content-Type': 'multipart/form-data; boundary=$boundary',
      });

    // Add the audio file
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        audioData,
        filename: fileName,
        contentType: MediaType.parse(mimeType),
      ),
    );

    // Add user_id parameter
    request.fields['user_id'] = uuid;

    // Send the request with timeout
    final streamedResponse = await request.send().timeout(
      timeout,
      onTimeout: () {
        throw APIError('Request timed out after ${timeout.inSeconds} seconds');
      },
    );

    final response = await http.Response.fromStream(streamedResponse).timeout(
      timeout,
      onTimeout: () {
        throw APIError(
            'Response processing timed out after ${timeout.inSeconds} seconds');
      },
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return (Uint8List.fromList(response.bodyBytes), response);
    } else {
      throw APIError.errorCode(response.statusCode);
    }
  } on FileError {
    rethrow;
  } on APIError {
    rethrow;
  } catch (e) {
    throw APIError.unknown();
  }
}
