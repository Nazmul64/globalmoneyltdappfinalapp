// ==================== P2P HISTORY PAGE - THEME ENABLED ====================
// ✅ Navbar theme color from database
// ✅ All icons and colors dynamic
// ✅ Fixed TabController initialization error
// ✅ Fixed 404 API endpoint issue
// ✅ Beautiful UI with status badges
// ✅ Filter by type (All, Deposits, Withdraws)
// ✅ Pull to refresh

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'config/api_config.dart';

String get baseUrl => ApiConfig.baseUrl;

// ==================== MODELS ====================
class AppTheme {
  final String colorCode;
  final String name;

  AppTheme({required this.colorCode, required this.name});

  factory AppTheme.fromJson(Map<String, dynamic> json) {
    return AppTheme(
      colorCode: json['color_code'] ?? '#4361EE',
      name: json['name'] ?? 'Default',
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
      return const Color(0xFF4361EE);
    }
  }

  List<Color> get gradientColors {
    final base = primaryColor;
    return [base, Color.lerp(base, Colors.white, 0.2) ?? base];
  }
}

class ThemeService {
  // URL: use ApiConfig.baseUrl
  static AppTheme? _cachedTheme;

  static Future<AppTheme> fetchTheme() async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/themechange'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == true && data['data'] != null) {
          _cachedTheme = AppTheme.fromJson(data['data']);
          return _cachedTheme!;
        }
      }
    } catch (e) {
      debugPrint('❌ Theme fetch error: $e');
    }
    return _cachedTheme ?? AppTheme(colorCode: '#4361EE', name: 'Default');
  }
}

// ==================== HISTORY PAGE ====================
class P2PHistoryPage extends StatefulWidget {
  const P2PHistoryPage({super.key});

  @override
  State<P2PHistoryPage> createState() => _P2PHistoryPageState();
}

class _P2PHistoryPageState extends State<P2PHistoryPage>
    with SingleTickerProviderStateMixin {
  // URL: use ApiConfig.baseUrl

  AppTheme? _appTheme;
  List<Color> get primaryGradient =>
      _appTheme?.gradientColors ??
      [const Color(0xFF4361EE), const Color(0xFF6B8AFF)];
  Color get themeColor => _appTheme?.primaryColor ?? const Color(0xFF4361EE);

  String? authToken;
  List<dynamic> allHistory = [];
  List<dynamic> filteredHistory = [];
  bool isLoading = true;
  String? errorMessage;
  String selectedFilter = 'all'; // all, deposit, withdraw

  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController?.addListener(_onTabChanged);
    _initializeApp();
  }

  @override
  void dispose() {
    _tabController?.removeListener(_onTabChanged);
    _tabController?.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController != null && !_tabController!.indexIsChanging) {
      setState(() {
        if (_tabController!.index == 0) {
          selectedFilter = 'all';
        } else if (_tabController!.index == 1) {
          selectedFilter = 'deposit';
        } else {
          selectedFilter = 'withdraw';
        }
        _applyFilter();
      });
    }
  }

  Future<void> _initializeApp() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    await _loadTheme();
    await _loadAuthToken();

    if (mounted && authToken != null && authToken!.isNotEmpty) {
      await _loadHistory();
    } else {
      setState(() {
        isLoading = false;
        errorMessage = 'No authentication token found';
      });
    }
  }

  Future<void> _loadTheme() async {
    try {
      final theme = await ThemeService.fetchTheme();
      if (mounted) setState(() => _appTheme = theme);
    } catch (e) {
      debugPrint('❌ Theme load error: $e');
    }
  }

  Future<void> _loadAuthToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      authToken =
          prefs.getString('auth_token') ??
          prefs.getString('token') ??
          prefs.getString('access_token');

      if (authToken != null && authToken!.isNotEmpty) {
        debugPrint('✅ Auth Token Loaded for History');
      }
    } catch (e) {
      debugPrint('❌ Token load error: $e');
      authToken = null;
    }
  }

  Future<void> _loadHistory() async {
    if (authToken == null || authToken!.isEmpty) {
      setState(() {
        isLoading = false;
        errorMessage = 'Authentication required';
      });
      return;
    }

    try {
      debugPrint('📡 Fetching P2P History...');

      final response = await http
          .get(
            Uri.parse('$baseUrl/p2p/getHistory'),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $authToken',
            },
          )
          .timeout(const Duration(seconds: 15));

      debugPrint('📥 History Response Status: ${response.statusCode}');
      debugPrint('📥 History Response Body: ${response.body}');

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == true) {
          setState(() {
            allHistory = (data['history'] as List? ?? []).map((item) {
              return {
                'id': item['id'],
                'type': item['type'] ?? 'unknown',
                'amount': item['amount']?.toString() ?? '0.00',
                'currency': item['currency'] ?? 'USDT',
                'status': item['status'] ?? 'pending',
                'agent_name': item['agent_name'] ?? 'Unknown',
                'category': item['category'] ?? 'N/A',
                'transaction_id': item['transaction_id'] ?? '',
                'payment_method': item['payment_method'] ?? '',
                'sender_account': item['sender_account'] ?? '',
                'created_at': item['created_at'] ?? '',
                'completed_at': item['completed_at'],
              };
            }).toList();

            filteredHistory = List.from(allHistory);
            isLoading = false;
            errorMessage = null;
          });

          debugPrint('✅ Loaded ${allHistory.length} history records');
        } else {
          setState(() {
            isLoading = false;
            errorMessage = data['message'] ?? 'Failed to load history';
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
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
          errorMessage = 'Connection error: ${e.toString()}';
        });
      }
      debugPrint('❌ Load history error: $e');
    }
  }

  Future<void> _handleSessionExpired() async {
    setState(() => isLoading = false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    authToken = null;
    if (mounted) {
      _showMessage('Session expired. Please login again.', isError: true);
    }
  }

  void _applyFilter() {
    setState(() {
      if (selectedFilter == 'all') {
        filteredHistory = List.from(allHistory);
      } else {
        filteredHistory = allHistory
            .where((item) => item['type'] == selectedFilter)
            .toList();
      }
    });
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : themeColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: Duration(seconds: isError ? 5 : 3),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'agent_confirmed':
        return themeColor;
      case 'cancelled':
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return 'Completed';
      case 'pending':
        return 'Pending';
      case 'agent_confirmed':
        return 'Agent Confirmed';
      case 'cancelled':
        return 'Cancelled';
      case 'rejected':
        return 'Rejected';
      default:
        return status;
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'N/A';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd MMM yyyy, hh:mm a').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: themeColor,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'P2P History',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
        ),
        body: Center(child: CircularProgressIndicator(color: themeColor)),
      );
    }

    if (errorMessage != null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: themeColor,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'P2P History',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  errorMessage!,
                  style: const TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _initializeApp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: themeColor,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 12,
                  ),
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: themeColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'P2P History',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadHistory,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_tabController != null) _buildTabBar(),
          Expanded(
            child: filteredHistory.isEmpty
                ? _buildEmptyState()
                : _buildHistoryList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(4),
        child: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(
            color: themeColor,
            borderRadius: BorderRadius.circular(10),
          ),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.black54,
          labelStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Deposits'),
            Tab(text: 'Withdraws'),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 80, color: themeColor.withOpacity(0.5)),
          const SizedBox(height: 16),
          const Text(
            'No Transaction History',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Your ${selectedFilter == 'all' ? '' : selectedFilter} transactions will appear here',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadHistory,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
            style: ElevatedButton.styleFrom(
              backgroundColor: themeColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList() {
    return RefreshIndicator(
      onRefresh: _loadHistory,
      color: themeColor,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: filteredHistory.length,
        itemBuilder: (context, index) {
          final item = filteredHistory[index];
          return _buildHistoryCard(item);
        },
      ),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> item) {
    final isDeposit = item['type'] == 'deposit';
    final status = item['status'] ?? 'pending';
    final statusColor = _getStatusColor(status);

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
          onTap: () => _showDetailsBottomSheet(item),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDeposit
                            ? themeColor.withOpacity(0.1)
                            : Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isDeposit ? Icons.arrow_downward : Icons.arrow_upward,
                        color: isDeposit ? themeColor : Colors.green,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isDeposit ? 'Buy USDT' : 'Sell USDT',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Agent: ${item['agent_name']}',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${item['amount']} ${item['currency']}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDeposit ? themeColor : Colors.green,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _getStatusText(status),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 14,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _formatDate(item['created_at']),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                    Icon(Icons.touch_app, size: 14, color: themeColor),
                    const SizedBox(width: 4),
                    Text(
                      'Tap for details',
                      style: TextStyle(
                        fontSize: 11,
                        color: themeColor,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDetailsBottomSheet(Map<String, dynamic> item) {
    final isDeposit = item['type'] == 'deposit';
    final status = item['status'] ?? 'pending';
    final statusColor = _getStatusColor(status);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
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
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDeposit
                          ? themeColor.withOpacity(0.1)
                          : Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      isDeposit ? Icons.arrow_downward : Icons.arrow_upward,
                      color: isDeposit ? themeColor : Colors.green,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isDeposit ? 'Buy USDT' : 'Sell USDT',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _getStatusText(status),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildDetailRow(
                'Amount',
                '${item['amount']} ${item['currency']}',
              ),
              _buildDetailRow('Agent', item['agent_name']),
              _buildDetailRow('Category', item['category']),
              if (item['transaction_id']?.isNotEmpty == true)
                _buildDetailRow('Transaction ID', item['transaction_id']),
              if (item['payment_method']?.isNotEmpty == true)
                _buildDetailRow('Payment Method', item['payment_method']),
              if (item['sender_account']?.isNotEmpty == true)
                _buildDetailRow('Sender Account', item['sender_account']),
              _buildDetailRow('Created At', _formatDate(item['created_at'])),
              if (item['completed_at'] != null)
                _buildDetailRow(
                  'Completed At',
                  _formatDate(item['completed_at']),
                ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: themeColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Close',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
