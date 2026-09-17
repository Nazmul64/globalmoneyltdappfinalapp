import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'config/api_config.dart';

class WithdrawScreen extends StatefulWidget {
  final String authToken;
  final String? userId;
  final Function? onWithdrawSuccess;

  const WithdrawScreen({
    Key? key,
    required this.authToken,
    this.userId,
    this.onWithdrawSuccess,
  }) : super(key: key);

  @override
  State<WithdrawScreen> createState() => _WithdrawScreenState();
}

class _WithdrawScreenState extends State<WithdrawScreen>
    with SingleTickerProviderStateMixin {
  // ═══════════════════════════════════════════════════════════════════════════
  // CONTROLLERS & FOCUS NODES
  // ═══════════════════════════════════════════════════════════════════════════
  final TextEditingController accountController = TextEditingController();
  final TextEditingController walletController = TextEditingController();
  final TextEditingController amountController = TextEditingController();
  final TextEditingController noteController = TextEditingController();

  final FocusNode accountFocus = FocusNode();
  final FocusNode walletFocus = FocusNode();
  final FocusNode amountFocus = FocusNode();
  final FocusNode noteFocus = FocusNode();

  // ═══════════════════════════════════════════════════════════════════════════
  // STATE VARIABLES
  // ═══════════════════════════════════════════════════════════════════════════
  int? selectedPaymentMethodId;
  String? selectedPaymentMethodName;
  String? selectedPaymentMethodType;

  bool isLoading = true;
  bool isSubmitting = false;
  bool isWithdrawBlocked = false;
  bool isLoadingInstructions = true;
  bool isLoadingHistory = false;
  bool showHistory = false;
  bool isRefreshing = false;

  // ═══════════════════════════════════════════════════════════════════════════
  // API DATA
  // ═══════════════════════════════════════════════════════════════════════════
  double balance = 0.0;
  double totalUserBalance = 0.0;
  double minWithdraw = 0.0;
  double maxWithdraw = 0.0;
  double withdrawCharge = 0.0;
  String currency = "USD";

  List<Map<String, dynamic>> paymentMethods = [];
  List<Map<String, dynamic>> withdrawInstructions = [];
  List<Map<String, dynamic>> withdrawHistory = [];

  // ═══════════════════════════════════════════════════════════════════════════
  // THEME & UI
  // ═══════════════════════════════════════════════════════════════════════════
  Color primaryColor = const Color(0xFF4361EE);
  Color lightPrimaryColor = const Color(0xFF7289FF);
  Color darkPrimaryColor = const Color(0xFF2A4DBF);
  Color accentColor = const Color(0xFFFF6B6B);

  late TabController _tabController;
  int currentTabIndex = 0;

  // ═══════════════════════════════════════════════════════════════════════════
  // COMPUTED PROPERTIES
  // ═══════════════════════════════════════════════════════════════════════════
  String get baseUrl {
    if (Platform.isAndroid) {
      return ApiConfig.mediaBaseUrl;
    } else if (Platform.isIOS) {
      return ApiConfig.mediaBaseUrl;
    } else {
      return ApiConfig.mediaBaseUrl;
    }
  }

  double get calculatedAmount {
    final amount = double.tryParse(amountController.text.trim()) ?? 0.0;
    return amount > 0 ? amount - withdrawCharge : 0.0;
  }

  double get remainingBalance {
    final amount = double.tryParse(amountController.text.trim()) ?? 0.0;
    return balance - amount;
  }

  bool get isFormValid {
    return selectedPaymentMethodId != null &&
        accountController.text.trim().isNotEmpty &&
        amountController.text.trim().isNotEmpty &&
        (double.tryParse(amountController.text.trim()) ?? 0) > 0;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // LIFECYCLE METHODS
  // ═══════════════════════════════════════════════════════════════════════════
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index != currentTabIndex) {
        setState(() {
          currentTabIndex = _tabController.index;
        });
        if (_tabController.index == 1 &&
            !isLoadingHistory &&
            withdrawHistory.isEmpty) {
          _fetchWithdrawHistory();
        }
      }
    });
    _initializeScreen();
    _setupListeners();
  }

  @override
  void dispose() {
    _tabController.dispose();
    accountController.dispose();
    walletController.dispose();
    amountController.dispose();
    noteController.dispose();
    accountFocus.dispose();
    walletFocus.dispose();
    amountFocus.dispose();
    noteFocus.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // INITIALIZATION
  // ═══════════════════════════════════════════════════════════════════════════
  void _setupListeners() {
    amountController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  Future<void> _initializeScreen() async {
    try {
      await _loadTheme();
      await Future.wait([_fetchWithdrawData(), _fetchWithdrawInstructions()]);
    } catch (e) {
      debugPrint('❌ Initialization Error: $e');
      if (mounted) {
        _showErrorMessage('Failed to initialize screen');
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // THEME LOADING
  // ═══════════════════════════════════════════════════════════════════════════
  Future<void> _loadTheme() async {
    try {
      final url = '$baseUrl/api/themechange';
      debugPrint('🎨 Fetching theme from: $url');

      final response = await http
          .get(Uri.parse(url), headers: {'Accept': 'application/json'})
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw TimeoutException('Theme fetch timeout'),
          );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['status'] == true && data['data'] != null) {
          String colorCode = data['data']['color_code'] ?? '#4361EE';
          colorCode = colorCode.replaceAll('#', '');

          if (colorCode.length == 6) {
            final int colorValue = int.parse('FF$colorCode', radix: 16);
            final Color themeColor = Color(colorValue);

            if (mounted) {
              setState(() {
                primaryColor = themeColor;
                lightPrimaryColor = _lightenColor(themeColor, 0.15);
                darkPrimaryColor = _darkenColor(themeColor, 0.2);
                accentColor = _generateAccentColor(themeColor);
              });
            }

            debugPrint('✅ Theme loaded successfully: #$colorCode');
          }
        }
      } else {
        debugPrint('⚠️ Theme API returned: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('⚠️ Theme fetch error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // COLOR MANIPULATION
  // ═══════════════════════════════════════════════════════════════════════════
  Color _lightenColor(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withLightness((hsl.lightness + amount).clamp(0.0, 1.0))
        .toColor();
  }

  Color _darkenColor(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withLightness((hsl.lightness - amount).clamp(0.0, 1.0))
        .toColor();
  }

  Color _generateAccentColor(Color baseColor) {
    final hsl = HSLColor.fromColor(baseColor);
    return hsl
        .withHue((hsl.hue + 180) % 360)
        .withSaturation((hsl.saturation * 0.8).clamp(0.0, 1.0))
        .toColor();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // API: FETCH WITHDRAW DATA
  // ═══════════════════════════════════════════════════════════════════════════
  Future<void> _fetchWithdrawData() async {
    final String url = "$baseUrl/api/userwidthrawshow";

    try {
      debugPrint('═══════════════════════════════════════════════════════');
      debugPrint('📥 FETCHING WITHDRAW DATA');
      debugPrint('URL: $url');
      debugPrint('Token Length: ${widget.authToken.length}');
      debugPrint('═══════════════════════════════════════════════════════');

      final response = await http
          .get(
            Uri.parse(url),
            headers: {
              "Accept": "application/json",
              "Authorization": "Bearer ${widget.authToken}",
            },
          )
          .timeout(
            const Duration(seconds: 20),
            onTimeout: () => throw TimeoutException('Connection timeout'),
          );

      debugPrint("📊 Response Status: ${response.statusCode}");
      debugPrint(
        "📄 Response Body: ${response.body.substring(0, response.body.length > 500 ? 500 : response.body.length)}",
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data["success"] == true && data["data"] != null) {
          final responseData = data["data"];

          final blocked = responseData["is_withdraw_blocked"] == true ||
              responseData["is_blocked"] == true ||
              responseData["user"]?["is_withdraw_blocked"] == true ||
              responseData["user"]?["is_blocked"] == true ||
              data["is_withdraw_blocked"] == true;

          setState(() {
            isWithdrawBlocked = blocked;
            balance = _parseDouble(responseData["user"]?["balance"]);
            totalUserBalance = _parseDouble(responseData["total_user_balance"]);
            paymentMethods = _parsePaymentMethods(
              responseData["payment_methods"],
            );

            if (responseData["withdraw_limit"] != null) {
              minWithdraw = _parseDouble(
                responseData["withdraw_limit"]["min_withdraw_limit"],
              );
              maxWithdraw = _parseDouble(
                responseData["withdraw_limit"]["max_withdraw_limit"],
              );
            }

            withdrawCharge = _parseDouble(responseData["withdraw_charge"] ?? 0);
            currency = responseData["currency"]?.toString() ?? "USD";
            isLoading = false;
          });

          debugPrint('✅ Data loaded successfully');
          debugPrint('💰 Balance: $balance');
          debugPrint('🚫 Is Withdraw Blocked: $isWithdrawBlocked');
          debugPrint('💳 Payment Methods: ${paymentMethods.length}');
          debugPrint('📉 Min: $minWithdraw | Max: $maxWithdraw');

          if (isWithdrawBlocked) {
            _showWithdrawBlockedDialog();
          }
        } else {
          setState(() => isLoading = false);
          _showErrorMessage(data["message"] ?? "Failed to load data");
        }
      } else if (response.statusCode == 403) {
        setState(() {
          isLoading = false;
          isWithdrawBlocked = true;
        });
        final errorData = jsonDecode(response.body);
        _showWithdrawBlockedDialog(errorData["message"]);
      } else if (response.statusCode == 401) {
        setState(() => isLoading = false);
        _showErrorMessage("Invalid authentication token. Please try again.");
      } else {
        setState(() => isLoading = false);
        final errorData = jsonDecode(response.body);
        _showErrorMessage(errorData["message"] ?? "Error loading data");
      }
    } on SocketException catch (e) {
      _handleNetworkError(e);
    } on TimeoutException catch (e) {
      _handleTimeoutError(e);
    } on http.ClientException catch (e) {
      _handleClientError(e);
    } catch (e) {
      _handleUnexpectedError(e);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // API: FETCH WITHDRAW INSTRUCTIONS
  // ═══════════════════════════════════════════════════════════════════════════
  Future<void> _fetchWithdrawInstructions() async {
    final String url = "$baseUrl/api/widthrawinstructionss";

    try {
      debugPrint('📝 Fetching withdraw instructions from: $url');

      final response = await http
          .get(Uri.parse(url), headers: {"Accept": "application/json"})
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw TimeoutException('Instructions timeout'),
          );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data["status"] == true && data["data"] != null) {
          setState(() {
            withdrawInstructions = List<Map<String, dynamic>>.from(
              data["data"].map(
                (item) => {
                  "id": item["id"],
                  "instructions": item["instructions"]?.toString() ?? "",
                  "created_at": item["created_at"],
                  "updated_at": item["updated_at"],
                },
              ),
            );
            isLoadingInstructions = false;
          });

          debugPrint('✅ Instructions loaded: ${withdrawInstructions.length}');
        } else {
          setState(() => isLoadingInstructions = false);
        }
      } else {
        setState(() => isLoadingInstructions = false);
        debugPrint('⚠️ Instructions API returned: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoadingInstructions = false);
        debugPrint("⚠️ Instructions Error: $e");
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // API: FETCH WITHDRAW HISTORY
  // ═══════════════════════════════════════════════════════════════════════════
  Future<void> _fetchWithdrawHistory() async {
    if (isLoadingHistory) return;

    setState(() => isLoadingHistory = true);

    final String url = "$baseUrl/api/withdraw-history";

    try {
      debugPrint('═══════════════════════════════════════════════════════');
      debugPrint('📜 FETCHING WITHDRAW HISTORY');
      debugPrint('URL: $url');
      debugPrint('Token: Bearer ${widget.authToken.substring(0, 20)}...');
      debugPrint('═══════════════════════════════════════════════════════');

      final response = await http
          .get(
            Uri.parse(url),
            headers: {
              "Accept": "application/json",
              "Authorization": "Bearer ${widget.authToken}",
            },
          )
          .timeout(
            const Duration(seconds: 20),
            onTimeout: () => throw TimeoutException('History fetch timeout'),
          );

      debugPrint("📊 History Response Status: ${response.statusCode}");
      debugPrint("📄 History Response Body: ${response.body}");

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data["success"] == true && data["data"] != null) {
          final historyData = data["data"]["withdraw_history"];

          setState(() {
            withdrawHistory = List<Map<String, dynamic>>.from(
              historyData.map(
                (item) => {
                  "id": item["id"],
                  "amount": _parseDouble(item["amount"]),
                  "commission": _parseDouble(item["commission"] ?? 0),
                  "status": item["status"]?.toString() ?? 'pending',
                  "payment_method": item["payment_method"]?.toString() ?? 'N/A',
                  "account_number": item["account_number"]?.toString() ?? 'N/A',
                  "wallet_address": item["wallet_address"]?.toString() ?? '',
                  "requested_at": item["requested_at"]?.toString() ?? '',
                  "updated_at": item["updated_at"]?.toString() ?? '',
                  "created_at": item["requested_at"]?.toString() ?? '',
                },
              ),
            );
            isLoadingHistory = false;
          });

          debugPrint('✅ History loaded successfully');
          debugPrint('📊 Total records: ${withdrawHistory.length}');

          if (withdrawHistory.isNotEmpty) {
            debugPrint('📋 First record: ${withdrawHistory[0]}');
          }
        } else {
          setState(() => isLoadingHistory = false);
          debugPrint('⚠️ No history data available');
        }
      } else if (response.statusCode == 401) {
        setState(() => isLoadingHistory = false);
        _showErrorMessage(
          "Invalid authentication. Please check your credentials.",
        );
      } else {
        setState(() => isLoadingHistory = false);
        final errorData = jsonDecode(response.body);
        debugPrint('❌ History Error: ${errorData["message"]}');
        _showErrorMessage(errorData["message"] ?? "Failed to load history");
      }
    } on SocketException catch (e) {
      setState(() => isLoadingHistory = false);
      _handleNetworkError(e);
    } on TimeoutException catch (e) {
      setState(() => isLoadingHistory = false);
      _handleTimeoutError(e);
    } catch (e) {
      setState(() => isLoadingHistory = false);
      _handleUnexpectedError(e);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // API: SUBMIT WITHDRAW REQUEST
  // ═══════════════════════════════════════════════════════════════════════════
  Future<void> _submitWithdraw() async {
    FocusScope.of(context).unfocus();

    if (!_validateForm()) return;

    final double amount = double.parse(amountController.text.trim());

    final bool? confirmed = await _showConfirmationDialog(amount);
    if (confirmed != true) return;

    setState(() => isSubmitting = true);

    final String url = "$baseUrl/api/userwidthrawstore";

    try {
      final requestBody = {
        "payment_method_id": selectedPaymentMethodId,
        "account_number": accountController.text.trim(),
        "wallet_address": walletController.text.trim(),
        "amount": amount,
        "note": noteController.text.trim(),
      };

      debugPrint('═══════════════════════════════════════════════════════');
      debugPrint('📤 SUBMITTING WITHDRAW REQUEST');
      debugPrint('URL: $url');
      debugPrint('Payment Method: $selectedPaymentMethodName');
      debugPrint('Amount: $amount');
      debugPrint('═══════════════════════════════════════════════════════');

      final response = await http
          .post(
            Uri.parse(url),
            headers: {
              "Accept": "application/json",
              "Content-Type": "application/json",
              "Authorization": "Bearer ${widget.authToken}",
            },
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 20));

      if (!mounted) return;

      setState(() => isSubmitting = false);

      debugPrint("📊 Submit Status: ${response.statusCode}");
      debugPrint("📄 Submit Response: ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);

        if (data["success"] == true) {
          await _handleSuccessfulWithdraw(data);
        } else {
          _showErrorMessage(data["message"] ?? "Failed to submit request");
        }
      } else if (response.statusCode == 403) {
        setState(() => isWithdrawBlocked = true);
        final errorData = jsonDecode(response.body);
        _showWithdrawBlockedDialog(errorData["message"]);
      } else if (response.statusCode == 401) {
        _showErrorMessage(
          "Authentication failed. Please check your credentials.",
        );
      } else if (response.statusCode == 422) {
        final data = jsonDecode(response.body);
        _handleValidationErrors(data);
      } else {
        final errorData = jsonDecode(response.body);
        _showErrorMessage(errorData["message"] ?? "Failed to submit request");
      }
    } on SocketException catch (e) {
      setState(() => isSubmitting = false);
      _handleNetworkError(e);
    } on TimeoutException catch (e) {
      setState(() => isSubmitting = false);
      _handleTimeoutError(e);
    } catch (e) {
      setState(() => isSubmitting = false);
      _handleUnexpectedError(e);
    }
  }

  void _showWithdrawBlockedDialog([String? customMessage]) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.block_flipped, color: Colors.red, size: 24),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                "উত্তোলন স্থগিত (Withdrawal Blocked)",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          customMessage ??
              "আপনার অ্যাকাউন্ট থেকে উইথড্র ও P2P USDT সেল সাময়িকভাবে বন্ধ আছে। বিস্তারিত জানতে সাপোর্টে যোগাযোগ করুন।",
          style: const TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text("ঠিক আছে",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ),
        ],
      ),
    );
  }
  // PART 2 - VALIDATION, ERROR HANDLERS & UTILITY METHODS
  // ═══════════════════════════════════════════════════════════════════════════
  // This part continues from Part 1 - Add after _submitWithdraw method

  // ═══════════════════════════════════════════════════════════════════════════
  // VALIDATION
  // ═══════════════════════════════════════════════════════════════════════════
  bool _validateForm() {
    if (selectedPaymentMethodId == null) {
      _showErrorMessage("Please select a payment method");
      return false;
    }

    if (accountController.text.trim().isEmpty) {
      _showErrorMessage("Please enter account number");
      accountFocus.requestFocus();
      return false;
    }

    if (amountController.text.trim().isEmpty) {
      _showErrorMessage("Please enter withdraw amount");
      amountFocus.requestFocus();
      return false;
    }

    final double amount = double.tryParse(amountController.text.trim()) ?? 0;

    if (amount <= 0) {
      _showErrorMessage("Please enter a valid amount");
      amountFocus.requestFocus();
      return false;
    }

    if (amount < minWithdraw) {
      _showErrorMessage(
        "Minimum withdraw amount is $currency${minWithdraw.toStringAsFixed(2)}",
      );
      return false;
    }

    if (amount > maxWithdraw) {
      _showErrorMessage(
        "Maximum withdraw amount is $currency${maxWithdraw.toStringAsFixed(2)}",
      );
      return false;
    }

    if (amount > balance) {
      _showErrorMessage("Insufficient balance");
      return false;
    }

    if (amount > totalUserBalance) {
      _showErrorMessage("Insufficient main balance. Please contact support.");
      return false;
    }

    return true;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SUCCESS HANDLER
  // ═══════════════════════════════════════════════════════════════════════════
  Future<void> _handleSuccessfulWithdraw(Map<String, dynamic> data) async {
    debugPrint('✅ Withdraw submitted successfully');

    await _showSuccessDialog(data);
    _clearForm();
    await _fetchWithdrawData();

    if (currentTabIndex == 1) {
      await _fetchWithdrawHistory();
    }

    if (widget.onWithdrawSuccess != null) {
      widget.onWithdrawSuccess!();
    }
  }

  void _clearForm() {
    accountController.clear();
    walletController.clear();
    amountController.clear();
    noteController.clear();
    setState(() {
      selectedPaymentMethodId = null;
      selectedPaymentMethodName = null;
      selectedPaymentMethodType = null;
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ERROR HANDLERS
  // ═══════════════════════════════════════════════════════════════════════════
  void _handleNetworkError(dynamic error) {
    if (mounted) {
      setState(() => isLoading = false);
      debugPrint("❌ Network Error: $error");
      _showErrorMessage(
        "Cannot connect to server. Please check your internet connection.",
      );
    }
  }

  void _handleTimeoutError(dynamic error) {
    if (mounted) {
      setState(() => isLoading = false);
      debugPrint("❌ Timeout Error: $error");
      _showErrorMessage("Request timeout. Please try again.");
    }
  }

  void _handleClientError(dynamic error) {
    if (mounted) {
      setState(() => isLoading = false);
      debugPrint("❌ Client Error: $error");
      _showErrorMessage("Network error. Please try again.");
    }
  }

  void _handleUnexpectedError(dynamic error) {
    if (mounted) {
      setState(() => isLoading = false);
      debugPrint("❌ Unexpected Error: $error");
      _showErrorMessage("An unexpected error occurred");
    }
  }

  void _handleValidationErrors(Map<String, dynamic> data) {
    if (data["errors"] != null) {
      final errors = data["errors"] as Map<String, dynamic>;
      final firstError = errors.values.first;
      if (firstError is List && firstError.isNotEmpty) {
        _showErrorMessage(firstError.first.toString());
      } else {
        _showErrorMessage(firstError.toString());
      }
    } else {
      _showErrorMessage(data["message"] ?? "Validation failed");
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // UTILITY METHODS
  // ═══════════════════════════════════════════════════════════════════════════
  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }

  List<Map<String, dynamic>> _parsePaymentMethods(dynamic data) {
    if (data == null) return [];
    try {
      return List<Map<String, dynamic>>.from(
        data.map(
          (item) => {
            "id": item["id"],
            "method_name": item["method_name"]?.toString() ?? "",
            "photo": item["photo"]?.toString() ?? "",
            "status": item["status"]?.toString() ?? "inactive",
            "type": item["type"]?.toString() ?? "bank",
          },
        ),
      );
    } catch (e) {
      debugPrint("Error parsing payment methods: $e");
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // REFRESH
  // ═══════════════════════════════════════════════════════════════════════════
  Future<void> _refreshAll() async {
    if (isRefreshing) return;

    setState(() => isRefreshing = true);

    try {
      await Future.wait([
        _fetchWithdrawData(),
        _fetchWithdrawInstructions(),
        if (currentTabIndex == 1) _fetchWithdrawHistory(),
      ]);
    } finally {
      if (mounted) {
        setState(() => isRefreshing = false);
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // STATUS HELPER METHODS
  // ═══════════════════════════════════════════════════════════════════════════
  Map<String, dynamic> _getStatusInfo(String status) {
    final statusLower = status.toLowerCase();

    switch (statusLower) {
      case 'approved':
      case 'completed':
        return {
          'color': Colors.green,
          'icon': Icons.check_circle,
          'text': 'Completed',
          'bgColor': Colors.green[50],
        };
      case 'rejected':
      case 'cancelled':
        return {
          'color': Colors.red,
          'icon': Icons.cancel,
          'text': 'Rejected',
          'bgColor': Colors.red[50],
        };
      case 'processing':
        return {
          'color': Colors.orange,
          'icon': Icons.hourglass_empty,
          'text': 'Processing',
          'bgColor': Colors.orange[50],
        };
      default:
        return {
          'color': Colors.blue,
          'icon': Icons.pending,
          'text': 'Pending',
          'bgColor': Colors.blue[50],
        };
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DATE FORMATTING
  // ═══════════════════════════════════════════════════════════════════════════
  String _formatDate(String dateString) {
    if (dateString.isEmpty) return 'N/A';

    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays == 0) {
        if (difference.inHours == 0) {
          if (difference.inMinutes == 0) {
            return 'Just now';
          }
          return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
        }
        return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
      } else if (difference.inDays == 1) {
        return 'Yesterday at ${DateFormat('hh:mm a').format(date)}';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
      } else if (difference.inDays < 30) {
        final weeks = (difference.inDays / 7).floor();
        return '$weeks week${weeks > 1 ? 's' : ''} ago';
      } else {
        return DateFormat('MMM dd, yyyy • hh:mm a').format(date);
      }
    } catch (e) {
      debugPrint('Error formatting date: $e');
      return dateString;
    }
  }

  String _formatFullDate(String dateString) {
    if (dateString.isEmpty) return 'N/A';

    try {
      final date = DateTime.parse(dateString);
      return DateFormat('MMMM dd, yyyy • hh:mm a').format(date);
    } catch (e) {
      return dateString;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DIALOGS - CONFIRMATION
  // ═══════════════════════════════════════════════════════════════════════════
  Future<bool?> _showConfirmationDialog(double amount) async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange[100],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orange[700],
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Confirm Withdraw',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  children: [
                    _buildConfirmRow(
                      'Payment Method:',
                      selectedPaymentMethodName ?? '',
                      Icons.payment,
                    ),
                    const Divider(height: 24),
                    _buildConfirmRow(
                      'Account:',
                      accountController.text,
                      Icons.account_balance,
                    ),
                    if (walletController.text.trim().isNotEmpty) ...[
                      const Divider(height: 24),
                      _buildConfirmRow(
                        'Wallet:',
                        walletController.text,
                        Icons.account_balance_wallet,
                      ),
                    ],
                    const Divider(height: 24),
                    _buildConfirmRow(
                      'Amount:',
                      '$currency${amount.toStringAsFixed(2)}',
                      Icons.monetization_on,
                      valueColor: primaryColor,
                    ),
                    if (withdrawCharge > 0) ...[
                      const Divider(height: 24),
                      _buildConfirmRow(
                        'Processing Fee:',
                        '- $currency${withdrawCharge.toStringAsFixed(2)}',
                        Icons.remove_circle_outline,
                        valueColor: Colors.red,
                      ),
                      const Divider(height: 24, thickness: 2),
                      _buildConfirmRow(
                        'You will receive:',
                        '$currency${calculatedAmount.toStringAsFixed(2)}',
                        Icons.account_balance_wallet,
                        isBold: true,
                        valueColor: Colors.green,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Please verify all details before confirming',
                        style: TextStyle(
                          color: Colors.blue[900],
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 2,
              ),
              child: const Text(
                'Confirm',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildConfirmRow(
    String label,
    String value,
    IconData icon, {
    bool isBold = false,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              fontSize: isBold ? 16 : 13,
              color: valueColor ?? Colors.black87,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DIALOGS - SUCCESS
  // ═══════════════════════════════════════════════════════════════════════════
  Future<void> _showSuccessDialog(Map<String, dynamic> data) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          contentPadding: const EdgeInsets.all(32),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green[400]!, Colors.green[600]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withOpacity(0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.check_circle_outline,
                  color: Colors.white,
                  size: 64,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Success!',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                data["message"] ?? "Withdraw request submitted successfully!",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Your request is being processed',
                  style: TextStyle(
                    color: Colors.blue[700],
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                child: const Text(
                  'OK',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SNACKBAR MESSAGES
  // ═══════════════════════════════════════════════════════════════════════════
  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;

    try {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                isError ? Icons.error_outline : Icons.check_circle_outline,
                color: Colors.white,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
          backgroundColor: isError ? Colors.red[700] : Colors.green[700],
          duration: Duration(seconds: isError ? 4 : 3),
          action: SnackBarAction(
            label: 'OK',
            textColor: Colors.white,
            onPressed: () {
              if (mounted) {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              }
            },
          ),
        ),
      );
    } catch (e) {
      debugPrint('⚠️ Error showing message: $e');
    }
  }

  void _showErrorMessage(String message) {
    _showMessage(message, isError: true);
  }

  void _showSuccessMessage(String message) {
    _showMessage(message, isError: false);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PART 3 - BUILD METHOD & UI COMPONENTS
  // ═══════════════════════════════════════════════════════════════════════════
  // This part continues from Part 2 - Add after _showSuccessMessage method

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD METHOD
  // ═══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: _buildAppBar(),
      body: isLoading ? _buildLoadingState() : _buildMainContent(),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // APP BAR
  // ═══════════════════════════════════════════════════════════════════════════
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: primaryColor,
      elevation: 0,
      title: const Text(
        "Withdraw Funds",
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 18,
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      centerTitle: true,
      actions: [
        if (!isLoading)
          IconButton(
            icon: isRefreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.refresh, color: Colors.white),
            onPressed: isRefreshing ? null : _refreshAll,
            tooltip: 'Refresh',
          ),
      ],
      bottom: TabBar(
        controller: _tabController,
        indicatorColor: Colors.white,
        indicatorWeight: 3,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white70,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        tabs: const [
          Tab(icon: Icon(Icons.send), text: 'New Withdraw'),
          Tab(icon: Icon(Icons.history), text: 'History'),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // LOADING STATE
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: primaryColor, strokeWidth: 3),
          const SizedBox(height: 20),
          Text(
            "Loading withdraw data...",
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MAIN CONTENT
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildMainContent() {
    return TabBarView(
      controller: _tabController,
      children: [_buildWithdrawTab(), _buildHistoryTab()],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // WITHDRAW TAB
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildWithdrawTab() {
    return RefreshIndicator(
      color: primaryColor,
      onRefresh: _refreshAll,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            _buildBalanceCard(),
            if (withdrawInstructions.isNotEmpty)
              _buildWithdrawInstructionsCard(),
            _buildWithdrawForm(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BALANCE CARD
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildBalanceCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor, darkPrimaryColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            "AVAILABLE BALANCE",
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white70,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "$currency${balance.toStringAsFixed(2)}",
            style: const TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.3)),
            ),
            child: Column(
              children: [
                _buildLimitRow(
                  "Minimum Withdraw",
                  "$currency${minWithdraw.toStringAsFixed(2)}",
                  Icons.arrow_downward,
                  Colors.orangeAccent,
                ),
                Divider(height: 24, color: Colors.white.withOpacity(0.3)),
                _buildLimitRow(
                  "Maximum Withdraw",
                  "$currency${maxWithdraw.toStringAsFixed(2)}",
                  Icons.arrow_upward,
                  Colors.greenAccent,
                ),
                if (withdrawCharge > 0) ...[
                  Divider(height: 24, color: Colors.white.withOpacity(0.3)),
                  _buildLimitRow(
                    "Withdraw Charge",
                    "$currency${withdrawCharge.toStringAsFixed(2)}",
                    Icons.account_balance,
                    Colors.yellowAccent,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLimitRow(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // INSTRUCTIONS CARD
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildWithdrawInstructionsCard() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [primaryColor, lightPrimaryColor],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.info_outline,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Important Instructions',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: withdrawInstructions.asMap().entries.map((entry) {
                  int index = entry.key;
                  Map<String, dynamic> instruction = entry.value;
                  return Column(
                    children: [
                      _buildInstructionItem(instruction, index + 1),
                      if (index < withdrawInstructions.length - 1)
                        Divider(
                          height: 24,
                          thickness: 1,
                          color: Colors.grey[200],
                        ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionItem(Map<String, dynamic> instruction, int number) {
    final String instructions =
        instruction['instructions']?.toString() ?? 'No instructions';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primaryColor.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryColor, darkPrimaryColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              '$number',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              instructions,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[800],
                height: 1.6,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // WITHDRAW FORM
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildWithdrawForm() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle("Select Payment Method", Icons.payment),
            const SizedBox(height: 12),
            _buildPaymentMethodDropdown(),
            const SizedBox(height: 24),
            _buildSectionTitle("Account Number", Icons.account_balance),
            const SizedBox(height: 12),
            _buildTextField(
              controller: accountController,
              focusNode: accountFocus,
              hint: "Enter your account number",
              keyboardType: TextInputType.number,
              prefixIcon: Icons.account_balance,
            ),
            const SizedBox(height: 24),
            _buildSectionTitle(
              "Wallet Address (Optional)",
              Icons.account_balance_wallet,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: walletController,
              focusNode: walletFocus,
              hint: "Enter wallet address if applicable",
              keyboardType: TextInputType.text,
              prefixIcon: Icons.account_balance_wallet,
            ),
            const SizedBox(height: 24),
            _buildSectionTitle("Withdraw Amount", Icons.attach_money),
            const SizedBox(height: 12),
            _buildTextField(
              controller: amountController,
              focusNode: amountFocus,
              hint:
                  "Enter amount ($currency${minWithdraw.toStringAsFixed(0)} - $currency${maxWithdraw.toStringAsFixed(0)})",
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              prefixIcon: Icons.attach_money,
            ),
            if (amountController.text.isNotEmpty &&
                double.tryParse(amountController.text) != null &&
                double.parse(amountController.text) > 0) ...[
              const SizedBox(height: 16),
              _buildAmountSummary(),
            ],
            const SizedBox(height: 24),
            _buildSectionTitle("Note (Optional)", Icons.note),
            const SizedBox(height: 12),
            _buildTextField(
              controller: noteController,
              focusNode: noteFocus,
              hint: "Add any additional note",
              keyboardType: TextInputType.multiline,
              prefixIcon: Icons.note,
              maxLines: 3,
            ),
            const SizedBox(height: 30),
            _buildSubmitButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: primaryColor),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentMethodDropdown() {
    final activeMethods = paymentMethods
        .where((item) => item["status"] == "active")
        .toList();

    if (activeMethods.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange[50],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.orange[200]!),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange[700]),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'No active payment methods available',
                style: TextStyle(
                  color: Colors.orange[900],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(10),
        color: Colors.grey[50],
      ),
      child: DropdownButtonFormField<int>(
        value: selectedPaymentMethodId,
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          prefixIcon: Icon(Icons.payment, color: primaryColor, size: 22),
        ),
        hint: const Text("-- Select Payment Method --"),
        isExpanded: true,
        items: activeMethods.map((item) {
          return DropdownMenuItem<int>(
            value: item["id"],
            child: Row(
              children: [
                if (item["photo"] != null &&
                    item["photo"].toString().isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.network(
                      "$baseUrl/${item["photo"]}",
                      width: 35,
                      height: 35,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return _buildMethodIcon();
                      },
                    ),
                  )
                else
                  _buildMethodIcon(),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item["method_name"].toString(),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
        onChanged: (value) {
          setState(() {
            selectedPaymentMethodId = value;
            final method = paymentMethods.firstWhere(
              (item) => item["id"] == value,
              orElse: () => {},
            );
            selectedPaymentMethodName = method["method_name"]?.toString();
            selectedPaymentMethodType = method["type"]?.toString();
          });
        },
      ),
    );
  }

  Widget _buildMethodIcon() {
    return Container(
      width: 35,
      height: 35,
      decoration: BoxDecoration(
        color: lightPrimaryColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(Icons.payment, size: 22, color: primaryColor),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hint,
    required TextInputType keyboardType,
    required IconData prefixIcon,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      maxLines: maxLines,
      onChanged: (value) => setState(() {}),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
        prefixIcon: Icon(prefixIcon, color: primaryColor, size: 22),
        border: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(10),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(10),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: primaryColor, width: 2),
          borderRadius: BorderRadius.circular(10),
        ),
        errorBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.red),
          borderRadius: BorderRadius.circular(10),
        ),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 16,
          horizontal: 16,
        ),
        filled: true,
        fillColor: Colors.grey[50],
      ),
    );
  }

  Widget _buildAmountSummary() {
    final amount = double.parse(amountController.text);
    final willReceive = withdrawCharge > 0 ? amount - withdrawCharge : amount;
    final remaining = balance - amount;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            lightPrimaryColor.withOpacity(0.1),
            primaryColor.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primaryColor.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          _buildSummaryRow(
            "Withdraw Amount",
            "$currency${amount.toStringAsFixed(2)}",
            Icons.monetization_on,
            Colors.blue,
          ),
          if (withdrawCharge > 0) ...[
            const SizedBox(height: 12),
            _buildSummaryRow(
              "Processing Fee",
              "- $currency${withdrawCharge.toStringAsFixed(2)}",
              Icons.remove_circle_outline,
              Colors.red,
            ),
            const Divider(height: 24),
            _buildSummaryRow(
              "You Will Receive",
              "$currency${willReceive.toStringAsFixed(2)}",
              Icons.account_balance_wallet,
              Colors.green,
              isBold: true,
            ),
            const SizedBox(height: 12),
          ],
          if (withdrawCharge == 0) const SizedBox(height: 12),
          _buildSummaryRow(
            "Remaining Balance",
            "$currency${remaining.toStringAsFixed(2)}",
            Icons.account_balance,
            remaining >= 0 ? Colors.green : Colors.red,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value,
    IconData icon,
    Color color, {
    bool isBold = false,
  }) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[700],
              fontWeight: isBold ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 16 : 14,
            color: color,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: (isSubmitting || !isFormValid || isWithdrawBlocked)
            ? null
            : _submitWithdraw,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 2,
          disabledBackgroundColor: Colors.grey[400],
        ),
        child: isSubmitting
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.send, color: Colors.white, size: 20),
                  SizedBox(width: 12),
                  Text(
                    "SUBMIT WITHDRAW REQUEST",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 15,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PART 4 - HISTORY TAB & DETAILS DIALOG
  // ═══════════════════════════════════════════════════════════════════════════
  // This part continues from Part 3 - Add after _buildSubmitButton method

  // ═══════════════════════════════════════════════════════════════════════════
  // HISTORY TAB
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildHistoryTab() {
    if (isLoadingHistory) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: primaryColor, strokeWidth: 3),
            const SizedBox(height: 16),
            Text(
              'Loading history...',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    if (withdrawHistory.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.history, size: 80, color: Colors.grey[300]),
            ),
            const SizedBox(height: 24),
            Text(
              'No withdraw history',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your withdraw requests will appear here',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                _tabController.animateTo(0);
              },
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text(
                'Make a Withdraw',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: primaryColor,
      onRefresh: _fetchWithdrawHistory,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: withdrawHistory.length,
        physics: const AlwaysScrollableScrollPhysics(),
        itemBuilder: (context, index) {
          return _buildHistoryCard(withdrawHistory[index], index);
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HISTORY CARD - ENHANCED WITH ALL DETAILS
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildHistoryCard(Map<String, dynamic> withdraw, int index) {
    final status = withdraw['status']?.toString().toLowerCase() ?? 'pending';
    final amount = _parseDouble(withdraw['amount']);
    final commission = _parseDouble(withdraw['commission']);
    final receivedAmount = amount - commission;
    final method = withdraw['payment_method']?.toString() ?? 'N/A';
    final account = withdraw['account_number']?.toString() ?? 'N/A';
    final wallet = withdraw['wallet_address']?.toString() ?? '';
    final requestedAt = withdraw['requested_at']?.toString() ?? '';
    final updatedAt = withdraw['updated_at']?.toString() ?? '';

    final statusInfo = _getStatusInfo(status);
    final Color statusColor = statusInfo['color'];
    final IconData statusIcon = statusInfo['icon'];
    final String statusText = statusInfo['text'];
    final Color bgColor = statusInfo['bgColor'];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(statusIcon, color: statusColor, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            "$currency${amount.toStringAsFixed(2)}",
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (commission > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange[100],
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                "Fee: $currency${commission.toStringAsFixed(2)}",
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.orange[900],
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.schedule,
                            size: 14,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              _formatDate(requestedAt),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: statusColor.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    statusText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildDetailRow(
                  icon: Icons.payment,
                  label: 'Payment Method',
                  value: method,
                  iconColor: Colors.blue,
                ),
                const SizedBox(height: 14),
                _buildDetailRow(
                  icon: Icons.account_balance,
                  label: 'Account Number',
                  value: account,
                  iconColor: Colors.purple,
                ),
                if (wallet.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _buildDetailRow(
                    icon: Icons.account_balance_wallet,
                    label: 'Wallet Address',
                    value: wallet,
                    iconColor: Colors.orange,
                    isExpandable: true,
                  ),
                ],
                if (commission > 0) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 16,
                                  color: Colors.blue[700],
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Amount Breakdown',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.blue[900],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _buildBreakdownRow('Requested', amount),
                        const SizedBox(height: 6),
                        _buildBreakdownRow(
                          'Commission',
                          commission,
                          isNegative: true,
                        ),
                        Divider(height: 16, color: Colors.blue[300]),
                        _buildBreakdownRow(
                          'You Received',
                          receivedAmount,
                          isBold: true,
                        ),
                      ],
                    ),
                  ),
                ],
                if (updatedAt.isNotEmpty && updatedAt != requestedAt) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.update, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Last updated: ${_formatFullDate(updatedAt)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.tag, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 6),
                    Text(
                      'Transaction ID: #${withdraw['id']}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () {
                    _showWithdrawDetailsDialog(withdraw);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        Text(
                          'Details',
                          style: TextStyle(
                            fontSize: 12,
                            color: primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 10,
                          color: primaryColor,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DETAIL ROW BUILDER
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    required Color iconColor,
    bool isExpandable = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: isExpandable ? 2 : 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BREAKDOWN ROW BUILDER
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildBreakdownRow(
    String label,
    double amount, {
    bool isNegative = false,
    bool isBold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isBold ? 13 : 12,
            color: Colors.grey[700],
            fontWeight: isBold ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
        Text(
          '${isNegative ? '-' : ''}$currency${amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: isBold ? 14 : 12,
            color: isNegative
                ? Colors.red[700]
                : (isBold ? Colors.green[700] : Colors.black87),
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // WITHDRAW DETAILS DIALOG
  // ═══════════════════════════════════════════════════════════════════════════
  void _showWithdrawDetailsDialog(Map<String, dynamic> withdraw) {
    final status = withdraw['status']?.toString() ?? 'pending';
    final amount = _parseDouble(withdraw['amount']);
    final commission = _parseDouble(withdraw['commission']);
    final receivedAmount = amount - commission;
    final method = withdraw['payment_method']?.toString() ?? 'N/A';
    final account = withdraw['account_number']?.toString() ?? 'N/A';
    final wallet = withdraw['wallet_address']?.toString() ?? '';
    final requestedAt = withdraw['requested_at']?.toString() ?? '';
    final updatedAt = withdraw['updated_at']?.toString() ?? '';

    final statusInfo = _getStatusInfo(status);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [primaryColor, darkPrimaryColor],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Withdraw Details',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close, color: Colors.white),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "$currency${amount.toStringAsFixed(2)}",
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: statusInfo['color'],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              statusInfo['icon'],
                              color: Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              statusInfo['text'],
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDialogInfoRow(
                        'Transaction ID',
                        '#${withdraw['id']}',
                        Icons.tag,
                      ),
                      const Divider(height: 24),
                      _buildDialogInfoRow(
                        'Payment Method',
                        method,
                        Icons.payment,
                      ),
                      const Divider(height: 24),
                      _buildDialogInfoRow(
                        'Account Number',
                        account,
                        Icons.account_balance,
                      ),
                      if (wallet.isNotEmpty) ...[
                        const Divider(height: 24),
                        _buildDialogInfoRow(
                          'Wallet Address',
                          wallet,
                          Icons.account_balance_wallet,
                        ),
                      ],
                      if (commission > 0) ...[
                        const Divider(height: 24),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.calculate,
                                    size: 18,
                                    color: Colors.blue[700],
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Amount Breakdown',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue[900],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _buildBreakdownRow('Requested Amount', amount),
                              const SizedBox(height: 8),
                              _buildBreakdownRow(
                                'Processing Fee',
                                commission,
                                isNegative: true,
                              ),
                              Divider(height: 20, color: Colors.blue[300]),
                              _buildBreakdownRow(
                                'Amount Received',
                                receivedAmount,
                                isBold: true,
                              ),
                            ],
                          ),
                        ),
                      ],
                      const Divider(height: 24),
                      _buildDialogInfoRow(
                        'Requested At',
                        _formatFullDate(requestedAt),
                        Icons.schedule,
                      ),
                      if (updatedAt.isNotEmpty && updatedAt != requestedAt) ...[
                        const Divider(height: 24),
                        _buildDialogInfoRow(
                          'Last Updated',
                          _formatFullDate(updatedAt),
                          Icons.update,
                        ),
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Close',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDialogInfoRow(String label, String value, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: primaryColor),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PART 5 - FINAL PART (CLOSING)
  // ═══════════════════════════════════════════════════════════════════════════
  // This part continues from Part 4 - Add after _buildDialogInfoRow method

  // Closing brace for _WithdrawScreenState class
}

// ═══════════════════════════════════════════════════════════════════════════
// EXTENSION: TIMEOUT EXCEPTION
// ═══════════════════════════════════════════════════════════════════════════
class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);

  @override
  String toString() => message;
}

// ═══════════════════════════════════════════════════════════════════════════
// END OF FILE
// ═══════════════════════════════════════════════════════════════════════════

/*
 * ═══════════════════════════════════════════════════════════════════════════
 * WITHDRAW SCREEN - COMPLETE STRUCTURE
 * ═══════════════════════════════════════════════════════════════════════════
 *
 * FILE STRUCTURE:
 * ---------------
 * Part 1: Imports, Class Declaration & State Variables
 *         - Controllers & Focus Nodes
 *         - State Variables
 *         - API Data
 *         - Theme & UI
 *         - Computed Properties
 *         - Lifecycle Methods
 *         - Theme Loading & Color Manipulation
 *         - API Methods (Fetch Data, Instructions, History, Submit)
 *
 * Part 2: Validation, Error Handlers & Utility Methods
 *         - Form Validation
 *         - Success Handler
 *         - Error Handlers (Network, Timeout, Client, Unexpected)
 *         - Utility Methods (Parse Double, Parse Payment Methods)
 *         - Refresh Functionality
 *         - Status Helper Methods
 *         - Date Formatting
 *         - Confirmation Dialog
 *         - Success Dialog
 *         - Snackbar Messages
 *
 * Part 3: Build Method & UI Components
 *         - Main Build Method
 *         - AppBar
 *         - Loading State
 *         - Main Content (TabBarView)
 *         - Withdraw Tab
 *         - Balance Card
 *         - Instructions Card
 *         - Withdraw Form (Payment Method, Fields, Summary, Submit Button)
 *
 * Part 4: History Tab & Details Dialog
 *         - History Tab (Loading, Empty, List)
 *         - History Card (Enhanced with all details)
 *         - Detail Row Builder
 *         - Breakdown Row Builder
 *         - Withdraw Details Dialog (Full transaction details)
 *
 * Part 5: Final Part
 *         - Class Closing
 *         - TimeoutException Class
 *
 * ═══════════════════════════════════════════════════════════════════════════
 * FEATURES:
 * ═══════════════════════════════════════════════════════════════════════════
 * ✅ Dynamic theme loading from API
 * ✅ Withdraw form with validation
 * ✅ Payment method selection with images
 * ✅ Amount calculation with fees
 * ✅ Withdraw history with detailed view
 * ✅ Pull-to-refresh functionality
 * ✅ Real-time balance updates
 * ✅ Comprehensive error handling
 * ✅ Network timeout handling
 * ✅ Beautiful UI with gradients
 * ✅ Status indicators (Pending, Completed, Rejected, Processing)
 * ✅ Date formatting (relative & absolute)
 * ✅ Transaction details dialog
 * ✅ Amount breakdown display
 * ✅ Form clearing after success
 * ✅ Loading states for all operations
 * ✅ Confirmation dialog before submission
 * ✅ Success dialog after submission
 * ✅ Snackbar notifications
 * ✅ Focus management for inputs
 * ✅ Input validation (min/max amounts, balance check)
 * ✅ Responsive layout
 * ✅ Tab navigation (New Withdraw / History)
 *
 * ═══════════════════════════════════════════════════════════════════════════
 * NO SESSION USED - NO REDIRECT ISSUES
 * ═══════════════════════════════════════════════════════════════════════════
 * This implementation does NOT use any session management.
 * Authentication is handled via Bearer token in API headers.
 * No localStorage, sessionStorage, or any client-side session.
 * Token is passed as parameter from parent widget.
 *
 * ═══════════════════════════════════════════════════════════════════════════
 * USAGE:
 * ═══════════════════════════════════════════════════════════════════════════
 * Navigator.push(
 *   context,
 *   MaterialPageRoute(
 *     builder: (context) => WithdrawScreen(
 *       authToken: "your_auth_token_here",
 *       userId: "optional_user_id",
 *       onWithdrawSuccess: () {
 *         // Optional callback after successful withdraw
 *       },
 *     ),
 *   ),
 * );
 *
 * ═══════════════════════════════════════════════════════════════════════════
 * API ENDPOINTS USED:
 * ═══════════════════════════════════════════════════════════════════════════
 * 1. GET  /api/themechange              - Theme color loading
 * 2. GET  /api/userwidthrawshow         - Fetch withdraw data & balance
 * 3. GET  /api/widthrawinstructionss    - Fetch withdraw instructions
 * 4. GET  /api/withdraw-history         - Fetch withdraw history
 * 5. POST /api/userwidthrawstore        - Submit withdraw request
 *
 * ═══════════════════════════════════════════════════════════════════════════
 * DEPENDENCIES REQUIRED:
 * ═══════════════════════════════════════════════════════════════════════════
 * dependencies:
 *   flutter:
 *     sdk: flutter
 *   http: ^1.1.0
 *   intl: ^0.18.1
 *
 * ═══════════════════════════════════════════════════════════════════════════
 * ASSEMBLY INSTRUCTIONS:
 * ═══════════════════════════════════════════════════════════════════════════
 *
 * Create a new file: lib/withdraw.dart
 *
 * Then copy-paste in this order:
 *
 * 1. Copy entire Part 1 content
 * 2. Copy entire Part 2 content (AFTER Part 1, inside the class)
 * 3. Copy entire Part 3 content (AFTER Part 2, inside the class)
 * 4. Copy entire Part 4 content (AFTER Part 3, inside the class)
 * 5. Copy entire Part 5 content (AFTER Part 4, this closes the class)
 *
 * The final structure will be:
 *
 * ```dart
 * import ...
 *
 * class WithdrawScreen extends StatefulWidget { ... }
 *
 * class _WithdrawScreenState extends State<WithdrawScreen> {
 *   // Part 1: Variables & initial methods
 *   // Part 2: Validation & error handlers
 *   // Part 3: Build & UI components
 *   // Part 4: History & dialogs
 * } // <- Part 5 closes this
 *
 * class TimeoutException { ... }
 * ```
 *
 * ═══════════════════════════════════════════════════════════════════════════
 * TOTAL LINES: ~2700 lines
 * ═══════════════════════════════════════════════════════════════════════════
 */
