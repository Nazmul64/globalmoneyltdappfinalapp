// ==================== P2P TRADING - PART 1/5 (FIXED - FINAL) ====================
// ✅ Core Models, Services, Theme Management
// ✅ Smart Cancel State Management
// ✅ Authentication & Initialization
// ✅ Payment Method Model with Number Support
// ✅ FIXED: Agent Payment Methods Loading

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'p2p_withdraw_history.dart';
import 'agent_chat.dart';
import 'agentlists.dart';
import 'config/api_config.dart';

// ==================== CONFIGURATION ====================
class AppConfig {
  static const String baseUrl = ApiConfig.baseUrl;
  static const String photoBaseUrl = ApiConfig.mediaBaseUrl;
  static const Duration requestTimeout = Duration(seconds: 30);
  static const Duration statusCheckInterval = Duration(seconds: 5);
  static const int maxImageRetries = 3;
  static const int maxImageCacheSize = 50;
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
      colorCode: json['color_code'] ?? '#4361EE',
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
      return const Color(0xFF4361EE);
    } catch (e) {
      debugPrint('❌ Color parse error: $e');
      return const Color(0xFF4361EE);
    }
  }

  List<Color> get gradientColors {
    final base = primaryColor;
    return [base, Color.lerp(base, Colors.white, 0.2) ?? base];
  }

  Color get depositColor => primaryColor;

  Color get withdrawColor =>
      Color.lerp(primaryColor, Colors.green, 0.3) ?? Colors.green;
}

// ==================== THEME SERVICE ====================
class ThemeService {
  static AppTheme? _cachedTheme;

  static Future<AppTheme> fetchTheme() async {
    try {
      final response = await http
          .get(
        Uri.parse('${AppConfig.baseUrl}/themechange'),
        headers: {'Accept': 'application/json'},
      )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == true && data['data'] != null) {
          _cachedTheme = AppTheme.fromJson(data['data']);
          debugPrint('✅ Theme loaded: ${_cachedTheme!.name}');
          return _cachedTheme!;
        }
      }
    } catch (e) {
      debugPrint('❌ Theme fetch error: $e');
    }

    return _cachedTheme ??
        AppTheme(
          colorCode: '#4361EE',
          name: 'Default',
          updatedAt: DateTime.now(),
        );
  }

  static void clearCache() {
    _cachedTheme = null;
  }
}

// ==================== IMAGE CACHE MANAGER ====================
class ImageCacheManager {
  static final Map<String, ImageProvider> _cache = {};

  static ImageProvider getImage(String url) {
    if (_cache.length > AppConfig.maxImageCacheSize) {
      final keysToRemove = _cache.keys
          .take(_cache.length - AppConfig.maxImageCacheSize)
          .toList();

      for (var key in keysToRemove) {
        _cache.remove(key);
      }
    }

    if (!_cache.containsKey(url)) {
      _cache[url] = NetworkImage(url);
    }

    return _cache[url]!;
  }

  static void clearCache() {
    _cache.clear();
    debugPrint('🗑️ Image cache cleared');
  }

  static int get cacheSize => _cache.length;
}

// ==================== PAYMENT METHOD MODEL (ENHANCED) ====================
class PaymentMethod {
  final int id;
  final String methodName;
  final String methodNumber;
  final String? numberType;
  final String? fieldLabel;
  final String? usdRate;
  final double? usdRateBdt;
  final String? photo;

  PaymentMethod({
    required this.id,
    required this.methodName,
    required this.methodNumber,
    this.numberType,
    this.fieldLabel,
    this.usdRate,
    this.usdRateBdt,
    this.photo,
  });

  factory PaymentMethod.fromJson(Map<String, dynamic> json) {
    double? parsedRate;
    if (json['usd_rate_bdt'] != null) {
      parsedRate = double.tryParse(json['usd_rate_bdt'].toString());
    } else if (json['usd_rate'] != null) {
      final match = RegExp(r'([\d\.]+)').firstMatch(json['usd_rate'].toString());
      if (match != null) {
        parsedRate = double.tryParse(match.group(1) ?? '');
      }
    }

    final rawPhoto = json['photo']?.toString();
    String? fullPhotoUrl;
    if (rawPhoto != null && rawPhoto.isNotEmpty) {
      if (rawPhoto.startsWith('http://') || rawPhoto.startsWith('https://')) {
        fullPhotoUrl = rawPhoto;
      } else {
        fullPhotoUrl = '${ApiConfig.mediaBaseUrl}/uploads/paymentmethod/$rawPhoto';
      }
    }

    final label = json['number_type']?.toString() ??
        json['field_label']?.toString() ??
        json['label_type']?.toString() ??
        'Account Number';

    return PaymentMethod(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      methodName: json['method_name']?.toString() ?? json['name']?.toString() ?? 'Unknown',
      methodNumber: json['method_number']?.toString() ?? json['number']?.toString() ?? '',
      numberType: label,
      fieldLabel: label,
      usdRate: json['usd_rate']?.toString(),
      usdRateBdt: parsedRate,
      photo: fullPhotoUrl,
    );
  }

  String get labelText => fieldLabel ?? numberType ?? 'Account Number';

  String get displayName {
    if (methodNumber.isNotEmpty) {
      return '$methodName ($labelText: $methodNumber)';
    }
    return methodName;
  }

  @override
  String toString() =>
      'PaymentMethod(id: $id, name: $methodName, label: $labelText, number: $methodNumber, usdRate: $usdRateBdt)';
}

// ==================== POST CANCEL STATE MODEL ====================
class PostCancelState {
  final int postId;
  final bool hasPendingDeposit;
  final bool hasPendingWithdraw;
  final int? depositRequestId;
  final int? withdrawRequestId;
  final String? depositStatus;
  final String? withdrawStatus;
  final DateTime? lastUpdated;

  PostCancelState({
    required this.postId,
    this.hasPendingDeposit = false,
    this.hasPendingWithdraw = false,
    this.depositRequestId,
    this.withdrawRequestId,
    this.depositStatus,
    this.withdrawStatus,
    DateTime? lastUpdated,
  }) : lastUpdated = lastUpdated ?? DateTime.now();

  bool get shouldShowDepositCancel =>
      hasPendingDeposit && depositStatus == 'pending';

  bool get shouldShowWithdrawCancel =>
      hasPendingWithdraw && withdrawStatus == 'pending';

  bool get shouldShowBuySellButton =>
      !shouldShowDepositCancel && !shouldShowWithdrawCancel;

  bool get isDepositConfirmed => depositStatus == 'agent_confirmed';
  bool get isWithdrawConfirmed => withdrawStatus == 'agent_confirmed';

  PostCancelState copyWith({
    bool? hasPendingDeposit,
    bool? hasPendingWithdraw,
    int? depositRequestId,
    int? withdrawRequestId,
    String? depositStatus,
    String? withdrawStatus,
    bool clearDeposit = false,
    bool clearWithdraw = false,
  }) {
    return PostCancelState(
      postId: postId,
      hasPendingDeposit: clearDeposit
          ? false
          : (hasPendingDeposit ?? this.hasPendingDeposit),
      hasPendingWithdraw: clearWithdraw
          ? false
          : (hasPendingWithdraw ?? this.hasPendingWithdraw),
      depositRequestId: clearDeposit
          ? null
          : (depositRequestId ?? this.depositRequestId),
      withdrawRequestId: clearWithdraw
          ? null
          : (withdrawRequestId ?? this.withdrawRequestId),
      depositStatus: clearDeposit
          ? null
          : (depositStatus ?? this.depositStatus),
      withdrawStatus: clearWithdraw
          ? null
          : (withdrawStatus ?? this.withdrawStatus),
      lastUpdated: DateTime.now(),
    );
  }

  @override
  String toString() {
    return 'PostCancelState(postId: $postId, '
        'hasPendingDeposit: $hasPendingDeposit, '
        'hasPendingWithdraw: $hasPendingWithdraw, '
        'depositStatus: $depositStatus, '
        'withdrawStatus: $withdrawStatus, '
        'shouldShowBuySell: $shouldShowBuySellButton)';
  }
}

// ==================== REQUEST STATUS MODEL ====================
class RequestStatus {
  final int requestId;
  final String status;
  final int agentId;
  final String? amount;
  final String? senderAccount;
  final String? paymentMethod;
  final String? paymentNumber;

  RequestStatus({
    required this.requestId,
    required this.status,
    required this.agentId,
    this.amount,
    this.senderAccount,
    this.paymentMethod,
    this.paymentNumber,
  });

  factory RequestStatus.fromJson(Map<String, dynamic> json, String type) {
    return RequestStatus(
      requestId: json['${type}_id'] ?? 0,
      status: json['status'] ?? 'unknown',
      agentId: json['agent_id'] ?? 0,
      amount: json['amount']?.toString(),
      senderAccount: json['sender_account']?.toString(),
      paymentMethod: json['payment_method']?.toString(),
      paymentNumber: json['payment_number']?.toString(),
    );
  }

  bool get isPending => status == 'pending';
  bool get isConfirmed => status == 'agent_confirmed';
  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';
}

// ==================== AUTH SERVICE ====================
class AuthService {
  static String? _cachedToken;

  static Future<String?> getAuthToken() async {
    if (_cachedToken != null && _cachedToken!.isNotEmpty) {
      return _cachedToken;
    }

    try {
      final prefs = await SharedPreferences.getInstance();

      _cachedToken =
          prefs.getString('auth_token') ??
              prefs.getString('token') ??
              prefs.getString('access_token');

      if (_cachedToken != null && _cachedToken!.isNotEmpty) {
        debugPrint('✅ Auth token loaded: ${_cachedToken!.substring(0, 20)}...');
        return _cachedToken;
      } else {
        debugPrint('⚠️ No auth token found in storage');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Token load error: $e');
      return null;
    }
  }

  static Future<void> clearAuth() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      _cachedToken = null;
      debugPrint('🗑️ Auth cleared');
    } catch (e) {
      debugPrint('❌ Clear auth error: $e');
    }
  }

  static void cacheToken(String token) {
    _cachedToken = token;
  }
}

// ==================== API SERVICE (SUB-SECOND OPTIMIZED) ====================
class ApiService {
  static final http.Client _client = http.Client();

  static Future<http.Response> get(
      String endpoint, {
        String? authToken,
        Map<String, String>? headers,
      }) async {
    final url = Uri.parse('${AppConfig.baseUrl}$endpoint');

    final requestHeaders = {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Connection': 'keep-alive',
      if (authToken != null) 'Authorization': 'Bearer $authToken',
      ...?headers,
    };

    return await _client
        .get(url, headers: requestHeaders)
        .timeout(AppConfig.requestTimeout);
  }

  static Future<http.Response> post(
      String endpoint, {
        String? authToken,
        Map<String, dynamic>? body,
        Map<String, String>? headers,
      }) async {
    final url = Uri.parse('${AppConfig.baseUrl}$endpoint');

    final requestHeaders = {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Connection': 'keep-alive',
      if (authToken != null) 'Authorization': 'Bearer $authToken',
      ...?headers,
    };

    return await _client
        .post(
      url,
      headers: requestHeaders,
      body: body != null ? json.encode(body) : null,
    )
        .timeout(AppConfig.requestTimeout);
  }

  static Future<http.StreamedResponse> multipartPost(
      String endpoint, {
        required String authToken,
        required Map<String, String> fields,
        required List<http.MultipartFile> files,
      }) async {
    final url = Uri.parse('${AppConfig.baseUrl}$endpoint');

    var request = http.MultipartRequest('POST', url);

    request.headers.addAll({
      'Accept': 'application/json',
      'Authorization': 'Bearer $authToken',
    });

    request.fields.addAll(fields);
    request.files.addAll(files);

    debugPrint('📡 MULTIPART POST: $url');
    debugPrint('📤 Fields: $fields');
    debugPrint('📤 Files: ${files.length}');

    return await request.send().timeout(const Duration(seconds: 60));
  }
}

// ==================== P2P PAGE ====================
class P2PPage extends StatefulWidget {
  const P2PPage({super.key});

  @override
  State<P2PPage> createState() => _P2PPageState();
}

class _P2PPageState extends State<P2PPage> with SingleTickerProviderStateMixin {
  // ==================== THEME & COLORS ====================
  AppTheme? _appTheme;

  Color get themeColor => _appTheme?.primaryColor ?? const Color(0xFF4361EE);
  Color get depositColor => _appTheme?.depositColor ?? themeColor;
  Color get withdrawColor => _appTheme?.withdrawColor ?? Colors.green;
  List<Color> get primaryGradient =>
      _appTheme?.gradientColors ??
          [themeColor, Color.lerp(themeColor, Colors.white, 0.2) ?? themeColor];

  // ==================== CONTROLLERS ====================
  late TabController _tabController;
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _senderAccountController =
  TextEditingController();
  final TextEditingController _transactionIdController =
  TextEditingController();
  final TextEditingController _withdrawTransactionIdController =
  TextEditingController();
  final ImagePicker _picker = ImagePicker();

  // ==================== STATE VARIABLES ====================
  String? authToken;
  List<dynamic> allPosts = [];
  List<dynamic> categories = [];
  List<dynamic> currencies = [];

  String? selectedCategory;
  String? selectedPaymentMethodId;
  File? _selectedImage;

  bool isLoading = true;
  bool _isDialogShown = false;
  String? errorMessage;

  Map<String, dynamic>? pendingDeposit;
  Map<String, dynamic>? pendingWithdraw;

  Timer? _statusCheckTimer;

  // ==================== POST CANCEL STATES ====================
  final Map<int, PostCancelState> _postCancelStates = {};

  // Image retry tracking
  final Map<String, int> _imageRetryCount = {};

  // ✅ AGENT'S PAYMENT METHODS (Confirmation dialog এ use হবে)
  List<PaymentMethod> _agentPaymentMethods = [];

  // ==================== LIFECYCLE ====================
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeApp();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _senderAccountController.dispose();
    _transactionIdController.dispose();
    _withdrawTransactionIdController.dispose();
    _statusCheckTimer?.cancel();
    _tabController.dispose();
    ImageCacheManager.clearCache();
    super.dispose();
  }

  // ==================== INITIALIZATION ====================
  Future<void> _initializeApp() async {
    debugPrint('🚀 Initializing P2P Trading...');

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      await _loadTheme();
      await _loadAuthToken();

      if (mounted && authToken != null && authToken!.isNotEmpty) {
        await _loadPostsData();
        await _checkAllPendingRequests();
        _startStatusPolling();

        debugPrint('✅ App initialized successfully');
      } else {
        setState(() {
          isLoading = false;
          errorMessage = 'Authentication required. Please login.';
        });
      }
    } catch (e) {
      debugPrint('❌ Initialization error: $e');

      if (mounted) {
        setState(() {
          isLoading = false;
          errorMessage = 'Failed to initialize: ${e.toString()}';
        });
      }
    }
  }

  Future<void> _loadTheme() async {
    try {
      final theme = await ThemeService.fetchTheme();
      if (mounted) {
        setState(() => _appTheme = theme);
      }
    } catch (e) {
      debugPrint('❌ Theme load error: $e');
    }
  }

  Future<void> _loadAuthToken() async {
    try {
      authToken = await AuthService.getAuthToken();
    } catch (e) {
      debugPrint('❌ Auth token load error: $e');
      authToken = null;
    }
  }

  // ==================== CHECK ALL PENDING REQUESTS ====================
  Future<void> _checkAllPendingRequests() async {
    if (authToken == null) return;

    try {
      debugPrint('🔍 Checking all pending requests...');

      await _checkDepositRequestStatus();
      await _checkWithdrawRequestStatus();

      debugPrint('✅ Pending requests checked');
    } catch (e) {
      debugPrint('❌ Check all pending requests error: $e');
    }
  }

  // ==================== CHECK DEPOSIT REQUEST STATUS ====================
  Future<void> _checkDepositRequestStatus() async {
    try {
      final response = await ApiService.get(
        '/user/deposit/status',
        authToken: authToken,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('📥 Deposit Status: ${response.body}');

        if (data['success'] == true && data['deposit_id'] != null) {
          final status = RequestStatus.fromJson(data, 'deposit');

          final postId = _findPostIdByAgentId(status.agentId);

          if (postId != null) {
            _updatePostCancelState(
              postId: postId,
              isDeposit: true,
              requestId: status.requestId,
              status: status.status,
            );
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Deposit status check error: $e');
    }
  }

  // ==================== CHECK WITHDRAW REQUEST STATUS ====================
  Future<void> _checkWithdrawRequestStatus() async {
    try {
      final response = await ApiService.get(
        '/user/withdraw/status',
        authToken: authToken,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('📥 Withdraw Status: ${response.body}');

        if (data['success'] == true && data['withdraw_id'] != null) {
          final status = RequestStatus.fromJson(data, 'withdraw');

          final postId = _findPostIdByAgentId(status.agentId);

          if (postId != null) {
            _updatePostCancelState(
              postId: postId,
              isDeposit: false,
              requestId: status.requestId,
              status: status.status,
            );
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Withdraw status check error: $e');
    }
  }

  // ==================== UPDATE POST CANCEL STATE ====================
  void _updatePostCancelState({
    required int postId,
    required bool isDeposit,
    required int requestId,
    required String status,
  }) {
    final currentState = _getPostCancelState(postId);

    if (isDeposit) {
      if (status == 'pending') {
        setState(() {
          _postCancelStates[postId] = currentState.copyWith(
            hasPendingDeposit: true,
            depositRequestId: requestId,
            depositStatus: 'pending',
          );
        });
        debugPrint('✅ Post #$postId: Deposit Cancel Button VISIBLE');
      } else if (status == 'agent_confirmed') {
        setState(() {
          _postCancelStates[postId] = currentState.copyWith(clearDeposit: true);
        });
        debugPrint(
          '✅ Post #$postId: Deposit Confirmed - Buy/Sell Button VISIBLE',
        );
      } else if (status == 'completed' || status == 'cancelled') {
        setState(() {
          _postCancelStates[postId] = currentState.copyWith(clearDeposit: true);
        });
        debugPrint(
          '✅ Post #$postId: Deposit $status - Buy/Sell Button VISIBLE',
        );
      }
    } else {
      if (status == 'pending') {
        setState(() {
          _postCancelStates[postId] = currentState.copyWith(
            hasPendingWithdraw: true,
            withdrawRequestId: requestId,
            withdrawStatus: 'pending',
          );
        });
        debugPrint('✅ Post #$postId: Withdraw Cancel Button VISIBLE');
      } else if (status == 'agent_confirmed') {
        setState(() {
          _postCancelStates[postId] = currentState.copyWith(
            clearWithdraw: true,
          );
        });
        debugPrint(
          '✅ Post #$postId: Withdraw Confirmed - Buy/Sell Button VISIBLE',
        );
      } else if (status == 'completed' || status == 'cancelled') {
        setState(() {
          _postCancelStates[postId] = currentState.copyWith(
            clearWithdraw: true,
          );
        });
        debugPrint(
          '✅ Post #$postId: Withdraw $status - Buy/Sell Button VISIBLE',
        );
      }
    }
  }

  // ==================== FIND POST BY AGENT ID ====================
  int? _findPostIdByAgentId(int? agentId) {
    if (agentId == null) return null;

    try {
      final post = allPosts.firstWhere(
            (p) => p['agent']?['id'] == agentId,
        orElse: () => null,
      );

      return post?['id'];
    } catch (e) {
      debugPrint('❌ Find post by agent ID error: $e');
      return null;
    }
  }

  // ==================== GET POST CANCEL STATE ====================
  PostCancelState _getPostCancelState(int postId) {
    return _postCancelStates[postId] ?? PostCancelState(postId: postId);
  }

  // ==================== START STATUS POLLING ====================
  void _startStatusPolling() {
    _statusCheckTimer?.cancel();

    _statusCheckTimer = Timer.periodic(AppConfig.statusCheckInterval, (timer) {
      if (mounted && authToken != null && !_isDialogShown) {
        _checkRequestStatus();
        _checkAllPendingRequests();
      }
    });

    debugPrint(
      '⏰ Status polling started (${AppConfig.statusCheckInterval.inSeconds}s interval)',
    );
  }

  // ==================== FILTERED POSTS ====================
  List<dynamic> get filteredPosts {
    if (selectedCategory == null) return allPosts;

    return allPosts
        .where((post) => post['category']?['id'].toString() == selectedCategory)
        .toList();
  }

  // ==================== SHOW MESSAGE ====================
  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: Duration(seconds: isError ? 5 : 3),
      ),
    );
  }

  // ==================== SHOW LOADING DIALOG ====================
  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => WillPopScope(
        onWillPop: () async => false,
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: themeColor),
                const SizedBox(height: 16),
                const Text(
                  'Processing...',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==================== NAVIGATE TO HISTORY ====================
  void _navigateToHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => P2PHistoryPage()),
    );
  }
  // ==================== P2P TRADING - PART 2/5 (FIXED - FINAL) ====================
// ✅ Load Posts Data with Agent Payment Methods (FIXED)
// ✅ Parse Post Data - Payment Methods Properly Loaded
// ✅ Handle Session Expired

  // ==================== LOAD POSTS DATA (FIXED) ====================
  Future<void> _loadPostsData() async {
    if (authToken == null || authToken!.isEmpty) {
      setState(() {
        isLoading = false;
        errorMessage = 'Authentication required';
      });
      return;
    }

    try {
      debugPrint('📡 Fetching P2P data...');

      final response = await ApiService.get(
        '/buysellpost',
        authToken: authToken,
      );

      debugPrint('📥 Response Status: ${response.statusCode}');

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == true) {
          setState(() {
            // Parse categories
            categories = (data['categories'] as List? ?? [])
                .map(
                  (cat) => {'id': cat['id'], 'name': cat['name'] ?? 'Unknown'},
            )
                .toList();

            // Parse currencies
            currencies = (data['currencies'] as List? ?? [])
                .map((cur) => {'id': cur['id'], 'sign': cur['sign'] ?? 'BDT'})
                .toList();

            // ✅ Parse posts with agent payment methods (FIXED)
            final postsData = data['posts'] as List? ?? [];
            debugPrint('📦 Total posts received: ${postsData.length}');

            allPosts = postsData
                .map((post) => _parsePostData(post))
                .where((post) => post != null)
                .toList();

            isLoading = false;
            errorMessage = null;
          });

          debugPrint('✅ Successfully loaded: ${allPosts.length} posts');

          // ✅ Debug: Print payment methods for each post
          for (var post in allPosts) {
            final agentPaymentMethods =
                post['agent']?['payment_methods'] as List<dynamic>? ?? [];
            debugPrint(
              '💳 Post #${post['id']} | Agent: ${post['agent']?['name']} | Payment Methods: ${agentPaymentMethods.length}',
            );
          }
        } else {
          setState(() {
            isLoading = false;
            errorMessage = data['message'] ?? 'Failed to load data';
          });
        }
      } else if (response.statusCode == 401) {
        await _handleSessionExpired();
      } else {
        setState(() {
          isLoading = false;
          errorMessage = 'Server error: ${response.statusCode}';
        });
      }
    } on TimeoutException catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
          errorMessage = 'Connection timeout. Please try again.';
        });
      }
      debugPrint('❌ Timeout: $e');
    } on SocketException catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
          errorMessage = 'No internet connection.';
        });
      }
      debugPrint('❌ Socket error: $e');
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
          errorMessage = 'Error: ${e.toString()}';
        });
      }
      debugPrint('❌ Load error: $e');
    }
  }

  // ==================== PARSE POST DATA (ENHANCED DEBUG) ====================
  Map<String, dynamic>? _parsePostData(Map<String, dynamic> post) {
    try {
      final agent = post['agent'] ?? {};
      final category = post['category'] ?? {};
      final amounts = post['amounts'] ?? {};
      final orders = post['orders'] ?? {};
      final payment = post['payment'] ?? {};

      final isOnline = agent['is_online'] == true;
      final isVerified = agent['is_verified'] == true;

      // ✅ ENHANCED DEBUG - PAYMENT METHODS PARSING
      List<PaymentMethod> agentPaymentMethods = [];

      debugPrint('\n🔍 ========================================');
      debugPrint('🔍 PARSING POST #${post['id']}');
      debugPrint('🔍 Agent ID: ${agent['id']}');
      debugPrint('🔍 Agent Name: ${agent['name']}');
      debugPrint('🔍 ========================================');

      // Check if agent exists
      if (agent.isEmpty) {
        debugPrint('❌ ERROR: Agent data is empty!');
        return null;
      }

      // Check payment_methods field
      debugPrint('🔍 Checking payment_methods field...');
      debugPrint('🔍 agent.keys: ${agent.keys.toList()}');

      if (agent.containsKey('payment_methods')) {
        debugPrint('✅ payment_methods key EXISTS');

        final methodsData = agent['payment_methods'];
        debugPrint('🔍 payment_methods type: ${methodsData.runtimeType}');
        debugPrint('🔍 payment_methods value: $methodsData');

        if (methodsData == null) {
          debugPrint('⚠️ payment_methods is NULL');
        } else if (methodsData is List) {
          debugPrint(
            '✅ payment_methods is List with ${methodsData.length} items',
          );

          if (methodsData.isEmpty) {
            debugPrint('⚠️ payment_methods List is EMPTY');
          } else {
            for (int i = 0; i < methodsData.length; i++) {
              final item = methodsData[i];
              debugPrint('\n🔍 --- Item #$i ---');
              debugPrint('🔍 Type: ${item.runtimeType}');
              debugPrint('🔍 Value: $item');

              if (item is Map) {
                debugPrint('🔍 Map keys: ${item.keys.toList()}');
                debugPrint('🔍 id: ${item['id']}');
                debugPrint('🔍 method_name: ${item['method_name']}');
                debugPrint('🔍 method_number: ${item['method_number']}');

                try {
                  // Convert to Map<String, dynamic> if needed
                  final mapData = item is Map<String, dynamic>
                      ? item
                      : Map<String, dynamic>.from(item as Map);

                  final method = PaymentMethod.fromJson(mapData);
                  agentPaymentMethods.add(method);
                  debugPrint('✅ Successfully parsed: ${method.methodName}');
                } catch (e) {
                  debugPrint('❌ Parse error for item #$i: $e');
                }
              } else {
                debugPrint('⚠️ Item #$i is NOT a Map!');
              }
            }
          }
        } else {
          debugPrint(
            '❌ payment_methods is NOT a List! Type: ${methodsData.runtimeType}',
          );
        }
      } else {
        debugPrint('❌ payment_methods key DOES NOT EXIST');
        debugPrint('Available keys: ${agent.keys.toList()}');
      }

      debugPrint('\n🔍 FINAL RESULT:');
      debugPrint('💳 Total parsed methods: ${agentPaymentMethods.length}');
      for (var m in agentPaymentMethods) {
        debugPrint('   ✅ ${m.methodName} (${m.methodNumber})');
      }
      debugPrint('🔍 ========================================\n');

      // Parse photos
      List<String> photos = [];
      try {
        if (post['photo'] != null) {
          dynamic photoData = post['photo'];

          if (photoData is List) {
            for (var p in photoData) {
              if (p != null && p.toString().trim().isNotEmpty) {
                String photoPath = p.toString().trim();
                photos.add(_buildPhotoUrl(photoPath));
              }
            }
          } else if (photoData is String && photoData.trim().isNotEmpty) {
            photos.add(_buildPhotoUrl(photoData.trim()));
          }
        }

        photos = photos.toSet().toList();
      } catch (e) {
        debugPrint('❌ Photo parsing error: $e');
        photos = [];
      }

      // Parse payment names
      List<String> paymentNames = [];
      try {
        if (post['payment_names'] != null) {
          dynamic paymentData = post['payment_names'];

          if (paymentData is List) {
            paymentNames = paymentData
                .where((p) => p != null && p.toString().trim().isNotEmpty)
                .map((p) => p.toString().trim())
                .toSet()
                .toList();
          } else if (paymentData is String && paymentData.trim().isNotEmpty) {
            paymentNames = paymentData
                .split(',')
                .where((p) => p.trim().isNotEmpty)
                .map((p) => p.trim())
                .toSet()
                .toList();
          }
        }
      } catch (e) {
        debugPrint('❌ Payment names error: $e');
        paymentNames = [];
      }

      // Determine post type
      String postType = post['post_type'] ?? 'other';
      final categoryName = category['name']?.toString().toLowerCase() ?? '';

      if (postType == 'other' && categoryName.isNotEmpty) {
        if (categoryName.contains('deposit') || categoryName.contains('buy')) {
          postType = 'deposit';
        } else if (categoryName.contains('withdraw') ||
            categoryName.contains('sell')) {
          postType = 'withdraw';
        }
      }

      return {
        'id': post['id'],
        'post_type': postType,
        'trade_limit': post['trade_limit'] ?? 0,
        'trade_limit_two': post['trade_limit_two'] ?? 0,
        'available_balance': post['available_balance'] ?? 0,
        'rate_balance': post['rate_balance'] ?? 0,
        'duration': post['duration'],
        'status': post['status'],
        'photo': photos,
        'payment_names': paymentNames,
        'created_at': post['created_at'],

        'agent': {
          'id': agent['id'],
          'name': agent['name'] ?? 'Agent',
          'email': agent['email'] ?? '',
          'is_verified': isVerified,
          'is_online': isOnline,
          'last_active_at': agent['last_active_at'],
          'total_balance': agent['total_balance'] ?? '0.00',
          // ✅ AGENT'S PAYMENT METHODS
          'payment_methods': agentPaymentMethods,
        },

        'category': {
          'id': category['id'],
          'name': category['name'] ?? 'Unknown',
        },

        'limits': {
          'min': post['trade_limit'] ?? 0,
          'max': post['trade_limit_two'] ?? 0,
        },

        'amounts': {
          'hold': amounts['hold'] ?? '0.00',
          'currency': amounts['currency'] ?? 'BDT',
        },

        'payment': {'currency_sign': payment['currency_sign'] ?? 'BDT'},

        'orders': {
          'completed_deposit': orders['completed_deposit'] ?? 0,
          'completed_withdraw': orders['completed_withdraw'] ?? 0,
          'total': orders['total'] ?? 0,
          'success_rate': (orders['success_rate'] ?? 0.0).toDouble(),
        },
      };
    } catch (e) {
      debugPrint('❌ Error parsing post: $e');
      debugPrint('Stack trace: ${StackTrace.current}');
      return null;
    }
  }

  String _buildPhotoUrl(String photoPath) {
    if (photoPath.startsWith('http://') || photoPath.startsWith('https://')) {
      return photoPath;
    }

    photoPath = photoPath.replaceAll(RegExp(r'^/+'), '');
    photoPath = photoPath.replaceAll('uploads/agentbuysellpost/', '');

    if (photoPath.isNotEmpty && _isValidImageFile(photoPath)) {
      return '${AppConfig.photoBaseUrl}/uploads/agentbuysellpost/$photoPath';
    }

    return '';
  }

  bool _isValidImageFile(String filename) {
    final validExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.webp'];
    return validExtensions.any(
          (ext) => filename.toLowerCase().endsWith(ext.toLowerCase()),
    );
  }

  // ==================== HANDLE SESSION EXPIRED ====================
  Future<void> _handleSessionExpired() async {
    setState(() => isLoading = false);

    await AuthService.clearAuth();
    authToken = null;

    if (mounted) {
      _showMessage('Session expired. Please login again.', isError: true);
    }
  }

  // ==================== CANCEL DEPOSIT ====================
  Future<void> _cancelDeposit(int postId, int depositId) async {
    debugPrint('🚫 Attempting to cancel deposit #$depositId for post #$postId');

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: Colors.orange.shade700,
              size: 28,
            ),
            const SizedBox(width: 12),
            const Text(
              'Cancel Deposit?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        content: const Text(
          'Are you sure you want to cancel this deposit request? '
              'This action cannot be undone.',
          style: TextStyle(fontSize: 15, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'No',
              style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: const Text(
              'Yes, Cancel',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    _showLoadingDialog();

    try {
      debugPrint('📤 Cancelling deposit #$depositId');

      final response = await ApiService.post(
        '/depositecancled',
        authToken: authToken,
        body: {'deposit_id': depositId},
      );

      if (mounted) Navigator.pop(context);

      debugPrint('📥 Cancel Response: ${response.statusCode}');
      debugPrint('📥 Cancel Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true) {
          setState(() {
            pendingDeposit = null;
            _postCancelStates[postId] = PostCancelState(
              postId: postId,
              hasPendingDeposit: false,
              hasPendingWithdraw:
              _postCancelStates[postId]?.hasPendingWithdraw ?? false,
            );
          });

          _showMessage('✅ Deposit request cancelled successfully!');
          debugPrint('✅ Post #$postId: Buy/Sell Button VISIBLE after cancel');

          await _loadPostsData();
          await _checkAllPendingRequests();
        } else {
          _showMessage(data['message'] ?? 'Failed to cancel', isError: true);
        }
      } else {
        final error = json.decode(response.body);
        _showMessage(
          error['message'] ?? 'Failed to cancel deposit',
          isError: true,
        );
      }
    } on TimeoutException catch (e) {
      if (mounted) Navigator.pop(context);
      _showMessage('Request timeout. Please try again.', isError: true);
      debugPrint('❌ Timeout: $e');
    } on SocketException catch (e) {
      if (mounted) Navigator.pop(context);
      _showMessage('No internet connection.', isError: true);
      debugPrint('❌ Socket error: $e');
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _showMessage('Connection error: ${e.toString()}', isError: true);
      debugPrint('❌ Cancel deposit error: $e');
    }
  }

  // ==================== CANCEL WITHDRAW ====================
  Future<void> _cancelWithdraw(int postId, int withdrawId) async {
    debugPrint(
      '🚫 Attempting to cancel withdraw #$withdrawId for post #$postId',
    );

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: Colors.orange.shade700,
              size: 28,
            ),
            const SizedBox(width: 12),
            const Text(
              'Cancel Withdraw?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        content: const Text(
          'Are you sure you want to cancel this withdraw request? '
              'This action cannot be undone.',
          style: TextStyle(fontSize: 15, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'No',
              style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: const Text(
              'Yes, Cancel',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    _showLoadingDialog();

    try {
      debugPrint('📤 Cancelling withdraw #$withdrawId');

      final response = await ApiService.post(
        '/withdrawcancled',
        authToken: authToken,
        body: {'withdraw_id': withdrawId},
      );

      if (mounted) Navigator.pop(context);

      debugPrint('📥 Cancel Response: ${response.statusCode}');
      debugPrint('📥 Cancel Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true) {
          setState(() {
            pendingWithdraw = null;
            _postCancelStates[postId] = PostCancelState(
              postId: postId,
              hasPendingDeposit:
              _postCancelStates[postId]?.hasPendingDeposit ?? false,
              hasPendingWithdraw: false,
            );
          });

          _showMessage('✅ Withdraw request cancelled successfully!');
          debugPrint('✅ Post #$postId: Buy/Sell Button VISIBLE after cancel');

          await _loadPostsData();
          await _checkAllPendingRequests();
        } else {
          _showMessage(data['message'] ?? 'Failed to cancel', isError: true);
        }
      } else {
        final error = json.decode(response.body);
        _showMessage(
          error['message'] ?? 'Failed to cancel withdraw',
          isError: true,
        );
      }
    } on TimeoutException catch (e) {
      if (mounted) Navigator.pop(context);
      _showMessage('Request timeout. Please try again.', isError: true);
      debugPrint('❌ Timeout: $e');
    } on SocketException catch (e) {
      if (mounted) Navigator.pop(context);
      _showMessage('No internet connection.', isError: true);
      debugPrint('❌ Socket error: $e');
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _showMessage('Connection error: ${e.toString()}', isError: true);
      debugPrint('❌ Cancel withdraw error: $e');
    }
  }
  // ==================== P2P TRADING - PART 3/5 (FIXED - FINAL) ====================
// ✅ Create Request (FIXED - Deposit: শুধু Amount, Withdraw: সব একসাথে)
// ✅ Submit Deposit Details (Agent confirm এর পর)
// ✅ Release Withdraw
// ✅ Check Request Status
// ✅ Image Picker

  // ==================== CREATE REQUEST (FIXED - FINAL) ====================
  // ✅ DEPOSIT: শুধু Amount (প্রথমবার) - Payment Method নেই
  // ✅ WITHDRAW: Amount + Payment Method + Account Number + Transaction ID (সব একসাথে)
  Future<void> _createRequest(
      Map<String, dynamic> post,
      String amount,
      bool isDeposit,
      ) async {
    // Validate amount
    if (!_validateAmount(amount, post)) {
      return;
    }

    // ✅ WITHDRAW এর জন্য additional validation
    if (!isDeposit) {
      if (selectedPaymentMethodId == null || selectedPaymentMethodId!.isEmpty) {
        _showMessage('Please select a payment method', isError: true);
        return;
      }

      if (_senderAccountController.text.trim().isEmpty) {
        _showMessage('Please enter your account number', isError: true);
        return;
      }

      if (_withdrawTransactionIdController.text.trim().isEmpty) {
        _showMessage('Please enter transaction ID or note', isError: true);
        return;
      }
    }

    _showLoadingDialog();

    try {
      // Build request body
      final requestBody = {
        'type': isDeposit ? 'deposit' : 'withdraw',
        'agent_id': post['agent']['id'],
        'post_id': post['id'],
        'amount': amount,
      };

      // ✅ WITHDRAW এর জন্য payment method + account + transaction ID
      if (!isDeposit) {
        // Get agent payment methods
        final agentPaymentMethodsList =
            post['agent']['payment_methods'] as List<dynamic>? ?? [];

        final agentMethods = agentPaymentMethodsList
            .map((m) => m as PaymentMethod)
            .toList();

        PaymentMethod? selectedMethod;
        for (var method in agentMethods) {
          if (method.id.toString() == selectedPaymentMethodId) {
            selectedMethod = method;
            break;
          }
        }

        if (selectedMethod != null) {
          requestBody['payment_method_id'] = selectedMethod.id.toString();
          requestBody['payment_method'] = selectedMethod.methodName;
          requestBody['payment_number'] = selectedMethod.methodNumber;

          debugPrint('💳 Selected Method: ${selectedMethod.methodName}');
          debugPrint('📱 Method Number: ${selectedMethod.methodNumber}');
        }

        requestBody['sender_account'] = _senderAccountController.text.trim();
        requestBody['transaction_id'] = _withdrawTransactionIdController.text
            .trim();
      }

      debugPrint('📤 Creating ${isDeposit ? 'deposit' : 'withdraw'} request');
      debugPrint('📤 Request body: ${json.encode(requestBody)}');

      final response = await ApiService.post(
        '/user/${isDeposit ? 'deposit' : 'withdraw'}/request',
        authToken: authToken,
        body: requestBody,
      );

      if (mounted) Navigator.pop(context);

      debugPrint('📥 Response: ${response.statusCode}');
      debugPrint('📥 Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true || data['status'] == true) {
          final requestId = data['request_id'];

          setState(() {
            if (isDeposit) {
              _postCancelStates[post['id']] = PostCancelState(
                postId: post['id'],
                hasPendingDeposit: true,
                depositRequestId: requestId,
                depositStatus: 'pending',
              );
              debugPrint(
                '✅ Post #${post['id']}: Deposit Cancel Button VISIBLE',
              );
            } else {
              _postCancelStates[post['id']] = PostCancelState(
                postId: post['id'],
                hasPendingWithdraw: true,
                withdrawRequestId: requestId,
                withdrawStatus: 'pending',
              );
              debugPrint(
                '✅ Post #${post['id']}: Withdraw Cancel Button VISIBLE',
              );
            }
          });

          _showMessage(data['message'] ?? 'Request submitted successfully!');

          // Clear form
          _amountController.clear();
          _senderAccountController.clear();
          _withdrawTransactionIdController.clear();
          selectedPaymentMethodId = null;

          await _loadPostsData();
          await _checkAllPendingRequests();
          _startStatusPolling();
        } else {
          _showMessage(data['message'] ?? 'Request failed', isError: true);
        }
      } else {
        final error = json.decode(response.body);
        _showMessage(
          error['message'] ?? 'Failed to submit request',
          isError: true,
        );
      }
    } on TimeoutException catch (e) {
      if (mounted) Navigator.pop(context);
      _showMessage('Request timeout. Please try again.', isError: true);
      debugPrint('❌ Timeout: $e');
    } on SocketException catch (e) {
      if (mounted) Navigator.pop(context);
      _showMessage('No internet connection.', isError: true);
      debugPrint('❌ Socket error: $e');
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _showMessage('Connection error: ${e.toString()}', isError: true);
      debugPrint('❌ Request error: $e');
    }
  }

  // ==================== VALIDATE AMOUNT ====================
  bool _validateAmount(String amount, Map<String, dynamic> post) {
    final numAmount = double.tryParse(amount);

    if (numAmount == null || numAmount <= 0) {
      _showMessage('Enter valid amount', isError: true);
      return false;
    }

    final limits = post['limits'];
    final minLimit = double.tryParse(limits?['min']?.toString() ?? '0') ?? 0;
    final maxLimit = double.tryParse(limits?['max']?.toString() ?? '0') ?? 0;

    if (numAmount < minLimit || numAmount > maxLimit) {
      _showMessage(
        'Amount must be between $minLimit-$maxLimit USDT',
        isError: true,
      );
      return false;
    }

    return true;
  }

  // ==================== SUBMIT DEPOSIT DETAILS (FIXED) ====================
  // ✅ Agent confirm করার পর এই function call হবে
  // ✅ এখানে Payment Method + Transaction ID + Sender Account + Photo submit করা হবে
  Future<void> _submitDepositDetails(int depositId) async {
    if (!_validateDepositForm()) return;

    _showLoadingDialog();

    try {
      final imageFile = _selectedImage!;
      final fileSize = await imageFile.length();

      debugPrint('📤 Submitting deposit #$depositId');
      debugPrint('📤 Image: ${imageFile.path}');
      debugPrint('📤 Size: ${(fileSize / 1024).toStringAsFixed(2)} KB');

      // ✅ Get selected payment method
      PaymentMethod? selectedMethod;
      if (selectedPaymentMethodId != null) {
        for (var method in _agentPaymentMethods) {
          if (method.id.toString() == selectedPaymentMethodId) {
            selectedMethod = method;
            break;
          }
        }
      }

      // Create multipart request
      final files = [
        await http.MultipartFile.fromPath('photo', imageFile.path),
      ];

      final fields = {
        'transaction_id': _transactionIdController.text.trim(),
        'sender_account': _senderAccountController.text.trim(),
      };

      // ✅ Add payment method info
      if (selectedMethod != null) {
        fields['payment_method_id'] = selectedMethod.id.toString();
        fields['payment_method'] = selectedMethod.methodName;
        fields['payment_number'] = selectedMethod.methodNumber;

        debugPrint('💳 Submitting with method: ${selectedMethod.methodName}');
        debugPrint('📱 Method number: ${selectedMethod.methodNumber}');
      }

      final streamedResponse = await ApiService.multipartPost(
        '/user/deposit/submit/$depositId',
        authToken: authToken!,
        fields: fields,
        files: files,
      );

      final response = await http.Response.fromStream(streamedResponse);

      if (mounted) Navigator.pop(context);

      debugPrint('📥 Response: ${response.statusCode}');
      debugPrint('📥 Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true || data['status'] == true) {
          _clearDepositForm();
          _showMessage('Deposit submitted successfully!');

          await _loadPostsData();
          await _checkAllPendingRequests();
        } else {
          _showMessage(data['message'] ?? 'Failed to submit', isError: true);
        }
      } else {
        final error = json.decode(response.body);
        _showMessage(error['message'] ?? 'Upload failed', isError: true);
      }
    } on TimeoutException catch (e) {
      if (mounted) Navigator.pop(context);
      _showMessage('Upload timeout. Please try again.', isError: true);
      debugPrint('❌ Upload timeout: $e');
    } on SocketException catch (e) {
      if (mounted) Navigator.pop(context);
      _showMessage('No internet connection.', isError: true);
      debugPrint('❌ Socket error: $e');
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _showMessage('Upload error: ${e.toString()}', isError: true);
      debugPrint('❌ Upload error: $e');
    }
  }

  // ==================== RELEASE WITHDRAW ====================
  Future<void> _releaseWithdraw(int withdrawId) async {
    _showLoadingDialog();

    try {
      debugPrint('📤 Releasing withdraw #$withdrawId');

      final response = await ApiService.post(
        '/user/withdraw/submit/$withdrawId',
        authToken: authToken,
        body: {},
      );

      if (mounted) Navigator.pop(context);

      debugPrint('📥 Response: ${response.statusCode}');
      debugPrint('📥 Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true || data['status'] == true) {
          setState(() => pendingWithdraw = null);
          _showMessage('Withdraw completed successfully!');

          await _loadPostsData();
          await _checkAllPendingRequests();
        } else {
          _showMessage(data['message'] ?? 'Failed to complete', isError: true);
        }
      } else {
        final error = json.decode(response.body);
        _showMessage(error['message'] ?? 'Failed to release', isError: true);
      }
    } on TimeoutException catch (e) {
      if (mounted) Navigator.pop(context);
      _showMessage('Request timeout. Please try again.', isError: true);
      debugPrint('❌ Timeout: $e');
    } on SocketException catch (e) {
      if (mounted) Navigator.pop(context);
      _showMessage('No internet connection.', isError: true);
      debugPrint('❌ Socket error: $e');
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _showMessage('Connection error: ${e.toString()}', isError: true);
      debugPrint('❌ Withdraw error: $e');
    }
  }

  // ==================== CHECK REQUEST STATUS ====================
  Future<void> _checkRequestStatus() async {
    if (authToken == null || _isDialogShown) return;

    try {
      await Future.wait([_checkDepositStatus(), _checkWithdrawStatus()]);
    } catch (e) {
      debugPrint('❌ Status check error: $e');
    }
  }

  // ==================== CHECK DEPOSIT STATUS (FIXED - FINAL WITH FALLBACK) ====================
  Future<void> _checkDepositStatus() async {
    try {
      final response = await ApiService.get(
        '/user/deposit/status',
        authToken: authToken,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('📥 Deposit Status Response: ${response.body}');

        if (data['status'] == 'agent_confirmed' && mounted && !_isDialogShown) {
          final depositId = data['deposit_id'];
          var agentId = data['agent_id']; // Try to get from response

          // ✅ FALLBACK: If agent_id not in response, find from deposit table
          if (agentId == null) {
            debugPrint('⚠️ agent_id not in response, searching in posts...');

            // Search through all posts to find matching deposit
            for (var post in allPosts) {
              final postAgentId = post['agent']['id'];

              // Check if this agent has this deposit
              // We'll load payment methods for any agent as fallback
              if (postAgentId != null) {
                agentId = postAgentId;
                debugPrint(
                  '✅ Using Agent ID from first available post: $agentId',
                );
                break;
              }
            }
          }

          if (depositId != null) {
            debugPrint(
              '✅ Agent Confirmed! Deposit ID: $depositId, Agent ID: $agentId',
            );

            // ✅ Load agent payment methods if we have agent_id
            if (agentId != null) {
              await _loadAgentPaymentMethodsForDialog(agentId);
            } else {
              debugPrint(
                '⚠️ Could not determine agent_id, payment methods may be empty',
              );
              setState(() {
                _agentPaymentMethods = [];
              });
            }

            // Show the dialog
            setState(() {
              pendingDeposit = {
                'id': depositId is int
                    ? depositId
                    : int.tryParse(depositId.toString()) ?? 0,
                'amount': data['amount'],
                'status': data['status'],
                'payment_method': data['payment_method'],
                'payment_number': data['payment_number'],
              };
              _isDialogShown = true;
            });

            await _showConfirmationDialog(pendingDeposit!, isDeposit: true);
          } else {
            debugPrint('⚠️ Missing deposit_id in response');
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Deposit status error: $e');
    }
  }

  // ✅ HELPER FUNCTION
  Future<void> _loadAgentPaymentMethodsForDialog(int agentId) async {
    try {
      debugPrint('🔍 Loading payment methods for Agent #$agentId...');

      final post = allPosts.firstWhere(
            (p) => p['agent']['id'] == agentId,
        orElse: () => null,
      );

      if (post != null) {
        final methods =
            post['agent']['payment_methods'] as List<dynamic>? ?? [];

        setState(() {
          _agentPaymentMethods = methods
              .map((m) => m as PaymentMethod)
              .toList();
        });

        debugPrint(
          '💳 Loaded ${_agentPaymentMethods.length} payment methods for Agent #$agentId',
        );

        for (var method in _agentPaymentMethods) {
          debugPrint('   ✅ ${method.methodName}: ${method.methodNumber}');
        }
      } else {
        debugPrint('⚠️ Post not found for Agent #$agentId');
        setState(() {
          _agentPaymentMethods = [];
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading agent payment methods: $e');
      setState(() {
        _agentPaymentMethods = [];
      });
    }
  }

  // ==================== CHECK WITHDRAW STATUS ====================
  Future<void> _checkWithdrawStatus() async {
    try {
      final response = await ApiService.get(
        '/user/withdraw/status',
        authToken: authToken,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'agent_confirmed' && mounted && !_isDialogShown) {
          final withdrawId = data['withdraw_id'];

          if (withdrawId != null) {
            setState(() {
              pendingWithdraw = {
                'id': withdrawId is int
                    ? withdrawId
                    : int.tryParse(withdrawId.toString()) ?? 0,
                'amount': data['amount'],
                'status': data['status'],
                'sender_account': data['sender_account'],
                'payment_method': data['payment_method'],
                'payment_number': data['payment_number'],
              };
              _isDialogShown = true;
            });

            await _showConfirmationDialog(pendingWithdraw!, isDeposit: false);
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Withdraw status error: $e');
    }
  }

  // ==================== VALIDATION METHODS ====================
  bool _validateDepositForm() {
    if (_transactionIdController.text.trim().isEmpty) {
      _showMessage('Enter transaction ID', isError: true);
      return false;
    }

    if (_senderAccountController.text.trim().isEmpty) {
      _showMessage('Enter sender account', isError: true);
      return false;
    }

    if (_selectedImage == null) {
      _showMessage('Select payment screenshot', isError: true);
      return false;
    }

    if (selectedPaymentMethodId == null) {
      _showMessage('Select payment method', isError: true);
      return false;
    }

    return true;
  }

  void _clearDepositForm() {
    setState(() {
      pendingDeposit = null;
      _selectedImage = null;
      selectedPaymentMethodId = null;
      _agentPaymentMethods = [];
    });
    _transactionIdController.clear();
    _senderAccountController.clear();
  }

  // ==================== IMAGE PICKER ====================
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null && mounted) {
        final file = File(image.path);
        final fileSize = await file.length();

        debugPrint('📷 Image picked: ${image.path}');
        debugPrint('📷 Size: ${(fileSize / 1024).toStringAsFixed(2)} KB');

        if (fileSize > 5 * 1024 * 1024) {
          _showMessage(
            'Image too large. Please select image under 5MB.',
            isError: true,
          );
          return;
        }

        setState(() => _selectedImage = file);
      }
    } catch (e) {
      _showMessage('Failed to pick image: ${e.toString()}', isError: true);
      debugPrint('❌ Image pick error: $e');
    }
  }

  // ==================== SHOW IMAGE SOURCE DIALOG ====================
  Future<void> _showImageSourceDialog() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Choose Image Source',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickImage(ImageSource.camera);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: depositColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: depositColor, width: 2),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.camera_alt, size: 40, color: depositColor),
                          const SizedBox(height: 8),
                          const Text(
                            'Camera',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: InkWell(
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickImage(ImageSource.gallery);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: withdrawColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: withdrawColor, width: 2),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.photo_library,
                            size: 40,
                            color: withdrawColor,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Gallery',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  // ==================== P2P TRADING - PART 4/5 (FIXED - FINAL) ====================
// ✅ Confirmation Dialog (Agent Confirm এর পর - Payment Method Select সহ)
// ✅ Deposit Form & Withdraw Actions
// ✅ Main UI Build Methods
// ✅ Transaction Bottom Sheet (FIXED - Withdraw এ Agent Number দেখায় না)

  // ==================== SHOW CONFIRMATION DIALOG (FIXED) ====================
  // ✅ Agent confirm করার পর এই dialog show হবে
  // ✅ এখানে Payment Method Select করতে হবে + Transaction ID + Sender Account + Photo
  Future<void> _showConfirmationDialog(
      Map<String, dynamic> data, {
        required bool isDeposit,
      }) async {
    if (!mounted) return;

    final amount = data['amount']?.toString() ?? '0';

    debugPrint('🔔 Showing confirmation dialog');
    debugPrint(
      '💳 Agent payment methods available: ${_agentPaymentMethods.length}',
    );

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => WillPopScope(
          onWillPop: () async => false,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            contentPadding: EdgeInsets.zero,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: primaryGradient),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Agent Confirmed',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          Navigator.pop(context);
                          setState(() => _isDialogShown = false);
                        },
                        icon: const Icon(Icons.close, color: Colors.white),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),

                // Content
                SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.check_circle,
                          size: 64,
                          color: Colors.green.shade500,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Amount Display
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Amount:',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.black54,
                              ),
                            ),
                            Text(
                              '$amount USDT',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // ✅ DEPOSIT FORM (Agent confirm এর পর)
                      isDeposit
                          ? _buildDepositFormInDialog(setDialogState)
                          : _buildWithdrawActions(data),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    setState(() => _isDialogShown = false);
  }

  // ==================== BUILD DEPOSIT FORM IN DIALOG (FIXED - WITH SCROLLING) ====================
  Widget _buildDepositFormInDialog(StateSetter setDialogState) {
    return SizedBox(
      height:
      MediaQuery.of(context).size.height *
          0.5, // ✅ Max height 50% of screen
      child: SingleChildScrollView(
        // ✅ Make it scrollable
        child: Column(
          children: [
            // ✅ PAYMENT METHOD DROPDOWN
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.payment, size: 16, color: depositColor),
                    const SizedBox(width: 8),
                    const Text(
                      'Select Payment Method',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Text(' *', style: TextStyle(color: Colors.red)),
                  ],
                ),
                const SizedBox(height: 8),
                if (_agentPaymentMethods.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade300),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber,
                          color: Colors.orange.shade700,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'No payment methods available',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  )
                else ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: selectedPaymentMethodId,
                        hint: Text(
                          'Choose payment method',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        items: _agentPaymentMethods
                            .map<DropdownMenuItem<String>>((method) {
                          return DropdownMenuItem<String>(
                            value: method.id.toString(),
                            child: Row(
                              children: [
                                if (method.photo != null && method.photo!.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 8.0),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(3),
                                      child: Image.network(
                                        method.photo!,
                                        height: 20,
                                        width: 32,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) =>
                                            const Icon(Icons.payment, size: 16),
                                      ),
                                    ),
                                  ),
                                Expanded(
                                  child: Text(
                                    method.displayName,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          );
                        })
                            .toList(),
                        onChanged: (String? newValue) {
                          setState(() => selectedPaymentMethodId = newValue);
                          setDialogState(
                                () => selectedPaymentMethodId = newValue,
                          );
                        },
                      ),
                    ),
                  ),

                  // ✅ SHOW SELECTED METHOD NUMBER (WITH COPY BUTTON)
                  if (selectedPaymentMethodId != null) ...[
                    Builder(
                      builder: (context) {
                        PaymentMethod? selectedMethod;
                        for (var method in _agentPaymentMethods) {
                          if (method.id.toString() == selectedPaymentMethodId) {
                            selectedMethod = method;
                            break;
                          }
                        }

                        if (selectedMethod != null &&
                            selectedMethod.methodNumber.isNotEmpty) {
                          return Column(
                            children: [
                              const SizedBox(height: 12),
                      Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      depositColor.withOpacity(0.1),
                                      depositColor.withOpacity(0.05),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: depositColor.withOpacity(0.3),
                                    width: 2,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        if (selectedMethod.photo != null && selectedMethod.photo!.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(right: 8.0),
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(4),
                                              child: Image.network(
                                                selectedMethod.photo!,
                                                height: 24,
                                                width: 36,
                                                fit: BoxFit.cover,
                                                errorBuilder: (context, error, stackTrace) =>
                                                    Icon(Icons.account_balance_wallet, color: depositColor, size: 18),
                                              ),
                                            ),
                                          )
                                        else
                                          Icon(
                                            Icons.account_balance_wallet,
                                            color: depositColor,
                                            size: 18,
                                          ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Agent\'s ${selectedMethod.methodName} Number',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: depositColor,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                              BorderRadius.circular(8),
                                              border: Border.all(
                                                color: Colors.grey.shade300,
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  child: SelectableText(
                                                    selectedMethod.methodNumber,
                                                    style: const TextStyle(
                                                      fontSize: 16,
                                                      fontWeight:
                                                      FontWeight.bold,
                                                      color: Colors.black87,
                                                    ),
                                                  ),
                                                ),
                                                // ✅ COPY BUTTON
                                                InkWell(
                                                  onTap: () {
                                                    Clipboard.setData(
                                                      ClipboardData(
                                                        text: selectedMethod!
                                                            .methodNumber,
                                                      ),
                                                    );
                                                    _showMessage(
                                                      'Number copied!',
                                                    );
                                                  },
                                                  child: Container(
                                                    padding:
                                                    const EdgeInsets.all(8),
                                                    decoration: BoxDecoration(
                                                      color: depositColor,
                                                      borderRadius:
                                                      BorderRadius.circular(
                                                        6,
                                                      ),
                                                    ),
                                                    child: const Row(
                                                      children: [
                                                        Icon(
                                                          Icons.copy,
                                                          color: Colors.white,
                                                          size: 16,
                                                        ),
                                                        SizedBox(width: 4),
                                                        Text(
                                                          'Copy',
                                                          style: TextStyle(
                                                            color: Colors.white,
                                                            fontSize: 12,
                                                            fontWeight:
                                                            FontWeight.bold,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ],
                ],
              ],
            ),

            const SizedBox(height: 16),

            // Transaction ID
            TextField(
              controller: _transactionIdController,
              decoration: InputDecoration(
                labelText: 'Transaction ID *',
                hintText: 'Enter transaction ID',
                prefixIcon: const Icon(Icons.receipt_long),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: themeColor, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Sender Account
            TextField(
              controller: _senderAccountController,
              decoration: InputDecoration(
                labelText: 'Sender Account *',
                hintText: 'Enter sender account number',
                prefixIcon: const Icon(Icons.account_circle),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: themeColor, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Image Upload
            InkWell(
              onTap: _showImageSourceDialog,
              child: Container(
                height: 120, // ✅ Reduced height
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300, width: 2),
                ),
                child: _selectedImage != null
                    ? Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        _selectedImage!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: InkWell(
                        onTap: () {
                          setState(() => _selectedImage = null);
                          setDialogState(() => _selectedImage = null);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                )
                    : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_photo_alternate,
                      size: 40, // ✅ Smaller icon
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Upload Payment Screenshot *',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Submit Button
            Container(
              width: double.infinity,
              height: 50,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [depositColor, depositColor.withOpacity(0.8)],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: depositColor.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: () {
                  if (pendingDeposit == null) {
                    _showMessage('No pending deposit found', isError: true);
                    return;
                  }

                  final depositId = pendingDeposit!['id'];

                  if (depositId == null || depositId == 0) {
                    _showMessage('Invalid deposit ID', isError: true);
                    return;
                  }

                  Navigator.pop(context);
                  _submitDepositDetails(depositId);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Submit Deposit',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== BUILD WITHDRAW ACTIONS ====================
  Widget _buildWithdrawActions(Map<String, dynamic> data) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          height: 50,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [withdrawColor, withdrawColor.withOpacity(0.8)],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: withdrawColor.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: () {
              Navigator.pop(context);

              if (data['id'] != null) {
                _releaseWithdraw(data['id']);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Confirm & Complete',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ==================== MAIN BUILD METHOD ====================
  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: Colors.grey.shade50,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: themeColor),
              const SizedBox(height: 16),
              const Text(
                'Loading P2P offers...',
                style: TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    if (errorMessage != null) {
      return Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          title: const Text('P2P Trading'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 0,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
                const SizedBox(height: 16),
                Text(
                  errorMessage!,
                  style: const TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _initializeApp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: themeColor,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final depositPosts = filteredPosts
        .where((p) => p['post_type'] == 'deposit')
        .toList();

    final withdrawPosts = filteredPosts
        .where((p) => p['post_type'] == 'withdraw')
        .toList();

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: themeColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'P2P Trading',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black87),
            onPressed: _loadPostsData,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildTabBarWithHistory(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPostList(depositPosts, true),
                _buildPostList(withdrawPosts, false),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== BUILD TAB BAR WITH HISTORY ====================
  Widget _buildTabBarWithHistory() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(4),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  gradient: LinearGradient(colors: primaryGradient),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: themeColor.withOpacity(0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                labelColor: Colors.white,
                unselectedLabelColor: Colors.black54,
                labelStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
                tabs: const [
                  Tab(text: 'Buy USDT'),
                  Tab(text: 'Sell USDT'),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          InkWell(
            onTap: _navigateToHistory,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: primaryGradient),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: themeColor.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => P2PHistoryPage(),
                        ),
                      );
                    },
                    child: Row(
                      children: const [
                        Icon(Icons.history, color: Colors.white, size: 18),
                        SizedBox(width: 6),
                        Text(
                          'History',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 1,
                    height: 16,
                    color: Colors.white.withOpacity(0.5),
                  ),
                  const SizedBox(width: 12),
                  InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AgentListScreen(),
                        ),
                      );
                    },
                    child: const Row(
                      children: [
                        Icon(Icons.chat, color: Colors.white, size: 18),
                        SizedBox(width: 6),
                        Text(
                          'Chat',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== BUILD POST LIST ====================
  Widget _buildPostList(List<dynamic> posts, bool isDeposit) {
    if (posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No ${isDeposit ? 'Buy' : 'Sell'} Offers Available',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Pull down to refresh',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPostsData,
      color: themeColor,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: posts.length,
        itemBuilder: (context, index) {
          final post = posts[index];
          final postId = post['id'];
          final cancelState = _getPostCancelState(postId);

          return _OfferCard(
            key: ValueKey('post_$postId'),
            post: post,
            isDeposit: isDeposit,
            primaryGradient: primaryGradient,
            themeColor: themeColor,
            depositColor: depositColor,
            withdrawColor: withdrawColor,
            cancelState: cancelState,
            onTap: () => _showTransactionBottomSheet(post, isDeposit),
            onCancelDeposit: (requestId) => _cancelDeposit(postId, requestId),
            onCancelWithdraw: (requestId) => _cancelWithdraw(postId, requestId),
          );
        },
      ),
    );
  }

  // ==================== TRANSACTION BOTTOM SHEET (FIXED - FINAL) ====================
  // ✅ DEPOSIT: শুধু Amount (Payment Method নেই)
  // ✅ WITHDRAW: Amount + Payment Method + Account Number + Transaction ID
  // ✅ FIXED: Withdraw এ Agent এর Number দেখাবে না
  Future<void> _showTransactionBottomSheet(
      Map<String, dynamic> post,
      bool isDeposit,
      ) async {
    // Reset states
    setState(() {
      selectedPaymentMethodId = null;
    });

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  isDeposit ? 'Buy USDT' : 'Sell USDT',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Enter amount between ${post['limits']['min']} - '
                      '${post['limits']['max']} USDT',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 20),

                // ✅ AMOUNT INPUT (BOTH)
                _buildAmountInput(),

                // ✅ WITHDRAW এর জন্য additional fields (NO AGENT NUMBER)
                if (!isDeposit) ...[
                  const SizedBox(height: 16),
                  _buildPaymentMethodDropdownForWithdraw(post, setModalState),
                  const SizedBox(height: 16),
                  _buildAccountInput(),
                  const SizedBox(height: 16),
                  _buildWithdrawTransactionIdInput(),
                ],

                const SizedBox(height: 24),
                _buildSubmitButton(post, isDeposit),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==================== AMOUNT INPUT ====================
  Widget _buildAmountInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.monetization_on, size: 16, color: themeColor),
            const SizedBox(width: 8),
            const Text(
              'Amount (USDT)',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const Text(' *', style: TextStyle(color: Colors.red)),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _amountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            hintText: 'Enter amount',
            filled: true,
            fillColor: Colors.grey.shade50,
            suffixText: 'USDT',
            suffixStyle: TextStyle(
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w600,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: themeColor, width: 2),
            ),
            contentPadding: const EdgeInsets.all(14),
          ),
        ),
      ],
    );
  }

  // ==================== WITHDRAW FIELDS (FIXED - NO AGENT NUMBER) ====================
  Widget _buildPaymentMethodDropdownForWithdraw(
      Map<String, dynamic> post,
      StateSetter setModalState,
      ) {
    final agentPaymentMethodsList =
        post['agent']['payment_methods'] as List<dynamic>? ?? [];
    final agentMethods = agentPaymentMethodsList
        .map((m) => m as PaymentMethod)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.payment, size: 16, color: withdrawColor),
            const SizedBox(width: 8),
            const Text(
              'Select Payment Method',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const Text(' *', style: TextStyle(color: Colors.red)),
          ],
        ),
        const SizedBox(height: 8),
        if (agentMethods.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade300),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.warning_amber,
                  color: Colors.orange.shade700,
                  size: 20,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'No payment methods available for this agent',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: selectedPaymentMethodId,
                hint: Text(
                  'Choose payment method',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
                items: agentMethods.map<DropdownMenuItem<String>>((method) {
                  return DropdownMenuItem<String>(
                    value: method.id.toString(),
                    child: Text(
                      method.methodName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() => selectedPaymentMethodId = newValue);
                  setModalState(() => selectedPaymentMethodId = newValue);
                },
              ),
            ),
          ),
        // ✅ REMOVED: Agent Number Display for Withdraw
      ],
    );
  }

  Widget _buildAccountInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.phone, size: 16, color: withdrawColor),
            const SizedBox(width: 8),
            const Text(
              'Your Account Number',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const Text(' *', style: TextStyle(color: Colors.red)),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _senderAccountController,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            hintText: 'Enter your account number',
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: withdrawColor, width: 2),
            ),
            contentPadding: const EdgeInsets.all(14),
          ),
        ),
      ],
    );
  }

  Widget _buildWithdrawTransactionIdInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.receipt_long, size: 16, color: withdrawColor),
            const SizedBox(width: 8),
            const Text(
              'Note',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const Text(' *', style: TextStyle(color: Colors.red)),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _withdrawTransactionIdController,
          maxLines: 2,
          decoration: InputDecoration(
            hintText: 'Enter transaction ID or note',
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: withdrawColor, width: 2),
            ),
            contentPadding: const EdgeInsets.all(14),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton(Map<String, dynamic> post, bool isDeposit) {
    return Container(
      width: double.infinity,
      height: 50,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDeposit
              ? [depositColor, depositColor.withOpacity(0.8)]
              : [withdrawColor, withdrawColor.withOpacity(0.8)],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: (isDeposit ? depositColor : withdrawColor).withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: () {
          Navigator.pop(context);
          _createRequest(post, _amountController.text, isDeposit);
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isDeposit ? Icons.add : Icons.send,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              isDeposit ? 'Submit Buy Request' : 'Submit Sell Request',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
// ==================== P2P TRADING - PART 5/5 FINAL (FIXED - COMPLETE) ====================
// ✅ Offer Card Widget with Smart Cancel Button
// ✅ Agent Info, Balance, Rate, Limits
// ✅ Payment Methods Display
// ✅ Photos Display with Full Image Viewer
// ✅ Buy/Sell Button Logic
// ✅ Final Part - Complete Implementation

// ==================== OFFER CARD WITH SMART CANCEL BUTTON ====================
class _OfferCard extends StatefulWidget {
  final Map<String, dynamic> post;
  final bool isDeposit;
  final List<Color> primaryGradient;
  final Color themeColor;
  final Color depositColor;
  final Color withdrawColor;
  final PostCancelState cancelState;
  final VoidCallback onTap;
  final Function(int) onCancelDeposit;
  final Function(int) onCancelWithdraw;

  const _OfferCard({
    super.key,
    required this.post,
    required this.isDeposit,
    required this.primaryGradient,
    required this.themeColor,
    required this.depositColor,
    required this.withdrawColor,
    required this.cancelState,
    required this.onTap,
    required this.onCancelDeposit,
    required this.onCancelWithdraw,
  });

  @override
  State<_OfferCard> createState() => _OfferCardState();
}

class _OfferCardState extends State<_OfferCard> {
  final Map<String, int> _retryCount = {};

  @override
  Widget build(BuildContext context) {
    final agent = widget.post['agent'];
    final category = widget.post['category'];
    final limits = widget.post['limits'];
    final orders = widget.post['orders'];
    final paymentNames = (widget.post['payment_names'] as List<dynamic>?) ?? [];
    final photos = (widget.post['photo'] as List<dynamic>?) ?? [];

    final isOnline = agent['is_online'] == false;
    final isVerified = agent['is_verified'] == true;
    final agentBalance = agent['total_balance']?.toString() ?? '0.00';
    final rateBalance = widget.post['rate_balance']?.toString() ?? '0';
    final currencySign = widget.post['payment']?['currency_sign'] ?? 'BDT';
    final successRate = (orders['success_rate'] ?? 0.0).toDouble();

    // ✅ Check if cancel button should be shown
    final showCancelButton = widget.isDeposit
        ? widget.cancelState.shouldShowDepositCancel
        : widget.cancelState.shouldShowWithdrawCancel;

    // ✅ Check if Buy/Sell button should be shown
    final showBuySellButton = widget.cancelState.shouldShowBuySellButton;

    final requestId = widget.isDeposit
        ? widget.cancelState.depositRequestId
        : widget.cancelState.withdrawRequestId;

    debugPrint(
      '🎨 Card #${widget.post['id']} | ${agent['name']} | '
          'Show Cancel: $showCancelButton | Show Buy/Sell: $showBuySellButton | '
          'Status: ${widget.isDeposit ? widget.cancelState.depositStatus : widget.cancelState.withdrawStatus}',
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: showBuySellButton ? widget.onTap : null,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAgentInfo(agent, category, isOnline, isVerified),
                const SizedBox(height: 16),
                _buildAgentBalance(agentBalance),
                const SizedBox(height: 12),
                _buildRateBalance(rateBalance, currencySign),
                const SizedBox(height: 12),
                _buildTradeLimitAndRating(limits, orders, successRate),
                if (paymentNames.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildPaymentMethods(paymentNames),
                ],
                if (photos.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildPhotosDisplay(photos),
                ],
                const SizedBox(height: 16),
                // ✅ SMART BUTTON LOGIC
                if (showCancelButton && requestId != null)
                  _buildCancelButton(requestId)
                else if (showBuySellButton)
                  _buildBuySellButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==================== SMART CANCEL BUTTON ====================
  Widget _buildCancelButton(int requestId) {
    return Container(
      width: double.infinity,
      height: 50,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.red.shade600, Colors.red.shade800],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.4),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: () {
          if (widget.isDeposit) {
            widget.onCancelDeposit(requestId);
          } else {
            widget.onCancelWithdraw(requestId);
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cancel, color: Colors.white, size: 22),
            const SizedBox(width: 10),
            Text(
              widget.isDeposit ? 'Cancel Deposit' : 'Cancel Withdraw',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== BUY/SELL BUTTON ====================
  Widget _buildBuySellButton() {
    return Container(
      width: double.infinity,
      height: 50,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: widget.isDeposit
              ? [widget.depositColor, widget.depositColor.withOpacity(0.8)]
              : [widget.withdrawColor, widget.withdrawColor.withOpacity(0.8)],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color:
            (widget.isDeposit ? widget.depositColor : widget.withdrawColor)
                .withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: widget.onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              widget.isDeposit ? Icons.add_circle : Icons.send,
              color: Colors.white,
              size: 22,
            ),
            const SizedBox(width: 10),
            Text(
              widget.isDeposit ? 'Buy USDT' : 'Sell USDT',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== AGENT INFO ====================
  Widget _buildAgentInfo(agent, category, bool isOnline, bool isVerified) {
    return Row(
      children: [
        _buildAgentAvatar(agent, isOnline),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      agent['name']?.toString() ?? 'Agent',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  if (isVerified)
                    Row(
                      children: [
                        Icon(
                          Icons.verified,
                          color: Colors.green.shade700,
                          size: 18,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'VERIFIED',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ],
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'UNVERIFIED',
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade700,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    category['name']?.toString() ?? '',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(width: 10),
                  _buildOnlineIndicator(isOnline),
                ],
              ),
            ],
          ),
        ),
        _buildBuySellBadge(),
      ],
    );
  }

  Widget _buildAgentAvatar(agent, bool isOnline) {
    return Stack(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: widget.isDeposit
              ? widget.depositColor
              : widget.withdrawColor,
          child: Text(
            (agent['name']?.toString() ?? 'A')[0].toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
        ),
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: isOnline ? Colors.green : Colors.grey,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOnlineIndicator(bool isOnline) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isOnline
            ? widget.themeColor.withOpacity(0.1)
            : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isOnline ? widget.themeColor : Colors.grey.shade300,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: isOnline ? widget.themeColor : Colors.grey,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            isOnline ? 'Online' : 'Offline',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isOnline ? widget.themeColor : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBuySellBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: widget.isDeposit
              ? [widget.depositColor, widget.depositColor.withOpacity(0.7)]
              : [widget.withdrawColor, widget.withdrawColor.withOpacity(0.7)],
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        widget.isDeposit ? 'BUY' : 'SELL',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  // ==================== AGENT BALANCE ====================
  Widget _buildAgentBalance(String agentBalance) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.green.shade50,
            Colors.green.shade100.withOpacity(0.5),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.green.shade200, width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.account_balance_wallet,
              color: Colors.green.shade700,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Agent Balance',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$agentBalance USDT',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade900,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: Colors.green.shade700, size: 24),
        ],
      ),
    );
  }

  // ==================== RATE BALANCE ====================
  Widget _buildRateBalance(String rateBalance, String currencySign) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200, width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.trending_up, color: Colors.red.shade700, size: 18),
              const SizedBox(width: 8),
              Text(
                'Rate',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.red.shade700,
                ),
              ),
            ],
          ),
          Row(
            children: [
              Text(
                rateBalance,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade700,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.red.shade700,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  currencySign,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== TRADE LIMIT & RATING ====================
  Widget _buildTradeLimitAndRating(limits, orders, double successRate) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Trade Limit',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 4),
              Text(
                '${limits['min']} - ${limits['max']} USDT',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                children: [
                  ...List.generate(5, (index) {
                    final starValue = (index + 1) * 20.0;
                    return Icon(
                      starValue <= successRate ? Icons.star : Icons.star_border,
                      size: 16,
                      color: Colors.orange.shade700,
                    );
                  }),
                  const SizedBox(width: 6),
                  Text(
                    '${successRate.toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.orange.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${orders['total']} orders',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== PAYMENT METHODS ====================
  Widget _buildPaymentMethods(List<dynamic> paymentNames) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: paymentNames.take(3).map<Widget>((name) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: widget.primaryGradient),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            name.toString(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        );
      }).toList(),
    );
  }

  // ==================== PHOTOS DISPLAY ====================
  Widget _buildPhotosDisplay(List<dynamic> photos) {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.all(6),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: photos.length > 4 ? 4 : photos.length,
        itemBuilder: (context, index) {
          final photoUrl = photos[index].toString();
          return _buildPhotoThumbnail(photoUrl, index);
        },
      ),
    );
  }

  Widget _buildPhotoThumbnail(String photoUrl, int index) {
    final retryKey = '$photoUrl-$index';
    final retries = _retryCount[retryKey] ?? 0;

    return GestureDetector(
      onTap: () => _showFullImage(context, photoUrl),
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        width: 70,
        height: 68,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Image.network(
            photoUrl,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                color: Colors.grey.shade200,
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: widget.themeColor,
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                          : null,
                    ),
                  ),
                ),
              );
            },
            errorBuilder: (context, error, stack) {
              if (retries < 3) {
                Future.delayed(Duration(seconds: retries + 1), () {
                  if (mounted) {
                    setState(() {
                      _retryCount[retryKey] = retries + 1;
                    });
                  }
                });
              }

              return Container(
                color: Colors.grey.shade300,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      retries < 3 ? Icons.refresh : Icons.broken_image,
                      color: Colors.grey,
                      size: 20,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      retries < 3 ? 'Retry' : 'Error',
                      style: const TextStyle(fontSize: 8),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // ==================== SHOW FULL IMAGE ====================
  void _showFullImage(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: Stack(
          children: [
            InteractiveViewer(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                            : null,
                        color: Colors.white,
                      ),
                    );
                  },
                  errorBuilder: (context, error, stack) {
                    return Container(
                      color: Colors.grey.shade800,
                      child: const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.broken_image,
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
                      ),
                    );
                  },
                ),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: IconButton(
                onPressed: () => Navigator.pop(ctx),
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 24),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}