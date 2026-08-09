import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'config/api_config.dart';

// ==================== DEPOSIT SCREEN ====================
class DepositScreen extends StatefulWidget {
  const DepositScreen({Key? key}) : super(key: key);

  @override
  State<DepositScreen> createState() => _DepositScreenState();
}

class _DepositScreenState extends State<DepositScreen> {
  // ==================== STATE VARIABLES ====================

  // Balance & Deposit Totals
  double userBalance = 0.0;
  double totalApprovedFromTables = 0.0;
  double totalPendingDeposit = 0.0;
  double totalRejectedDeposit = 0.0;

  // Loading & Error States
  bool isLoading = true;
  bool isSyncing = false;
  String errorMessage = '';

  // Deposits Lists
  List<Map<String, dynamic>> allDeposits = [];
  List<Map<String, dynamic>> approvedDeposits = [];
  List<Map<String, dynamic>> pendingDeposits = [];
  List<Map<String, dynamic>> rejectedDeposits = [];

  // Theme Colors
  Color primaryColor = const Color(0xFFE53935);
  Color secondaryColor = const Color(0xFFE53935);
  Color approvedColor = const Color(0xFF4CAF50);
  Color pendingColor = const Color(0xFFFF9800);
  Color rejectedColor = const Color(0xFFF44336);

  // Base URL Configuration
  String get baseUrl {
    if (Platform.isAndroid) {
      return ApiConfig.mediaBaseUrl;
    } else if (Platform.isIOS) {
      return ApiConfig.mediaBaseUrl;
    } else {
      return ApiConfig.mediaBaseUrl;
    }
  }

  // ==================== LIFECYCLE METHODS ====================

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  @override
  void dispose() {
    super.dispose();
  }

  // ==================== INITIALIZATION ====================

  Future<void> _initializeScreen() async {
    await _fetchThemeColor();
    await _fetchAllData();
  }

  // ==================== FETCH THEME COLOR ====================

  Future<void> _fetchThemeColor() async {
    try {
      final url = '$baseUrl/api/themechange';
      debugPrint('🎨 Fetching theme from: $url');

      final response = await http
          .get(Uri.parse(url), headers: {'Accept': 'application/json'})
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw Exception('Connection timeout'),
          );

      debugPrint('🎨 Theme API Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['status'] == true && data['data'] != null) {
          String colorCode = data['data']['color_code'] ?? '#E53935';
          colorCode = colorCode.replaceAll('#', '');

          final int colorValue = int.parse('FF$colorCode', radix: 16);
          final Color themeColor = Color(colorValue);

          if (mounted) {
            setState(() {
              primaryColor = themeColor;
              secondaryColor = _lightenColor(themeColor, 0.1);
            });
          }

          debugPrint('✅ Theme loaded: $colorCode');
        }
      }
    } catch (e) {
      debugPrint('💥 Theme fetch error: $e');
      // Continue with default theme
    }
  }

  Color _lightenColor(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withLightness((hsl.lightness + amount).clamp(0.0, 1.0))
        .toColor();
  }

  // ==================== FETCH ALL DATA ====================

  Future<void> _fetchAllData() async {
    if (mounted) {
      setState(() {
        isLoading = true;
        errorMessage = '';
      });
    }

    try {
      await Future.wait([_fetchUserDeposits(), _fetchUserBalance()]);
    } catch (e) {
      debugPrint('💥 Error in _fetchAllData: $e');
      if (mounted) {
        setState(() {
          errorMessage = 'Failed to load data. Please try again.';
        });
      }
    }

    if (mounted) {
      setState(() {
        isLoading = false;
      });
    }
  }

  // ==================== GET AUTH TOKEN ====================

  Future<String?> _getAuthToken() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();

      // ✅ Try both 'auth_token' and 'token' for compatibility
      String? token = prefs.getString('auth_token');

      if (token == null || token.isEmpty) {
        token = prefs.getString('token');
      }

      if (token == null || token.isEmpty) {
        debugPrint('❌ No auth token found in SharedPreferences');
        debugPrint('   Keys available: ${prefs.getKeys()}');
        return null;
      }

      debugPrint('✅ Auth token found: ${token.substring(0, 20)}...');
      return token;
    } catch (e) {
      debugPrint('💥 Error getting auth token: $e');
      return null;
    }
  }

  // ==================== FETCH USER BALANCE ====================

  Future<void> _fetchUserBalance() async {
    try {
      String? token = await _getAuthToken();

      if (token == null) {
        if (mounted) {
          setState(() {
            errorMessage =
                'Authentication token not found. Please login again.';
          });
        }
        return;
      }

      final url = '$baseUrl/api/user/balance';
      debugPrint('🌐 Fetching balance from: $url');

      final response = await http
          .get(
            Uri.parse(url),
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw Exception('Connection timeout'),
          );

      debugPrint('📊 Balance API Status: ${response.statusCode}');
      debugPrint('📊 Balance API Response: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['success'] == true && data['data'] != null) {
          if (mounted) {
            setState(() {
              userBalance = _parseAmount(data['data']['balance']);
              errorMessage = '';
            });
          }
          debugPrint('✅ User Balance: \$${userBalance.toStringAsFixed(2)}');
        } else {
          debugPrint('❌ Balance API returned success=false');
        }
      } else if (response.statusCode == 401) {
        debugPrint('❌ 401 Unauthorized - Token expired or invalid');
        if (mounted) {
          setState(() {
            errorMessage = 'Session expired. Please login again.';
          });
        }
        _showLoginDialog();
      } else {
        debugPrint('❌ Balance API error: ${response.statusCode}');
        if (mounted) {
          setState(() {
            errorMessage = 'Server error: ${response.statusCode}';
          });
        }
      }
    } on SocketException catch (e) {
      debugPrint('💥 SocketException: $e');
      if (mounted) {
        setState(() {
          errorMessage =
              'Cannot connect to server. Please check your internet connection.';
        });
      }
    } on FormatException catch (e) {
      debugPrint('💥 FormatException: $e');
      if (mounted) {
        setState(() {
          errorMessage = 'Invalid response from server.';
        });
      }
    } catch (e) {
      debugPrint('💥 Error fetching balance: $e');
      if (mounted) {
        setState(() {
          errorMessage = 'Error: ${e.toString()}';
        });
      }
    }
  }

  // ==================== FETCH USER DEPOSITS ====================

  Future<void> _fetchUserDeposits() async {
    try {
      String? token = await _getAuthToken();

      if (token == null) {
        if (mounted) {
          setState(() {
            errorMessage =
                'Authentication token not found. Please login again.';
          });
        }
        return;
      }

      final url = '$baseUrl/api/userDeposits';
      debugPrint('🌐 Fetching deposits from: $url');

      final response = await http
          .get(
            Uri.parse(url),
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw Exception('Connection timeout'),
          );

      debugPrint('📊 Deposits API Status: ${response.statusCode}');
      debugPrint('📊 Deposits API Response: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['success'] == true && data['data'] != null) {
          final depositsList = data['data'] as List;
          final summary = data['summary'];

          List<Map<String, dynamic>> approved = [];
          List<Map<String, dynamic>> pending = [];
          List<Map<String, dynamic>> rejected = [];

          for (var deposit in depositsList) {
            String status = deposit['status']?.toString().toLowerCase() ?? '';

            if (status == 'approved') {
              approved.add(deposit);
            } else if (status == 'pending') {
              pending.add(deposit);
            } else if (status == 'rejected') {
              rejected.add(deposit);
            }
          }

          if (mounted) {
            setState(() {
              allDeposits = List<Map<String, dynamic>>.from(depositsList);
              approvedDeposits = approved;
              pendingDeposits = pending;
              rejectedDeposits = rejected;

              totalApprovedFromTables = _parseAmount(summary['total_approved']);
              totalPendingDeposit = _parseAmount(summary['total_pending']);
              totalRejectedDeposit = _parseAmount(summary['total_rejected']);

              errorMessage = '';
            });
          }

          debugPrint(
            '✅ Approved: ${approved.length} (\$${totalApprovedFromTables.toStringAsFixed(2)})',
          );
          debugPrint(
            '✅ Pending: ${pending.length} (\$${totalPendingDeposit.toStringAsFixed(2)})',
          );
          debugPrint(
            '✅ Rejected: ${rejected.length} (\$${totalRejectedDeposit.toStringAsFixed(2)})',
          );
        } else {
          if (mounted) {
            setState(() {
              errorMessage = data['message'] ?? 'Failed to fetch deposits';
            });
          }
        }
      } else if (response.statusCode == 401) {
        debugPrint('❌ 401 Unauthorized - Token expired or invalid');
        if (mounted) {
          setState(() {
            errorMessage = 'Session expired. Please login again.';
          });
        }
        _showLoginDialog();
      } else {
        if (mounted) {
          setState(() {
            errorMessage = 'Server error: ${response.statusCode}';
          });
        }
      }
    } on SocketException catch (e) {
      debugPrint('💥 SocketException: $e');
      if (mounted) {
        setState(() {
          errorMessage =
              'Cannot connect to server.\n\n'
              'Please check:\n'
              '✓ Internet connection\n'
              '✓ Laravel server is running\n'
              '✓ Correct API URL';
        });
      }
    } on FormatException catch (e) {
      debugPrint('💥 FormatException: $e');
      if (mounted) {
        setState(() {
          errorMessage = 'Invalid response from server.';
        });
      }
    } catch (e) {
      debugPrint('💥 Exception: $e');
      if (mounted) {
        setState(() {
          errorMessage = 'Error: ${e.toString()}';
        });
      }
    }
  }

  // ==================== MANUAL BALANCE SYNC ====================

  Future<void> _syncBalance() async {
    if (mounted) {
      setState(() {
        isSyncing = true;
      });
    }

    try {
      String? token = await _getAuthToken();

      if (token == null) {
        _showSnackBar('Token not found. Please login again.', rejectedColor);
        return;
      }

      final url = '$baseUrl/api/user/sync-balance';
      debugPrint('🔄 Syncing balance: $url');

      final response = await http
          .post(
            Uri.parse(url),
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw Exception('Connection timeout'),
          );

      debugPrint('🔄 Sync API Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['success'] == true && data['data'] != null) {
          final newBalance = _parseAmount(data['data']['new_balance']);

          if (mounted) {
            setState(() {
              userBalance = newBalance;
              totalApprovedFromTables = newBalance;
            });
          }

          _showSnackBar(
            'Balance synced successfully! \$${newBalance.toStringAsFixed(2)}',
            approvedColor,
          );

          debugPrint('✅ Balance synced: \$${newBalance.toStringAsFixed(2)}');

          // Refresh all data
          await _fetchAllData();
        }
      }
    } catch (e) {
      debugPrint('💥 Sync error: $e');
      _showSnackBar('Sync failed. Please try again.', rejectedColor);
    } finally {
      if (mounted) {
        setState(() {
          isSyncing = false;
        });
      }
    }
  }

  // ==================== SHOW LOGIN DIALOG ====================

  void _showLoginDialog() {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Session Expired'),
        content: const Text('Your session has expired. Please login again.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Go back to previous screen
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // ==================== SHOW SNACKBAR ====================

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  // ==================== PARSE AMOUNT ====================

  double _parseAmount(dynamic amount) {
    if (amount == null) return 0.0;
    if (amount is double) return amount;
    if (amount is int) return amount.toDouble();
    if (amount is String) {
      return double.tryParse(amount) ?? 0.0;
    }
    return 0.0;
  }

  // ==================== REFRESH DATA ====================

  Future<void> _refreshBalance() async {
    await _fetchThemeColor();
    await _fetchAllData();
  }

  // ==================== BUILD UI ====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: _buildAppBar(),
      body: RefreshIndicator(
        onRefresh: _refreshBalance,
        color: primaryColor,
        child: isLoading
            ? _buildLoadingState()
            : errorMessage.isNotEmpty
            ? _buildErrorState()
            : _buildContentState(),
      ),
    );
  }

  // ==================== APP BAR ====================

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text(
        'My Deposits',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      ),
      backgroundColor: primaryColor,
      foregroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.of(context).pop(),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.white),
          onPressed: _refreshBalance,
          tooltip: 'Refresh',
        ),
      ],
    );
  }

  // ==================== LOADING STATE ====================

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: primaryColor),
          const SizedBox(height: 16),
          const Text(
            'Loading deposits...',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  // ==================== ERROR STATE ====================

  Widget _buildErrorState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off, size: 64, color: primaryColor),
            const SizedBox(height: 16),
            const Text(
              'Connection Error',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _refreshBalance,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== CONTENT STATE ====================

  Widget _buildContentState() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main Balance Card
          _buildBalanceCard(
            'Total Balance',
            userBalance,
            [primaryColor, secondaryColor],
            Icons.account_balance_wallet,
            subtitle: 'From users.balance table',
          ),

          const SizedBox(height: 12),

          // Summary Cards Row 1
          Row(
            children: [
              Expanded(
                child: _buildSmallCard(
                  'Approved',
                  totalApprovedFromTables,
                  approvedColor,
                  Icons.check_circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSmallCard(
                  'Pending',
                  totalPendingDeposit,
                  pendingColor,
                  Icons.pending,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Summary Cards Row 2
          Row(
            children: [
              Expanded(
                child: _buildSmallCard(
                  'Rejected',
                  totalRejectedDeposit,
                  rejectedColor,
                  Icons.cancel,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.receipt_long, size: 18, color: primaryColor),
                      const SizedBox(height: 8),
                      Text(
                        'Total',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${allDeposits.length}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Approved Deposits Section
          if (approvedDeposits.isNotEmpty) ...[
            _buildSectionHeader(
              'Approved Deposits',
              approvedDeposits.length,
              approvedColor,
            ),
            const SizedBox(height: 12),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: approvedDeposits.length,
              itemBuilder: (context, index) {
                return _buildDepositItem(approvedDeposits[index]);
              },
            ),
            const SizedBox(height: 24),
          ],

          // Pending Deposits Section
          if (pendingDeposits.isNotEmpty) ...[
            _buildSectionHeader(
              'Pending Deposits',
              pendingDeposits.length,
              pendingColor,
            ),
            const SizedBox(height: 12),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: pendingDeposits.length,
              itemBuilder: (context, index) {
                return _buildDepositItem(pendingDeposits[index]);
              },
            ),
            const SizedBox(height: 24),
          ],

          // Rejected Deposits Section
          if (rejectedDeposits.isNotEmpty) ...[
            _buildSectionHeader(
              'Rejected Deposits',
              rejectedDeposits.length,
              rejectedColor,
            ),
            const SizedBox(height: 12),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: rejectedDeposits.length,
              itemBuilder: (context, index) {
                return _buildDepositItem(rejectedDeposits[index]);
              },
            ),
          ],

          // Empty State
          if (allDeposits.isEmpty) _buildEmptyState(),
        ],
      ),
    );
  }

  // ==================== SECTION HEADER ====================

  Widget _buildSectionHeader(String title, int count, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Text(
            '$count Items',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  // ==================== BALANCE CARD ====================

  Widget _buildBalanceCard(
    String title,
    double amount,
    List<Color> gradientColors,
    IconData icon, {
    String subtitle = '',
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: gradientColors[0].withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 32, color: Colors.white),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '\$${amount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== SMALL CARD ====================

  Widget _buildSmallCard(
    String title,
    double amount,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '\$${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ==================== DEPOSIT ITEM ====================

  Widget _buildDepositItem(Map<String, dynamic> deposit) {
    final amount = deposit['amount'];
    final status = deposit['status'];
    final date = deposit['created_at'] ?? '';
    final transactionId = deposit['transaction_id'] ?? 'N/A';
    final source = deposit['source'] ?? 'deposites';

    double depositAmount = _parseAmount(amount);

    Color statusColor = approvedColor;
    IconData statusIcon = Icons.check_circle;

    if (status == 'pending') {
      statusColor = pendingColor;
      statusIcon = Icons.pending;
    } else if (status == 'rejected') {
      statusColor = rejectedColor;
      statusIcon = Icons.cancel;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(statusIcon, color: statusColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '\$${depositAmount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'TxID: $transactionId',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                if (date.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        date.split('T')[0],
                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: primaryColor.withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          source == 'deposites' ? 'Table 1' : 'Table 2',
                          style: TextStyle(
                            fontSize: 9,
                            color: primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: statusColor.withOpacity(0.3)),
            ),
            child: Text(
              status.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== EMPTY STATE ====================

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          children: [
            Icon(Icons.inbox_outlined, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'No Deposits Yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your deposit history will appear here',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== END OF DEPOSIT SCREEN ====================
