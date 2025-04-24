class OmniAPI {
  String baseUrl = 'http://localhost:8081';
  final Map<String, String> headers;

  OmniAPI({
    this.headers = const {'Content-Type': 'application/json'},
  });

  Uri get voiceCloneEndpoint => Uri.parse('$baseUrl/upload-wav/');
  Uri get signupEndpoint => Uri.parse('$baseUrl/auth/signup');
  Uri get loginEndpoint => Uri.parse('$baseUrl/auth/login');
}

class AuthResponse {
  final String message;
  final String username;
  final String language;
  final String accessToken;
  final bool embeddingsExist;

  AuthResponse({
    required this.message,
    required this.username,
    required this.language,
    required this.accessToken,
    required this.embeddingsExist,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      message: json['message'] ?? '',
      username: json['username'],
      language: json['language'],
      accessToken: json['access_token'],
      embeddingsExist: json['embeddings_exist'] ?? false,
    );
  }
}

class SignupRequest {
  final String username;
  final String password;
  final String email;
  final String name;
  final String language;

  SignupRequest({
    required this.username,
    required this.password,
    required this.email,
    required this.language,
    required this.name,
  });

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'password': password,
      'email': email,
      'name': name,
      'language': language,
    };
  }
}

class LoginRequest {
  final String email;
  final String password;

  LoginRequest({
    required this.email,
    required this.password,
  });

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'password': password,
    };
  }
}

class SignupResponse extends AuthResponse {
  SignupResponse({
    required super.message,
    required super.username,
    required super.language,
    required super.accessToken,
    required super.embeddingsExist,
  });

  factory SignupResponse.fromJson(Map<String, dynamic> json) {
    return SignupResponse(
      message: json['message'] ?? '',
      username: json['username'],
      language: json['language'],
      accessToken: json['access_token'],
      embeddingsExist: json['embeddings_exist'] ?? false,
    );
  }
}

class LoginResponse extends AuthResponse {
  LoginResponse({
    required super.message,
    required super.username,
    required super.language,
    required super.accessToken,
    required super.embeddingsExist,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      message: json['message'] ?? '',
      username: json['username'],
      language: json['language'],
      accessToken: json['access_token'],
      embeddingsExist: json['embeddings_exist'] ?? false,
    );
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
