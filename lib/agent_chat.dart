import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'agent_list.dart';
import 'config/api_config.dart';

// ========================== THEME MANAGER ==========================
class ThemeManager {
  static const String _themeColorKey = 'app_theme_color';
  static const String _themeNameKey = 'app_theme_name';
  static Color _currentThemeColor = const Color(0xFFFF6F61); // Default color

  // Get current theme color
  static Color get currentColor => _currentThemeColor;

  // Load theme from API
  static Future<void> loadThemeFromApi() async {
    try {
      debugPrint('🎨 Loading theme from API...');
      final response = await http
          .get(
            Uri.parse('${ApiConfig.baseUrl}/themechange'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));

      debugPrint('🎨 Theme API Response: ${response.statusCode}');
      debugPrint('🎨 Theme API Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == true && data['data'] != null) {
          final colorCode = data['data']['color_code'] as String?;
          final themeName = data['data']['name'] as String?;

          if (colorCode != null && colorCode.isNotEmpty) {
            // Parse color code and save
            final color = _parseColor(colorCode);
            await _saveTheme(color, themeName ?? 'Custom Theme');
            _currentThemeColor = color;
            debugPrint('✅ Theme loaded: $colorCode ($themeName)');
          }
        }
      } else {
        debugPrint('⚠️ Failed to load theme, using default');
      }
    } catch (e) {
      debugPrint('❌ Error loading theme: $e');
    }
  }

  // Load theme from local storage
  static Future<void> loadThemeFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final colorString = prefs.getString(_themeColorKey);

      if (colorString != null) {
        _currentThemeColor = _parseColor(colorString);
        debugPrint('✅ Theme loaded from cache: $colorString');
      }
    } catch (e) {
      debugPrint('❌ Error loading cached theme: $e');
    }
  }

  // Save theme to local storage
  static Future<void> _saveTheme(Color color, String name) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final colorString =
          '#${color.value.toRadixString(16).substring(2).toUpperCase()}';
      await prefs.setString(_themeColorKey, colorString);
      await prefs.setString(_themeNameKey, name);
      debugPrint('💾 Theme saved to cache: $colorString');
    } catch (e) {
      debugPrint('❌ Error saving theme: $e');
    }
  }

  // Parse color from hex string
  static Color _parseColor(String hexColor) {
    try {
      String colorStr = hexColor.replaceAll('#', '');
      if (colorStr.length == 6) {
        colorStr = 'FF$colorStr'; // Add alpha if not present
      }
      return Color(int.parse(colorStr, radix: 16));
    } catch (e) {
      debugPrint('❌ Error parsing color: $e');
      return const Color(0xFFFF6F61); // Default color
    }
  }

  // Get lighter shade of current theme color
  static Color getLightShade() {
    return Color.lerp(_currentThemeColor, Colors.white, 0.3) ??
        _currentThemeColor;
  }

  // Get gradient colors for theme
  static List<Color> getGradientColors() {
    final lighterShade =
        Color.lerp(_currentThemeColor, Colors.white, 0.2) ?? _currentThemeColor;
    return [_currentThemeColor, lighterShade];
  }
}

// ========================== SESSION MANAGER ==========================
class SessionManager {
  static const String _tokenKey = 'auth_token';
  static const String _userIdKey = 'user_id';
  static const String _userNameKey = 'user_name';
  static const String _userEmailKey = 'user_email';

  static const List<String> _legacyTokenKeys = [
    'auth_token',
    'token',
    'access_token',
    'bearer_token',
    'user_token',
    'api_token',
  ];

  static const List<String> _legacyUserIdKeys = [
    'user_id',
    'userId',
    'id',
    'current_user_id',
    'uid',
  ];

  static Future<bool> saveSession({
    required String token,
    required int userId,
    String? userName,
    String? userEmail,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, token.trim());
      await prefs.setInt(_userIdKey, userId);
      if (userName != null) await prefs.setString(_userNameKey, userName);
      if (userEmail != null) await prefs.setString(_userEmailKey, userEmail);
      debugPrint('✅ Session saved: userId=$userId');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to save session: $e');
      return false;
    }
  }

  static Future<String?> getToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (String key in _legacyTokenKeys) {
        final token = prefs.getString(key);
        if (token != null && token.trim().isNotEmpty) {
          return token.trim();
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<int?> getUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (String key in _legacyUserIdKeys) {
        final userId = prefs.getInt(key);
        if (userId != null && userId > 0) return userId;
      }
      for (String key in _legacyUserIdKeys) {
        final userIdStr = prefs.getString(key);
        if (userIdStr != null) {
          final userId = int.tryParse(userIdStr);
          if (userId != null && userId > 0) return userId;
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<SessionValidation> validateSession() async {
    final token = await getToken();
    final userId = await getUserId();
    final hasValidToken =
        token != null && token.isNotEmpty && token.length > 20;

    if (!hasValidToken) {
      return SessionValidation(
        isValid: false,
        errorType: SessionErrorType.noSession,
        message: 'No active session found. Please login.',
      );
    }

    return SessionValidation(isValid: true, token: token, userId: userId ?? 0);
  }

  static Future<void> clearSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (String key in _legacyTokenKeys) await prefs.remove(key);
      for (String key in _legacyUserIdKeys) await prefs.remove(key);
      await prefs.remove(_userNameKey);
      await prefs.remove(_userEmailKey);
      debugPrint('✅ Session cleared');
    } catch (e) {
      debugPrint('❌ Failed to clear session: $e');
    }
  }
}

class SessionValidation {
  final bool isValid;
  final SessionErrorType? errorType;
  final String? message;
  final String? token;
  final int? userId;

  SessionValidation({
    required this.isValid,
    this.errorType,
    this.message,
    this.token,
    this.userId,
  });
}

enum SessionErrorType { noSession, invalidToken, invalidUserId, expired }

// ========================== AGENT CHAT API CONFIG ==========================
class AgentChatConfig {
  // URL: use ApiConfig.mediaBaseUrl from lib/config/api_config.dart
  static String get storageUrl => '${ApiConfig.mediaBaseUrl}/storage';
  static const Duration timeout = Duration(seconds: 30);

  static Future<Map<String, String>> getHeaders() async {
    final token = await SessionManager.getToken();
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${token ?? ''}',
    };
  }

  static Future<Map<String, String>> getMultipartHeaders() async {
    final token = await SessionManager.getToken();
    return {
      'Accept': 'application/json',
      'Authorization': 'Bearer ${token ?? ''}',
    };
  }

  static String getFullImageUrl(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) return '';

    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      return imagePath;
    }

    final cleanPath = imagePath.startsWith('/')
        ? imagePath.substring(1)
        : imagePath;
    return '$storageUrl/$cleanPath';
  }
}

// ========================== API SERVICE ==========================
class ChatApiService {
  static Exception _handleApiError(http.Response response) {
    if (response.statusCode == 401) return Exception('SESSION_EXPIRED');
    try {
      final errorData = json.decode(response.body);
      return Exception(
        errorData['message'] ?? 'Request failed (${response.statusCode})',
      );
    } catch (e) {
      return Exception('Request failed (${response.statusCode})');
    }
  }

  static Future<Map<String, dynamic>> getAgentInfo() async {
    try {
      final validation = await SessionManager.validateSession();
      if (!validation.isValid)
        throw Exception(validation.message ?? 'Invalid session');

      final headers = await AgentChatConfig.getHeaders();
      final response = await http
          .get(
            Uri.parse('${ApiConfig.baseUrl}/usertoagentchat/agent'),
            headers: headers,
          )
          .timeout(AgentChatConfig.timeout);

      debugPrint('📥 Agent Info Response: ${response.statusCode}');
      debugPrint('📥 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw _handleApiError(response);
      }
    } on SocketException {
      throw Exception('No internet connection');
    } on TimeoutException {
      throw Exception('Connection timeout');
    }
  }

  static Future<Map<String, dynamic>> fetchMessages({
    int page = 1,
    int perPage = 50,
  }) async {
    try {
      final validation = await SessionManager.validateSession();
      if (!validation.isValid)
        throw Exception(validation.message ?? 'Invalid session');

      final headers = await AgentChatConfig.getHeaders();
      final url =
          '${ApiConfig.baseUrl}/usertoagentchat/fetch?page=$page&per_page=$perPage';

      debugPrint('🔗 Request URL: $url');
      debugPrint('📤 Request Headers: $headers');

      final response = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(AgentChatConfig.timeout);

      debugPrint('📥 Messages Response Status: ${response.statusCode}');
      debugPrint('📥 Messages Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('✅ Parsed Response Data: $data');
        return data;
      } else {
        throw _handleApiError(response);
      }
    } on SocketException {
      debugPrint('❌ No internet connection');
      throw Exception('No internet connection');
    } on TimeoutException {
      debugPrint('❌ Connection timeout');
      throw Exception('Connection timeout');
    } catch (e) {
      debugPrint('❌ Error in fetchMessages: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> sendMessage({
    String? message,
    File? image,
  }) async {
    try {
      final validation = await SessionManager.validateSession();
      if (!validation.isValid)
        throw Exception(validation.message ?? 'Invalid session');

      final headers = await AgentChatConfig.getMultipartHeaders();
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConfig.baseUrl}/usertoagentchat/send'),
      );

      request.headers.addAll(headers);

      if (message != null && message.isNotEmpty) {
        request.fields['message'] = message;
      }

      if (image != null) {
        request.fields['message_type'] = 'image';
      } else {
        request.fields['message_type'] = 'text';
      }

      if (image != null) {
        var stream = http.ByteStream(image.openRead());
        var length = await image.length();
        var multipartFile = http.MultipartFile(
          'image',
          stream,
          length,
          filename: image.path.split('/').last,
        );
        request.files.add(multipartFile);
      }

      debugPrint('📤 Sending message');
      debugPrint('   - Message: $message');
      debugPrint('   - Has Image: ${image != null}');

      var streamedResponse = await request.send().timeout(AgentChatConfig.timeout);
      var response = await http.Response.fromStream(streamedResponse);

      debugPrint('📥 Send Response: ${response.statusCode}');
      debugPrint('📥 Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        throw _handleApiError(response);
      }
    } on SocketException {
      throw Exception('No internet connection');
    } on TimeoutException {
      throw Exception('Connection timeout');
    }
  }

  static Future<Map<String, dynamic>> markAsRead() async {
    try {
      final validation = await SessionManager.validateSession();
      if (!validation.isValid)
        throw Exception(validation.message ?? 'Invalid session');

      final headers = await AgentChatConfig.getHeaders();
      final response = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/usertoagentchat/mark-read'),
            headers: headers,
          )
          .timeout(AgentChatConfig.timeout);

      debugPrint('📥 Mark as Read Response: ${response.statusCode}');

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw _handleApiError(response);
      }
    } catch (e) {
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> deleteMessage(int messageId) async {
    try {
      final validation = await SessionManager.validateSession();
      if (!validation.isValid)
        throw Exception(validation.message ?? 'Invalid session');

      final headers = await AgentChatConfig.getHeaders();
      final response = await http
          .delete(
            Uri.parse(
              '${ApiConfig.baseUrl}/usertoagentchat/message/$messageId',
            ),
            headers: headers,
          )
          .timeout(AgentChatConfig.timeout);

      debugPrint('📥 Delete Response: ${response.statusCode}');

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw _handleApiError(response);
      }
    } catch (e) {
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> getUnreadCount() async {
    try {
      final validation = await SessionManager.validateSession();
      if (!validation.isValid)
        throw Exception(validation.message ?? 'Invalid session');

      final headers = await AgentChatConfig.getHeaders();
      final response = await http
          .get(
            Uri.parse('${ApiConfig.baseUrl}/usertoagentchat/unread-count'),
            headers: headers,
          )
          .timeout(AgentChatConfig.timeout);

      debugPrint('📥 Unread Count Response: ${response.statusCode}');

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw _handleApiError(response);
      }
    } catch (e) {
      rethrow;
    }
  }
}

// ========================== MODELS ==========================
class Agent {
  final int id;
  final String name;
  final String email;
  final String? avatar;
  final String status;
  final int unreadCount;

  Agent({
    required this.id,
    required this.name,
    required this.email,
    this.avatar,
    this.status = 'available',
    this.unreadCount = 0,
  });

  factory Agent.fromJson(Map<String, dynamic> json) {
    String? avatarUrl;
    if (json['avatar'] != null && json['avatar'].toString().isNotEmpty) {
      avatarUrl = AgentChatConfig.getFullImageUrl(json['avatar']);
    }

    return Agent(
      id: json['id'] ?? 1,
      name: json['name'] ?? 'Support Agent',
      email: json['email'] ?? '',
      avatar: avatarUrl,
      status: json['status'] ?? 'available',
      unreadCount: json['unread_count'] ?? 0,
    );
  }

  Agent copyWith({int? unreadCount, String? status}) {
    return Agent(
      id: id,
      name: name,
      email: email,
      avatar: avatar,
      status: status ?? this.status,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }

  bool get isAvailable => status.toLowerCase() == 'available';
}

class ChatMessage {
  final int id;
  final int senderId;
  final String senderType;
  final int receiverId;
  final String? text;
  final String? imageUrl;
  final String messageType;
  final bool isRead;
  final String createdAt;
  final int currentUserId;
  final String? senderAvatar;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderType,
    required this.receiverId,
    this.text,
    this.imageUrl,
    required this.messageType,
    required this.isRead,
    required this.createdAt,
    required this.currentUserId,
    this.senderAvatar,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json, int currentUserId) {
    debugPrint('🔍 Parsing message JSON: ${json.toString()}');

    String? imageUrl;
    if (json['image_url'] != null && json['image_url'].toString().isNotEmpty) {
      imageUrl = AgentChatConfig.getFullImageUrl(json['image_url']);
    }

    String? senderAvatar;
    if (json['sender_avatar'] != null &&
        json['sender_avatar'].toString().isNotEmpty) {
      senderAvatar = AgentChatConfig.getFullImageUrl(json['sender_avatar']);
    }

    String? messageText = json['message']?.toString();
    if (messageText != null && messageText.trim().isEmpty) {
      messageText = null;
    }

    final message = ChatMessage(
      id: _parseInt(json['id']),
      senderId: _parseInt(json['sender_id']),
      senderType: json['sender_type']?.toString() ?? 'user',
      receiverId: _parseInt(json['receiver_id']),
      text: messageText,
      imageUrl: imageUrl,
      messageType: json['message_type']?.toString() ?? 'text',
      isRead: _parseBool(json['is_read']),
      createdAt: json['created_at']?.toString() ?? '',
      currentUserId: currentUserId,
      senderAvatar: senderAvatar,
    );

    debugPrint('✅ Parsed Message:');
    debugPrint('   - ID: ${message.id}');
    debugPrint('   - Sender: ${message.senderId} (${message.senderType})');
    debugPrint('   - Receiver: ${message.receiverId}');
    debugPrint('   - Text: ${message.text}');
    debugPrint('   - Image: ${message.imageUrl}');
    debugPrint('   - Type: ${message.messageType}');
    debugPrint('   - Sender Avatar: ${message.senderAvatar}');
    debugPrint('   - Is User Message: ${message.isSentByUser}');

    return message;
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static bool _parseBool(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is int) return value == 1;
    if (value is String) return value.toLowerCase() == 'true' || value == '1';
    return false;
  }

  bool get isSentByUser => senderType == 'user';
  bool get isImage =>
      messageType == 'image' || (imageUrl != null && imageUrl!.isNotEmpty);
  bool get hasText => text != null && text!.isNotEmpty;
}

// ========================== MAIN SCREEN ==========================
class AgentLiveChatScreen extends StatefulWidget {
  const AgentLiveChatScreen({Key? key}) : super(key: key);

  @override
  State<AgentLiveChatScreen> createState() => _AgentLiveChatScreenState();
}

class _AgentLiveChatScreenState extends State<AgentLiveChatScreen> {
  Agent? agent;
  int currentUserId = 0;
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    // Load theme first
    await ThemeManager.loadThemeFromCache();
    await ThemeManager.loadThemeFromApi();

    final validation = await SessionManager.validateSession();
    if (!mounted) return;

    if (!validation.isValid) {
      _handleSessionError(validation);
      return;
    }

    currentUserId = validation.userId ?? 0;
    debugPrint('✅ Current User ID: $currentUserId');
    await _loadAgentInfo();
  }

  void _handleSessionError(SessionValidation validation) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Session Error'),
        content: Text(validation.message ?? 'Please login to continue'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushReplacementNamed('/login');
            },
            child: const Text('Go to Login'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadAgentInfo() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      final response = await ChatApiService.getAgentInfo();
      if (!mounted) return;

      debugPrint('📦 Agent Response: ${response.toString()}');

      if (response['success'] == true && response['data'] != null) {
        final data = response['data'];
        debugPrint('📦 Agent Data: $data');

        setState(() {
          agent = Agent.fromJson(data);
          isLoading = false;
        });

        debugPrint('✅ Agent loaded: ${agent?.name}');
      } else {
        throw Exception('Failed to load agent info');
      }
    } catch (e) {
      debugPrint('❌ Error loading agent: $e');
      if (!mounted) return;
      if (e.toString().contains('SESSION_EXPIRED')) {
        _handleSessionExpired();
        return;
      }
      setState(() {
        errorMessage = e.toString().replaceAll('Exception: ', '');
        isLoading = false;
      });
    }
  }

  void _handleSessionExpired() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Session Expired'),
        content: const Text('Your session has expired. Please login again.'),
        actions: [
          TextButton(
            onPressed: () async {
              await SessionManager.clearSession();
              if (mounted) {
                Navigator.of(context).pop();
                Navigator.of(context).pushReplacementNamed('/login');
              }
            },
            child: const Text('Login Again'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Live Chat',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black87),
            onPressed: isLoading ? null : _loadAgentInfo,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: ThemeManager.currentColor),
            const SizedBox(height: 16),
            const Text('Loading...', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    if (errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
              const SizedBox(height: 16),
              const Text(
                'Failed to Load',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadAgentInfo,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ThemeManager.currentColor,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (agent == null) {
      return const Center(child: Text('Agent not available'));
    }

    return ChatArea(
      agent: agent!,
      currentUserId: currentUserId,
      onBack: _loadAgentInfo,
      onSessionExpired: _handleSessionExpired,
    );
  }
}

// ========================== CHAT AREA ==========================
class ChatArea extends StatefulWidget {
  final Agent agent;
  final int currentUserId;
  final VoidCallback? onBack;
  final VoidCallback? onSessionExpired;

  const ChatArea({
    Key? key,
    required this.agent,
    required this.currentUserId,
    this.onBack,
    this.onSessionExpired,
  }) : super(key: key);

  @override
  State<ChatArea> createState() => _ChatAreaState();
}

class _ChatAreaState extends State<ChatArea> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  final FocusNode _focusNode = FocusNode();

  bool _showEmojiPicker = false;
  bool isLoading = true;
  bool isSending = false;
  List<ChatMessage> messages = [];
  Timer? _autoRefreshTimer;
  File? _selectedImage;

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
    '🥲',
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
    '👍',
    '👎',
    '👌',
    '✌️',
    '🤞',
    '🤟',
    '🤘',
    '👏',
    '🙌',
    '👐',
    '🤲',
    '🤝',
    '🙏',
    '✍️',
    '💪',
    '🦾',
    '❤️',
    '🧡',
    '💛',
    '💚',
    '💙',
    '💜',
    '🤎',
    '🖤',
    '🤍',
    '💔',
    '❤️‍🔥',
    '❤️‍🩹',
    '💕',
    '💞',
    '💓',
    '⭐',
    '🌟',
    '✨',
    '💫',
    '🔥',
    '💥',
    '💯',
    '🎉',
    '🎊',
    '🎈',
    '🎁',
    '🏆',
    '🥇',
    '🥈',
    '🥉',
    '🎯',
  ];

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  void _startAutoRefresh() {
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted && !isSending) {
        _loadMessages(silent: true);
      }
    });
  }

  Future<void> _loadMessages({bool silent = false}) async {
    try {
      if (!silent) {
        setState(() {
          isLoading = true;
        });
      }

      debugPrint('📥 Loading messages...');
      final response = await ChatApiService.fetchMessages();
      if (!mounted) return;

      debugPrint('📦 Messages Response: ${response.toString()}');

      List<ChatMessage> messagesList = [];
      if (response['success'] == true && response['data'] != null) {
        final data = response['data'];
        debugPrint('📦 Messages Data: $data');

        if (data['messages'] != null && data['messages'] is List) {
          final msgList = data['messages'] as List;
          messagesList = msgList.map((msg) {
            debugPrint('💬 Message: $msg');
            return ChatMessage.fromJson(msg, widget.currentUserId);
          }).toList();
        }
      }

      debugPrint('✅ Total messages loaded: ${messagesList.length}');

      if (mounted) {
        setState(() {
          messages = messagesList;
          isLoading = false;
        });

        if (messagesList.isNotEmpty && !silent) {
          _scrollToBottom();
        }
      }
    } catch (e) {
      debugPrint('❌ Error loading messages: $e');
      if (!mounted) return;

      if (e.toString().contains('SESSION_EXPIRED')) {
        widget.onSessionExpired?.call();
        return;
      }

      if (!silent) {
        setState(() {
          isLoading = false;
        });
        _showSnackBar(
          'Failed to load messages: ${e.toString().replaceAll('Exception: ', '')}',
          isError: true,
        );
      }
    }
  }

  Future<void> _sendMessage() async {
    final messageText = _messageController.text.trim();

    if (messageText.isEmpty && _selectedImage == null) {
      _showSnackBar('Please enter a message or select an image', isError: true);
      return;
    }

    setState(() {
      isSending = true;
    });

    try {
      debugPrint('📤 Sending message...');
      debugPrint('   - Text: $messageText');
      debugPrint('   - Image: ${_selectedImage?.path}');

      final response = await ChatApiService.sendMessage(
        message: messageText.isNotEmpty ? messageText : null,
        image: _selectedImage,
      );

      debugPrint('✅ Message sent successfully: $response');

      if (!mounted) return;

      _messageController.clear();
      setState(() {
        _selectedImage = null;
        _showEmojiPicker = false;
      });

      await _loadMessages();
      _scrollToBottom();

      _showSnackBar('Message sent successfully', isError: false);
    } catch (e) {
      debugPrint('❌ Error sending message: $e');
      if (!mounted) return;

      if (e.toString().contains('SESSION_EXPIRED')) {
        widget.onSessionExpired?.call();
        return;
      }

      _showSnackBar(
        'Failed to send message: ${e.toString().replaceAll('Exception: ', '')}',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          isSending = false;
        });
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null && mounted) {
        setState(() {
          _selectedImage = File(image.path);
          _showEmojiPicker = false;
        });
        debugPrint('✅ Image selected: ${image.path}');
      }
    } catch (e) {
      debugPrint('❌ Error picking image: $e');
      _showSnackBar('Failed to pick image', isError: true);
    }
  }

  Future<void> _takePicture() async {
    try {
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (photo != null && mounted) {
        setState(() {
          _selectedImage = File(photo.path);
          _showEmojiPicker = false;
        });
        debugPrint('✅ Photo taken: ${photo.path}');
      }
    } catch (e) {
      debugPrint('❌ Error taking picture: $e');
      _showSnackBar('Failed to take picture', isError: true);
    }
  }

  void _clearSelectedImage() {
    setState(() {
      _selectedImage = null;
    });
  }

  void _insertEmoji(String emoji) {
    final text = _messageController.text;
    final selection = _messageController.selection;
    final newText = text.replaceRange(selection.start, selection.end, emoji);

    _messageController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: selection.start + emoji.length,
      ),
    );
  }

  void _toggleEmojiPicker() {
    setState(() {
      _showEmojiPicker = !_showEmojiPicker;
      if (_showEmojiPicker) {
        _focusNode.unfocus();
      }
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }

  Future<void> _showDeleteConfirmation(ChatMessage message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Message'),
        content: const Text('Are you sure you want to delete this message?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteMessage(message.id);
    }
  }

  Future<void> _deleteMessage(int messageId) async {
    try {
      await ChatApiService.deleteMessage(messageId);
      if (!mounted) return;

      _showSnackBar('Message deleted', isError: false);
      await _loadMessages();
    } catch (e) {
      debugPrint('❌ Error deleting message: $e');
      if (!mounted) return;

      if (e.toString().contains('SESSION_EXPIRED')) {
        widget.onSessionExpired?.call();
        return;
      }

      _showSnackBar('Failed to delete message', isError: true);
    }
  }

  void _showImagePreview(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return Center(
                      child: CircularProgressIndicator(
                        value: progress.expectedTotalBytes != null
                            ? progress.cumulativeBytesLoaded /
                                  progress.expectedTotalBytes!
                            : null,
                        color: Colors.white,
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      padding: const EdgeInsets.all(20),
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: Colors.white,
                            size: 48,
                          ),
                          SizedBox(height: 8),
                          Text(
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
            Positioned(
              top: 20,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildChatHeader(),
        Expanded(child: _buildMessageList()),
        if (_selectedImage != null) _buildImagePreview(),
        if (_showEmojiPicker) _buildEmojiPicker(),
        _buildMessageInput(),
      ],
    );
  }

  Widget _buildChatHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: ThemeManager.currentColor,
                backgroundImage:
                    (widget.agent.avatar != null &&
                        widget.agent.avatar!.isNotEmpty)
                    ? NetworkImage(widget.agent.avatar!)
                    : null,
                onBackgroundImageError:
                    (widget.agent.avatar != null &&
                        widget.agent.avatar!.isNotEmpty)
                    ? (exception, stackTrace) {
                        debugPrint('❌ Failed to load agent avatar: $exception');
                      }
                    : null,
                child:
                    (widget.agent.avatar == null ||
                        widget.agent.avatar!.isEmpty)
                    ? Text(
                        widget.agent.name.substring(0, 1).toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: widget.agent.isAvailable
                        ? Colors.green
                        : Colors.orange,
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
                Text(
                  widget.agent.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  widget.agent.status,
                  style: TextStyle(
                    color: widget.agent.isAvailable
                        ? Colors.green
                        : Colors.orange,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: isLoading ? null : () => _loadMessages(),
            tooltip: 'Refresh messages',
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    if (isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: ThemeManager.currentColor),
            const SizedBox(height: 16),
            const Text(
              'Loading messages...',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 80,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'No messages yet',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start a conversation with ${widget.agent.name}',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        final showDate =
            index == 0 || _shouldShowDate(messages[index - 1], message);

        return Column(
          children: [
            if (showDate) _buildDateDivider(message.createdAt),
            _buildMessageBubble(message),
          ],
        );
      },
    );
  }

  bool _shouldShowDate(ChatMessage previous, ChatMessage current) {
    try {
      final prevDate = DateTime.parse(previous.createdAt);
      final currDate = DateTime.parse(current.createdAt);
      return prevDate.day != currDate.day ||
          prevDate.month != currDate.month ||
          prevDate.year != currDate.year;
    } catch (e) {
      return false;
    }
  }

  Widget _buildDateDivider(String dateStr) {
    String formattedDate = 'Today';
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final messageDate = DateTime(date.year, date.month, date.day);

      if (messageDate == today) {
        formattedDate = 'Today';
      } else if (messageDate == today.subtract(const Duration(days: 1))) {
        formattedDate = 'Yesterday';
      } else {
        formattedDate = '${date.day}/${date.month}/${date.year}';
      }
    } catch (e) {
      debugPrint('Error formatting date: $e');
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(child: Divider(color: Colors.grey.shade300)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              formattedDate,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(child: Divider(color: Colors.grey.shade300)),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isUserMessage = message.isSentByUser;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isUserMessage
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUserMessage) _buildSenderAvatar(message),
          if (!isUserMessage) const SizedBox(width: 8),
          Flexible(
            child: GestureDetector(
              onLongPress: isUserMessage
                  ? () => _showDeleteConfirmation(message)
                  : null,
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.7,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  gradient: isUserMessage
                      ? LinearGradient(
                          colors: ThemeManager.getGradientColors(),
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: isUserMessage ? null : Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isUserMessage ? 16 : 4),
                    bottomRight: Radius.circular(isUserMessage ? 4 : 16),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (message.isImage && message.imageUrl != null)
                      _buildMessageImage(message.imageUrl!, isUserMessage),
                    if (message.isImage &&
                        message.imageUrl != null &&
                        message.hasText)
                      const SizedBox(height: 8),
                    if (message.hasText)
                      _buildMessageText(message.text!, isUserMessage),
                    const SizedBox(height: 4),
                    _buildMessageTime(message.createdAt, isUserMessage),
                  ],
                ),
              ),
            ),
          ),
          if (isUserMessage) const SizedBox(width: 8),
          if (isUserMessage) _buildSenderAvatar(message),
        ],
      ),
    );
  }

  Widget _buildSenderAvatar(ChatMessage message) {
    final isUserMessage = message.isSentByUser;

    if (isUserMessage) {
      return CircleAvatar(
        radius: 16,
        backgroundColor: ThemeManager.currentColor,
        backgroundImage:
            (message.senderAvatar != null && message.senderAvatar!.isNotEmpty)
            ? NetworkImage(message.senderAvatar!)
            : null,
        onBackgroundImageError:
            (message.senderAvatar != null && message.senderAvatar!.isNotEmpty)
            ? (exception, stackTrace) {
                debugPrint('❌ Failed to load user avatar: $exception');
              }
            : null,
        child: (message.senderAvatar == null || message.senderAvatar!.isEmpty)
            ? const Icon(Icons.person, size: 18, color: Colors.white)
            : null,
      );
    } else {
      return CircleAvatar(
        radius: 16,
        backgroundColor: ThemeManager.currentColor,
        backgroundImage:
            (widget.agent.avatar != null && widget.agent.avatar!.isNotEmpty)
            ? NetworkImage(widget.agent.avatar!)
            : null,
        onBackgroundImageError:
            (widget.agent.avatar != null && widget.agent.avatar!.isNotEmpty)
            ? (exception, stackTrace) {
                debugPrint('❌ Failed to load agent avatar: $exception');
              }
            : null,
        child: (widget.agent.avatar == null || widget.agent.avatar!.isEmpty)
            ? Text(
                widget.agent.name.substring(0, 1).toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              )
            : null,
      );
    }
  }

  Widget _buildMessageImage(String imageUrl, bool isUserMessage) {
    return GestureDetector(
      onTap: () => _showImagePreview(imageUrl),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          imageUrl,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return Container(
              height: 200,
              width: double.infinity,
              color: Colors.grey.shade200,
              child: Center(
                child: CircularProgressIndicator(
                  value: progress.expectedTotalBytes != null
                      ? progress.cumulativeBytesLoaded /
                            progress.expectedTotalBytes!
                      : null,
                  color: isUserMessage
                      ? Colors.white
                      : ThemeManager.currentColor,
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            debugPrint('❌ Failed to load chat image: $error');
            return Container(
              height: 200,
              width: double.infinity,
              color: Colors.grey.shade200,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.broken_image,
                    size: 48,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Failed to load image',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildMessageText(String text, bool isUserMessage) {
    return Text(
      text,
      style: TextStyle(
        color: isUserMessage ? Colors.white : Colors.black87,
        fontSize: 15,
      ),
    );
  }

  Widget _buildMessageTime(String createdAt, bool isUserMessage) {
    String timeStr = '';
    try {
      final date = DateTime.parse(createdAt);
      final hour = date.hour.toString().padLeft(2, '0');
      final minute = date.minute.toString().padLeft(2, '0');
      timeStr = '$hour:$minute';
    } catch (e) {
      timeStr = 'Now';
    }

    return Text(
      timeStr,
      style: TextStyle(
        color: isUserMessage ? Colors.white70 : Colors.grey.shade600,
        fontSize: 11,
      ),
    );
  }

  Widget _buildImagePreview() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              _selectedImage!,
              width: 60,
              height: 60,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _selectedImage!.path.split('/').last,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Ready to send',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.red),
            onPressed: _clearSelectedImage,
            tooltip: 'Remove image',
          ),
        ],
      ),
    );
  }

  Widget _buildEmojiPicker() {
    return Container(
      height: 250,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Emojis',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => setState(() => _showEmojiPicker = false),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 8,
                childAspectRatio: 1,
              ),
              itemCount: _emojis.length,
              itemBuilder: (context, index) {
                return InkWell(
                  onTap: () => _insertEmoji(_emojis[index]),
                  borderRadius: BorderRadius.circular(8),
                  child: Center(
                    child: Text(
                      _emojis[index],
                      style: const TextStyle(fontSize: 24),
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

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              icon: Icon(
                _showEmojiPicker
                    ? Icons.keyboard
                    : Icons.emoji_emotions_outlined,
                color: ThemeManager.currentColor,
              ),
              onPressed: _toggleEmojiPicker,
              tooltip: _showEmojiPicker ? 'Show keyboard' : 'Show emojis',
            ),
            IconButton(
              icon: Icon(Icons.photo, color: ThemeManager.currentColor),
              onPressed: isSending ? null : _pickImage,
              tooltip: 'Pick image',
            ),
            IconButton(
              icon: Icon(Icons.camera_alt, color: ThemeManager.currentColor),
              onPressed: isSending ? null : _takePicture,
              tooltip: 'Take picture',
            ),
            Expanded(
              child: TextField(
                controller: _messageController,
                focusNode: _focusNode,
                enabled: !isSending,
                maxLines: null,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
                onTap: () {
                  if (_showEmojiPicker) {
                    setState(() {
                      _showEmojiPicker = false;
                    });
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: ThemeManager.getGradientColors(),
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: isSending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send, color: Colors.white),
                onPressed: isSending ? null : _sendMessage,
                tooltip: 'Send message',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
