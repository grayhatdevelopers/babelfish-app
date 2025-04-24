import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:audio_recorder/models/api_response.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:http_parser/http_parser.dart';
import 'dart:convert';

Future<(Uint8List, http.Response)> postVoiceClone({
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

    final request = http.MultipartRequest('POST', OmniAPI.voiceCloneEndpoint)
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

Future<SignupResponse> signup({
  required SignupRequest request,
  Duration timeout = const Duration(seconds: 10),
}) async {
  try {
    final Uri signupEndpoint = OmniAPI.signupEndpoint;
    final response = await http
        .post(
          signupEndpoint,
          headers: {
            'Content-Type': 'application/json',
          },
          body: jsonEncode(request.toJson()),
        )
        .timeout(timeout);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return SignupResponse.fromJson(jsonDecode(response.body));
    } else {
      final errorBody = jsonDecode(response.body);
      throw APIError(
          errorBody['detail'] ?? 'Signup failed', response.statusCode);
    }
  } on TimeoutException {
    throw APIError('Request timed out after ${timeout.inSeconds} seconds');
  } catch (e) {
    if (e is APIError) rethrow;
    throw APIError(e.toString());
  }
}

Future<LoginResponse> login({
  required LoginRequest request,
  Duration timeout = const Duration(seconds: 10),
}) async {
  try {
    final Uri loginEndpoint = OmniAPI.loginEndpoint;
    final response = await http
        .post(
          loginEndpoint,
          headers: {
            'Content-Type': 'application/json',
          },
          body: jsonEncode(request.toJson()),
        )
        .timeout(timeout);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return LoginResponse.fromJson(jsonDecode(response.body));
    } else {
      final errorBody = jsonDecode(response.body);
      throw APIError(
          errorBody['detail'] ?? 'Login failed', response.statusCode);
    }
  } on TimeoutException {
    throw APIError('Request timed out after ${timeout.inSeconds} seconds');
  } catch (e) {
    if (e is APIError) rethrow;
    throw APIError(e.toString());
  }
}
