import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'config/api_config.dart';

// ==================== API Configuration ====================
class ApiEndpoints {
  static String get baseUrl => ApiConfig.mediaBaseUrl;

  static const String loginEndpoint = '/api/login';
  static const String profileEndpoint = '/api/profile';
  static const String updateProfileEndpoint = '/api/profileupdate';
  static const String themeEndpoint = '/api/themechange';

  static String get loginUrl => '$baseUrl$loginEndpoint';
  static String get profileUrl => '$baseUrl$profileEndpoint';
  static String get updateProfileUrl => '$baseUrl$updateProfileEndpoint';
  static String get themeUrl => '$baseUrl$themeEndpoint';
}

// ==================== Token Manager ====================
class TokenManager {
  static const String _tokenKey = 'auth_token';
  static const String _tokenTypeKey = 'token_type';

  static Future<void> saveToken(
    String token, {
    String tokenType = 'Bearer',
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_tokenTypeKey, tokenType);
    debugPrint('✅ Token saved');
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<String> getTokenType() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenTypeKey) ?? 'Bearer';
  }

  static Future<String?> getAuthHeader() async {
    final token = await getToken();
    if (token == null) return null;

    final tokenType = await getTokenType();
    return '$tokenType $token';
  }

  static Future<bool> hasToken() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_tokenTypeKey);
    debugPrint('🗑️ Token cleared');
  }
}

// ==================== Data Models ====================
class User {
  final String name;
  final String email;
  final String? profilePhoto;

  User({required this.name, required this.email, this.profilePhoto});

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      profilePhoto: json['photo'],
    );
  }

  User copyWith({String? name, String? email, String? profilePhoto}) {
    return User(
      name: name ?? this.name,
      email: email ?? this.email,
      profilePhoto: profilePhoto ?? this.profilePhoto,
    );
  }
}

// ==================== Theme Configuration ====================
class ThemeConfig {
  final Color primaryColor;
  final Color accentColor;
  final Color backgroundColor;
  final Color cardColor;

  ThemeConfig({
    required this.primaryColor,
    required this.accentColor,
    required this.backgroundColor,
    required this.cardColor,
  });

  factory ThemeConfig.fromColorCode(String colorCode) {
    final primaryColor = _parseColor(colorCode);
    return ThemeConfig(
      primaryColor: primaryColor,
      accentColor: _adjustBrightness(primaryColor, 0.2),
      backgroundColor: const Color(0xFFF5F5F5),
      cardColor: Colors.white,
    );
  }

  factory ThemeConfig.defaultTheme() {
    return ThemeConfig(
      primaryColor: const Color(0xFF5B7FFF),
      accentColor: const Color(0xFF7D9AFF),
      backgroundColor: const Color(0xFFF5F5F5),
      cardColor: Colors.white,
    );
  }

  static Color _parseColor(String hexCode) {
    try {
      String hex = hexCode.trim().replaceAll('#', '');
      if (hex.length == 3) {
        hex = hex.split('').map((c) => c + c).join();
      }
      if (hex.length == 6) {
        hex = 'FF$hex';
      }
      return Color(int.parse(hex, radix: 16));
    } catch (e) {
      return const Color(0xFF5B7FFF);
    }
  }

  static Color _adjustBrightness(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    final lightness = (hsl.lightness + amount).clamp(0.0, 1.0);
    return hsl.withLightness(lightness).toColor();
  }

  LinearGradient get primaryGradient {
    return LinearGradient(
      colors: [primaryColor, accentColor],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  BoxShadow get cardShadow {
    return BoxShadow(
      color: primaryColor.withOpacity(0.25),
      blurRadius: 15,
      offset: const Offset(0, 5),
    );
  }
}

// ==================== API Service ====================
class ProfileService {
  static Future<Map<String, String>> _getHeaders() async {
    final headers = {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };

    final authHeader = await TokenManager.getAuthHeader();
    if (authHeader != null) {
      headers['Authorization'] = authHeader;
      debugPrint('🔐 Using auth header: ${authHeader.substring(0, 20)}...');
    } else {
      debugPrint('⚠️ No auth token found');
    }

    return headers;
  }

  static Future<ThemeConfig> getTheme() async {
    try {
      final headers = await _getHeaders();

      debugPrint('🎨 Fetching theme from: ${ApiEndpoints.themeUrl}');

      final response = await http
          .get(Uri.parse(ApiEndpoints.themeUrl), headers: headers)
          .timeout(const Duration(seconds: 10));

      debugPrint('📥 Theme Response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);

        if (jsonData['status'] == true &&
            jsonData['data']?['color_code'] != null) {
          final colorCode = jsonData['data']['color_code'].toString();
          debugPrint('✅ Theme loaded: $colorCode');
          return ThemeConfig.fromColorCode(colorCode);
        }
      }

      return ThemeConfig.defaultTheme();
    } catch (error) {
      debugPrint('❌ Theme error: $error');
      return ThemeConfig.defaultTheme();
    }
  }

  static Future<User> getUserProfile() async {
    try {
      final headers = await _getHeaders();

      debugPrint('👤 Fetching profile from: ${ApiEndpoints.profileUrl}');

      final response = await http
          .get(Uri.parse(ApiEndpoints.profileUrl), headers: headers)
          .timeout(const Duration(seconds: 10));

      debugPrint('📥 Profile Response Status: ${response.statusCode}');
      debugPrint('📄 Profile Response Body: ${response.body}');

      if (response.statusCode == 401) {
        throw Exception('Session expired. Please login again.');
      }

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);

        debugPrint('🔍 JSON Keys: ${jsonData.keys.toList()}');
        debugPrint('🔍 Success Key: ${jsonData['success']}');
        debugPrint('🔍 Status Key: ${jsonData['status']}');

        final isSuccess =
            jsonData['success'] == true || jsonData['status'] == true;

        if (isSuccess && jsonData['data'] != null) {
          debugPrint('✅ Profile data found');
          debugPrint('📝 Name: ${jsonData['data']['name']}');
          debugPrint('📧 Email: ${jsonData['data']['email']}');
          debugPrint('📸 Photo: ${jsonData['data']['photo']}');

          return User.fromJson(jsonData['data']);
        }

        throw Exception('Invalid response format');
      }

      throw Exception('Failed to load profile: ${response.statusCode}');
    } catch (error) {
      debugPrint('❌ Profile error: $error');
      rethrow;
    }
  }

  /// Update user profile with partial update support
  /// Only sends fields that have actually changed
  static Future<User> updateUserProfile({
    String? name,
    String? email,
    File? photoFile,
  }) async {
    try {
      debugPrint('🔄 Updating profile at: ${ApiEndpoints.updateProfileUrl}');

      final request = http.MultipartRequest(
        'POST',
        Uri.parse(ApiEndpoints.updateProfileUrl),
      );

      final authHeader = await TokenManager.getAuthHeader();
      if (authHeader != null) {
        request.headers['Authorization'] = authHeader;
        debugPrint('🔐 Auth header added');
      }

      request.headers['Accept'] = 'application/json';

      // Only send name if it's provided and not empty
      if (name != null && name.trim().isNotEmpty) {
        request.fields['name'] = name.trim();
        debugPrint('📝 Sending Name: $name');
      }

      // Only send email if it's provided and not empty
      if (email != null && email.trim().isNotEmpty) {
        request.fields['email'] = email.trim();
        debugPrint('📧 Sending Email: $email');
      }

      // Only send photo if a file is selected
      if (photoFile != null) {
        final fileSize = await photoFile.length();
        debugPrint(
          '📸 Attaching photo: ${(fileSize / 1024).toStringAsFixed(0)} KB',
        );

        request.files.add(
          await http.MultipartFile.fromPath('photo', photoFile.path),
        );
      }

      debugPrint('📤 Request fields: ${request.fields}');
      debugPrint('📤 Request files: ${request.files.length}');

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
      );

      final response = await http.Response.fromStream(streamedResponse);
      debugPrint('📥 Update Response Status: ${response.statusCode}');
      debugPrint('📄 Update Response Body: ${response.body}');

      if (response.statusCode == 401) {
        throw Exception('Session expired. Please login again.');
      }

      final jsonData = jsonDecode(response.body);

      final isSuccess =
          jsonData['success'] == true || jsonData['status'] == true;

      if (response.statusCode == 200 && isSuccess) {
        debugPrint('✅ Profile updated successfully');
        return User.fromJson(jsonData['data']);
      }

      final errorMessage = _extractErrorMessage(jsonData);
      throw Exception(errorMessage);
    } catch (error) {
      debugPrint('❌ Update error: $error');
      rethrow;
    }
  }

  static String _extractErrorMessage(Map<String, dynamic> jsonData) {
    if (jsonData['data'] is Map) {
      final errors = jsonData['data'] as Map;
      if (errors.isNotEmpty) {
        final firstError = errors.values.first;
        if (firstError is List && firstError.isNotEmpty) {
          return firstError.first.toString();
        }
        return firstError.toString();
      }
    }
    return jsonData['message']?.toString() ?? 'Update failed';
  }
}

// ==================== Profile Update Page ====================
class UpdateProfilePage extends StatefulWidget {
  const UpdateProfilePage({super.key});

  @override
  State<UpdateProfilePage> createState() => _UpdateProfilePageState();
}

class _UpdateProfilePageState extends State<UpdateProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _imagePicker = ImagePicker();

  ThemeConfig? _theme;
  User? _currentUser;
  File? _selectedPhoto;

  bool _isLoading = true;
  bool _isSaving = false;
  bool _hasAuthToken = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _checkAuthAndLoad();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _checkAuthAndLoad() async {
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('🚀 Checking authentication...');

    _hasAuthToken = await TokenManager.hasToken();

    if (!_hasAuthToken) {
      debugPrint('❌ No authentication token found');

      if (!mounted) return;

      setState(() {
        _theme = ThemeConfig.defaultTheme();
        _isLoading = false;
      });

      _showAuthRequiredDialog();
      return;
    }

    debugPrint('✅ Token found, loading data...');
    await _loadInitialData();
  }

  void _showAuthRequiredDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Authentication Required'),
        content: const Text(
          'You need to login first to update your profile. '
          'Please login and try again.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadInitialData() async {
    try {
      debugPrint('📡 Loading profile and theme...');

      final results = await Future.wait([
        ProfileService.getTheme(),
        ProfileService.getUserProfile(),
      ]);

      if (!mounted) return;

      final theme = results[0] as ThemeConfig;
      final user = results[1] as User;

      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('✅ User loaded successfully:');
      debugPrint('   Name: ${user.name}');
      debugPrint('   Email: ${user.email}');
      debugPrint('   Photo URL: ${user.profilePhoto}');
      debugPrint('   Photo is null: ${user.profilePhoto == null}');
      debugPrint('   Photo is empty: ${user.profilePhoto?.isEmpty ?? true}');
      if (user.profilePhoto != null) {
        debugPrint('   Photo length: ${user.profilePhoto!.length}');
        debugPrint(
          '   Starts with http: ${user.profilePhoto!.startsWith('http')}',
        );
      }
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      setState(() {
        _theme = theme;
        _currentUser = user;
        _nameController.text = user.name;
        _emailController.text = user.email;
        _isLoading = false;
        _loadError = null;
      });

      debugPrint('✅ Data loaded successfully');
    } catch (error) {
      debugPrint('❌ Load error: $error');

      if (!mounted) return;

      setState(() {
        _theme = ThemeConfig.defaultTheme();
        _isLoading = false;
        _loadError = error.toString();
      });

      if (error.toString().contains('Session expired')) {
        _showSessionExpiredDialog();
      } else {
        _showMessage('Failed to load profile data', isError: true);
      }
    }
  }

  void _showSessionExpiredDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Session Expired'),
        content: const Text(
          'Your session has expired. Please login again to continue.',
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await TokenManager.clearToken();
              if (!mounted) return;
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    // Check what has changed
    final nameChanged = _nameController.text.trim() != _currentUser?.name;
    final emailChanged = _emailController.text.trim() != _currentUser?.email;
    final photoChanged = _selectedPhoto != null;

    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('📝 Checking changes:');
    debugPrint('   Name changed: $nameChanged');
    debugPrint('   Email changed: $emailChanged');
    debugPrint('   Photo changed: $photoChanged');

    if (!nameChanged && !emailChanged && !photoChanged) {
      debugPrint('⚠️ No changes detected');
      _showMessage('No changes to update', isError: false);
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Only send changed fields
      final updatedUser = await ProfileService.updateUserProfile(
        name: nameChanged ? _nameController.text.trim() : null,
        email: emailChanged ? _emailController.text.trim() : null,
        photoFile: _selectedPhoto,
      );

      if (!mounted) return;

      setState(() {
        _currentUser = updatedUser;
        _nameController.text = updatedUser.name;
        _emailController.text = updatedUser.email;
        _selectedPhoto = null;
        _isSaving = false;
      });

      debugPrint('✅ Profile updated successfully');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      _showMessage('Profile updated successfully!', isError: false);
    } catch (error) {
      debugPrint('❌ Update failed: $error');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      if (!mounted) return;

      setState(() => _isSaving = false);

      if (error.toString().contains('Session expired')) {
        _showSessionExpiredDialog();
      } else {
        final errorMessage = error.toString().replaceAll('Exception: ', '');
        _showMessage(errorMessage, isError: true);
      }
    }
  }

  Future<void> _selectPhoto(ImageSource source) async {
    try {
      final pickedImage = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1200,
        maxHeight: 1200,
      );

      if (pickedImage == null) return;

      final imageFile = File(pickedImage.path);
      final fileSizeInBytes = await imageFile.length();
      final fileSizeInMB = fileSizeInBytes / (1024 * 1024);

      if (fileSizeInMB > 5) {
        _showMessage('Image size must be less than 5MB', isError: true);
        return;
      }

      setState(() => _selectedPhoto = imageFile);
      debugPrint('✅ Photo selected: ${(fileSizeInMB).toStringAsFixed(2)} MB');
    } catch (error) {
      debugPrint('❌ Photo selection error: $error');
      _showMessage('Failed to select image', isError: true);
    }
  }

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Select Photo',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 20),
              _buildPhotoOption(
                icon: Icons.camera_alt_rounded,
                title: 'Take Photo',
                onTap: () {
                  Navigator.pop(context);
                  _selectPhoto(ImageSource.camera);
                },
              ),
              _buildPhotoOption(
                icon: Icons.photo_library_rounded,
                title: 'Choose from Gallery',
                onTap: () {
                  Navigator.pop(context);
                  _selectPhoto(ImageSource.gallery);
                },
              ),
              if (_selectedPhoto != null || _currentUser?.profilePhoto != null)
                _buildPhotoOption(
                  icon: Icons.delete_outline_rounded,
                  title: 'Remove Photo',
                  color: Colors.red,
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _selectedPhoto = null);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? color,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (color ?? _theme?.primaryColor ?? Colors.blue).withOpacity(
            0.1,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color ?? _theme?.primaryColor ?? Colors.blue),
      ),
      title: Text(
        title,
        style: TextStyle(fontWeight: FontWeight.w500, color: color),
      ),
      onTap: onTap,
    );
  }

  void _showMessage(String message, {required bool isError}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? Colors.red.shade600
            : _theme?.primaryColor ?? Colors.blue,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingView();
    }

    if (!_hasAuthToken) {
      return _buildNoAuthView();
    }

    if (_loadError != null) {
      return _buildErrorView();
    }

    return Scaffold(
      backgroundColor: _theme!.backgroundColor,
      appBar: _buildAppBar(),
      body: _buildBodyContent(),
    );
  }

  Widget _buildLoadingView() {
    return Scaffold(
      backgroundColor: _theme?.backgroundColor ?? Colors.grey.shade50,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: _theme?.primaryColor ?? Colors.blue,
              strokeWidth: 3,
            ),
            const SizedBox(height: 20),
            const Text(
              'Loading profile...',
              style: TextStyle(fontSize: 16, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoAuthView() {
    return Scaffold(
      backgroundColor: _theme?.backgroundColor ?? Colors.grey.shade50,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock_outline_rounded,
                size: 80,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 24),
              const Text(
                'Authentication Required',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Text(
                'Please login to update your profile',
                style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _theme?.primaryColor ?? Colors.blue,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
                child: const Text(
                  'Go Back',
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Scaffold(
      backgroundColor: _theme?.backgroundColor ?? Colors.grey.shade50,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 80,
                color: Colors.red.shade400,
              ),
              const SizedBox(height: 24),
              const Text(
                'Failed to Load Profile',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Text(
                _loadError ?? 'Unknown error occurred',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _loadError = null;
                  });
                  _loadInitialData();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _theme?.primaryColor ?? Colors.blue,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
                child: const Text(
                  'Retry',
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text(
        'Update Profile',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 18,
        ),
      ),
      centerTitle: true,
      elevation: 0,
      iconTheme: const IconThemeData(color: Colors.white),
      flexibleSpace: Container(
        decoration: BoxDecoration(gradient: _theme!.primaryGradient),
      ),
    );
  }

  Widget _buildBodyContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            _buildProfilePhotoSection(),
            const SizedBox(height: 10),
            Text(
              'Tap to change photo',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 40),
            _buildInputField(
              controller: _nameController,
              label: 'Full Name',
              hint: 'Enter your full name',
              icon: Icons.person_outline_rounded,
              validator: (value) {
                if (value != null && value.trim().isNotEmpty) {
                  if (value.trim().length < 2) {
                    return 'Name must be at least 2 characters';
                  }
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            _buildInputField(
              controller: _emailController,
              label: 'Email Address',
              hint: 'Enter your email address',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value != null && value.trim().isNotEmpty) {
                  final emailRegex = RegExp(
                    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
                  );
                  if (!emailRegex.hasMatch(value.trim())) {
                    return 'Enter a valid email address';
                  }
                }
                return null;
              },
            ),
            const SizedBox(height: 40),
            _buildSaveButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildProfilePhotoSection() {
    ImageProvider? imageProvider;
    String? photoUrl;
    bool hasImage = false;

    // Check if new photo is selected
    if (_selectedPhoto != null) {
      imageProvider = FileImage(_selectedPhoto!);
      hasImage = true;
      debugPrint('🖼️ Displaying: Selected file photo');
    }
    // Check if user has a profile photo from API
    else if (_currentUser?.profilePhoto != null &&
        _currentUser!.profilePhoto!.trim().isNotEmpty) {
      photoUrl = _currentUser!.profilePhoto!.trim();

      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('🖼️ Attempting to load network photo:');
      debugPrint('   Raw URL: $photoUrl');

      // Ensure we have the full URL
      if (!photoUrl.startsWith('http://') && !photoUrl.startsWith('https://')) {
        // Remove leading slash if present
        if (photoUrl.startsWith('/')) {
          photoUrl = photoUrl.substring(1);
        }
        photoUrl = '${ApiEndpoints.baseUrl}/$photoUrl';
      }

      debugPrint('   Final URL: $photoUrl');
      debugPrint('   Base URL: ${ApiEndpoints.baseUrl}');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      imageProvider = NetworkImage(photoUrl);
      hasImage = true;
    } else {
      debugPrint('🖼️ No photo available - showing placeholder');
    }

    return GestureDetector(
      onTap: _showPhotoOptions,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: _theme!.primaryGradient,
              boxShadow: [_theme!.cardShadow],
            ),
            padding: const EdgeInsets.all(4),
            child: Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
              child: ClipOval(
                child: hasImage
                    ? Image(
                        image: imageProvider!,
                        fit: BoxFit.cover,
                        width: 132,
                        height: 132,
                        errorBuilder: (context, error, stackTrace) {
                          debugPrint('❌ Image Error: $error');
                          debugPrint('   Failed URL: $photoUrl');
                          return Icon(
                            Icons.person_rounded,
                            size: 70,
                            color: Colors.grey.shade400,
                          );
                        },
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) {
                            debugPrint('✅ Image loaded successfully');
                            return child;
                          }
                          return Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                  : null,
                              strokeWidth: 2,
                              color: _theme!.primaryColor,
                            ),
                          );
                        },
                      )
                    : Icon(
                        Icons.person_rounded,
                        size: 70,
                        color: Colors.grey.shade400,
                      ),
              ),
            ),
          ),
          Positioned(
            bottom: 5,
            right: 5,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: _theme!.primaryGradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _theme!.primaryColor.withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(
                Icons.camera_alt_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required String? Function(String?) validator,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: _theme!.cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _theme!.primaryColor.withOpacity(0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            validator: validator,
            style: const TextStyle(fontSize: 16, color: Colors.black87),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey.shade400),
              prefixIcon: Icon(icon, color: _theme!.primaryColor, size: 22),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 18,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: _theme!.primaryGradient,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [_theme!.cardShadow],
      ),
      child: ElevatedButton(
        onPressed: _isSaving ? null : _saveProfile,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: _isSaving
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : const Text(
                'Update Profile',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
      ),
    );
  }
}
