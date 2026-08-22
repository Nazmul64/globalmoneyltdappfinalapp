// ==========================================
// 🔥 Live Chat Application - PART 1/5
// Theme Manager + API Service + Models
// ==========================================

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'config/api_config.dart';
import 'screens/support_live_chat_screen.dart';

String get baseUrl => ApiConfig.baseUrl;

String get _baseUrl => ApiConfig.baseUrl;

// ==================== THEME MANAGER ====================
/// 🎨 Database থেকে Theme Color Manage করার জন্য
class ThemeManager {
  // URL: use ApiConfig.baseUrl

  // Default fallback colors
  static Color defaultColorStart = const Color(0xFFFF6F61);
  static Color defaultColorEnd = const Color(0xFFFF8A5C);

  // Current theme colors
  static Color themeColorStart = defaultColorStart;
  static Color themeColorEnd = defaultColorEnd;
  static String themeName = 'Default Theme';
  static bool isThemeLoaded = false;

  /// 🎨 Database থেকে theme load করো
  static Future<bool> loadThemeFromDatabase() async {
    debugPrint('🎨 [ThemeManager] Loading theme...');

    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/themechange'))
          .timeout(const Duration(seconds: 10));

      debugPrint('📡 Response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);

        if (json['status'] == true && json['data'] != null) {
          final data = json['data'];
          final colorCode = data['color_code'];
          final name = data['name'] ?? 'Custom Theme';

          if (colorCode != null && colorCode.isNotEmpty) {
            final parsedColor = _hexToColor(colorCode);
            themeColorStart = parsedColor;
            themeColorEnd = _lightenColor(parsedColor, 0.15);
            themeName = name;
            isThemeLoaded = true;

            debugPrint('✅ Theme loaded: $name');
            return true;
          }
        }
      }

      debugPrint('⚠️ Using default theme');
      _useDefaultTheme();
      return false;
    } catch (e) {
      debugPrint('❌ Error: $e');
      _useDefaultTheme();
      return false;
    }
  }

  /// 🎨 Default theme use করো
  static void _useDefaultTheme() {
    themeColorStart = defaultColorStart;
    themeColorEnd = defaultColorEnd;
    themeName = 'Default Theme';
    isThemeLoaded = true;
  }

  /// 🎨 Hex to Color conversion
  static Color _hexToColor(String hex) {
    try {
      hex = hex.trim().replaceAll('#', '');
      if (hex.length == 3) {
        hex = hex.split('').map((c) => c + c).join('');
      }
      if (hex.length == 6) hex = 'FF$hex';
      if (hex.length != 8) throw const FormatException('Invalid hex');
      return Color(int.parse(hex, radix: 16));
    } catch (e) {
      return defaultColorStart;
    }
  }

  /// 🎨 Lighten color
  static Color _lightenColor(Color color, double amount) {
    try {
      final hsl = HSLColor.fromColor(color);
      return hsl
          .withLightness((hsl.lightness + amount).clamp(0.0, 1.0))
          .toColor();
    } catch (e) {
      return color;
    }
  }

  /// 🎨 Gradient decoration
  static BoxDecoration getGradientDecoration({
    double opacity = 1.0,
    BorderRadius? borderRadius,
  }) {
    return BoxDecoration(
      gradient: LinearGradient(
        colors: [
          themeColorStart.withOpacity(opacity),
          themeColorEnd.withOpacity(opacity),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: borderRadius,
    );
  }

  /// 🎨 Light gradient
  static BoxDecoration getLightGradientDecoration({
    BorderRadius? borderRadius,
    Border? border,
  }) {
    return BoxDecoration(
      gradient: LinearGradient(
        colors: [
          themeColorStart.withOpacity(0.1),
          themeColorEnd.withOpacity(0.1),
        ],
      ),
      borderRadius: borderRadius,
      border: border,
    );
  }

  /// 🎨 Gradient
  static Gradient getGradient() {
    return LinearGradient(
      colors: [themeColorStart, themeColorEnd],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  /// 🎨 Shadow
  static BoxShadow getShadow({double opacity = 0.3, double blur = 8}) {
    return BoxShadow(
      color: themeColorStart.withOpacity(opacity),
      blurRadius: blur,
      offset: const Offset(0, 2),
    );
  }
}

// ==================== API SERVICE ====================
class ApiService {
  // URL: use ApiConfig.baseUrl

  /// 🔑 Get token from SharedPreferences
  static Future<String?> getToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tokenKeys = [
        'auth_token',
        'token',
        'access_token',
        'user_token',
        'authToken',
        'bearer_token',
        'jwt_token',
        'api_token',
      ];

      for (var key in tokenKeys) {
        final value = prefs.getString(key);
        if (value != null && value.trim().isNotEmpty) {
          debugPrint('✅ Token found: ${value.length} chars');
          return value.trim();
        }
      }

      debugPrint('❌ No token found');
      return null;
    } catch (e) {
      debugPrint('❌ Error: $e');
      return null;
    }
  }

  /// 📝 Get headers
  static Future<Map<String, String>> getHeaders() async {
    final token = await getToken();
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    return headers;
  }

  /// 📤 Get multipart headers
  static Future<Map<String, String>> getMultipartHeaders() async {
    final token = await getToken();
    final headers = {'Accept': 'application/json'};

    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    return headers;
  }

  /// 👤 🔥 Get user photo from uploads/profile using /chat-profile-user
  static Future<String> getUserPhoto(int userId) async {
    try {
      debugPrint('📷 [getUserPhoto] Fetching photo for user $userId');

      final headers = await getHeaders();
      final response = await http
          .get(
            Uri.parse('$baseUrl/chat-profile-user?user_id=$userId'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 10));

      debugPrint('📡 [getUserPhoto] Response: ${response.statusCode}');
      debugPrint('📡 [getUserPhoto] Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // 🔥 Check for 'success' field in response
        if (data['success'] == true && data['data'] != null) {
          final profileData = data['data'];
          final photoUrl = profileData['photo']?.toString();

          if (photoUrl != null && photoUrl.isNotEmpty) {
            debugPrint('✅ [getUserPhoto] Photo URL: $photoUrl');
            return photoUrl;
          } else {
            debugPrint('⚠️ [getUserPhoto] No photo in response');
          }
        } else {
          debugPrint(
            '⚠️ [getUserPhoto] API returned false: ${data['message']}',
          );
        }
      } else {
        debugPrint('❌ [getUserPhoto] Status ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ [getUserPhoto] Error: $e');
    }

    // 🔥 Return default avatar (uploads/avator.jpg)
    final defaultUrl = ApiConfig.defaultAvatar;
    debugPrint('🔄 [getUserPhoto] Using default: $defaultUrl');
    return defaultUrl;
  }

  /// ✅ Get user verification status
  static Future<bool> getUserVerificationStatus(int userId) async {
    try {
      debugPrint('🔍 [getUserVerificationStatus] Checking user $userId');

      final headers = await getHeaders();
      final response = await http
          .get(
            Uri.parse('$baseUrl/user/$userId/verify-status'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 10));

      debugPrint('📡 [Verification] Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == true) {
          final isVerified = data['verified'] == true;
          debugPrint('✅ [Verification] User $userId verified: $isVerified');
          return isVerified;
        }
      }
    } catch (e) {
      debugPrint('❌ [Verification] Error: $e');
    }

    debugPrint('⚠️ [Verification] Default: false');
    return false;
  }

  /// 📋 Get chat contacts with photos
  static Future<ApiResponse<List<ChatContact>>> getChatList() async {
    try {
      debugPrint('📡 [getChatList] Fetching contacts...');

      final headers = await getHeaders();
      final response = await http
          .get(Uri.parse('$baseUrl/chat/frontend/list'), headers: headers)
          .timeout(const Duration(seconds: 15));

      debugPrint('📥 [getChatList] Status: ${response.statusCode}');
      debugPrint('📥 [getChatList] Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true) {
          final contactsData = data['data'] as List;
          List<ChatContact> contacts = [];

          debugPrint(
            '🔄 [getChatList] Loading ${contactsData.length} contacts...',
          );

          // 🔥 Load each contact with photo and verification
          for (var item in contactsData) {
            final contact = ChatContact.fromJson(item);
            if (contact.image == null || contact.image!.isEmpty || !contact.image!.startsWith('http')) {
              contact.image = ApiConfig.defaultAvatar;
            }
            contacts.add(contact);
          }

          debugPrint(
            '✅ [getChatList] Loaded ${contacts.length} contacts with photos',
          );
          return ApiResponse.success(contacts);
        } else {
          return ApiResponse.error(data['message'] ?? 'Failed to load');
        }
      } else if (response.statusCode == 401) {
        return ApiResponse.error('Please login again');
      } else {
        return ApiResponse.error('Server error: ${response.statusCode}');
      }
    } on TimeoutException {
      return ApiResponse.error('Connection timeout');
    } on SocketException {
      return ApiResponse.error('No internet connection');
    } catch (e) {
      debugPrint('❌ [getChatList] Error: $e');
      return ApiResponse.error('Error: $e');
    }
  }

  /// 💬 🔥 Get messages - FIXED VERSION
  static Future<ApiResponse<List<ChatMessage>>> getMessages(int userId) async {
    try {
      // 🔥 FIXED: Use correct query parameter format
      final url = '$baseUrl/chat/frontend/messages?user_id=$userId';
      debugPrint('📡 [getMessages] URL: $url');
      debugPrint('📡 [getMessages] Fetching messages for user $userId...');

      final headers = await getHeaders();
      debugPrint('📡 [getMessages] Headers: $headers');

      final response = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 15));

      debugPrint('📥 [getMessages] Status: ${response.statusCode}');
      debugPrint('📥 [getMessages] Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true) {
          final messagesData = data['data'] as List;
          List<ChatMessage> messages = messagesData
              .map((item) => ChatMessage.fromJson(item))
              .toList();

          debugPrint('✅ [getMessages] Loaded ${messages.length} messages');
          return ApiResponse.success(messages);
        } else {
          final errorMsg = data['message'] ?? 'Failed';
          debugPrint('❌ [getMessages] API error: $errorMsg');
          return ApiResponse.error(errorMsg);
        }
      } else if (response.statusCode == 401) {
        debugPrint('❌ [getMessages] Unauthorized');
        return ApiResponse.error('Please login again');
      } else if (response.statusCode == 403) {
        debugPrint('❌ [getMessages] Forbidden');
        return ApiResponse.error('Access denied');
      } else if (response.statusCode == 500) {
        debugPrint('❌ [getMessages] Server error 500');
        // 🔥 Try to parse error message from response
        try {
          final errorData = json.decode(response.body);
          final errorMsg = errorData['message'] ?? 'Server error';
          debugPrint('❌ [getMessages] Server message: $errorMsg');
          return ApiResponse.error(errorMsg);
        } catch (e) {
          return ApiResponse.error('Server error. Please try again.');
        }
      } else {
        debugPrint('❌ [getMessages] Unexpected status: ${response.statusCode}');
        return ApiResponse.error('Server error: ${response.statusCode}');
      }
    } on TimeoutException {
      debugPrint('❌ [getMessages] Timeout');
      return ApiResponse.error('Connection timeout');
    } on SocketException {
      debugPrint('❌ [getMessages] No internet');
      return ApiResponse.error('No internet');
    } catch (e) {
      debugPrint('❌ [getMessages] Exception: $e');
      return ApiResponse.error('Error: $e');
    }
  }

  /// 📤 Send message
  static Future<ApiResponse<ChatMessage>> sendMessage(
    int receiverId,
    String message,
  ) async {
    try {
      debugPrint('📤 [sendMessage] Sending to user $receiverId...');

      final headers = await getMultipartHeaders();
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/chat/frontend/submit'),
      );

      request.headers.addAll(headers);
      request.fields['receiver_id'] = receiverId.toString();
      request.fields['message'] = message;

      debugPrint('📤 [sendMessage] Request fields: ${request.fields}');

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 20),
      );
      final response = await http.Response.fromStream(streamedResponse);

      debugPrint('📥 [sendMessage] Status: ${response.statusCode}');
      debugPrint('📥 [sendMessage] Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);

        if (data['success'] == true) {
          debugPrint('✅ [sendMessage] Message sent successfully');
          final messageData = ChatMessage.fromSendResponse(data['data']);
          return ApiResponse.success(messageData);
        } else {
          final errorMsg = data['message'] ?? 'Failed';
          debugPrint('❌ [sendMessage] API error: $errorMsg');
          return ApiResponse.error(errorMsg);
        }
      } else {
        debugPrint('❌ [sendMessage] Failed: ${response.statusCode}');
        return ApiResponse.error('Failed: ${response.statusCode}');
      }
    } on TimeoutException {
      debugPrint('❌ [sendMessage] Timeout');
      return ApiResponse.error('Connection timeout');
    } on SocketException {
      debugPrint('❌ [sendMessage] No internet');
      return ApiResponse.error('No internet');
    } catch (e) {
      debugPrint('❌ [sendMessage] Error: $e');
      return ApiResponse.error('Error: $e');
    }
  }

  /// 📷 Send image
  static Future<ApiResponse<ChatMessage>> sendImageMessage(
    int receiverId,
    File imageFile, {
    String? caption,
  }) async {
    try {
      debugPrint('📤 [sendImageMessage] Sending image to user $receiverId...');

      if (!await imageFile.exists()) {
        return ApiResponse.error('Image not found');
      }

      final headers = await getMultipartHeaders();
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/chat/frontend/submit'),
      );

      request.headers.addAll(headers);
      request.fields['receiver_id'] = receiverId.toString();
      request.fields['message'] = caption ?? '📷 Photo';

      final multipartFile = await http.MultipartFile.fromPath(
        'image',
        imageFile.path,
      );

      request.files.add(multipartFile);

      debugPrint('📤 [sendImageMessage] Sending...');

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 45),
      );
      final response = await http.Response.fromStream(streamedResponse);

      debugPrint('📥 [sendImageMessage] Status: ${response.statusCode}');
      debugPrint('📥 [sendImageMessage] Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);

        if (data['success'] == true) {
          debugPrint('✅ [sendImageMessage] Image sent successfully');
          final messageData = ChatMessage.fromSendResponse(data['data']);
          return ApiResponse.success(messageData);
        } else {
          return ApiResponse.error(data['message'] ?? 'Failed');
        }
      } else {
        return ApiResponse.error('Upload failed');
      }
    } on TimeoutException {
      return ApiResponse.error('Upload timeout');
    } on SocketException {
      return ApiResponse.error('No internet');
    } catch (e) {
      debugPrint('❌ [sendImageMessage] Error: $e');
      return ApiResponse.error('Error: $e');
    }
  }

  /// 🔢 Get unread counts
  static Future<ApiResponse<Map<int, int>>> getUnreadCounts() async {
    try {
      final headers = await getHeaders();
      final response = await http
          .get(Uri.parse('$baseUrl/chat/unread-counts'), headers: headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true) {
          Map<int, int> counts = {};
          final countsData = data['data'] as Map<String, dynamic>;

          countsData.forEach((key, value) {
            try {
              counts[int.parse(key)] = int.parse(value.toString());
            } catch (e) {
              debugPrint('❌ [getUnreadCounts] Parse error: $e');
            }
          });

          return ApiResponse.success(counts);
        }
      }

      return ApiResponse.success({});
    } catch (e) {
      return ApiResponse.success({});
    }
  }

  /// 💾 Save token
  static Future<bool> saveToken(
    String token, {
    String key = 'auth_token',
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, token);
      debugPrint('✅ Token saved');
      return true;
    } catch (e) {
      debugPrint('❌ Error: $e');
      return false;
    }
  }

  /// 🗑️ Clear tokens
  static Future<void> clearAllTokens() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = ['auth_token', 'token', 'access_token', 'user_token'];
      for (var key in keys) {
        await prefs.remove(key);
      }
      debugPrint('✅ Tokens cleared');
    } catch (e) {
      debugPrint('❌ Error: $e');
    }
  }
}

// ==================== MODELS ====================

/// 📦 API Response wrapper
class ApiResponse<T> {
  final bool success;
  final T? data;
  final String? error;

  ApiResponse.success(this.data) : success = true, error = null;

  ApiResponse.error(this.error) : success = false, data = null;
}

/// 👤 Chat Contact model
class ChatContact {
  final int id;
  final String name;
  final String email;
  String? image; // 🔥 Populated from /chat-profile-user API
  bool isVerified;

  ChatContact({
    required this.id,
    required this.name,
    required this.email,
    this.image,
    this.isVerified = false,
  });

  factory ChatContact.fromJson(Map<String, dynamic> json) {
    return ChatContact(
      id: _parseInt(json['id']),
      name: json['name']?.toString() ?? 'Unknown User',
      email: json['email']?.toString() ?? '',
      image: json['photo']?.toString() ?? json['image']?.toString(),
      isVerified: json['is_verified'] == true,
    );
  }

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  /// Get user initials for avatar
  String get initials {
    if (name.isEmpty) return 'U';
    final names = name.trim().split(' ');
    if (names.length >= 2 && names[0].isNotEmpty && names[1].isNotEmpty) {
      return '${names[0][0]}${names[1][0]}'.toUpperCase();
    }
    return name.length >= 2
        ? name.substring(0, 2).toUpperCase()
        : name[0].toUpperCase();
  }
}

/// 💬 Chat Message model
class ChatMessage {
  final int id;
  final String? message;
  final String? image;
  final bool isSent;
  final String createdAt;
  final bool isRead;

  ChatMessage({
    required this.id,
    this.message,
    this.image,
    required this.isSent,
    required this.createdAt,
    this.isRead = false,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: _parseInt(json['id']),
      message: json['message']?.toString(),
      image: json['image']?.toString(),
      isSent: json['is_sent'] == true || json['is_sent'] == 1,
      createdAt: json['created_at']?.toString() ?? '',
      isRead: json['is_read'] == true || json['is_read'] == 1,
    );
  }

  factory ChatMessage.fromSendResponse(Map<String, dynamic> json) {
    return ChatMessage(
      id: _parseInt(json['id']),
      message: json['message']?.toString(),
      image: json['image']?.toString(),
      isSent: true,
      createdAt: json['created_at']?.toString() ?? 'Just now',
      isRead: false,
    );
  }

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  bool get hasContent =>
      (message != null && message!.isNotEmpty) ||
      (image != null && image!.isNotEmpty);
}

// ==================== MAIN APP ====================
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🎨 Theme load করো
  await ThemeManager.loadThemeFromDatabase();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Live Chat',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.red,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
      ),
      home: const UserLiveChatScreen(),
    );
  }
}
// ==========================================
// 🔥 Live Chat Application - PART 2/5
// UserLiveChatScreen + Contact List
// ==========================================

// NOTE: Add this after Part 1 code

// ==================== MAIN CHAT SCREEN ====================
class UserLiveChatScreen extends StatefulWidget {
  const UserLiveChatScreen({Key? key}) : super(key: key);

  @override
  State<UserLiveChatScreen> createState() => _UserLiveChatScreenState();
}

class _UserLiveChatScreenState extends State<UserLiveChatScreen> {
  ChatContact? selectedContact;
  final TextEditingController _searchController = TextEditingController();
  List<ChatContact> contacts = [];
  Map<int, int> unreadCounts = {};
  bool isLoading = true;
  String? errorMessage;
  String? _authToken;
  Timer? _refreshTimer;
  bool _themeLoading = true;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  /// 🚀 Initialize
  Future<void> _initialize() async {
    debugPrint('🚀 [UserLiveChatScreen] Initializing...');
    await _loadTheme();
    await _loadToken();
    await _loadContacts();
    await _loadUnreadCounts();
    _startAutoRefresh();
  }

  /// 🎨 Load theme
  Future<void> _loadTheme() async {
    setState(() => _themeLoading = true);
    await ThemeManager.loadThemeFromDatabase();
    if (mounted) setState(() => _themeLoading = false);
  }

  /// 🔑 Load token
  Future<void> _loadToken() async {
    final token = await ApiService.getToken();
    if (mounted) {
      setState(() => _authToken = token);
      debugPrint('🔑 [UserLiveChatScreen] Token loaded: ${token != null}');
    }
  }

  /// ⏱️ Auto refresh
  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        debugPrint('🔄 [UserLiveChatScreen] Auto-refreshing unread counts...');
        _loadUnreadCounts();
      }
    });
  }

  /// 📋 Load contacts with photos
  Future<void> _loadContacts() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    debugPrint('🔄 [UserLiveChatScreen] Loading contacts with photos...');
    final response = await ApiService.getChatList();

    if (mounted) {
      setState(() {
        isLoading = false;
        if (response.success) {
          contacts = response.data ?? [];
          errorMessage = null;
          debugPrint(
            '✅ [UserLiveChatScreen] ${contacts.length} contacts loaded',
          );

          // 🔥 Log photo URLs for debugging
          for (var contact in contacts) {
            debugPrint(
              '📷 [UserLiveChatScreen] ${contact.name}: ${contact.image} | Verified: ${contact.isVerified}',
            );
          }
        } else {
          errorMessage = response.error;
          contacts = [];
          debugPrint('❌ [UserLiveChatScreen] Error: $errorMessage');
        }
      });
    }
  }

  /// 🔢 Load unread counts
  Future<void> _loadUnreadCounts() async {
    final response = await ApiService.getUnreadCounts();
    if (mounted && response.success) {
      setState(() => unreadCounts = response.data ?? {});
      debugPrint('✅ [UserLiveChatScreen] Unread counts updated');
    }
  }

  /// 🔍 Filter contacts
  List<ChatContact> get filteredContacts {
    if (_searchController.text.isEmpty) return contacts;
    final query = _searchController.text.toLowerCase();
    return contacts.where((contact) {
      return contact.name.toLowerCase().contains(query) ||
          contact.email.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Scaffold(
      body: SafeArea(
        child: isMobile ? _buildMobileLayout() : _buildDesktopLayout(),
      ),
    );
  }


  /// 📱 Mobile layout
  Widget _buildMobileLayout() {
    if (selectedContact == null) {
      return _buildContactList();
    } else {
      return ChatArea(
        contact: selectedContact!,
        onBack: () {
          setState(() => selectedContact = null);
          _loadUnreadCounts();
        },
        onMessageSent: _loadUnreadCounts,
      );
    }
  }

  /// 🖥️ Desktop layout
  Widget _buildDesktopLayout() {
    return Row(
      children: [
        Container(
          width: 320,
          decoration: ThemeManager.getGradientDecoration(),
          child: _buildContactList(),
        ),
        Expanded(
          child: Container(
            color: const Color(0xFFF5F5F5),
            child: selectedContact == null
                ? _buildWelcomeScreen()
                : ChatArea(
                    contact: selectedContact!,
                    onMessageSent: _loadUnreadCounts,
                  ),
          ),
        ),
      ],
    );
  }

  /// 📋 Contact list with photos
  Widget _buildContactList() {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Container(
      decoration: isMobile ? ThemeManager.getGradientDecoration() : null,
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16.0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [ThemeManager.getShadow()],
                  ),
                  child: Icon(
                    Icons.chat,
                    color: ThemeManager.themeColorStart,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Friend Chat', 
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          // Search
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search contacts...',
                hintStyle: const TextStyle(color: Colors.white70),
                filled: true,
                fillColor: Colors.white.withOpacity(0.2),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: const Icon(Icons.search, color: Colors.white70),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white70),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      )
                    : null,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Contact list
          Expanded(
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : errorMessage != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 60,
                            color: Colors.white70,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: _initialize,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: ThemeManager.themeColorStart,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : filteredContacts.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Text(
                        _searchController.text.isEmpty
                            ? 'No contacts found\n\nAdd friends to start chatting'
                            : 'No matching contacts',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: () async {
                      await _loadTheme();
                      await _loadToken();
                      await _loadContacts();
                      await _loadUnreadCounts();
                    },
                    color: ThemeManager.themeColorStart,
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: filteredContacts.length,
                      itemBuilder: (context, index) {
                        final contact = filteredContacts[index];
                        final unreadCount = unreadCounts[contact.id] ?? 0;
                        return ContactTile(
                          contact: contact,
                          isSelected: selectedContact?.id == contact.id,
                          unreadCount: unreadCount,
                          onTap: () {
                            debugPrint(
                              '👆 [UserLiveChatScreen] Selected: ${contact.name}',
                            );
                            setState(() => selectedContact = contact);
                            _loadUnreadCounts();
                          },
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  /// 👋 Welcome screen
  Widget _buildWelcomeScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: ThemeManager.getGradient(),
              shape: BoxShape.circle,
              boxShadow: [ThemeManager.getShadow(opacity: 0.4, blur: 16)],
            ),
            child: const Icon(
              Icons.chat_bubble_outline,
              size: 60,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Welcome to Friend Chat',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: ThemeManager.themeColorStart,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select a friend to start messaging',
            style: TextStyle(fontSize: 16, color: Colors.grey[500]),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: ThemeManager.getLightGradientDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: ThemeManager.themeColorStart.withOpacity(0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.palette,
                  color: ThemeManager.themeColorStart,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  'Theme: ${ThemeManager.themeName}',
                  style: TextStyle(
                    color: ThemeManager.themeColorStart,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }
}

// ==================== CONTACT TILE WITH PHOTO ====================
class ContactTile extends StatelessWidget {
  final ChatContact contact;
  final bool isSelected;
  final int unreadCount;
  final VoidCallback onTap;

  const ContactTile({
    Key? key,
    required this.contact,
    required this.isSelected,
    required this.unreadCount,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? Colors.white.withOpacity(0.2)
                : Colors.transparent,
            border: Border(
              bottom: BorderSide(
                color: Colors.white.withOpacity(0.1),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              // 🔥 Avatar with photo & online status
              Stack(
                children: [
                  _buildAvatar(),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: ThemeManager.themeColorStart,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),

              // Name and verification
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            contact.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        const SizedBox(width: 6),
                        // 🔥 Verification badge
                        _buildVerificationBadge(),
                      ],
                    ),
                  ],
                ),
              ),

              // Unread count
              if (unreadCount > 0)
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: unreadCount > 9 ? 7 : 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.5),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    unreadCount > 99 ? '99+' : unreadCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// ✅ 🔥 Verification badge - SHOWS IN CONTACT LIST
  Widget _buildVerificationBadge() {
    if (contact.isVerified) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.green,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.verified, color: Colors.white, size: 10),
            SizedBox(width: 3),
            Text(
              'Verified',
              style: TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Text(
          'Unverified',
          style: TextStyle(
            color: Colors.white,
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }
  }

  /// 👤 🔥 Build avatar with photo from uploads/profile
  Widget _buildAvatar() {
    debugPrint('🖼️ [ContactTile] Building avatar for ${contact.name}');
    debugPrint('🖼️ [ContactTile] Image URL: ${contact.image}');

    // 🔥 If contact has image URL, show network image
    if (contact.image != null && contact.image!.isNotEmpty) {
      // 🔥 Check if it's not the default avatar
      final isDefaultAvatar = contact.image!.contains('avator.jpg');

      if (!isDefaultAvatar) {
        return CircleAvatar(
          radius: 24,
          backgroundColor: Colors.white,
          child: ClipOval(
            child: Image.network(
              contact.image!,
              width: 48,
              height: 48,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                debugPrint(
                  '❌ [ContactTile] Image load error for ${contact.name}: $error',
                );
                return _buildInitialsAvatar();
              },
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) {
                  debugPrint(
                    '✅ [ContactTile] Image loaded for ${contact.name}',
                  );
                  return child;
                }
                return Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: ThemeManager.getGradient(),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      }
    }

    // 🔥 Fallback to initials avatar
    debugPrint('🔤 [ContactTile] Using initials avatar for ${contact.name}');
    return _buildInitialsAvatar();
  }

  /// 🔤 Initials avatar (fallback)
  Widget _buildInitialsAvatar() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        gradient: ThemeManager.getGradient(),
        shape: BoxShape.circle,
        boxShadow: [ThemeManager.getShadow()],
      ),
      child: Center(
        child: Text(
          contact.initials,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
// ==========================================
// 🔥 Live Chat Application - PART 3/5
// ChatArea Widget + Message Handling
// ==========================================

// NOTE: Add this after Part 2 code

// ==================== CHAT AREA ====================
class ChatArea extends StatefulWidget {
  final ChatContact contact;
  final VoidCallback? onBack;
  final VoidCallback? onMessageSent;

  const ChatArea({
    Key? key,
    required this.contact,
    this.onBack,
    this.onMessageSent,
  }) : super(key: key);

  @override
  State<ChatArea> createState() => _ChatAreaState();
}

class _ChatAreaState extends State<ChatArea> {
  final TextEditingController _messageController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  final ScrollController _scrollController = ScrollController();
  bool _showEmojiPicker = false;
  List<ChatMessage> messages = [];
  bool isLoading = true;
  bool isSending = false;
  String? errorMessage;
  Timer? _pollTimer;

  // 🔥 Photo URLs for sender and receiver
  String? _senderPhoto;
  String? _receiverPhoto;
  int? _currentUserId;

  final List<String> _emojis = [
    '😀',
    '😃',
    '😄',
    '😁',
    '😆',
    '😅',
    '🤣',
    '😂',
    '🙂',
    '🙃',
    '😉',
    '😊',
    '😇',
    '🥰',
    '😍',
    '🤩',
    '😘',
    '😗',
    '😚',
    '😙',
    '😋',
    '😛',
    '😜',
    '🤪',
    '😝',
    '🤑',
    '🤗',
    '🤭',
    '🤫',
    '🤔',
    '🤐',
    '🤨',
    '😐',
    '😑',
    '😶',
    '😏',
    '😒',
    '🙄',
    '😬',
    '🤥',
    '👍',
    '👎',
    '👏',
    '🙌',
    '🤝',
    '🙏',
    '💪',
    '✨',
    '🎉',
    '🎊',
    '❤️',
    '💕',
    '💖',
    '💗',
    '💓',
    '💞',
    '💝',
    '🔥',
    '⭐',
    '🌟',
    '😴',
    '😌',
    '😎',
    '🥳',
    '🎯',
    '✅',
    '💯',
    '🚀',
    '💡',
    '📱',
  ];

  @override
  void initState() {
    super.initState();
    debugPrint('🚀 [ChatArea] Initializing for ${widget.contact.name}');
    _loadPhotos();
    _loadMessages();
    _startPolling();
  }

  /// 📷 🔥 Load both sender and receiver photos
  Future<void> _loadPhotos() async {
    debugPrint('📷 [ChatArea] Loading photos for chat...');

    // 🔥 Load receiver photo (contact) - already loaded from contact list
    _receiverPhoto = widget.contact.image;
    debugPrint('👤 [ChatArea] Receiver photo: $_receiverPhoto');

    // 🔥 Load sender photo (current user) from SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      _currentUserId = prefs.getInt('user_id');

      if (_currentUserId != null) {
        debugPrint(
          '👤 [ChatArea] Loading sender photo for user $_currentUserId',
        );
        _senderPhoto = await ApiService.getUserPhoto(_currentUserId!);
        debugPrint('✅ [ChatArea] Sender photo loaded: $_senderPhoto');
      } else {
        debugPrint('⚠️ [ChatArea] No user_id found in SharedPreferences');
      }
    } catch (e) {
      debugPrint('❌ [ChatArea] Error loading sender photo: $e');
    }

    if (mounted) setState(() {});
  }

  /// ⏱️ Start polling for new messages
  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted && !isSending) {
        _loadMessagesQuietly();
      }
    });
  }

  /// 📥 🔥 Load messages - FIXED VERSION
  Future<void> _loadMessages() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    debugPrint('📥 [ChatArea] Loading messages for ${widget.contact.name}...');
    debugPrint('📥 [ChatArea] Contact ID: ${widget.contact.id}');

    final response = await ApiService.getMessages(widget.contact.id);

    if (mounted) {
      setState(() {
        isLoading = false;
        if (response.success) {
          messages = response.data ?? [];
          errorMessage = null;
          debugPrint('✅ [ChatArea] Loaded ${messages.length} messages');

          // 🔥 Debug log messages
          for (var msg in messages) {
            debugPrint(
              '💬 Message ${msg.id}: ${msg.message ?? "📷"} | Sent: ${msg.isSent} | Time: ${msg.createdAt}',
            );
          }
        } else {
          errorMessage = response.error;
          debugPrint('❌ [ChatArea] Error: $errorMessage');
        }
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    }
  }

  /// 🔄 Load messages quietly (no loading indicator)
  Future<void> _loadMessagesQuietly() async {
    final response = await ApiService.getMessages(widget.contact.id);

    if (mounted && response.success) {
      final newMessages = response.data ?? [];

      if (newMessages.length != messages.length) {
        setState(() => messages = newMessages);
        _scrollToBottom();
      }
    }
  }

  /// 📜 Scroll to bottom
  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  /// 📤 Send message
  Future<void> _sendMessage() async {
    final messageText = _messageController.text.trim();

    if (messageText.isEmpty || isSending) return;

    _messageController.clear();
    setState(() {
      isSending = true;
      _showEmojiPicker = false;
    });

    debugPrint('📤 [ChatArea] Sending message to ${widget.contact.name}...');
    final response = await ApiService.sendMessage(
      widget.contact.id,
      messageText,
    );

    if (mounted) {
      setState(() => isSending = false);

      if (response.success) {
        await _loadMessages();
        widget.onMessageSent?.call();

        if (mounted) {
          _showSnackBar('Message sent', isError: false);
        }
      } else {
        _messageController.text = messageText;

        if (mounted) {
          _showSnackBar(response.error ?? 'Failed to send', isError: true);
        }
      }
    }
  }

  /// 📷 Pick and send image
  Future<void> _pickImage() async {
    if (isSending) return;

    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (pickedFile == null) return;

      final imageFile = File(pickedFile.path);
      final fileSize = await imageFile.length();

      // Check size (max 5MB)
      if (fileSize > 5 * 1024 * 1024) {
        if (mounted) {
          _showSnackBar('Image too large. Max 5MB', isError: true);
        }
        return;
      }

      setState(() {
        isSending = true;
        _showEmojiPicker = false;
      });

      debugPrint('📷 [ChatArea] Sending image to ${widget.contact.name}...');
      final response = await ApiService.sendImageMessage(
        widget.contact.id,
        imageFile,
      );

      if (mounted) {
        setState(() => isSending = false);

        if (response.success) {
          await _loadMessages();
          widget.onMessageSent?.call();

          if (mounted) {
            _showSnackBar('Image sent', isError: false);
          }
        } else {
          if (mounted) {
            _showSnackBar(
              response.error ?? 'Failed to send',
              isError: true,
              action: SnackBarAction(
                label: 'Retry',
                textColor: Colors.white,
                onPressed: _pickImage,
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('❌ [ChatArea] Image error: $e');

      if (mounted) {
        setState(() => isSending = false);
        _showSnackBar('Failed to select image', isError: true);
      }
    }
  }

  /// 📢 Show snackbar
  void _showSnackBar(
    String message, {
    bool isError = false,
    SnackBarAction? action,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error : Icons.check_circle,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        duration: Duration(seconds: isError ? 3 : 2),
        backgroundColor: isError ? Colors.red : ThemeManager.themeColorStart,
        behavior: SnackBarBehavior.floating,
        action: action,
      ),
    );
  }

  /// 😊 Toggle emoji picker
  void _toggleEmojiPicker() {
    setState(() => _showEmojiPicker = !_showEmojiPicker);
  }

  /// 😀 Add emoji
  void _addEmoji(String emoji) {
    final currentText = _messageController.text;
    final selection = _messageController.selection;

    final newText =
        currentText.substring(0, selection.start) +
        emoji +
        currentText.substring(selection.end);

    _messageController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: selection.start + emoji.length,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Column(
      children: [
        // Header for Mobile and Desktop
        if (isMobile) _buildMobileHeader() else _buildDesktopHeader(),

        // Messages with sender/receiver photos
        Expanded(child: _buildMessagesArea()),

        // Emoji picker
        if (_showEmojiPicker) _buildEmojiPicker(),

        // Input
        _buildMessageInput(),
      ],
    );
  }

  /// 🖥️ Desktop header with receiver photo
  /// Mobile header with receiver info and back button
  Widget _buildMobileHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        gradient: ThemeManager.getGradient(),
        boxShadow: [ThemeManager.getShadow(opacity: 0.15, blur: 8)],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
              size: 20,
            ),
            onPressed: widget.onBack,
          ),
          Stack(
            children: [
              _buildContactAvatar(),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        widget.contact.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    _buildVerificationBadge(),
                  ],
                ),
                const Text(
                  'Online',
                  style: TextStyle(fontSize: 11, color: Colors.white70),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white, size: 22),
            onPressed: _loadMessages,
            tooltip: 'Refresh',
          ),
        ],
      ),
    );
  }

  /// Desktop header with receiver photo
  Widget _buildDesktopHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        gradient: ThemeManager.getGradient(),
        boxShadow: [ThemeManager.getShadow(opacity: 0.15, blur: 8)],
      ),
      child: Row(
        children: [
          Stack(
            children: [
              _buildContactAvatar(), // 🔥 Receiver photo
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        widget.contact.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    // 🔥 Verification badge in chat header
                    _buildVerificationBadge(),
                  ],
                ),
                const Text(
                  'Online',
                  style: TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: _loadMessages,
              tooltip: 'Refresh',
            ),
          ),
        ],
      ),
    );
  }

  /// ✅ 🔥 Verification badge in chat header
  Widget _buildVerificationBadge() {
    if (widget.contact.isVerified) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.green,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.verified, color: Colors.white, size: 10),
            SizedBox(width: 3),
            Text(
              'Verified',
              style: TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Text(
          'Unverified',
          style: TextStyle(
            color: Colors.white,
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }
  }

  /// 👤 🔥 Contact avatar (receiver photo from uploads/profile)
  Widget _buildContactAvatar() {
    debugPrint(
      '🖼️ [ChatArea Header] Building avatar for ${widget.contact.name}',
    );
    debugPrint('🖼️ [ChatArea Header] Photo URL: $_receiverPhoto');

    if (_receiverPhoto != null && _receiverPhoto!.isNotEmpty) {
      // Check if it's not the default avatar
      final isDefaultAvatar = _receiverPhoto!.contains('avator.jpg');

      if (!isDefaultAvatar) {
        return CircleAvatar(
          radius: 22,
          backgroundColor: Colors.white,
          child: ClipOval(
            child: Image.network(
              _receiverPhoto!,
              width: 44,
              height: 44,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                debugPrint('❌ [ChatArea Header] Receiver photo error: $error');
                return _buildInitialsAvatar();
              },
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) {
                  debugPrint('✅ [ChatArea Header] Photo loaded');
                  return child;
                }
                return _buildInitialsAvatar();
              },
            ),
          ),
        );
      }
    }

    debugPrint('🔤 [ChatArea Header] Using initials avatar');
    return _buildInitialsAvatar();
  }

  /// 🔤 Initials avatar
  Widget _buildInitialsAvatar() {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        gradient: ThemeManager.getGradient(),
        shape: BoxShape.circle,
        boxShadow: [ThemeManager.getShadow()],
      ),
      child: Center(
        child: Text(
          widget.contact.initials,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  /// 💬 Messages area
  Widget _buildMessagesArea() {
    if (isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                ThemeManager.themeColorStart,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Loading messages...',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    if (errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 60, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600], fontSize: 16),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _loadMessages,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ThemeManager.themeColorStart,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      color: Colors.grey.shade100,
      child: messages.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: ThemeManager.getGradient(),
                      shape: BoxShape.circle,
                      boxShadow: [
                        ThemeManager.getShadow(opacity: 0.3, blur: 12),
                      ],
                    ),
                    child: const Icon(
                      Icons.chat_bubble_outline,
                      size: 50,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No messages yet',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: ThemeManager.themeColorStart,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Start the conversation!',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadMessages,
              color: ThemeManager.themeColorStart,
              child: ListView.builder(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  // 🔥 Pass sender and receiver photos to MessageBubble
                  return MessageBubble(
                    message: messages[index],
                    contact: widget.contact,
                    senderPhoto: _senderPhoto,
                    receiverPhoto: _receiverPhoto,
                  );
                },
              ),
            ),
    );
  }

  /// 😊 Emoji picker
  Widget _buildEmojiPicker() {
    return Container(
      height: 250,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: ThemeManager.themeColorStart.withOpacity(0.2),
            width: 2,
          ),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: ThemeManager.getLightGradientDecoration(
              border: Border(
                bottom: BorderSide(
                  color: ThemeManager.themeColorStart.withOpacity(0.2),
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.emoji_emotions,
                      color: ThemeManager.themeColorStart,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Select Emoji',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: ThemeManager.themeColorStart,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(
                    Icons.close,
                    size: 20,
                    color: ThemeManager.themeColorStart,
                  ),
                  onPressed: _toggleEmojiPicker,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 8,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemCount: _emojis.length,
              itemBuilder: (context, index) {
                return InkWell(
                  onTap: () => _addEmoji(_emojis[index]),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    decoration: ThemeManager.getLightGradientDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: ThemeManager.themeColorStart.withOpacity(0.2),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        _emojis[index],
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// ⌨️ Message input
  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [ThemeManager.getShadow(opacity: 0.1, blur: 8)],
        border: Border(
          top: BorderSide(
            color: ThemeManager.themeColorStart.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Image button
            Container(
              decoration: BoxDecoration(
                gradient: isSending
                    ? null
                    : LinearGradient(
                        colors: [
                          ThemeManager.themeColorStart.withOpacity(0.1),
                          ThemeManager.themeColorEnd.withOpacity(0.1),
                        ],
                      ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                icon: Icon(
                  Icons.image,
                  color: isSending ? Colors.grey : ThemeManager.themeColorStart,
                ),
                onPressed: isSending ? null : _pickImage,
                tooltip: 'Send Image',
              ),
            ),

            // Emoji button
            Container(
              decoration: BoxDecoration(
                gradient: _showEmojiPicker
                    ? ThemeManager.getGradient()
                    : LinearGradient(
                        colors: [
                          ThemeManager.themeColorStart.withOpacity(0.1),
                          ThemeManager.themeColorEnd.withOpacity(0.1),
                        ],
                      ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                icon: Icon(
                  _showEmojiPicker
                      ? Icons.keyboard
                      : Icons.emoji_emotions_outlined,
                  color: _showEmojiPicker
                      ? Colors.white
                      : ThemeManager.themeColorStart,
                ),
                onPressed: _toggleEmojiPicker,
                tooltip: 'Emoji',
              ),
            ),

            // Text field
            Expanded(
              child: TextField(
                controller: _messageController,
                enabled: !isSending,
                maxLines: null,
                textInputAction: TextInputAction.send,
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  filled: true,
                  fillColor: const Color(0xFFF5F5F5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(
                      color: ThemeManager.themeColorStart.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),

            const SizedBox(width: 8),

            // Send button
            Container(
              decoration: BoxDecoration(
                gradient: isSending ? null : ThemeManager.getGradient(),
                color: isSending ? Colors.grey : null,
                shape: BoxShape.circle,
                boxShadow: isSending
                    ? null
                    : [ThemeManager.getShadow(opacity: 0.3, blur: 8)],
              ),
              child: isSending
                  ? const Padding(
                      padding: EdgeInsets.all(12.0),
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      ),
                    )
                  : IconButton(
                      icon: const Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                      onPressed: _sendMessage,
                      tooltip: 'Send',
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    debugPrint('🗑️ [ChatArea] Disposing...');
    _messageController.dispose();
    _scrollController.dispose();
    _pollTimer?.cancel();
    super.dispose();
  }
}
// ==========================================
// 🔥 Live Chat Application - PART 4/5
// MessageBubble with Sender/Receiver Photos
// ==========================================

// NOTE: Add this after Part 3 code

// ==================== MESSAGE BUBBLE WITH PHOTOS ====================
class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final ChatContact contact;
  final String? senderPhoto;
  final String? receiverPhoto;

  const MessageBubble({
    Key? key,
    required this.message,
    required this.contact,
    this.senderPhoto,
    this.receiverPhoto,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: message.isSent
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!message.isSent) ...[
            _buildReceiverAvatar(),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: message.isSent
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                // 🔥 Show sender name with verification badge for received messages
                if (!message.isSent) _buildSenderName(),
                _buildMessageContent(context),
                _buildMessageTime(),
              ],
            ),
          ),
          if (message.isSent) ...[
            const SizedBox(width: 8),
            _buildSenderAvatar(),
          ],
        ],
      ),
    );
  }

  /// 👤 🔥 Receiver avatar (contact photo from uploads/profile)
  Widget _buildReceiverAvatar() {
    debugPrint(
      '🖼️ [MessageBubble] Building receiver avatar for ${contact.name}',
    );
    debugPrint('🖼️ [MessageBubble] Receiver photo URL: $receiverPhoto');

    if (receiverPhoto != null && receiverPhoto!.isNotEmpty) {
      // Check if it's not the default avatar
      final isDefaultAvatar = receiverPhoto!.contains('avator.jpg');

      if (!isDefaultAvatar) {
        return CircleAvatar(
          radius: 18,
          backgroundColor: Colors.white,
          child: ClipOval(
            child: Image.network(
              receiverPhoto!,
              width: 36,
              height: 36,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                debugPrint(
                  '❌ [MessageBubble] Receiver avatar load error: $error',
                );
                return _buildInitialsAvatar();
              },
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) {
                  debugPrint('✅ [MessageBubble] Receiver avatar loaded');
                  return child;
                }
                return Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: ThemeManager.getGradient(),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      }
    }

    debugPrint('🔤 [MessageBubble] Using initials avatar for receiver');
    return _buildInitialsAvatar();
  }

  /// 👤 🔥 Sender avatar (current user photo from uploads/profile)
  Widget _buildSenderAvatar() {
    debugPrint('🖼️ [MessageBubble] Building sender avatar');
    debugPrint('🖼️ [MessageBubble] Sender photo URL: $senderPhoto');

    if (senderPhoto != null && senderPhoto!.isNotEmpty) {
      // Check if it's not the default avatar
      final isDefaultAvatar = senderPhoto!.contains('avator.jpg');

      if (!isDefaultAvatar) {
        return CircleAvatar(
          radius: 18,
          backgroundColor: Colors.white,
          child: ClipOval(
            child: Image.network(
              senderPhoto!,
              width: 36,
              height: 36,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                debugPrint(
                  '❌ [MessageBubble] Sender avatar load error: $error',
                );
                return _buildSenderInitialsAvatar();
              },
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) {
                  debugPrint('✅ [MessageBubble] Sender avatar loaded');
                  return child;
                }
                return Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        ThemeManager.themeColorEnd,
                        ThemeManager.themeColorStart,
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      }
    }

    debugPrint('🔤 [MessageBubble] Using initials avatar for sender');
    return _buildSenderInitialsAvatar();
  }

  /// 🔤 Initials avatar for receiver
  Widget _buildInitialsAvatar() {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        gradient: ThemeManager.getGradient(),
        shape: BoxShape.circle,
        boxShadow: [ThemeManager.getShadow(opacity: 0.2, blur: 4)],
      ),
      child: Center(
        child: Text(
          contact.initials,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  /// 🔤 Initials avatar for sender (you/me)
  Widget _buildSenderInitialsAvatar() {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [ThemeManager.themeColorEnd, ThemeManager.themeColorStart],
        ),
        shape: BoxShape.circle,
        boxShadow: [ThemeManager.getShadow(opacity: 0.2, blur: 4)],
      ),
      child: const Center(
        child: Text(
          'Me',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  /// 📛 🔥 Sender name with verification badge - SHOWS IN CHAT BOX
  Widget _buildSenderName() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        gradient: ThemeManager.getGradient(),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [ThemeManager.getShadow(opacity: 0.2, blur: 4)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.person, color: Colors.white, size: 12),
          const SizedBox(width: 4),
          Text(
            contact.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          // 🔥 Verification badge in message bubble
          if (contact.isVerified) ...[
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.verified, color: Colors.white, size: 10),
                  SizedBox(width: 2),
                  Text(
                    'Verified',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Unverified',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 💬 Message content (text or image)
  Widget _buildMessageContent(BuildContext context) {
    return Container(
      padding: message.image != null
          ? const EdgeInsets.all(4)
          : const EdgeInsets.all(12),
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.7,
      ),
      decoration: BoxDecoration(
        color: message.isSent ? null : Colors.white,
        gradient: message.isSent ? ThemeManager.getGradient() : null,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: message.isSent
                ? ThemeManager.themeColorStart.withOpacity(0.3)
                : Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: message.image != null ? _buildImageMessage() : _buildTextMessage(),
    );
  }

  /// 📷 Image message with photo preview
  Widget _buildImageMessage() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              Image.network(
                message.image!,
                width: 200,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    width: 200,
                    height: 200,
                    decoration: ThemeManager.getLightGradientDecoration(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                : null,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              ThemeManager.themeColorStart,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Loading image...',
                            style: TextStyle(
                              color: ThemeManager.themeColorStart,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  debugPrint('❌ [MessageBubble] Image load error: $error');
                  return Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.broken_image,
                          size: 50,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Image not available',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  );
                },
              ),
              // Gradient overlay
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withOpacity(0.5),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          // Caption (if exists)
          if (message.message != null &&
              message.message!.isNotEmpty &&
              message.message != '📷 Photo')
            Container(
              padding: const EdgeInsets.all(8.0),
              decoration: message.isSent
                  ? null
                  : ThemeManager.getLightGradientDecoration(),
              child: Text(
                message.message!,
                style: TextStyle(
                  color: message.isSent
                      ? Colors.white
                      : ThemeManager.themeColorStart,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 📝 Text message
  Widget _buildTextMessage() {
    return Text(
      message.message ?? '',
      style: TextStyle(
        color: message.isSent ? Colors.white : Colors.black87,
        fontSize: 14,
        height: 1.4,
      ),
    );
  }

  /// ⏰ Message time with read status
  Widget _buildMessageTime() {
    return Padding(
      padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.access_time, size: 10, color: Colors.grey.shade600),
          const SizedBox(width: 4),
          Text(
            message.createdAt,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
          ),
          if (message.isSent) ...[
            const SizedBox(width: 4),
            Icon(
              message.isRead ? Icons.done_all : Icons.done,
              size: 14,
              color: message.isRead
                  ? ThemeManager.themeColorStart
                  : Colors.grey.shade600,
            ),
          ],
        ],
      ),
    );
  }
}

// ==================== ADDITIONAL UTILITY WIDGETS ====================

/// 🔥 Image Preview Dialog (Optional - for full screen image view)
class ImagePreviewDialog extends StatelessWidget {
  final String imageUrl;
  final String? caption;

  const ImagePreviewDialog({Key? key, required this.imageUrl, this.caption})
    : super(key: key);

  static void show(BuildContext context, String imageUrl, {String? caption}) {
    showDialog(
      context: context,
      builder: (context) =>
          ImagePreviewDialog(imageUrl: imageUrl, caption: caption),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: EdgeInsets.zero,
      child: Stack(
        children: [
          // Image
          Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                              : null,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            ThemeManager.themeColorStart,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Loading image...',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.broken_image,
                          size: 80,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Failed to load image',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),

          // Close button
          Positioned(
            top: 40,
            right: 16,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),

          // Caption (if exists)
          if (caption != null && caption!.isNotEmpty && caption != '📷 Photo')
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black.withOpacity(0.8), Colors.transparent],
                  ),
                ),
                child: Text(
                  caption!,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 🔥 User Status Indicator (Optional - for online/offline status)
class UserStatusIndicator extends StatelessWidget {
  final bool isOnline;
  final double size;

  const UserStatusIndicator({Key? key, required this.isOnline, this.size = 12})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isOnline ? Colors.green : Colors.grey,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: size * 0.15),
        boxShadow: [
          BoxShadow(
            color: isOnline
                ? Colors.green.withOpacity(0.5)
                : Colors.grey.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
    );
  }
}

/// 🔥 Typing Indicator (Optional - shows "User is typing...")
class TypingIndicator extends StatefulWidget {
  final String userName;

  const TypingIndicator({Key? key, required this.userName}) : super(key: key);

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: ThemeManager.getGradient(),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                widget.userName[0].toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${widget.userName} is typing',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 20,
                  height: 20,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(3, (index) {
                      return AnimatedBuilder(
                        animation: _controller,
                        builder: (context, child) {
                          final delay = index * 0.2;
                          final value = (_controller.value - delay) % 1.0;
                          final scale = value < 0.5
                              ? 1.0 + (value * 2)
                              : 2.0 - (value * 2);
                          return Transform.scale(
                            scale: scale.clamp(0.5, 1.5),
                            child: Container(
                              width: 4,
                              height: 4,
                              decoration: BoxDecoration(
                                color: ThemeManager.themeColorStart,
                                shape: BoxShape.circle,
                              ),
                            ),
                          );
                        },
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
// ==========================================
// 🔥 Live Chat Application - PART 5/5
// Message Actions + Final Utilities + Usage
// ==========================================

// NOTE: Add this after Part 4 code

// ==================== MESSAGE ACTIONS ====================
/// 🔥 Message Actions (Optional - long press menu)
class MessageActions {
  static void show(
    BuildContext context,
    ChatMessage message, {
    VoidCallback? onCopy,
    VoidCallback? onDelete,
    VoidCallback? onForward,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [ThemeManager.getShadow(opacity: 0.2, blur: 12)],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Copy
              if (message.message != null && message.message!.isNotEmpty)
                ListTile(
                  leading: Icon(
                    Icons.copy,
                    color: ThemeManager.themeColorStart,
                  ),
                  title: const Text('Copy Message'),
                  onTap: () {
                    Navigator.pop(context);
                    onCopy?.call();
                  },
                ),

              // Delete
              if (message.isSent)
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('Delete Message'),
                  onTap: () {
                    Navigator.pop(context);
                    onDelete?.call();
                  },
                ),

              // Forward
              ListTile(
                leading: Icon(
                  Icons.forward,
                  color: ThemeManager.themeColorStart,
                ),
                title: const Text('Forward Message'),
                onTap: () {
                  Navigator.pop(context);
                  onForward?.call();
                },
              ),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== ENHANCED MESSAGE BUBBLE WITH LONG PRESS ====================
/// 🔥 Optional: Enhanced MessageBubble with long press support
/// Wrap MessageBubble with GestureDetector to enable long press
class MessageBubbleWithActions extends StatelessWidget {
  final ChatMessage message;
  final ChatContact contact;
  final String? senderPhoto;
  final String? receiverPhoto;

  const MessageBubbleWithActions({
    Key? key,
    required this.message,
    required this.contact,
    this.senderPhoto,
    this.receiverPhoto,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: () {
        MessageActions.show(
          context,
          message,
          onCopy: () {
            // TODO: Implement copy to clipboard
            debugPrint('📋 Copied: ${message.message}');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.white),
                    SizedBox(width: 8),
                    Text('Message copied'),
                  ],
                ),
                backgroundColor: ThemeManager.themeColorStart,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 2),
              ),
            );
          },
          onDelete: () {
            // TODO: Implement delete message
            debugPrint('🗑️ Delete: ${message.id}');
            _showDeleteConfirmation(context);
          },
          onForward: () {
            // TODO: Implement forward message
            debugPrint('➡️ Forward: ${message.id}');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Row(
                  children: [
                    Icon(Icons.info, color: Colors.white),
                    SizedBox(width: 8),
                    Text('Forward feature coming soon'),
                  ],
                ),
                backgroundColor: ThemeManager.themeColorStart,
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
        );
      },
      child: MessageBubble(
        message: message,
        contact: contact,
        senderPhoto: senderPhoto,
        receiverPhoto: receiverPhoto,
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Message'),
        content: const Text('Are you sure you want to delete this message?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Call delete API
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.white),
                      SizedBox(width: 8),
                      Text('Message deleted'),
                    ],
                  ),
                  backgroundColor: Colors.red,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// ==================== CHAT SETTINGS DIALOG ====================
/// 🔥 Optional: Chat Settings Dialog
class ChatSettingsDialog extends StatelessWidget {
  final ChatContact contact;

  const ChatSettingsDialog({Key? key, required this.contact}) : super(key: key);

  static void show(BuildContext context, ChatContact contact) {
    showDialog(
      context: context,
      builder: (context) => ChatSettingsDialog(contact: contact),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: ThemeManager.getGradient(),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.settings,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        contact.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        contact.email,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),

            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 10),

            // Options
            _buildOption(
              context,
              icon: Icons.notifications,
              title: 'Notifications',
              subtitle: 'Manage chat notifications',
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement notifications settings
              },
            ),

            _buildOption(
              context,
              icon: Icons.block,
              title: 'Block User',
              subtitle: 'Block this user',
              isDestructive: true,
              onTap: () {
                Navigator.pop(context);
                _showBlockConfirmation(context);
              },
            ),

            _buildOption(
              context,
              icon: Icons.delete,
              title: 'Clear Chat',
              subtitle: 'Delete all messages',
              isDestructive: true,
              onTap: () {
                Navigator.pop(context);
                _showClearConfirmation(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    bool isDestructive = false,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isDestructive ? Colors.red : ThemeManager.themeColorStart,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isDestructive ? Colors.red : Colors.black87,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(subtitle),
      onTap: onTap,
    );
  }

  void _showBlockConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Block User'),
        content: Text('Are you sure you want to block ${contact.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Call block API
            },
            child: const Text('Block', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showClearConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Chat'),
        content: const Text('Are you sure you want to delete all messages?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Call clear chat API
            },
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// ==================== ERROR HANDLER ====================
/// 🔥 Centralized Error Handler
class ChatErrorHandler {
  static void handle(BuildContext context, String error) {
    debugPrint('❌ [ChatErrorHandler] Error: $error');

    if (!context.mounted) return;

    // Parse common errors
    String userMessage = error;
    IconData icon = Icons.error;
    Color color = Colors.red;

    if (error.contains('timeout') || error.contains('Timeout')) {
      userMessage = 'Connection timeout. Please try again.';
      icon = Icons.wifi_off;
    } else if (error.contains('internet') || error.contains('network')) {
      userMessage = 'No internet connection';
      icon = Icons.wifi_off;
    } else if (error.contains('401') || error.contains('login')) {
      userMessage = 'Session expired. Please login again.';
      icon = Icons.lock;
    } else if (error.contains('403') || error.contains('Access denied')) {
      userMessage = 'Access denied';
      icon = Icons.block;
    } else if (error.contains('500') || error.contains('Server error')) {
      userMessage = 'Server error. Please try again later.';
      icon = Icons.cloud_off;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(userMessage, style: const TextStyle(fontSize: 14)),
            ),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }
}
