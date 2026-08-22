// ═══════════════════════════════════════════════════════════════
// FRIEND REQUESTS PAGE - FIXED VERSION
// Photo URLs now come directly from API response
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'home_page.dart';
import 'config/api_config.dart';

const Duration _timeout = Duration(seconds: 15);
const Duration _autoRefreshInterval = Duration(seconds: 30);

// ═══════════════════════════════════════════════════════════════
// THEME MODEL
// ═══════════════════════════════════════════════════════════════

class AppTheme {
  final String colorCode;
  final String name;

  AppTheme({required this.colorCode, required this.name});

  factory AppTheme.fromJson(Map<String, dynamic> json) {
    return AppTheme(
      colorCode: json['color_code']?.toString() ?? '#4361EE',
      name: json['name']?.toString() ?? 'Default Theme',
    );
  }

  factory AppTheme.defaultTheme() {
    return AppTheme(colorCode: '#4361EE', name: 'Default Blue');
  }

  Color get primary {
    try {
      String hex = colorCode.replaceAll('#', '');
      if (hex.length == 6) hex = 'FF$hex';
      return Color(int.parse(hex, radix: 16));
    } catch (e) {
      debugPrint('⚠️ Invalid color code: $colorCode');
      return const Color(0xFF4361EE);
    }
  }

  Color get light => Color.lerp(primary, Colors.white, 0.3) ?? primary;
  Color get dark => Color.lerp(primary, Colors.black, 0.2) ?? primary;

  List<Color> get gradient => [primary, light];

  Color get cardBackground => Colors.white;
  Color get scaffoldBackground => Colors.grey[50]!;
}

// ═══════════════════════════════════════════════════════════════
// FRIEND REQUEST MODEL - FIXED
// Now includes photo URL directly from API
// ═══════════════════════════════════════════════════════════════

class FriendRequest {
  final int id;
  final int senderId;
  final String senderName;
  final String senderEmail;
  final String senderPhoto; // Now non-nullable with default
  final DateTime createdAt;
  final String status;

  FriendRequest({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.senderEmail,
    required this.senderPhoto,
    required this.createdAt,
    required this.status,
  });

  factory FriendRequest.fromJson(Map<String, dynamic> json) {
    try {
      final sender = json['sender'] as Map<String, dynamic>? ?? {};

      // Get photo URL from API response with fallback
      String photoUrl = ApiConfig.avatarUrl(sender['photo']?.toString());

      return FriendRequest(
        id: _parseInt(json['id']) ?? 0,
        senderId: _parseInt(sender['id']) ?? 0,
        senderName: sender['name']?.toString() ?? 'Unknown User',
        senderEmail: sender['email']?.toString() ?? 'no-email@example.com',
        senderPhoto: photoUrl,
        createdAt: _parseDateTime(json['created_at']) ?? DateTime.now(),
        status: json['status']?.toString() ?? 'pending',
      );
    } catch (e) {
      debugPrint('❌ Error parsing FriendRequest: $e');
      rethrow;
    }
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inSeconds < 60) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    if (difference.inDays < 30)
      return '${(difference.inDays / 7).floor()}w ago';

    return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
  }

  @override
  String toString() {
    return 'FriendRequest(id: $id, senderId: $senderId, name: $senderName, photo: $senderPhoto)';
  }
}

// ═══════════════════════════════════════════════════════════════
// API RESPONSE MODEL
// ═══════════════════════════════════════════════════════════════

class ApiResponse<T> {
  final bool success;
  final String? message;
  final T? data;
  final int statusCode;

  ApiResponse({
    required this.success,
    this.message,
    this.data,
    required this.statusCode,
  });

  bool get isUnauthorized => statusCode == 401;
  bool get isServerError => statusCode >= 500;
  bool get isClientError => statusCode >= 400 && statusCode < 500;
  bool get isNetworkError => statusCode == 0;
}

// ═══════════════════════════════════════════════════════════════
// FRIEND REQUEST API SERVICE
// ═══════════════════════════════════════════════════════════════

class FriendRequestApi {
  /// Fetch all pending friend requests
  static Future<ApiResponse<List<FriendRequest>>> fetchRequests(
    String token,
  ) async {
    try {
      final url = ApiConfig.friendRequestsReceived;
      debugPrint('');
      debugPrint('═══════════════════════════════════════════════════');
      debugPrint('📥 FETCHING FRIEND REQUESTS');
      debugPrint('═══════════════════════════════════════════════════');
      debugPrint('🔗 URL: $url');
      debugPrint('═══════════════════════════════════════════════════');

      final response = await http
          .get(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(_timeout);

      debugPrint('📥 Response Status: ${response.statusCode}');
      debugPrint('📥 Response Body: ${response.body}');
      debugPrint('═══════════════════════════════════════════════════');

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;

        if (data['success'] == true) {
          final items = data['data'] as List? ?? [];
          final requests = items
              .map((e) => FriendRequest.fromJson(e as Map<String, dynamic>))
              .toList();

          debugPrint(
            '✅ Successfully loaded ${requests.length} friend requests',
          );

          // Log photo URLs for debugging
          for (var req in requests) {
            debugPrint('👤 ${req.senderName} - Photo: ${req.senderPhoto}');
          }

          return ApiResponse(
            success: true,
            data: requests,
            message: data['message']?.toString() ?? 'Requests loaded',
            statusCode: response.statusCode,
          );
        }
      }

      return ApiResponse(
        success: false,
        message: 'Failed to load requests',
        statusCode: response.statusCode,
      );
    } on TimeoutException {
      debugPrint('⏱️ Request timeout');
      return ApiResponse(
        success: false,
        message: 'Request timeout. Please check your connection.',
        statusCode: 0,
      );
    } catch (e) {
      debugPrint('❌ Fetch requests error: $e');
      return ApiResponse(
        success: false,
        message: 'Network error: ${e.toString()}',
        statusCode: 0,
      );
    }
  }

  /// Accept a friend request
  static Future<ApiResponse<void>> acceptRequest(
    String token,
    int senderId,
  ) async {
    try {
      final url = ApiConfig.friendAccept;

      final response = await http
          .post(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: json.encode({'sender_id': senderId}),
          )
          .timeout(_timeout);

      debugPrint('✅ Accept Response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return ApiResponse(
          success: data['success'] == true,
          message: data['message']?.toString() ?? 'Friend request accepted!',
          statusCode: response.statusCode,
        );
      }

      return ApiResponse(
        success: false,
        message: 'Failed to accept request',
        statusCode: response.statusCode,
      );
    } catch (e) {
      debugPrint('❌ Accept error: $e');
      return ApiResponse(
        success: false,
        message: 'Error: ${e.toString()}',
        statusCode: 0,
      );
    }
  }

  /// Reject a friend request
  static Future<ApiResponse<void>> rejectRequest(
    String token,
    int senderId,
  ) async {
    try {
      final url = ApiConfig.friendReject;

      final response = await http
          .post(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: json.encode({'sender_id': senderId}),
          )
          .timeout(_timeout);

      debugPrint('❌ Reject Response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return ApiResponse(
          success: data['success'] == true,
          message: data['message']?.toString() ?? 'Friend request rejected',
          statusCode: response.statusCode,
        );
      }

      return ApiResponse(
        success: false,
        message: 'Failed to reject request',
        statusCode: response.statusCode,
      );
    } catch (e) {
      debugPrint('❌ Reject error: $e');
      return ApiResponse(
        success: false,
        message: 'Error: ${e.toString()}',
        statusCode: 0,
      );
    }
  }
}

// ═══════════════════════════════════════════════════════════════
// THEME API SERVICE
// ═══════════════════════════════════════════════════════════════

class ThemeApi {
  static AppTheme? _cachedTheme;
  static DateTime? _cacheTime;

  static Future<AppTheme> fetchTheme() async {
    if (_cachedTheme != null && _cacheTime != null) {
      final age = DateTime.now().difference(_cacheTime!);
      if (age < const Duration(minutes: 5)) {
        return _cachedTheme!;
      }
    }

    try {
      final url = ApiConfig.themeChange;

      final response = await http
          .get(
            Uri.parse(url),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;

        if (data['status'] == true || data['success'] == true) {
          final themeData = data['data'] as Map<String, dynamic>? ?? {};
          final theme = AppTheme.fromJson(themeData);

          _cachedTheme = theme;
          _cacheTime = DateTime.now();

          return theme;
        }
      }

      return AppTheme.defaultTheme();
    } catch (e) {
      debugPrint('❌ Theme fetch error: $e');
      return AppTheme.defaultTheme();
    }
  }
}

// ═══════════════════════════════════════════════════════════════
// FRIEND REQUESTS PAGE - MAIN WIDGET
// ═══════════════════════════════════════════════════════════════

class FriendRequestsPage extends StatefulWidget {
  final String? authToken;

  const FriendRequestsPage({Key? key, required this.authToken})
    : super(key: key);

  @override
  State<FriendRequestsPage> createState() => _FriendRequestsPageState();
}

class _FriendRequestsPageState extends State<FriendRequestsPage> {
  AppTheme? _theme;
  List<FriendRequest> _requests = [];

  bool _isLoading = true;
  bool _isProcessing = false;
  String? _errorMessage;

  Timer? _autoRefreshTimer;

  String? get _authToken => widget.authToken;

  bool get _isAuthenticated {
    if (_authToken == null) return false;
    if (_authToken!.isEmpty) return false;
    if (_authToken!.length < 20) return false;
    return true;
  }

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _initialize() async {
    await _loadTheme();

    if (_isAuthenticated) {
      await _loadFriendRequests();
      _startAutoRefresh();
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Authentication required';
      });
    }
  }

  Future<void> _loadTheme() async {
    try {
      final theme = await ThemeApi.fetchTheme();
      if (mounted) {
        setState(() => _theme = theme);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _theme = AppTheme.defaultTheme());
      }
    }
  }

  Future<void> _loadFriendRequests() async {
    if (!_isAuthenticated) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Please login to view friend requests';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await FriendRequestApi.fetchRequests(_authToken!);

      if (!mounted) return;

      if (response.success && response.data != null) {
        setState(() {
          _requests = response.data!;
          _isLoading = false;
        });

        debugPrint('✅ Loaded ${_requests.length} requests with photos');
      } else {
        setState(() {
          _errorMessage = response.message ?? 'Failed to load requests';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(_autoRefreshInterval, (_) {
      if (_isAuthenticated && !_isLoading && mounted) {
        _loadFriendRequests();
      }
    });
  }

  Future<void> _handleAccept(FriendRequest request) async {
    if (!_isAuthenticated || _isProcessing) return;

    final confirmed = await _showConfirmDialog(
      title: 'Accept Friend Request',
      message: 'Do you want to be friends with ${request.senderName}?',
      confirmText: 'Accept',
      isDestructive: false,
    );

    if (!confirmed || !mounted) return;

    setState(() => _isProcessing = true);

    try {
      final response = await FriendRequestApi.acceptRequest(
        _authToken!,
        request.senderId,
      );

      if (!mounted) return;

      if (response.success) {
        setState(() {
          _requests.removeWhere((r) => r.id == request.id);
          _isProcessing = false;
        });

        _showSnackbar(
          '✅ You are now friends with ${request.senderName}!',
          isError: false,
        );
      } else {
        setState(() => _isProcessing = false);
        _showSnackbar(
          response.message ?? 'Failed to accept request',
          isError: true,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        _showSnackbar('Error: ${e.toString()}', isError: true);
      }
    }
  }

  Future<void> _handleReject(FriendRequest request) async {
    if (!_isAuthenticated || _isProcessing) return;

    final confirmed = await _showConfirmDialog(
      title: 'Reject Friend Request',
      message:
          'Are you sure you want to reject ${request.senderName}\'s request?',
      confirmText: 'Reject',
      isDestructive: true,
    );

    if (!confirmed || !mounted) return;

    setState(() => _isProcessing = true);

    try {
      final response = await FriendRequestApi.rejectRequest(
        _authToken!,
        request.senderId,
      );

      if (!mounted) return;

      if (response.success) {
        setState(() {
          _requests.removeWhere((r) => r.id == request.id);
          _isProcessing = false;
        });

        _showSnackbar(
          'Request from ${request.senderName} rejected',
          isError: false,
        );
      } else {
        setState(() => _isProcessing = false);
        _showSnackbar(
          response.message ?? 'Failed to reject request',
          isError: true,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        _showSnackbar('Error: ${e.toString()}', isError: true);
      }
    }
  }

  Future<bool> _showConfirmDialog({
    required String title,
    required String message,
    required String confirmText,
    required bool isDestructive,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDestructive
                      ? Colors.red
                      : _theme?.primary ?? Colors.blue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
                child: Text(
                  confirmText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showSnackbar(String message, {required bool isError}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message, style: const TextStyle(fontSize: 14)),
            ),
          ],
        ),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: Duration(seconds: isError ? 4 : 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = _theme ?? AppTheme.defaultTheme();

    return Scaffold(
      backgroundColor: theme.scaffoldBackground,
      appBar: _buildAppBar(theme),
      body: _buildBody(theme),
    );
  }

  PreferredSizeWidget _buildAppBar(AppTheme theme) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(64),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: theme.gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: theme.primary.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
              size: 22,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'Friend Requests',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          centerTitle: false,
          actions: [
            if (_isAuthenticated && !_isLoading)
              IconButton(
                icon: const Icon(
                  Icons.refresh_rounded,
                  color: Colors.white,
                  size: 26,
                ),
                onPressed: _loadFriendRequests,
                tooltip: 'Refresh',
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(AppTheme theme) {
    if (_isLoading && _requests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: theme.primary, strokeWidth: 3),
            const SizedBox(height: 20),
            Text(
              'Loading friend requests...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null && _requests.isEmpty) {
      return _ErrorView(
        theme: theme,
        message: _errorMessage!,
        onRetry: _loadFriendRequests,
      );
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _HeaderCard(theme: theme, requestCount: _requests.length),
            const SizedBox(height: 20),
            Expanded(
              child: _requests.isEmpty
                  ? _EmptyStateView(theme: theme)
                  : _RequestsList(
                      theme: theme,
                      requests: _requests,
                      isProcessing: _isProcessing,
                      onAccept: _handleAccept,
                      onReject: _handleReject,
                      onRefresh: _loadFriendRequests,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// UI COMPONENTS
// ═══════════════════════════════════════════════════════════════

class _HeaderCard extends StatelessWidget {
  final AppTheme theme;
  final int requestCount;

  const _HeaderCard({required this.theme, required this.requestCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: theme.gradient),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: theme.primary.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.25),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.people_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pending Requests',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$requestCount ${requestCount == 1 ? "request" : "requests"} waiting',
                  style: const TextStyle(fontSize: 14, color: Colors.white70),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(25),
            ),
            child: Text(
              '$requestCount',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: theme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RequestsList extends StatelessWidget {
  final AppTheme theme;
  final List<FriendRequest> requests;
  final bool isProcessing;
  final Function(FriendRequest) onAccept;
  final Function(FriendRequest) onReject;
  final VoidCallback onRefresh;

  const _RequestsList({
    required this.theme,
    required this.requests,
    required this.isProcessing,
    required this.onAccept,
    required this.onReject,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      color: theme.primary,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: requests.length,
        itemBuilder: (context, index) {
          final request = requests[index];

          return _RequestCard(
            key: ValueKey(request.id),
            request: request,
            theme: theme,
            isProcessing: isProcessing,
            onAccept: () => onAccept(request),
            onReject: () => onReject(request),
          );
        },
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final FriendRequest request;
  final AppTheme theme;
  final bool isProcessing;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _RequestCard({
    Key? key,
    required this.request,
    required this.theme,
    required this.isProcessing,
    required this.onAccept,
    required this.onReject,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey[200]!, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.grey[100]!,
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Row(
              children: [
                _buildAvatar(),
                const SizedBox(width: 16),
                Expanded(child: _buildInfo()),
              ],
            ),
            const SizedBox(height: 18),
            _buildActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    final photoUrl = request.senderPhoto.trim();

    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: theme.primary.withOpacity(0.3), width: 2.5),
      ),
      child: ClipOval(
        child: photoUrl.isNotEmpty &&
                !photoUrl.endsWith('/uploads/avator.jpg') &&
                !photoUrl.endsWith('/avator.jpg')
            ? Image.network(
                photoUrl,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: theme.primary,
                      value: progress.expectedTotalBytes != null
                          ? progress.cumulativeBytesLoaded /
                              progress.expectedTotalBytes!
                          : null,
                    ),
                  );
                },
                errorBuilder: (context, error, stack) {
                  return Image.asset('assets/avator.jpg', fit: BoxFit.cover);
                },
              )
            : Image.asset('assets/avator.jpg', fit: BoxFit.cover),
      ),
    );
  }

  Widget _buildInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          request.senderName,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.3,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 5),

        const SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.access_time_rounded, size: 15, color: Colors.grey[500]),
            const SizedBox(width: 5),
            Text(
              request.timeAgo,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActions() {
    return Row(
      children: [
        Expanded(
          child: _ActionButton(
            label: 'Accept',
            icon: Icons.check_circle_outline_rounded,
            theme: theme,
            isProcessing: isProcessing,
            isPrimary: true,
            onTap: onAccept,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _ActionButton(
            label: 'Reject',
            icon: Icons.close_rounded,
            theme: theme,
            isProcessing: isProcessing,
            isPrimary: false,
            onTap: onReject,
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final AppTheme theme;
  final bool isProcessing;
  final bool isPrimary;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.theme,
    required this.isProcessing,
    required this.isPrimary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        gradient: isPrimary && !isProcessing
            ? LinearGradient(colors: theme.gradient)
            : null,
        color: isPrimary
            ? (isProcessing ? Colors.grey[300] : null)
            : (isProcessing ? Colors.grey[200] : Colors.grey[100]),
        borderRadius: BorderRadius.circular(14),
        border: !isPrimary
            ? Border.all(color: Colors.grey[300]!, width: 1.5)
            : null,
        boxShadow: isPrimary && !isProcessing
            ? [
                BoxShadow(
                  color: theme.primary.withOpacity(0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isProcessing ? null : onTap,
          borderRadius: BorderRadius.circular(14),
          child: Center(
            child: isProcessing && isPrimary
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        icon,
                        color: isPrimary
                            ? Colors.white
                            : (isProcessing
                                  ? Colors.grey[400]
                                  : Colors.grey[700]),
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isPrimary
                              ? Colors.white
                              : (isProcessing
                                    ? Colors.grey[400]
                                    : Colors.grey[700]),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _EmptyStateView extends StatelessWidget {
  final AppTheme theme;

  const _EmptyStateView({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.people_outline_rounded,
              size: 90,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 28),
          const Text(
            'No Friend Requests',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Text(
            'You\'re all caught up!',
            style: TextStyle(fontSize: 15, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final AppTheme theme;
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({
    required this.theme,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded, size: 90, color: Colors.red[300]),
            const SizedBox(height: 28),
            const Text(
              'Something Went Wrong',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: TextStyle(fontSize: 15, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              label: const Text(
                'Try Again',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
