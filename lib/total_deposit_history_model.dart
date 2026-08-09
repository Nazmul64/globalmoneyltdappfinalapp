import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:shared_preferences/shared_preferences.dart';
import 'config/api_config.dart';

// ======================= CONFIG =======================

class _LocalApiConfig {
  static const Duration timeout = Duration(seconds: 30);
}

// ======================= MODEL CLASSES =======================

class WithdrawalHistoryResponse {
  final bool status;
  final String message;
  final WithdrawalData? data;

  WithdrawalHistoryResponse({
    required this.status,
    required this.message,
    this.data,
  });

  factory WithdrawalHistoryResponse.fromJson(Map<String, dynamic> json) {
    return WithdrawalHistoryResponse(
      status: json['status'] ?? false,
      message: json['message'] ?? '',
      data: json['data'] != null ? WithdrawalData.fromJson(json['data']) : null,
    );
  }
}

class WithdrawalData {
  final int totalWithdrawals;
  final double totalAmountWithdrawn;
  final int pendingWithdrawals;
  final int approvedWithdrawals;
  final int rejectedWithdrawals;

  WithdrawalData({
    required this.totalWithdrawals,
    required this.totalAmountWithdrawn,
    required this.pendingWithdrawals,
    required this.approvedWithdrawals,
    required this.rejectedWithdrawals,
  });

  factory WithdrawalData.fromJson(Map<String, dynamic> json) {
    return WithdrawalData(
      totalWithdrawals: json['total_withdrawals'] ?? 0,
      totalAmountWithdrawn: _parseDouble(json['total_amount_withdrawn']),
      pendingWithdrawals: json['pending_withdrawals'] ?? 0,
      approvedWithdrawals: json['approved_withdrawals'] ?? 0,
      rejectedWithdrawals: json['rejected_withdrawals'] ?? 0,
    );
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}

class ThemeResponse {
  final bool status;
  final String message;
  final ThemeDataModel? data;

  ThemeResponse({required this.status, required this.message, this.data});

  factory ThemeResponse.fromJson(Map<String, dynamic> json) {
    return ThemeResponse(
      status: json['status'] ?? false,
      message: json['message'] ?? '',
      data: json['data'] != null ? ThemeDataModel.fromJson(json['data']) : null,
    );
  }
}

class ThemeDataModel {
  final String colorCode;
  final String name;
  final String updatedAt;

  ThemeDataModel({
    required this.colorCode,
    required this.name,
    required this.updatedAt,
  });

  factory ThemeDataModel.fromJson(Map<String, dynamic> json) {
    return ThemeDataModel(
      colorCode: json['color_code'] ?? '#9C27B0',
      name: json['name'] ?? 'Default Theme',
      updatedAt: json['updated_at'] ?? '',
    );
  }
}

// ======================= API SERVICE =======================

class WithdrawalApiService {
  // ✅ Get auth token from SharedPreferences
  static Future<String?> _getAuthToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null || token.isEmpty) {
        developer.log('⚠️ WARNING: No auth token found!', name: 'API');
      }

      return token;
    } catch (e) {
      developer.log('❌ Error getting token: $e', name: 'API');
      return null;
    }
  }

  // ✅ Get user data from SharedPreferences
  static Future<Map<String, dynamic>> _getUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return {
        'user_name': prefs.getString('user_name') ?? 'Guest',
        'user_email': prefs.getString('user_email') ?? 'No email',
        'user_id': prefs.getInt('user_id'),
      };
    } catch (e) {
      developer.log('❌ Error getting user data: $e', name: 'API');
      return {'user_name': 'Guest', 'user_email': 'No email', 'user_id': null};
    }
  }

  // ✅ Clear session
  static Future<void> _clearSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      developer.log('✅ Session cleared', name: 'API');
    } catch (e) {
      developer.log('❌ Failed to clear session: $e', name: 'API');
    }
  }

  // ✅ Fetch Withdrawal History from user_widthdraws table
  static Future<WithdrawalHistoryResponse> fetchWithdrawalHistory() async {
    final endpoint = '${ApiConfig.baseUrl}/totalwidthrawhistory';

    try {
      final token = await _getAuthToken();

      if (token == null || token.isEmpty) {
        throw ApiException('Authentication required. Please login again.');
      }

      final userData = await _getUserData();

      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      };

      developer.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', name: 'API');
      developer.log('📤 GET: $endpoint', name: 'API');
      developer.log('   Token: ${token.substring(0, 20)}...', name: 'API');
      developer.log('   User: ${userData['user_name']}', name: 'API');

      final response = await http
          .get(Uri.parse(endpoint), headers: headers)
          .timeout(
            _LocalApiConfig.timeout,
            onTimeout: () {
              throw TimeoutException('Request timeout. Check your connection.');
            },
          );

      developer.log('📥 Status: ${response.statusCode}', name: 'API');
      developer.log('📥 Body: ${response.body}', name: 'API');
      developer.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', name: 'API');

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        return WithdrawalHistoryResponse.fromJson(jsonData);
      } else if (response.statusCode == 401) {
        developer.log('❌ 401 Unauthorized', name: 'API');
        await _clearSession();
        throw UnauthorizedException('Session expired. Please login again.');
      } else if (response.statusCode == 404) {
        throw NotFoundException('API endpoint not found.');
      } else if (response.statusCode == 500) {
        // Server error - show detailed error message
        try {
          final errorBody = json.decode(response.body);
          final errorMsg =
              errorBody['message'] ?? 'Server error. Try again later.';
          throw ServerException(errorMsg);
        } catch (e) {
          throw ServerException('Server error. Try again later.');
        }
      } else {
        try {
          final errorBody = json.decode(response.body);
          final errorMsg = errorBody['message'] ?? 'Failed to load data';
          throw ApiException(errorMsg);
        } catch (e) {
          throw ApiException('Failed to load data (${response.statusCode})');
        }
      }
    } on TimeoutException catch (e) {
      developer.log('❌ Timeout: $e', name: 'API');
      rethrow;
    } on UnauthorizedException catch (e) {
      developer.log('❌ Unauthorized: $e', name: 'API');
      rethrow;
    } on http.ClientException catch (e) {
      developer.log('❌ Network error: $e', name: 'API');
      throw NetworkException('Network error. Check your connection.');
    } catch (e) {
      developer.log('❌ Error: $e', name: 'API');
      if (e is ApiException) rethrow;
      throw ApiException('Unexpected error: ${e.toString()}');
    }
  }

  // ✅ Fetch Theme
  static Future<ThemeResponse> fetchTheme() async {
    final endpoint = '${ApiConfig.baseUrl}/themechange';

    try {
      final response = await http
          .get(
            Uri.parse(endpoint),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        return ThemeResponse.fromJson(jsonData);
      } else {
        return _getDefaultTheme();
      }
    } catch (e) {
      developer.log('⚠️ Theme load failed: $e', name: 'API');
      return _getDefaultTheme();
    }
  }

  static ThemeResponse _getDefaultTheme() {
    return ThemeResponse(
      status: true,
      message: 'Using default theme',
      data: ThemeDataModel(
        colorCode: '#9C27B0',
        name: 'Default Theme',
        updatedAt: DateTime.now().toString(),
      ),
    );
  }
}

// ======================= CUSTOM EXCEPTIONS =======================

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

class UnauthorizedException extends ApiException {
  UnauthorizedException(String message) : super(message);
}

class TimeoutException extends ApiException {
  TimeoutException(String message) : super(message);
}

class NetworkException extends ApiException {
  NetworkException(String message) : super(message);
}

class NotFoundException extends ApiException {
  NotFoundException(String message) : super(message);
}

class ServerException extends ApiException {
  ServerException(String message) : super(message);
}

// ======================= MAIN SCREEN =======================

class MyWithdrawalScreen extends StatefulWidget {
  const MyWithdrawalScreen({Key? key}) : super(key: key);

  @override
  State<MyWithdrawalScreen> createState() => _MyWithdrawalScreenState();
}

class _MyWithdrawalScreenState extends State<MyWithdrawalScreen> {
  // State
  bool isLoading = true;
  bool hasError = false;
  String errorMessage = '';

  // Data - ডাটাবেজ থেকে আসবে
  int totalWithdrawals = 0;
  double totalAmountWithdrawn = 0.0;
  int pendingWithdrawals = 0;
  int approvedWithdrawals = 0;
  int rejectedWithdrawals = 0;

  // Theme
  Color themeColor = const Color(0xFF9C27B0);
  String themeName = 'Default Theme';

  // User data
  String userName = 'Guest';
  String userEmail = 'No email';

  @override
  void initState() {
    super.initState();
    developer.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', name: 'SCREEN');
    developer.log('📄 MyWithdrawalScreen - initState', name: 'SCREEN');
    developer.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', name: 'SCREEN');

    _checkAuthAndLoadData();
  }

  // ✅ Check auth and load data
  Future<void> _checkAuthAndLoadData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      // Get user data
      userName = prefs.getString('user_name') ?? 'Guest';
      userEmail = prefs.getString('user_email') ?? 'No email';
      final userId = prefs.getInt('user_id');

      developer.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', name: 'AUTH');
      developer.log('🔐 Checking authentication...', name: 'AUTH');
      developer.log('   User: $userName', name: 'AUTH');
      developer.log('   Email: $userEmail', name: 'AUTH');
      developer.log('   User ID: $userId', name: 'AUTH');
      developer.log(
        '   Token: ${token != null ? "${token.substring(0, 20)}..." : "null"}',
        name: 'AUTH',
      );
      developer.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', name: 'AUTH');

      if (token == null || token.isEmpty) {
        setState(() {
          hasError = true;
          errorMessage = 'You are not logged in. Redirecting to login...';
          isLoading = false;
        });

        developer.log('❌ User not logged in!', name: 'SCREEN');

        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.of(context).pushReplacementNamed('/login');
          }
        });
        return;
      }

      await _loadData();
    } catch (e) {
      developer.log('❌ Auth check failed: $e', name: 'SCREEN');
      setState(() {
        hasError = true;
        errorMessage = 'Authentication failed. Please login again.';
        isLoading = false;
      });

      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/login');
        }
      });
    }
  }

  // ✅ Load data from database
  Future<void> _loadData() async {
    setState(() {
      isLoading = true;
      hasError = false;
      errorMessage = '';
    });

    try {
      developer.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', name: 'DATA');
      developer.log(
        '🔄 Loading withdrawal data from user_widthdraws table...',
        name: 'DATA',
      );

      // Load theme (non-blocking)
      _loadTheme();

      // Load withdrawal data (must succeed)
      final response = await WithdrawalApiService.fetchWithdrawalHistory();

      if (response.status && response.data != null) {
        final data = response.data!;

        setState(() {
          totalWithdrawals = data.totalWithdrawals;
          totalAmountWithdrawn = data.totalAmountWithdrawn;
          pendingWithdrawals = data.pendingWithdrawals;
          approvedWithdrawals = data.approvedWithdrawals;
          rejectedWithdrawals = data.rejectedWithdrawals;
          isLoading = false;
          hasError = false;
        });

        developer.log('✅ Data loaded successfully:', name: 'DATA');
        developer.log('   Total Withdrawals: $totalWithdrawals', name: 'DATA');
        developer.log('   Total Amount: \$$totalAmountWithdrawn', name: 'DATA');
        developer.log('   Pending: $pendingWithdrawals', name: 'DATA');
        developer.log('   Approved: $approvedWithdrawals', name: 'DATA');
        developer.log('   Rejected: $rejectedWithdrawals', name: 'DATA');
        developer.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', name: 'DATA');
      } else {
        throw ApiException(response.message);
      }
    } on UnauthorizedException catch (e) {
      _handleUnauthorized(e.toString());
    } catch (e) {
      final cleanError = e.toString();

      setState(() {
        hasError = true;
        errorMessage = cleanError;
        isLoading = false;
      });

      developer.log('❌ Error: $cleanError', name: 'DATA');
      developer.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', name: 'DATA');
    }
  }

  // ✅ Load theme
  Future<void> _loadTheme() async {
    try {
      final themeResponse = await WithdrawalApiService.fetchTheme();
      if (themeResponse.status && themeResponse.data != null) {
        setState(() {
          themeColor = _parseColor(themeResponse.data!.colorCode);
          themeName = themeResponse.data!.name;
        });
        developer.log(
          '✅ Theme: ${themeResponse.data!.colorCode}',
          name: 'THEME',
        );
      }
    } catch (e) {
      developer.log('⚠️ Theme failed (using default)', name: 'THEME');
    }
  }

  // ✅ Handle unauthorized
  void _handleUnauthorized(String message) async {
    setState(() {
      hasError = true;
      errorMessage = message;
      isLoading = false;
    });

    _showSnackBar(message, Colors.red);

    // Clear session
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      developer.log(
        '✅ Session cleared due to unauthorized access',
        name: 'AUTH',
      );
    } catch (e) {
      developer.log('❌ Failed to clear session: $e', name: 'AUTH');
    }

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    });
  }

  // ✅ Parse color
  Color _parseColor(String colorCode) {
    try {
      String hex = colorCode.replaceAll('#', '');
      if (hex.length == 6) hex = 'FF$hex';
      return Color(int.parse(hex, radix: 16));
    } catch (e) {
      return const Color(0xFF9C27B0);
    }
  }

  // ✅ Show snackbar
  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ✅ Refresh
  Future<void> _refresh() async {
    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: themeColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'My Withdrawals',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: isLoading ? null : _refresh,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: isLoading
          ? _buildLoading()
          : hasError
          ? _buildError()
          : _buildContent(),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(themeColor),
            strokeWidth: 3,
          ),
          const SizedBox(height: 16),
          const Text(
            'Loading withdrawal history...',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              'Error Loading Data',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: themeColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return RefreshIndicator(
      onRefresh: _refresh,
      color: themeColor,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // User Card
            _buildUserCard(),
            const SizedBox(height: 16),

            // Total Amount Withdrawn
            _buildCard(
              icon: Icons.account_balance_wallet,
              iconColor: Colors.green,
              label: 'Total Amount Withdrawn',
              value: '\$${totalAmountWithdrawn.toStringAsFixed(2)}',
              valueColor: Colors.green,
            ),
            const SizedBox(height: 12),

            // Pending & Rejected
            Row(
              children: [
                Expanded(
                  child: _buildCard(
                    icon: Icons.access_time,
                    iconColor: Colors.orange,
                    label: 'Pending',
                    value: '$pendingWithdrawals',
                    valueColor: Colors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildCard(
                    icon: Icons.cancel,
                    iconColor: Colors.red,
                    label: 'Rejected',
                    value: '$rejectedWithdrawals',
                    valueColor: Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Approved
            _buildCard(
              icon: Icons.check_circle,
              iconColor: Colors.blue,
              label: 'Approved',
              value: '$approvedWithdrawals',
              valueColor: Colors.blue,
            ),
            const SizedBox(height: 16),

            // Total Withdrawals Count
            _buildTotalCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildUserCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [themeColor, themeColor.withOpacity(0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: themeColor.withOpacity(0.3),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 24,
            backgroundColor: Colors.white,
            child: Icon(Icons.person, color: Colors.grey),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  userName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  userEmail,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: valueColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Total Withdrawals',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: themeColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$totalWithdrawals',
              style: TextStyle(
                color: themeColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
