import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'home_page.dart';
import 'config/api_config.dart';
import 'services/app_service.dart';

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

    // Return cached or default theme
    return _cachedTheme ??
        AppTheme(
          colorCode: '#FF6347',
          name: 'Default',
          updatedAt: DateTime.now(),
        );
  }
}

// ==================== REGISTER SCREEN ====================
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _referralCodeController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  // ✅ Theme Colors
  AppTheme? _appTheme;
  Color get primaryColor =>
      _appTheme?.primaryColor ?? AppService().themeColorSync;
  List<Color> get gradientColors {
    final base = primaryColor;
    return [base, Color.lerp(base, Colors.white, 0.2) ?? base];
  }

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  // ✅ Load Theme from Backend asynchronously in background
  Future<void> _loadTheme() async {
    try {
      final theme = await ThemeService.fetchTheme();
      if (mounted) {
        setState(() {
          _appTheme = theme;
        });
      }
    } catch (e) {
      debugPrint('❌ Theme load error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: primaryColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                _avatarWidget(),
                const SizedBox(height: 32),
                _textField(
                  _nameController,
                  'Enter your name',
                  false,
                  validator: (value) {
                    if (value == null || value.isEmpty)
                      return 'Please enter your name';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _textField(
                  _emailController,
                  'Email',
                  false,
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty)
                      return 'Please enter your email';
                    if (!RegExp(
                      r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                    ).hasMatch(value))
                      return 'Please enter a valid email';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _textField(
                  _mobileController,
                  'Mobile',
                  false,
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.isEmpty)
                      return 'Please enter your mobile number';
                    if (value.length < 10)
                      return 'Please enter a valid mobile number';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _textField(
                  _passwordController,
                  'Enter password',
                  true,
                  obscureToggle: () {
                    setState(() => _obscurePassword = !_obscurePassword);
                  },
                  obscureText: _obscurePassword,
                  validator: (value) {
                    if (value == null || value.isEmpty)
                      return 'Please enter a password';
                    if (value.length < 6)
                      return 'Password must be at least 6 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _textField(
                  _confirmPasswordController,
                  'Confirm password',
                  true,
                  obscureToggle: () {
                    setState(
                      () => _obscureConfirmPassword = !_obscureConfirmPassword,
                    );
                  },
                  obscureText: _obscureConfirmPassword,
                  validator: (value) {
                    if (value == null || value.isEmpty)
                      return 'Please confirm your password';
                    if (value != _passwordController.text)
                      return 'Passwords do not match';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _textField(
                  _referralCodeController,
                  'Referral Code (Optional)',
                  false,
                ),
                const SizedBox(height: 32),
                _signUpButton(),
                const SizedBox(height: 24),
                _loginRedirect(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==================== AVATAR WIDGET ====================
  Widget _avatarWidget() {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        shape: BoxShape.circle,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.person, size: 60, color: Colors.grey.shade400),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: gradientColors),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.camera_alt,
                size: 20,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== TEXT FIELD ====================
  Widget _textField(
    TextEditingController controller,
    String hint,
    bool isPassword, {
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    VoidCallback? obscureToggle,
    bool obscureText = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 15),
        filled: true,
        fillColor: const Color(0xFFF5F5F7),
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
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
        suffixIcon: isPassword && obscureToggle != null
            ? IconButton(
                icon: Icon(
                  obscureText ? Icons.visibility_off : Icons.visibility,
                  color: Colors.grey.shade500,
                ),
                onPressed: obscureToggle,
              )
            : null,
      ),
      validator: validator,
    );
  }

  // ==================== SIGN UP BUTTON ====================
  Widget _signUpButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradientColors),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _registerApiCall,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Text(
                'Sign Up',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }

  // ==================== LOGIN REDIRECT ====================
  Widget _loginRedirect() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Already have an account? ',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
        ),
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Text(
            'Sign In',
            style: TextStyle(
              color: primaryColor,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  // ==================== API CALL ====================
  void _registerApiCall() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final body = <String, String>{
        "name": _nameController.text.trim(),
        "email": _emailController.text.trim(),
        "mobile": _mobileController.text.trim(),
        "password": _passwordController.text,
        "password_confirmation": _confirmPasswordController.text,
      };

      if (_referralCodeController.text.trim().isNotEmpty) {
        body["ref_code"] = _referralCodeController.text.trim();
      }

      var response = await http
          .post(
            Uri.parse(ApiConfig.register),
            headers: {
              "Accept": "application/json",
              "Content-Type": "application/json",
            },
            body: jsonEncode(body),
          )
          .timeout(
            const Duration(seconds: 45),
            onTimeout: () {
              throw Exception('Request timeout. Please check your internet connection or try again.');
            },
          );

      var data = jsonDecode(response.body);

      if (mounted) {
        if (response.statusCode == 200 && data["success"] == true) {
          final token = data["data"]?["token"] ?? data["token"];
          final user = data["data"]?["user"] ?? data["user"];

          // ✅ Save token & complete user profile to SharedPreferences
          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.clear();
          await prefs.setString("token", token);
          await prefs.setString("auth_token", token);
          await prefs.setBool('is_logged_in', true);

          if (user != null) {
            if (user["id"] != null) {
              final userId = user["id"] is int ? user["id"] : int.parse(user["id"].toString());
              await prefs.setInt('user_id', userId);
            }
            if (user["name"] != null) {
              await prefs.setString('user_name', user["name"].toString());
            }
            if (user["email"] != null) {
              await prefs.setString('user_email', user["email"].toString());
            }
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(data["message"] ?? "Registration successful!"),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );

          // ✅ Redirect to HomePage after successful registration
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const HomePage()),
            (route) => false, // Remove all previous routes
          );
        } else {
          // Extract specific field errors if available
          String errorMessage = data["message"] ?? "Registration failed";
          final errorsObj = data["errors"] ?? data["data"];
          if (errorsObj is Map) {
            final messagesList = <String>[];
            errorsObj.forEach((key, val) {
              if (val is List && val.isNotEmpty) {
                messagesList.add(val.first.toString());
              } else if (val is String && val.isNotEmpty) {
                messagesList.add(val);
              }
            });
            if (messagesList.isNotEmpty) {
              errorMessage = messagesList.join('\n');
            }
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
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Server error: ${e.toString()}"),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
      debugPrint('❌ Registration error: $e');
    }

    if (mounted) setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _referralCodeController.dispose();
    super.dispose();
  }
}
