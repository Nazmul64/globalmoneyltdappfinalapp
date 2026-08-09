// ============================================
// 📦 COMPLETE AGENT CHAT - PART 1/5 (FIXED)
// Type Error Fix: String to Int conversion
// ============================================

import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'config/api_config.dart';

String get baseUrl => ApiConfig.baseUrl;

// ============================================
// 🔧 API SERVICE CLASS - TYPE SAFE
// ============================================
class AgentChatApiService {
  // URL: use ApiConfig.baseUrl
  static const String uploadsBaseUrl = ApiConfig.baseUrl;

  // ✅ Get authentication token
  static Future<String?> getToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('auth_token') ?? prefs.getString('token');
    } catch (e) {
      debugPrint('❌ Token Error: $e');
      return null;
    }
  }

  // ✅ Safe integer parsing (CRITICAL FIX)
  static int _parseInt(dynamic value, [int defaultValue = 0]) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is String) {
      return int.tryParse(value) ?? defaultValue;
    }
    if (value is double) return value.toInt();
    return defaultValue;
  }

  // ✅ Safe boolean parsing
  static bool _parseBool(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is int) return value == 1;
    if (value is String) {
      return value.toLowerCase() == 'true' || value == '1';
    }
    return false;
  }

  // ✅ Build full image URL
  static String getFullImageUrl(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) {
      return '$uploadsBaseUrl/uploads/default-image.jpg';
    }

    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      return imagePath;
    }

    if (imagePath.startsWith('/')) {
      imagePath = imagePath.substring(1);
    }

    return '$uploadsBaseUrl/$imagePath';
  }

  // ✅ Get theme color from server
  static Future<Map<String, dynamic>> getThemeColor() async {
    try {
      debugPrint('🎨 Fetching theme color...');

      final response = await http
          .get(
            Uri.parse('$baseUrl/themechange'),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == true && data['data'] != null) {
          final colorCode = data['data']['color_code'] ?? '#4361EE';
          return {
            'success': true,
            'color': _parseColor(colorCode),
            'colorCode': colorCode,
            'name': data['data']['name'] ?? 'Default Theme',
          };
        }
      }
      return _getDefaultTheme();
    } catch (e) {
      debugPrint('⚠️ Theme Error: $e');
      return _getDefaultTheme();
    }
  }

  // ✅ Parse hex color to Flutter Color
  static Color _parseColor(String hexColor) {
    try {
      hexColor = hexColor.replaceAll('#', '');
      if (hexColor.length == 6) {
        return Color(int.parse('FF$hexColor', radix: 16));
      }
    } catch (e) {
      debugPrint('⚠️ Color parse error: $e');
    }
    return const Color(0xFF4361EE);
  }

  // ✅ Get default theme
  static Map<String, dynamic> _getDefaultTheme() {
    return {
      'success': true,
      'color': const Color(0xFF4361EE),
      'colorCode': '#4361EE',
      'name': 'Default Blue',
    };
  }

  // ✅ Check agent verification status
  static Future<Map<String, dynamic>> checkAgentVerification(
    int agentId,
  ) async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/agent/$agentId/verify-status'),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': data['status'] ?? false,
          'verified': data['verified'] ?? false,
          'message': data['message'] ?? '',
        };
      }

      return {'success': false, 'verified': false, 'message': 'Check failed'};
    } catch (e) {
      debugPrint('⚠️ Verification check error: $e');
      return {'success': false, 'verified': false, 'message': 'Error: $e'};
    }
  }

  // ✅ Get all agents list
  static Future<Map<String, dynamic>> getAgentsList() async {
    try {
      final token = await getToken();
      if (token == null || token.isEmpty) {
        throw Exception('Authentication required');
      }

      debugPrint('🔍 Fetching agents list...');

      final response = await http
          .get(
            Uri.parse('$baseUrl/usertoagentchat/agents'),
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 15));

      debugPrint('📥 Agents Response: ${response.statusCode}');

      if (response.statusCode == 401) {
        throw Exception('Session expired');
      }

      if (response.statusCode != 200) {
        throw Exception('Server error (${response.statusCode})');
      }

      final data = json.decode(response.body);

      if (data['success'] != true) {
        throw Exception(data['message'] ?? 'Failed to load agents');
      }

      return data;
    } catch (e) {
      debugPrint('❌ Get agents error: $e');
      rethrow;
    }
  }

  // ✅ Get messages with TYPE SAFETY (CRITICAL FIX)
  static Future<Map<String, dynamic>> getMessages(
    int agentId, {
    int page = 1,
  }) async {
    try {
      final token = await getToken();
      if (token == null) {
        throw Exception('Authentication required');
      }

      debugPrint('📥 Fetching messages for agent: $agentId (page: $page)');

      final response = await http
          .get(
            Uri.parse(
              '$baseUrl/usertoagentchat/fetch?agent_id=$agentId&page=$page&per_page=50',
            ),
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 15));

      debugPrint('📥 Messages Response: ${response.statusCode}');

      if (response.statusCode == 401) {
        throw Exception('Session expired');
      }

      if (response.statusCode != 200) {
        throw Exception('Server error (${response.statusCode})');
      }

      final data = json.decode(response.body);

      if (data['success'] == true && data['data'] != null) {
        final messageCount = (data['data']['messages'] as List?)?.length ?? 0;
        debugPrint('✅ Loaded $messageCount messages');
      }

      return data;
    } catch (e) {
      debugPrint('❌ Get messages error: $e');
      rethrow;
    }
  }

  // ✅ Send text message
  static Future<Map<String, dynamic>> sendMessage(
    int agentId,
    String message,
  ) async {
    try {
      final token = await getToken();
      if (token == null) {
        throw Exception('Authentication required');
      }

      debugPrint('📤 Sending text message to agent: $agentId');

      final response = await http
          .post(
            Uri.parse('$baseUrl/usertoagentchat/send'),
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: json.encode({
              'agent_id': agentId,
              'message': message,
              'message_type': 'text',
            }),
          )
          .timeout(const Duration(seconds: 15));

      debugPrint('📥 Send Response: ${response.statusCode}');

      if (response.statusCode == 401) {
        throw Exception('Session expired');
      }

      return json.decode(response.body);
    } catch (e) {
      debugPrint('❌ Send message error: $e');
      rethrow;
    }
  }

  // ✅ Send image message
  static Future<Map<String, dynamic>> sendImageMessage(
    int agentId,
    String imagePath,
  ) async {
    try {
      final token = await getToken();
      if (token == null) {
        throw Exception('Authentication required');
      }

      debugPrint('📤 Sending image to agent: $agentId');

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/usertoagentchat/send'),
      );

      request.headers['Accept'] = 'application/json';
      request.headers['Authorization'] = 'Bearer $token';

      request.files.add(await http.MultipartFile.fromPath('image', imagePath));

      request.fields['agent_id'] = agentId.toString();
      request.fields['message_type'] = 'image';
      request.fields['message'] = '';

      var streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
      );

      var response = await http.Response.fromStream(streamedResponse);

      debugPrint('📥 Image Upload: ${response.statusCode}');

      if (response.statusCode == 401) {
        throw Exception('Session expired');
      }

      return json.decode(response.body);
    } catch (e) {
      debugPrint('❌ Image send error: $e');
      rethrow;
    }
  }

  // ✅ Mark messages as read
  static Future<void> markAsRead(int agentId) async {
    try {
      final token = await getToken();
      if (token == null) return;

      await http
          .post(
            Uri.parse('$baseUrl/usertoagentchat/mark-read'),
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: json.encode({'agent_id': agentId}),
          )
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('⚠️ Mark as read error: $e');
    }
  }
}

// ============================================
// 📊 DATA MODELS (TYPE SAFE)
// ============================================

// ✅ Agent Model
class AgentModel {
  final int id;
  final String name;
  final String? email;
  final String? avatar;
  final String? status;
  final int unreadCount;
  bool isVerified;

  AgentModel({
    required this.id,
    required this.name,
    this.email,
    this.avatar,
    this.status,
    this.unreadCount = 0,
    this.isVerified = false,
  });

  factory AgentModel.fromJson(Map<String, dynamic> json) {
    return AgentModel(
      id: AgentChatApiService._parseInt(json['id'], 0),
      name: json['name']?.toString() ?? 'Unknown Agent',
      email: json['email']?.toString(),
      avatar: json['avatar']?.toString(),
      status: json['status']?.toString() ?? 'available',
      unreadCount: AgentChatApiService._parseInt(json['unread_count'], 0),
      isVerified: AgentChatApiService._parseBool(json['is_verified']),
    );
  }
}

// ✅ Message Model (TYPE SAFE - CRITICAL FIX)
class MessageModel {
  final int id;
  final int senderId;
  final String senderType;
  final int receiverId;
  final String message;
  final String messageType;
  final String? imageUrl;
  final bool isRead;
  final String createdAt;

  MessageModel({
    required this.id,
    required this.senderId,
    required this.senderType,
    required this.receiverId,
    required this.message,
    required this.messageType,
    this.imageUrl,
    required this.isRead,
    required this.createdAt,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    // ✅ CRITICAL FIX: Safe type conversion
    String? processedImageUrl;

    if (json['image_url'] != null && json['image_url'].toString().isNotEmpty) {
      String rawUrl = json['image_url'].toString();

      if (rawUrl.startsWith('http://') || rawUrl.startsWith('https://')) {
        processedImageUrl = rawUrl;
      } else {
        processedImageUrl = AgentChatApiService.getFullImageUrl(rawUrl);
      }
    }

    return MessageModel(
      id: AgentChatApiService._parseInt(json['id'], 0),
      senderId: AgentChatApiService._parseInt(json['sender_id'], 0),
      senderType: json['sender_type']?.toString() ?? 'user',
      receiverId: AgentChatApiService._parseInt(json['receiver_id'], 0),
      message: json['message']?.toString() ?? '',
      messageType: json['message_type']?.toString() ?? 'text',
      imageUrl: processedImageUrl,
      isRead: AgentChatApiService._parseBool(json['is_read']),
      createdAt:
          json['created_at']?.toString() ?? DateTime.now().toIso8601String(),
    );
  }

  bool get hasValidImage =>
      messageType == 'image' && imageUrl != null && imageUrl!.isNotEmpty;

  bool get isTextMessage => messageType == 'text' && message.isNotEmpty;
}

class AgentListScreen extends StatefulWidget {
  const AgentListScreen({Key? key}) : super(key: key);

  @override
  State<AgentListScreen> createState() => _AgentListScreenState();
}

class _AgentListScreenState extends State<AgentListScreen> {
  final TextEditingController _searchController = TextEditingController();

  List<AgentModel> _agents = [];
  List<AgentModel> _filteredAgents = [];
  bool _isLoading = true;
  String? _errorMessage;
  Color _themeColor = const Color(0xFF4361EE);

  @override
  void initState() {
    super.initState();
    debugPrint('🎬 AgentListScreen initialized');
    _searchController.addListener(_onSearchChanged);
    _initializeApp();
  }

  @override
  void dispose() {
    debugPrint('🛑 AgentListScreen disposed');
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      _filteredAgents = query.isEmpty
          ? List.from(_agents)
          : _agents
                .where(
                  (agent) =>
                      agent.name.toLowerCase().contains(query) ||
                      (agent.email?.toLowerCase().contains(query) ?? false),
                )
                .toList();
    });
  }

  Future<void> _initializeApp() async {
    await _loadThemeColor();
    await _loadAgentsList();
  }

  Future<void> _loadThemeColor() async {
    try {
      final themeData = await AgentChatApiService.getThemeColor();
      if (mounted && themeData['success'] == true) {
        setState(() => _themeColor = themeData['color']);
      }
    } catch (e) {
      debugPrint('⚠️ Theme load failed: $e');
    }
  }

  Future<void> _loadAgentsList() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await AgentChatApiService.getAgentsList();

      if (response['success'] == true && response['data'] != null) {
        final List<dynamic> agentsList = response['data']['agents'] ?? [];

        if (agentsList.isEmpty) {
          if (!mounted) return;
          setState(() {
            _agents = [];
            _filteredAgents = [];
            _isLoading = false;
          });
          return;
        }

        List<AgentModel> loadedAgents = [];

        for (var agentData in agentsList) {
          try {
            var agent = AgentModel.fromJson(agentData);

            try {
              final verifyResult =
                  await AgentChatApiService.checkAgentVerification(agent.id);
              agent.isVerified = verifyResult['verified'] ?? false;
            } catch (e) {
              debugPrint('⚠️ Verification check failed: $e');
              agent.isVerified = false;
            }

            loadedAgents.add(agent);
          } catch (e) {
            debugPrint('⚠️ Failed to parse agent: $e');
            continue;
          }
        }

        if (!mounted) return;

        setState(() {
          _agents = loadedAgents;
          _filteredAgents = List.from(_agents);
          _isLoading = false;
        });

        debugPrint('✅ Agents loaded: ${_agents.length} total');
      } else {
        throw Exception('Invalid response');
      }
    } catch (e) {
      debugPrint('❌ Load agents error: $e');

      if (!mounted) return;

      setState(() {
        _errorMessage = e
            .toString()
            .replaceAll('Exception:', '')
            .replaceAll('Exception ', '')
            .trim();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Agents${_agents.isNotEmpty ? ' (${_agents.length})' : ''}',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        backgroundColor: _themeColor,
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _initializeApp,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: _isLoading
                ? _buildLoadingWidget()
                : _errorMessage != null
                ? _buildErrorWidget()
                : _filteredAgents.isEmpty
                ? _buildEmptyWidget()
                : _buildAgentsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search agents...',
          prefixIcon: Icon(Icons.search, color: _themeColor),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => _searchController.clear(),
                )
              : null,
          filled: true,
          fillColor: Colors.grey[100],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide(color: _themeColor, width: 2),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: _themeColor, strokeWidth: 3),
          const SizedBox(height: 16),
          Text('Loading agents...', style: TextStyle(color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 80, color: Colors.red[400]),
            const SizedBox(height: 24),
            Text(
              'Oops! Something went wrong',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(_errorMessage ?? 'Unknown error', textAlign: TextAlign.center),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _initializeApp,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _themeColor,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 24),
          Text(
            _searchController.text.isEmpty
                ? 'No agents available'
                : 'No agents found',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            _searchController.text.isEmpty
                ? 'There are no agents to display'
                : 'Try a different search term',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildAgentsList() {
    return RefreshIndicator(
      onRefresh: _initializeApp,
      color: _themeColor,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _filteredAgents.length,
        itemBuilder: (context, index) =>
            _buildAgentCard(_filteredAgents[index]),
      ),
    );
  }

  Widget _buildAgentCard(AgentModel agent) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _openChat(agent),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _buildAgentAvatar(agent),
              const SizedBox(width: 12),
              Expanded(child: _buildAgentInfo(agent)),
              _buildTrailing(agent),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAgentAvatar(AgentModel agent) {
    return Stack(
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: _themeColor.withOpacity(0.2),
          child: agent.avatar != null && agent.avatar!.isNotEmpty
              ? ClipOval(
                  child: Image.network(
                    AgentChatApiService.getFullImageUrl(agent.avatar),
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        Icon(Icons.person, size: 28, color: _themeColor),
                  ),
                )
              : Icon(Icons.person, size: 28, color: _themeColor),
        ),
        if (agent.isVerified)
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: const Icon(Icons.verified, color: Colors.blue, size: 16),
            ),
          ),
      ],
    );
  }

  Widget _buildAgentInfo(AgentModel agent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                agent.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: agent.isVerified
                    ? Colors.blue.withOpacity(0.1)
                    : Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: agent.isVerified ? Colors.blue : Colors.grey,
                  width: 1,
                ),
              ),
              child: Text(
                agent.isVerified ? 'Verified' : 'Unverified',
                style: TextStyle(
                  color: agent.isVerified ? Colors.blue : Colors.grey,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(
              Icons.circle,
              size: 8,
              color: agent.status == 'available' ? Colors.green : Colors.grey,
            ),
            const SizedBox(width: 4),
            Text(
              agent.status == 'available' ? 'Online' : 'Offline',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        if (agent.email != null && agent.email!.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            agent.email!,
            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }

  Widget _buildTrailing(AgentModel agent) {
    if (agent.unreadCount > 0) {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(16),
        ),
        constraints: const BoxConstraints(minWidth: 24),
        child: Text(
          '${agent.unreadCount}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    return const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey);
  }

  void _openChat(AgentModel agent) {
    debugPrint('💬 Opening chat with: ${agent.name}');

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            ChatBoxScreen(agent: agent, themeColor: _themeColor),
      ),
    ).then((_) => _loadAgentsList());
  }
}

class ChatBoxScreen extends StatefulWidget {
  final AgentModel agent;
  final Color themeColor;

  const ChatBoxScreen({Key? key, required this.agent, required this.themeColor})
    : super(key: key);

  @override
  State<ChatBoxScreen> createState() => _ChatBoxScreenState();
}

class _ChatBoxScreenState extends State<ChatBoxScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();

  List<MessageModel> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  Timer? _refreshTimer;
  int _lastMessageCount = 0;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    debugPrint('💬 ChatBox initialized for: ${widget.agent.name}');
    _initializeChat();
  }

  @override
  void dispose() {
    debugPrint('💬 ChatBox disposed');
    _refreshTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeChat() async {
    await _loadMessages();
    await AgentChatApiService.markAsRead(widget.agent.id);
    _startAutoRefresh();
  }

  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted && !_isSending) {
        _loadMessagesQuietly();
      }
    });
  }

  // ✅ FIXED: Better error handling in message loading
  Future<void> _loadMessages() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      debugPrint('📥 Loading messages for agent ${widget.agent.id}...');

      final response = await AgentChatApiService.getMessages(widget.agent.id);

      if (response['success'] == true && response['data'] != null) {
        final List<dynamic> messageList = response['data']['messages'] ?? [];

        if (!mounted) return;

        // ✅ CRITICAL FIX: Safe message parsing with error handling
        List<MessageModel> loadedMessages = [];
        for (var msgData in messageList) {
          try {
            final msg = MessageModel.fromJson(msgData);
            loadedMessages.add(msg);
          } catch (e) {
            debugPrint('⚠️ Failed to parse message: $e');
            debugPrint('   Data: $msgData');
            continue; // Skip malformed messages
          }
        }

        setState(() {
          _messages = loadedMessages;
          _lastMessageCount = _messages.length;
          _isLoading = false;
        });

        debugPrint('✅ Loaded ${_messages.length} messages');
        _scrollToBottom();
      } else {
        throw Exception(response['message'] ?? 'Failed to load');
      }
    } catch (e) {
      debugPrint('❌ Load messages error: $e');

      if (!mounted) return;

      setState(() {
        _errorMessage = e.toString().replaceAll('Exception:', '').trim();
        _isLoading = false;
      });

      _showErrorSnackBar('Failed to load: ${e.toString()}');
    }
  }

  // ✅ FIXED: Silent refresh with better error handling
  Future<void> _loadMessagesQuietly() async {
    try {
      final response = await AgentChatApiService.getMessages(widget.agent.id);

      if (response['success'] == true && response['data'] != null) {
        final List<dynamic> messageList = response['data']['messages'] ?? [];

        // ✅ Safe parsing
        List<MessageModel> newMessages = [];
        for (var msgData in messageList) {
          try {
            newMessages.add(MessageModel.fromJson(msgData));
          } catch (e) {
            debugPrint('⚠️ Skip malformed message in refresh');
            continue;
          }
        }

        if (mounted && newMessages.length != _lastMessageCount) {
          debugPrint(
            '🔔 New messages: ${newMessages.length} (was: $_lastMessageCount)',
          );

          setState(() {
            _messages = newMessages;
            _lastMessageCount = newMessages.length;
          });

          _scrollToBottom();
        }
      }
    } catch (e) {
      debugPrint('⚠️ Silent refresh failed: $e');
      // Silent fail - don't show error to user
    }
  }

  Future<void> _sendTextMessage() async {
    final text = _messageController.text.trim();

    if (text.isEmpty || _isSending) return;

    setState(() {
      _isSending = true;
      _messageController.clear();
    });

    try {
      final response = await AgentChatApiService.sendMessage(
        widget.agent.id,
        text,
      );

      if (response['success'] == true && response['data'] != null) {
        try {
          final newMessage = MessageModel.fromJson(response['data']);

          if (!mounted) return;

          setState(() {
            _messages.add(newMessage);
            _lastMessageCount = _messages.length;
            _isSending = false;
          });

          _scrollToBottom();
          _showSuccessSnackBar('Message sent');
        } catch (e) {
          debugPrint('⚠️ Failed to parse sent message: $e');
          if (!mounted) return;
          setState(() => _isSending = false);
          // Still refresh to get the message
          await _loadMessages();
        }
      } else {
        throw Exception(response['message'] ?? 'Failed to send');
      }
    } catch (e) {
      debugPrint('❌ Send error: $e');

      if (!mounted) return;

      setState(() => _isSending = false);
      _showErrorSnackBar('Failed to send: ${e.toString()}');
    }
  }

  Future<void> _pickAndSendImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image == null) return;

      setState(() => _isSending = true);
      _showInfoSnackBar('Uploading image...');

      final response = await AgentChatApiService.sendImageMessage(
        widget.agent.id,
        image.path,
      );

      if (response['success'] == true && response['data'] != null) {
        try {
          final newMessage = MessageModel.fromJson(response['data']);

          if (!mounted) return;

          setState(() {
            _messages.add(newMessage);
            _lastMessageCount = _messages.length;
            _isSending = false;
          });

          _scrollToBottom();
          _showSuccessSnackBar('Image sent');

          // Force refresh
          Future.delayed(const Duration(seconds: 1), () {
            if (mounted) _loadMessagesQuietly();
          });
        } catch (e) {
          debugPrint('⚠️ Failed to parse sent image: $e');
          if (!mounted) return;
          setState(() => _isSending = false);
          await _loadMessages();
        }
      } else {
        throw Exception(response['message'] ?? 'Upload failed');
      }
    } catch (e) {
      debugPrint('❌ Image send error: $e');

      if (!mounted) return;

      setState(() => _isSending = false);
      _showErrorSnackBar('Failed to send image: ${e.toString()}');
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 150), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message, maxLines: 2)),
          ],
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showInfoSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                strokeWidth: 2,
              ),
            ),
            const SizedBox(width: 12),
            Text(message),
          ],
        ),
        backgroundColor: widget.themeColor,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(child: _buildMessagesArea()),
          _buildMessageInput(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: widget.themeColor.withOpacity(0.2),
                child: widget.agent.avatar != null
                    ? ClipOval(
                        child: Image.network(
                          AgentChatApiService.getFullImageUrl(
                            widget.agent.avatar,
                          ),
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.person,
                            size: 20,
                            color: widget.themeColor,
                          ),
                        ),
                      )
                    : Icon(Icons.person, size: 20, color: widget.themeColor),
              ),
              if (widget.agent.isVerified)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.verified,
                      color: Colors.blue,
                      size: 14,
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
                        widget.agent.name,
                        style: const TextStyle(fontSize: 16),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (widget.agent.isVerified) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.verified, size: 16, color: Colors.white),
                    ],
                  ],
                ),
                Text(
                  widget.agent.status == 'available' ? 'Online' : 'Offline',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
      backgroundColor: widget.themeColor,
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _isLoading ? null : _loadMessages,
        ),
      ],
    );
  }

  Widget _buildMessagesArea() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: widget.themeColor),
            const SizedBox(height: 16),
            const Text('Loading messages...'),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 60, color: Colors.red[400]),
              const SizedBox(height: 16),
              const Text(
                'Failed to load messages',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(_errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadMessages,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.themeColor,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('No messages yet', style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 8),
            Text(
              'Start a conversation!',
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadMessages,
      color: widget.themeColor,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: _messages.length,
        itemBuilder: (context, index) => _buildMessageBubble(_messages[index]),
      ),
    );
  }
  // ============================================
  // 📦 COMPLETE AGENT CHAT - PART 4/5 (FIXED)
  // Message Bubble Display - Continues from Part 3
  // ============================================

  // ✅ Build message bubble
  Widget _buildMessageBubble(MessageModel message) {
    final isMe = message.senderType == 'user';
    final hasImage = message.hasValidImage;
    final hasText = message.isTextMessage;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.all(hasImage && !hasText ? 4 : 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isMe ? widget.themeColor : Colors.grey[300],
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasImage) _buildImageContent(message, isMe),
            if (hasText) _buildTextContent(message, isMe),
            _buildMessageFooter(message, isMe),
          ],
        ),
      ),
    );
  }

  Widget _buildImageContent(MessageModel message, bool isMe) {
    return Padding(
      padding: EdgeInsets.only(bottom: message.isTextMessage ? 8 : 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: GestureDetector(
          onTap: () {
            if (message.imageUrl != null) {
              _showFullImage(message.imageUrl!);
            }
          },
          child: Container(
            constraints: const BoxConstraints(maxWidth: 280, maxHeight: 400),
            child: Image.network(
              message.imageUrl!,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;

                return Container(
                  width: 250,
                  height: 200,
                  color: isMe
                      ? widget.themeColor.withOpacity(0.3)
                      : Colors.grey[200],
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          color: isMe ? Colors.white : widget.themeColor,
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                              : null,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Loading image...',
                          style: TextStyle(
                            color: isMe ? Colors.white70 : Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 250,
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.broken_image,
                        size: 60,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Failed to load image',
                        style: TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      TextButton.icon(
                        onPressed: () => setState(() {}),
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text(
                          'Retry',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextContent(MessageModel message, bool isMe) {
    return Padding(
      padding: message.hasValidImage
          ? const EdgeInsets.only(top: 4)
          : EdgeInsets.zero,
      child: Text(
        message.message,
        style: TextStyle(
          color: isMe ? Colors.white : Colors.black87,
          fontSize: 15,
          height: 1.4,
        ),
      ),
    );
  }

  Widget _buildMessageFooter(MessageModel message, bool isMe) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _formatTime(message.createdAt),
            style: TextStyle(
              color: isMe ? Colors.white70 : Colors.black54,
              fontSize: 11,
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 4),
            Icon(
              message.isRead ? Icons.done_all : Icons.done,
              size: 14,
              color: message.isRead ? Colors.blue[200] : Colors.white70,
            ),
          ],
        ],
      ),
    );
  }

  String _formatTime(String isoString) {
    try {
      final dateTime = DateTime.parse(isoString);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

      final hour = dateTime.hour.toString().padLeft(2, '0');
      final minute = dateTime.minute.toString().padLeft(2, '0');
      final time = '$hour:$minute';

      if (messageDate == today) {
        return time;
      } else if (messageDate == today.subtract(const Duration(days: 1))) {
        return 'Yesterday $time';
      } else {
        final day = dateTime.day.toString().padLeft(2, '0');
        final month = dateTime.month.toString().padLeft(2, '0');
        return '$day/$month $time';
      }
    } catch (e) {
      return '';
    }
  }

  void _showFullImage(String imageUrl) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
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
                      child: CircularProgressIndicator(
                        color: widget.themeColor,
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                            : null,
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.broken_image,
                            size: 80,
                            color: Colors.white54,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Failed to load image',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            Positioned(
              top: 40,
              right: 16,
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 28),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Pinch to zoom',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              onPressed: _isSending
                  ? null
                  : () => _pickAndSendImage(ImageSource.gallery),
              icon: Icon(
                Icons.image,
                color: _isSending ? Colors.grey : widget.themeColor,
              ),
            ),
            IconButton(
              onPressed: _isSending
                  ? null
                  : () => _pickAndSendImage(ImageSource.camera),
              icon: Icon(
                Icons.camera_alt,
                color: _isSending ? Colors.grey : widget.themeColor,
              ),
            ),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _messageController,
                  decoration: const InputDecoration(
                    hintText: 'Type a message...',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                  maxLines: null,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendTextMessage(),
                  enabled: !_isSending,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                color: _isSending ? Colors.grey : widget.themeColor,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: _isSending ? null : _sendTextMessage,
                icon: _isSending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.send, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================
// END OF PART 4/5 (FIXED)
// Part 5 remains same
// ============================================
