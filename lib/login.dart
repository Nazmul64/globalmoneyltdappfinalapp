// ====================================================================
// 🔐 COMPLETE LOGIN SCREEN WITH DATABASE LOGO
// 📁 File: lib/screens/login_screen.dart
// ====================================================================

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/onesignal_notification_service.dart';
import 'home_page.dart';
import 'register.dart';
import 'forgot_password.dart';
import 'config/api_config.dart';

// ==================== LOGO MODEL ====================
class AppLogo {
  final int id;
  final String photoUrl;

  AppLogo({
    required this.id,
    required this.photoUrl,
  });

  factory AppLogo.fromJson(Map<String, dynamic> json) {
    return AppLogo(
      id: json['id'] ?? 0,
      photoUrl: json['photo'] ?? '',
    );
  }
}

// ==================== APP THEME MODEL ====================
class AppTheme {
  final String colorCode;
  final String name;
  final DateTime updatedAt;

  AppTheme({
    required this.colorCode,
    required this.name,
    required this.updatedAt,
  });

  factory AppTheme.fromJson(Map<String, dynamic> json) {
    return AppTheme(
      colorCode: json['color_code'] ?? '#FF6347',
      name: json['name'] ?? 'Default',
      updatedAt: DateTime.parse(
        json['updated_at'] ?? DateTime.now().toString(),
      ),
    );
  }

  Color get primaryColor => _parseColor(colorCode);

  Color _parseColor(String hexColor) {
    try {
      hexColor = hexColor.replaceAll('#', '');
      if (hexColor.length == 6) {
        return Color(int.parse('FF$hexColor', radix: 16));
      }
      return const Color(0xFFFF6347);
    } catch (e) {
      return const Color(0xFFFF6347);
    }
  }

  List<Color> get gradientColors {
    final base = primaryColor;
    return [base, Color.lerp(base, Colors.white, 0.2) ?? base];
  }
}

// ==================== LOGO SERVICE ====================
class LogoService {
  static Future<AppLogo?> fetchLogo(String token) async {
    try {
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('🖼️ FETCHING LOGO FROM DATABASE');
      debugPrint('   Token: ${token.substring(0, 20)}...');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      final response = await http
          .get(
        Uri.parse(ApiConfig.logoSetting),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      )
          .timeout(const Duration(seconds: 10));

      debugPrint('📥 Logo API Status: ${response.statusCode}');
      debugPrint('📥 Logo API Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == true && data['data'] != null) {
          final logo = AppLogo.fromJson(data['data']);
          debugPrint('✅ Logo loaded successfully!');
          debugPrint('   URL: ${logo.photoUrl}');
          debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
          return logo;
        }
      }

      debugPrint('❌ Logo not found in database');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      return null;
    } catch (e) {
      debugPrint('❌ Logo fetch error: $e');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      return null;
    }
  }
}

// ==================== THEME SERVICE ====================
class ThemeService {
  static AppTheme? _cachedTheme;

  static Future<AppTheme> fetchTheme() async {
    try {
      final response = await http
          .get(
        Uri.parse(ApiConfig.themeChange),
        headers: {'Accept': 'application/json'},
      )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == true && data['data'] != null) {
          _cachedTheme = AppTheme.fromJson(data['data']);
          debugPrint('✅ Theme loaded: ${_cachedTheme!.colorCode}');
          return _cachedTheme!;
        }
      }
    } catch (e) {
      debugPrint('❌ Theme fetch error: $e');
    }

    return _cachedTheme ??
        AppTheme(
          colorCode: '#FF6347',
          name: 'Default',
          updatedAt: DateTime.now(),
        );
  }
}

// ==================== LOGIN SCREEN ====================
class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isThemeLoading = true;
  bool _isCheckingLogin = true;

  AppTheme? _appTheme;
  AppLogo? _appLogo;

  Color get primaryColor => _appTheme?.primaryColor ?? const Color(0xFFFF6347);
  List<Color> get gradientColors =>
      _appTheme?.gradientColors ??
          [const Color(0xFFFF6347), const Color(0xFFFF7F5C)];

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  // ====================================================================
  // 🚀 INITIALIZE
  // ====================================================================
  Future<void> _initialize() async {
    await _loadTheme();
    await _checkAutoLogin();
  }

  // ====================================================================
  // 🔍 AUTO-LOGIN CHECK
  // ====================================================================
  Future<void> _checkAutoLogin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      final userId = prefs.getInt('user_id');

      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('🔍 Checking auto-login...');
      debugPrint('   Token exists: ${token != null}');
      debugPrint('   User ID: $userId');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      if (token != null && token.isNotEmpty && userId != null) {
        debugPrint('✅ User already logged in!');

        // Load logo if token exists
        final logo = await LogoService.fetchLogo(token);

        if (mounted) {
          setState(() {
            _appLogo = logo;
          });

          // Navigate to HomePage
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomePage()),
          );
        }
        return;
      }

      debugPrint('❌ No active session. Showing login screen.');
      if (mounted) {
        setState(() => _isCheckingLogin = false);
      }
    } catch (e) {
      debugPrint('❌ Auto-login check error: $e');
      if (mounted) {
        setState(() => _isCheckingLogin = false);
      }
    }
  }

  // ====================================================================
  // 🎨 LOAD THEME
  // ====================================================================
  Future<void> _loadTheme() async {
    try {
      final theme = await ThemeService.fetchTheme();
      if (mounted) {
        setState(() {
          _appTheme = theme;
          _isThemeLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Theme load error: $e');
      if (mounted) setState(() => _isThemeLoading = false);
    }
  }

  // ====================================================================
  // 🎨 BUILD UI
  // ====================================================================
  @override
  Widget build(BuildContext context) {
    if (_isCheckingLogin || _isThemeLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: primaryColor),
              const SizedBox(height: 16),
              const Text(
                'Loading...',
                style: TextStyle(fontSize: 14, color: Colors.black54),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  _buildLogo(),
                  const SizedBox(height: 40),
                  _buildEmailField(),
                  const SizedBox(height: 16),
                  _buildPasswordField(),
                  const SizedBox(height: 10),
                  _buildForgotPassword(),
                  const SizedBox(height: 30),
                  _buildLoginButton(),
                  const SizedBox(height: 20),
                  _buildDivider(),
                  const SizedBox(height: 20),
                  _buildRegisterButton(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ====================================================================
  // 🖼️ LOGO WIDGET
  // ====================================================================
  Widget _buildLogo() {
    // If logo is loaded from database
    if (_appLogo != null && _appLogo!.photoUrl.isNotEmpty) {
      return Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: primaryColor.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipOval(
          child: Image.network(
            _appLogo!.photoUrl,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Center(
                child: CircularProgressIndicator(
                  color: primaryColor,
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                      loadingProgress.expectedTotalBytes!
                      : null,
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              debugPrint('❌ Logo image load error: $error');
              return _buildDefaultLogo();
            },
          ),
        ),
      );
    }

    // Default gradient logo
    return _buildDefaultLogo();
  }

  Widget _buildDefaultLogo() {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: const Icon(
        Icons.person,
        size: 60,
        color: Colors.white,
      ),
    );
  }

  // ====================================================================
  // 📧 EMAIL FIELD
  // ====================================================================
  Widget _buildEmailField() {
    return TextFormField(
      controller: _emailController,
      decoration: _inputDecoration("Enter Email"),
      keyboardType: TextInputType.emailAddress,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter email';
        }
        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
          return 'Please enter valid email';
        }
        return null;
      },
    );
  }

  // ====================================================================
  // 🔐 PASSWORD FIELD
  // ====================================================================
  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      decoration: _inputDecoration("Enter Password").copyWith(
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility_off : Icons.visibility,
            color: Colors.grey.shade600,
          ),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Enter password';
        }
        if (value.length < 6) {
          return 'Password must be at least 6 characters';
        }
        return null;
      },
    );
  }

  // ====================================================================
  // 🔗 FORGOT PASSWORD LINK
  // ====================================================================
  Widget _buildForgotPassword() {
    return Align(
      alignment: Alignment.centerRight,
      child: GestureDetector(
        onTap: _handleForgotPassword,
        child: Text(
          "Forgot password?",
          style: TextStyle(
            color: primaryColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  // ====================================================================
  // 🔘 LOGIN BUTTON
  // ====================================================================
  Widget _buildLoginButton() {
    return Container(
      width: double.infinity,
      height: 55,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradientColors),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleLogin,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            color: Colors.white,
            strokeWidth: 2,
          ),
        )
            : const Text(
          "Login",
          style: TextStyle(
            fontSize: 18,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // ====================================================================
  // ➗ DIVIDER
  // ====================================================================
  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(child: Divider(color: Colors.grey.shade300)),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 10),
          child: Text("or"),
        ),
        Expanded(child: Divider(color: Colors.grey.shade300)),
      ],
    );
  }

  // ====================================================================
  // 🔘 REGISTER BUTTON
  // ====================================================================
  Widget _buildRegisterButton() {
    return Container(
      width: double.infinity,
      height: 55,
      decoration: BoxDecoration(
        border: Border.all(color: primaryColor, width: 2),
        borderRadius: BorderRadius.circular(30),
      ),
      child: ElevatedButton(
        onPressed: _handleSignUp,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        child: Text(
          "Register Now!",
          style: TextStyle(
            fontSize: 18,
            color: primaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // ====================================================================
  // 🎨 INPUT DECORATION
  // ====================================================================
  InputDecoration _inputDecoration(String hint) => InputDecoration(
    hintText: hint,
    fillColor: const Color(0xFFF5F5F7),
    filled: true,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: primaryColor, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Colors.red, width: 2),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Colors.red, width: 2),
    ),
    contentPadding:
    const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
  );

  // ====================================================================
  // 🔐 HANDLE LOGIN
  // ====================================================================
  void _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('🔐 ATTEMPTING LOGIN');
      debugPrint('   Email: ${_emailController.text.trim()}');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      final response = await http
          .post(
        Uri.parse(ApiConfig.login),
        headers: {"Accept": "application/json"},
        body: {
          "email": _emailController.text.trim(),
          "password": _passwordController.text,
        },
      )
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);

      debugPrint('📥 Response Status: ${response.statusCode}');
      debugPrint('📥 Response Data: $data');

      if (response.statusCode == 200 && data["success"] == true) {
        final token = data["data"]["token"];
        final user = data["data"]["user"];
        final userId =
        user["id"] is int ? user["id"] : int.parse(user["id"].toString());
        final userName = user["name"].toString();
        final userEmail = user["email"]?.toString();

        // Save to SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
        await prefs.setInt('user_id', userId);
        await prefs.setString('user_name', userName);
        await prefs.setString('auth_token', token);
        await prefs.setBool('is_logged_in', true);
        if (userEmail != null) {
          await prefs.setString('user_email', userEmail);
        }

        debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        debugPrint('✅ LOGIN SUCCESSFUL');
        debugPrint('   User ID: $userId');
        debugPrint('   Name: $userName');
        debugPrint('   Email: $userEmail');
        debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

        // Set OneSignal External User ID
        if (userEmail != null) {
          await OneSignalNotificationService().setExternalUserId(userEmail);
          debugPrint('✅ OneSignal user ID set');
        }

        // Load logo from database after login
        final logo = await LogoService.fetchLogo(token);

        if (mounted) {
          setState(() {
            _appLogo = logo;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Welcome back, $userName!"),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );

          // Navigate to HomePage
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const HomePage()),
                (route) => false,
          );
        }
      } else {
        debugPrint('❌ Login failed: ${data["message"]}');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(data["message"] ?? "Login failed"),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Login error: $e');

      if (mounted) {
        String errorMessage = "Server error! Try again.";
        if (e.toString().contains('timeout')) {
          errorMessage = "Connection timeout. Check internet.";
        }
        if (e.toString().contains('SocketException')) {
          errorMessage = "No internet connection";
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ====================================================================
  // 🔗 NAVIGATION HANDLERS
  // ====================================================================
  void _handleForgotPassword() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ForgotPasswordScreen()),
    );
  }

  void _handleSignUp() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const RegisterScreen()),
    );
  }

  // ====================================================================
  // 🗑️ DISPOSE
  // ====================================================================
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}

