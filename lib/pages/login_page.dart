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

  bool _showLoginForm = false;
  bool _showSignupForm = false;

  @override
  void dispose() {
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    _signupNameController.dispose();
    _signupEmailController.dispose();
    _signupPasswordController.dispose();
    _signupConfirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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

  void _executeOption(bool isLogin) {
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    bool isValidEmail(String email) {
      final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
      return emailRegex.hasMatch(email);
    }

    if (isLogin) {
      if (_loginEmailController.text.isEmpty ||
          _loginPasswordController.text.isEmpty) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Please fill in all login fields')),
        );
        return;
      }
      if (!isValidEmail(_loginEmailController.text)) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Please enter a valid email address')),
        );
        return;
      }
      print('Login');
    } else {
      if (_signupNameController.text.isEmpty ||
          _signupEmailController.text.isEmpty ||
          _signupPasswordController.text.isEmpty ||
          _signupConfirmPasswordController.text.isEmpty) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Please fill in all signup fields')),
        );
        return;
      }
      if (!isValidEmail(_signupEmailController.text)) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Please enter a valid email address')),
        );
        return;
      }
      if (_signupPasswordController.text !=
          _signupConfirmPasswordController.text) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Passwords do not match')),
        );
        return;
      }
      print('Register');
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
      onPressed: () {
        _toggleForm(true);
      },
      child: Text('Login',
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
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(12.0),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: TextField(
                controller: _loginEmailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  labelStyle: TextStyle(fontSize: 16),
                  hintText: 'Enter your email address',
                  hintStyle: TextStyle(fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16.0),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(12.0),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: TextField(
                controller: _loginPasswordController,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  labelStyle: TextStyle(fontSize: 16),
                  hintText: 'Enter your password',
                  hintStyle: TextStyle(fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16.0),
                ),
                obscureText: true,
              ),
            ),
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
      onPressed: () {
        _toggleForm(false);
      },
      child: const Text('Register',
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
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(12.0),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: TextField(
                controller: _signupNameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  labelStyle: TextStyle(fontSize: 16),
                  hintText: 'Enter your full name',
                  hintStyle: TextStyle(fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16.0),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(12.0),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: TextField(
                controller: _signupEmailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  labelStyle: TextStyle(fontSize: 16),
                  hintText: 'Enter your email address',
                  hintStyle: TextStyle(fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16.0),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(12.0),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: TextField(
                controller: _signupPasswordController,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  labelStyle: TextStyle(fontSize: 16),
                  hintText: 'Enter your password',
                  hintStyle: TextStyle(fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16.0),
                ),
                obscureText: true,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(12.0),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: TextField(
                controller: _signupConfirmPasswordController,
                decoration: const InputDecoration(
                  labelText: 'Confirm Password',
                  labelStyle: TextStyle(fontSize: 16),
                  hintText: 'Re-enter your password',
                  hintStyle: TextStyle(fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16.0),
                ),
                obscureText: true,
              ),
            ),
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
