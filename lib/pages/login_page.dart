import 'package:audio_recorder/models/api_response.dart';
import 'package:audio_recorder/models/language_model.dart';
import 'package:audio_recorder/pages/main_page.dart';
import 'package:audio_recorder/pages/voice_cloning.dart';
import 'package:audio_recorder/services/api_service.dart';
import 'package:audio_recorder/services/storage_service.dart';
import 'package:audio_recorder/utils.dart';
import 'package:flutter/material.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _loginEmailController = TextEditingController();
  final TextEditingController _loginPasswordController =
      TextEditingController();

  final TextEditingController _signupNameController = TextEditingController();
  final TextEditingController _signupEmailController = TextEditingController();
  final TextEditingController _signupPasswordController =
      TextEditingController();
  final TextEditingController _signupConfirmPasswordController =
      TextEditingController();
  final TextEditingController _signupUsernameController =
      TextEditingController();
  final TextEditingController _baseUrlController = TextEditingController();
  String _selectedLanguage =
      Languages.languages.values.first.code; // Default language

  bool _showLoginForm = false;
  bool _showSignupForm = false;
  bool _isLoading = false;

  final ErrorLogger _errorLogger = ErrorLogger();

  @override
  void initState() {
    super.initState();
    _checkStoredCredentials();
    _loadSavedUrl();
  }

  Future<void> _checkStoredCredentials() async {
    final (email, password) = await StorageService.getCredentials();

    if (email != null && password != null) {
      setState(() {
        _loginEmailController.text = email;
        _loginPasswordController.text = password;
        _isLoading = true;
      });

      // Attempt auto-signin
      _executeOption(true);
    }
  }

  Future<void> _loadSavedUrl() async {
    setState(() {
      _baseUrlController.text = OmniAPI.baseUrl;
    });
  }

  void _showApiSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('API Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _baseUrlController,
              decoration: const InputDecoration(
                labelText: 'Base URL',
                hintText: 'Enter API base URL',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Current URL: ${OmniAPI.baseUrl}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              OmniAPI.baseUrl = _baseUrlController.text;
              await StorageService.saveApiUrl(_baseUrlController.text);
              if (mounted) {
                Navigator.pop(context);
                ErrorLogger.showError(
                  context,
                  'API URL updated successfully',
                  duration: const Duration(seconds: 2),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    _signupNameController.dispose();
    _signupEmailController.dispose();
    _signupPasswordController.dispose();
    _signupConfirmPasswordController.dispose();
    _signupUsernameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showApiSettingsDialog,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
          child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            children: [
              if (_showLoginForm || _showSignupForm)
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 300),
                  left: _showLoginForm || _showSignupForm ? 16.0 : -50.0,
                  top: 0,
                  bottom: 0,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, size: 40),
                    onPressed: () {
                      setState(() {
                        _showLoginForm = false;
                        _showSignupForm = false;
                      });
                    },
                  ),
                ),
              Align(
                alignment: Alignment.center,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  opacity: _showLoginForm || _showSignupForm ? 0.5 : 1.0,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!_showLoginForm && !_showSignupForm)
                        PulsingLogo(
                          child: Image.asset(
                            'assets/Logo.png',
                            width: 200,
                            height: 200,
                            fit: BoxFit.contain,
                          ),
                        ),
                      const SizedBox(width: 15),
                      Image.asset(
                        'assets/oo.png',
                        width: 200,
                        height: 50,
                        fit: BoxFit.contain,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _showLoginForm
                ? Column(
                    key: const ValueKey('loginForm'),
                    children: [
                      _buildLoginForm(context),
                      const SizedBox(height: 20),
                      _buildLoginButton(context),
                    ],
                  )
                : _showSignupForm
                    ? Column(
                        key: const ValueKey('signupForm'),
                        children: [
                          _buildSignupForm(context),
                          const SizedBox(height: 20),
                          _buildRegisterButton(context),
                        ],
                      )
                    : Column(
                        key: const ValueKey('buttons'),
                        children: [
                          _buildLoginButton(context),
                          const SizedBox(height: 20),
                          _buildRegisterButton(context),
                        ],
                      ),
          ),
        ],
      )),
    );
  }

  void _toggleForm(isLogin) {
    if (_showLoginForm || _showSignupForm) {
      _executeOption(isLogin);
    }
    setState(() {
      _showLoginForm = isLogin;
      _showSignupForm = !isLogin;
    });
  }

  void _executeOption(bool isLogin) async {
    setState(() {
      _isLoading = true;
    });

    try {
      if (isLogin) {
        final loginRequest = LoginRequest(
          email: _loginEmailController.text,
          password: _loginPasswordController.text,
        );

        final response = await login(request: loginRequest);

        // Store the token and other data securely
        await StorageService.saveToken(
          response.username,
          response.accessToken,
          response.embeddingsExist,
          response.language,
        );

        // Save credentials separately
        await StorageService.saveCredentials(
          _loginEmailController.text,
          _loginPasswordController.text,
        );

        if (mounted) {
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(response.message)),
          );

          if (response.embeddingsExist) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const TranslationApp()),
            );
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (context) => const VoiceCloningScreen()),
            );
          }
        }
      } else {
        final signupRequest = SignupRequest(
          username: _signupUsernameController.text,
          password: _signupPasswordController.text,
          email: _signupEmailController.text,
          name: _signupNameController.text,
          language: _selectedLanguage,
        );

        final response = await signup(request: signupRequest);

        // Store the token and other data securely
        await StorageService.saveToken(
          response.username,
          response.accessToken,
          response.embeddingsExist,
          response.language,
        );

        // Save credentials separately
        await StorageService.saveCredentials(
          _signupEmailController.text,
          _signupPasswordController.text,
        );

        if (mounted) {
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(response.message)),
          );

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => response.embeddingsExist
                  ? const TranslationApp()
                  : const VoiceCloningScreen(),
            ),
          );
        }
      }
    } on APIError catch (e) {
      _errorLogger.logError(e.message,
          severity: ErrorSeverity.high, source: 'Authentication', error: e);

      if (mounted) {
        ErrorLogger.showError(context, 'Authentication error: ${e.message}',
            technicalError: e);
      }
    } catch (e) {
      _errorLogger.logError('Unexpected authentication error',
          severity: ErrorSeverity.critical, source: 'Authentication', error: e);

      if (mounted) {
        ErrorLogger.showError(context,
            'Unexpected error during authentication. Please try again.',
            technicalError: e);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildLoginButton(context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
        ),
        minimumSize: const Size(400, 70),
      ),
      onPressed: _isLoading ? null : () => _toggleForm(true),
      child: _isLoading
          ? CircularProgressIndicator(
              color: Theme.of(context).colorScheme.primary)
          : Text('Login',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              )),
    );
  }

  Widget _buildLoginForm(context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: [
          CustomTextField(
            controller: _loginEmailController,
            labelText: 'Email',
            hintText: 'Enter your email address',
          ),
          const SizedBox(height: 10),
          CustomTextField(
            controller: _loginPasswordController,
            labelText: 'Password',
            hintText: 'Enter your password',
            obscureText: true,
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildRegisterButton(context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
          backgroundColor: Theme.of(context).colorScheme.secondary,
          minimumSize: const Size(400, 70)),
      onPressed: _isLoading ? null : () => _toggleForm(false),
      child: _isLoading
          ? const CircularProgressIndicator(color: Colors.white)
          : const Text('Register',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              )),
    );
  }

  Widget _buildSignupForm(context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: [
          CustomTextField(
            controller: _signupNameController,
            labelText: 'Name',
            hintText: 'Enter your full name',
          ),
          const SizedBox(height: 10),
          CustomTextField(
            controller: _signupUsernameController,
            labelText: 'Username',
            hintText: 'Enter your username',
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade400,
              borderRadius: BorderRadius.circular(12.0),
            ),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: DropdownButtonFormField<String>(
                value: _selectedLanguage,
                dropdownColor: Colors.grey[200],
                style: const TextStyle(color: Colors.black),
                decoration: InputDecoration(
                  labelText: 'Preferred Language',
                  labelStyle: TextStyle(
                    fontSize: 16,
                    color: Colors.black.withAlpha(204),
                  ),
                  border: InputBorder.none,
                ),
                items: Languages.languages.values.map((LanguageModel language) {
                  return DropdownMenuItem<String>(
                    value: language.code,
                    child: Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            gradient: language.flagOrientation ==
                                    FlagOrientation.circle
                                ? RadialGradient(
                                    colors: language.colors,
                                    center: Alignment.center,
                                    radius: 0.8,
                                  )
                                : LinearGradient(
                                    colors: language.colors,
                                    begin: language.flagOrientation ==
                                            FlagOrientation.horizontal
                                        ? Alignment.centerLeft
                                        : Alignment.topCenter,
                                    end: language.flagOrientation ==
                                            FlagOrientation.horizontal
                                        ? Alignment.centerRight
                                        : Alignment.bottomCenter,
                                  ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        Text(
                          language.name,
                          style: const TextStyle(color: Colors.black),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedLanguage = newValue;
                    });
                  }
                },
                icon: Icon(
                  Icons.arrow_drop_down,
                  color: Colors.black.withAlpha(204),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          CustomTextField(
            controller: _signupEmailController,
            labelText: 'Email',
            hintText: 'Enter your email address',
          ),
          const SizedBox(height: 10),
          CustomTextField(
            controller: _signupPasswordController,
            labelText: 'Password',
            hintText: 'Enter your password',
            obscureText: true,
          ),
          const SizedBox(height: 10),
          CustomTextField(
            controller: _signupConfirmPasswordController,
            labelText: 'Confirm Password',
            hintText: 'Re-enter your password',
            obscureText: true,
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class PulsingLogo extends StatefulWidget {
  final Widget child;

  const PulsingLogo({super.key, required this.child});

  @override
  State<PulsingLogo> createState() => _PulsingLogoState();
}

class _PulsingLogoState extends State<PulsingLogo>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _animation,
      child: widget.child,
    );
  }
}

class CustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final String labelText;
  final String hintText;
  final bool obscureText;

  const CustomTextField({
    super.key,
    required this.controller,
    required this.labelText,
    required this.hintText,
    this.obscureText = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade400,
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.black),
          decoration: InputDecoration(
            labelText: labelText,
            labelStyle: TextStyle(
              fontSize: 16,
              color: Colors.black.withAlpha(204),
            ),
            hintText: hintText,
            hintStyle: TextStyle(
              fontSize: 14,
              color: Colors.black.withAlpha(128),
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
          ),
          obscureText: obscureText,
        ),
      ),
    );
  }
}
