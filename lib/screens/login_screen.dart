import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'admin_dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // Controllers for different login methods
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _registerUsernameController =
      TextEditingController();

  // Animation controllers
  late AnimationController _animationController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // State variables
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _rememberMe = false;
  bool _isLoading = false;
  int _currentTabIndex =
      0; // 0: Email/Password, 1: Username/Password, 2: Register
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _animationController.forward();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );

    _fadeController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _fadeController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    _confirmPasswordController.dispose();
    _registerUsernameController.dispose();
    super.dispose();
  }

  // Email/Password Login
  Future<void> _loginWithEmail() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final success = await _authService.loginWithEmail(
        _emailController.text.trim(),
        _passwordController.text,
        rememberMe: _rememberMe,
      );

      if (success && mounted) {
        _navigateBasedOnUserRole();
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Google Sign-In
  Future<void> _loginWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final success = await _authService.loginWithGoogle();

      if (success && mounted) {
        _navigateBasedOnUserRole();
      } else if (mounted) {
        setState(() {
          _errorMessage = 'تم إلغاء تسجيل الدخول';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Username/Password Login (Legacy)
  Future<void> _loginWithUsername() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final success = await _authService.login(
        _usernameController.text.trim(),
        _passwordController.text,
        rememberMe: _rememberMe,
      );

      if (success && mounted) {
        _navigateBasedOnUserRole();
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Register with Email
  Future<void> _registerWithEmail() async {
    if (!_formKey.currentState!.validate()) return;

    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() {
        _errorMessage = 'كلمات المرور غير متطابقة';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final success = await _authService.registerWithEmail(
        _emailController.text.trim(),
        _passwordController.text,
        _registerUsernameController.text.trim(),
      );

      if (success && mounted) {
        _navigateBasedOnUserRole();
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _navigateBasedOnUserRole() {
    final user = _authService.currentUser;
    if (user != null && user.canManageQuestions()) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const AdminDashboardScreen()),
      );
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.deepPurple.shade50,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.deepPurple.shade400,
              Colors.deepPurple.shade600,
              Colors.deepPurple.shade800,
            ],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const SizedBox(height: 40),

                  // App Logo
                  SlideTransition(
                    position: _slideAnimation,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withOpacity(0.3),
                            spreadRadius: 10,
                            blurRadius: 20,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/images/logo.png',
                          width: 120,
                          height: 120,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Welcome Text
                  const Text(
                    'مرحباً بك',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),

                  const SizedBox(height: 10),

                  const Text(
                    'سجل الدخول للمتابعة',
                    style: TextStyle(fontSize: 16, color: Colors.white70),
                  ),

                  const SizedBox(height: 40),

                  // Login Form Card
                  SlideTransition(
                    position: _slideAnimation,
                    child: Container(
                      padding: const EdgeInsets.all(25),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            spreadRadius: 5,
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            // Tab Bar
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  _buildTabButton('بريد إلكتروني', 0),
                                  _buildTabButton('اسم مستخدم', 1),
                                  _buildTabButton('تسجيل جديد', 2),
                                ],
                              ),
                            ),

                            const SizedBox(height: 25),

                            // Form Fields based on selected tab
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              child: _buildFormContent(),
                            ),

                            if (_errorMessage.isNotEmpty) ...[
                              const SizedBox(height: 15),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.red.shade200,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.error_outline,
                                      color: Colors.red.shade600,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        _errorMessage,
                                        style: TextStyle(
                                          color: Colors.red.shade700,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            const SizedBox(height: 25),

                            // Action Buttons
                            _buildActionButtons(),

                            // Google Sign-In Button (for non-register tabs)
                            if (_currentTabIndex != 2) ...[
                              const SizedBox(height: 20),
                              const Row(
                                children: [
                                  Expanded(child: Divider()),
                                  Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 15,
                                    ),
                                    child: Text(
                                      'أو',
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                  ),
                                  Expanded(child: Divider()),
                                ],
                              ),
                              const SizedBox(height: 20),
                              _buildGoogleSignInButton(),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Guest Continue Button
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'المتابعة كضيف',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabButton(String title, int index) {
    final isSelected = _currentTabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap:
            () => setState(() {
              _currentTabIndex = index;
              _errorMessage = '';
            }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.deepPurple : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey.shade600,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormContent() {
    switch (_currentTabIndex) {
      case 0: // Email/Password Login
        return Column(
          key: const ValueKey('email_login'),
          children: [
            _buildEmailField(),
            const SizedBox(height: 15),
            _buildPasswordField(),
            const SizedBox(height: 15),
            _buildRememberMeCheckbox(),
          ],
        );
      case 1: // Username/Password Login
        return Column(
          key: const ValueKey('username_login'),
          children: [
            _buildUsernameField(),
            const SizedBox(height: 15),
            _buildPasswordField(),
            const SizedBox(height: 15),
            _buildRememberMeCheckbox(),
          ],
        );
      case 2: // Register
        return Column(
          key: const ValueKey('register'),
          children: [
            _buildRegisterUsernameField(),
            const SizedBox(height: 15),
            _buildEmailField(),
            const SizedBox(height: 15),
            _buildPasswordField(),
            const SizedBox(height: 15),
            _buildConfirmPasswordField(),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildEmailField() {
    return TextFormField(
      controller: _emailController,
      decoration: InputDecoration(
        labelText: 'البريد الإلكتروني',
        prefixIcon: const Icon(Icons.email_outlined, color: Colors.deepPurple),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.deepPurple, width: 2),
        ),
      ),
      keyboardType: TextInputType.emailAddress,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'يرجى إدخال البريد الإلكتروني';
        }
        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
          return 'يرجى إدخال بريد إلكتروني صحيح';
        }
        return null;
      },
    );
  }

  Widget _buildUsernameField() {
    return TextFormField(
      controller: _usernameController,
      decoration: InputDecoration(
        labelText: 'اسم المستخدم',
        prefixIcon: const Icon(Icons.person_outline, color: Colors.deepPurple),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.deepPurple, width: 2),
        ),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'يرجى إدخال اسم المستخدم';
        }
        return null;
      },
    );
  }

  Widget _buildRegisterUsernameField() {
    return TextFormField(
      controller: _registerUsernameController,
      decoration: InputDecoration(
        labelText: 'اسم المستخدم',
        prefixIcon: const Icon(Icons.person_outline, color: Colors.deepPurple),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.deepPurple, width: 2),
        ),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'يرجى إدخال اسم المستخدم';
        }
        if (value.trim().length < 3) {
          return 'اسم المستخدم يجب أن يكون 3 أحرف على الأقل';
        }
        return null;
      },
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      obscureText: !_isPasswordVisible,
      decoration: InputDecoration(
        labelText: 'كلمة المرور',
        prefixIcon: const Icon(Icons.lock_outline, color: Colors.deepPurple),
        suffixIcon: IconButton(
          icon: Icon(
            _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
            color: Colors.deepPurple,
          ),
          onPressed:
              () => setState(() => _isPasswordVisible = !_isPasswordVisible),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.deepPurple, width: 2),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'يرجى إدخال كلمة المرور';
        }
        if (_currentTabIndex == 2 && value.length < 6) {
          return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
        }
        return null;
      },
    );
  }

  Widget _buildConfirmPasswordField() {
    return TextFormField(
      controller: _confirmPasswordController,
      obscureText: !_isConfirmPasswordVisible,
      decoration: InputDecoration(
        labelText: 'تأكيد كلمة المرور',
        prefixIcon: const Icon(Icons.lock_outline, color: Colors.deepPurple),
        suffixIcon: IconButton(
          icon: Icon(
            _isConfirmPasswordVisible ? Icons.visibility_off : Icons.visibility,
            color: Colors.deepPurple,
          ),
          onPressed:
              () => setState(
                () => _isConfirmPasswordVisible = !_isConfirmPasswordVisible,
              ),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.deepPurple, width: 2),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'يرجى تأكيد كلمة المرور';
        }
        if (value != _passwordController.text) {
          return 'كلمات المرور غير متطابقة';
        }
        return null;
      },
    );
  }

  Widget _buildRememberMeCheckbox() {
    return Row(
      children: [
        Checkbox(
          value: _rememberMe,
          onChanged: (value) => setState(() => _rememberMe = value ?? false),
          activeColor: Colors.deepPurple,
        ),
        const Text('تذكرني'),
      ],
    );
  }

  Widget _buildActionButtons() {
    String buttonText;
    VoidCallback? onPressed;

    switch (_currentTabIndex) {
      case 0:
        buttonText = 'تسجيل الدخول بالبريد الإلكتروني';
        onPressed = _isLoading ? null : _loginWithEmail;
        break;
      case 1:
        buttonText = 'تسجيل الدخول';
        onPressed = _isLoading ? null : _loginWithUsername;
        break;
      case 2:
        buttonText = 'إنشاء حساب';
        onPressed = _isLoading ? null : _registerWithEmail;
        break;
      default:
        buttonText = 'تسجيل الدخول';
        onPressed = null;
    }

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 3,
        ),
        child:
            _isLoading
                ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
                : Text(
                  buttonText,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
      ),
    );
  }

  Widget _buildGoogleSignInButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _isLoading ? null : _loginWithGoogle,
        icon: Image.asset(
          'assets/images/google_logo.png',
          height: 24,
          errorBuilder:
              (context, error, stackTrace) =>
                  const Icon(Icons.g_mobiledata, color: Colors.red, size: 24),
        ),
        label: const Text('تسجيل الدخول بـ Google'),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.grey.shade700,
          side: BorderSide(color: Colors.grey.shade300, width: 2),
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
