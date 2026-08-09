import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'config/api_config.dart';

String get baseUrl => ApiConfig.mediaBaseUrl;

class PaymentHistoryPage extends StatefulWidget {
  const PaymentHistoryPage({super.key});

  @override
  State<PaymentHistoryPage> createState() => _PaymentHistoryPageState();
}

class _PaymentHistoryPageState extends State<PaymentHistoryPage> {
  List<dynamic> history = [];
  bool loading = true;
  String? errorMessage;
  String? token;

  // আপনার actual API base URL এখানে দিন
  // URL: use ApiConfig.baseUrl

  @override
  void initState() {
    super.initState();
    _initializeAndFetch();
  }

  Future<void> _initializeAndFetch() async {
    await _loadToken();
    await fetchHistory();
  }

  // SharedPreferences থেকে token load করা
  Future<void> _loadToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      token = prefs.getString('auth_token') ?? prefs.getString('token');

      if (token == null || token!.isEmpty) {
        setState(() {
          errorMessage = "Authentication required. Please login.";
          loading = false;
        });
        return;
      }

      print('✅ Token loaded: ${token!.substring(0, 20)}...');
    } catch (e) {
      print('❌ Token load error: $e');
      setState(() {
        errorMessage = "Failed to load authentication token";
        loading = false;
      });
    }
  }

  // Payment history fetch করা
  Future<void> fetchHistory() async {
    if (token == null || token!.isEmpty) {
      setState(() {
        loading = false;
        errorMessage = "Please login to view payment history";
      });
      return;
    }

    setState(() {
      loading = true;
      errorMessage = null;
    });

    try {
      final url = "$baseUrl/api/paymenthistory";
      print('🔄 Fetching from: $url');

      final response = await http
          .get(
            Uri.parse(url),
            headers: {
              "Accept": "application/json",
              "Content-Type": "application/json",
              "Authorization": "Bearer $token",
            },
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw Exception(
                'Connection timeout. Please check your internet.',
              );
            },
          );

      print('📊 Response Status: ${response.statusCode}');
      print('📦 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['success'] == true) {
          setState(() {
            history = data['history'] ?? [];
            loading = false;
            errorMessage = null;
          });
          print('✅ History loaded: ${history.length} transactions');
        } else {
          setState(() {
            loading = false;
            errorMessage = data['message'] ?? 'Failed to load history';
          });
        }
      } else if (response.statusCode == 401) {
        setState(() {
          loading = false;
          errorMessage = "Session expired. Please login again.";
        });
        _handleLogout();
      } else {
        final data = jsonDecode(response.body);
        setState(() {
          loading = false;
          errorMessage = data['message'] ?? "Failed to load payment history";
        });
      }
    } on http.ClientException catch (e) {
      print('❌ Network error: $e');
      setState(() {
        loading = false;
        errorMessage = "Network error. Please check your connection.";
      });
    } on FormatException catch (e) {
      print('❌ JSON Parse error: $e');
      setState(() {
        loading = false;
        errorMessage = "Invalid server response";
      });
    } catch (e) {
      print('❌ Unknown error: $e');
      setState(() {
        loading = false;
        errorMessage = "Error: ${e.toString()}";
      });
    }
  }

  // Logout handler
  void _handleLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  // Status color
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
      case 'completed':
      case 'success':
        return const Color(0xFF22C55E);
      case 'pending':
      case 'processing':
        return const Color(0xFFFB923C);
      case 'rejected':
      case 'failed':
      case 'cancelled':
        return const Color(0xFFEF4444);
      default:
        return Colors.grey;
    }
  }

  // Type icon
  IconData _getTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'deposit':
      case 'deposit_request':
        return Icons.account_balance_wallet;
      case 'withdraw':
      case 'withdraw_request':
        return Icons.arrow_upward;
      default:
        return Icons.receipt;
    }
  }

  // Type label
  String _getTypeLabel(String type) {
    switch (type.toLowerCase()) {
      case 'deposit':
        return "Deposit";
      case 'deposit_request':
        return "Deposit Request";
      case 'withdraw':
        return "Withdraw";
      case 'withdraw_request':
        return "Withdraw Request";
      default:
        return type.capitalize();
    }
  }

  // Type color - returns Color directly
  Color _getTypeColorDirect(String type) {
    if (type.toLowerCase().contains('deposit')) {
      return Colors.green.shade700;
    } else if (type.toLowerCase().contains('withdraw')) {
      return Colors.blue.shade700;
    }
    return Colors.grey.shade700;
  }

  // Type background color
  Color _getTypeBackgroundColor(String type) {
    if (type.toLowerCase().contains('deposit')) {
      return Colors.green.shade50;
    } else if (type.toLowerCase().contains('withdraw')) {
      return Colors.blue.shade50;
    }
    return Colors.grey.shade50;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Payment History',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          if (!loading)
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.black87),
              onPressed: fetchHistory,
              tooltip: 'Refresh',
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (loading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Loading payment history...',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
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
              Icon(Icons.error_outline, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _initializeAndFetch,
                icon: const Icon(Icons.refresh),
                label: const Text("Retry"),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
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

    if (history.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 80,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              "No transaction found",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Your payment history will appear here",
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: fetchHistory,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: history.length,
        itemBuilder: (context, index) {
          final item = history[index];
          return _TransactionCard(
            transactionId: item['id']?.toString() ?? 'N/A',
            amount: item['amount']?.toString() ?? '0',
            date: item['formatted_date'] ?? item['date'] ?? 'N/A',
            time: item['time'] ?? '',
            status: item['status'] ?? 'pending',
            type: item['type'] ?? 'deposit',
            statusColor: _getStatusColor(item['status'] ?? 'pending'),
            typeIcon: _getTypeIcon(item['type'] ?? 'deposit'),
            typeLabel: _getTypeLabel(item['type'] ?? 'deposit'),
            typeColor: _getTypeColorDirect(item['type'] ?? 'deposit'),
            typeBackgroundColor: _getTypeBackgroundColor(
              item['type'] ?? 'deposit',
            ),
            photoUrl: item['photo'],
            paymentMethod: item['payment_method'],
            accountNumber: item['account_number'],
            walletAddress: item['wallet_address'],
            baseUrl: baseUrl,
          );
        },
      ),
    );
  }
}

class _TransactionCard extends StatelessWidget {
  final String transactionId;
  final String amount;
  final String date;
  final String time;
  final String status;
  final String type;
  final Color statusColor;
  final IconData typeIcon;
  final String typeLabel;
  final Color typeColor;
  final Color typeBackgroundColor;
  final String? photoUrl;
  final String? paymentMethod;
  final String? accountNumber;
  final String? walletAddress;
  final String baseUrl;

  const _TransactionCard({
    required this.transactionId,
    required this.amount,
    required this.date,
    required this.time,
    required this.status,
    required this.type,
    required this.statusColor,
    required this.typeIcon,
    required this.typeLabel,
    required this.typeColor,
    required this.typeBackgroundColor,
    required this.baseUrl,
    this.photoUrl,
    this.paymentMethod,
    this.accountNumber,
    this.walletAddress,
  });

  bool get isDeposit => type.toLowerCase().contains('deposit');

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Type Icon + Label + Amount
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: typeBackgroundColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(typeIcon, color: typeColor, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        typeLabel,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        transactionId,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '৳$amount',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: typeColor,
                  ),
                ),
              ],
            ),

            // Photo (if available)
            if (photoUrl != null && photoUrl!.isNotEmpty) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  "$baseUrl/storage/$photoUrl",
                  height: 100,
                  width: 100,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 100,
                      width: 100,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.broken_image,
                        color: Colors.grey.shade400,
                        size: 40,
                      ),
                    );
                  },
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      height: 100,
                      width: 100,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                              : null,
                          strokeWidth: 2,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],

            // Withdraw Details
            if (!isDeposit &&
                (paymentMethod != null ||
                    accountNumber != null ||
                    walletAddress != null)) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (paymentMethod != null)
                      _DetailRow(
                        icon: Icons.payment,
                        label: 'Method',
                        value: paymentMethod!,
                      ),
                    if (accountNumber != null)
                      _DetailRow(
                        icon: Icons.account_balance,
                        label: 'Account',
                        value: accountNumber!,
                      ),
                    if (walletAddress != null)
                      _DetailRow(
                        icon: Icons.account_balance_wallet,
                        label: 'Wallet',
                        value: walletAddress!,
                      ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),
            Divider(color: Colors.grey.shade200, height: 1),
            const SizedBox(height: 12),

            // Footer: Date + Time + Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 14,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          time.isNotEmpty ? '$date • $time' : date,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: statusColor.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        status.capitalize(),
                        style: TextStyle(
                          fontSize: 12,
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: Colors.blue.shade700),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 13,
              color: Colors.blue.shade800,
              fontWeight: FontWeight.w600,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return this[0].toUpperCase() + substring(1).toLowerCase();
  }
}
