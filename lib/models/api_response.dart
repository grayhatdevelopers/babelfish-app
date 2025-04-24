class SignupResponse {
  final String message;

  SignupResponse({required this.message});

  factory SignupResponse.fromJson(Map<String, dynamic> json) {
    return SignupResponse(message: json['message']);
  }
}

class SignupRequest {
  final String username;
  final String password;
  final String email;
  final String language;

  SignupRequest({
    required this.username,
    required this.password,
    required this.email,
    required this.language,
  });

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'password': password,
      'email': email,
      'language': language,
    };
  }
}

class LoginRequest {
  final String username;
  final String password;

  LoginRequest({
    required this.username,
    required this.password,
  });

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'password': password,
    };
  }
}

class LoginResponse {
  final String accessToken;

  LoginResponse({required this.accessToken});

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(accessToken: json['access_token']);
  }
}

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
  String baseUrl =
      'http://ec2-13-50-56-128.eu-north-1.compute.amazonaws.com:8000';
  final Map<String, String> headers;

  OmniAPI({
    this.headers = const {'Content-Type': 'application/json'},
  });

  Uri get voiceCloneEndpoint => Uri.parse('$baseUrl/upload-wav/');
  Uri get signupEndpoint => Uri.parse('$baseUrl/auth/signup');
  Uri get loginEndpoint => Uri.parse('$baseUrl/auth/login');
}
