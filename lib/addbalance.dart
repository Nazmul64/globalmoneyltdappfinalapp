import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'components/CustomNavigationBar.dart';
import 'total_deposite.dart';
import 'config/api_config.dart';

String get baseUrl => ApiConfig.mediaBaseUrl;

// =====================================================
// PART 1: Main Page Structure with Page State Management
// =====================================================

/// AddBalancePage - User deposit করার জন্য main page
/// Features:
/// - Payment method selection
/// - Deposit form with validation
/// - Video instructions
/// - Total deposit history button
/// - 🆕 Duplicate Transaction ID Check
class AddBalancePage extends StatefulWidget {
  const AddBalancePage({super.key});

  @override
  State<AddBalancePage> createState() => _AddBalancePageState();
}

class _AddBalancePageState extends State<AddBalancePage>
    with SingleTickerProviderStateMixin {
  // =====================================================
  // PAGE STATE MANAGEMENT
  // =====================================================
  /// এটা দিয়ে control করব কোন page দেখাবে
  /// true = main payment methods page
  /// false = deposit form page
  bool _showPaymentMethodsPage = true;

  // =====================================================
  // ANIMATION CONTROLLERS
  // =====================================================
  /// Page transition এর জন্য animation controller
  late AnimationController _pageAnimationController;
  late Animation<Offset> _slideAnimation;

  // =====================================================
  // NAVIGATION STATE
  // =====================================================
  /// Bottom navigation bar এর জন্য selected index
  int _selectedIndex = 2;

  // =====================================================
  // VIDEO CONTROLLERS
  // =====================================================
  /// YouTube video player controllers এর list
  List<YoutubePlayerController> _controllers = [];

  // =====================================================
  // DATA LISTS
  // =====================================================
  /// API থেকে আসা payment methods এর list
  List<dynamic> paymentMethods = [];

  /// Video instructions এর list
  List<dynamic> instructions = [];

  /// Text deposit instructions এর list
  List<dynamic> depositInstructions = [];

  // =====================================================
  // LOADING STATES
  // =====================================================
  /// Main data loading state
  bool loading = true;

  /// Theme loading state
  bool themeLoading = true;

  /// Deposit instructions loading state
  bool loadingDepositInstructions = true;

  /// Error message if any
  String? errorMessage;

  // =====================================================
  // THEME VARIABLES
  // =====================================================
  /// App theme color from database
  Color? themeColor;

  /// Theme name
  String themeName = 'Loading...';

  // =====================================================
  // DEPOSIT FORM CONTROLLERS
  // =====================================================
  /// Form key for validation
  final _formKey = GlobalKey<FormState>();

  /// Amount input controller
  final _amountController = TextEditingController();

  /// Sender account number controller
  final _accountController = TextEditingController();

  /// Transaction ID controller
  final _transactionController = TextEditingController();

  /// Image picker instance
  final ImagePicker _picker = ImagePicker();

  // =====================================================
  // 🆕 DUPLICATE TRANSACTION CHECK STATE
  // =====================================================
  /// Checking duplicate transaction ID state
  bool _checkingTransaction = false;

  /// Transaction ID already used flag
  bool _transactionAlreadyUsed = false;

  // =====================================================
  // DEPOSIT FORM DATA
  // =====================================================
  /// Selected transaction screenshot
  File? _selectedImage;

  /// Selected file name
  String _fileName = 'No file chosen';

  /// Minimum deposit amount
  double minDeposit = 0;

  /// Maximum deposit amount
  double maxDeposit = 0;

  /// Whether deposit limits are loaded
  bool limitsLoaded = false;

  // =====================================================
  // SELECTED PAYMENT METHOD
  // =====================================================
  /// Currently selected payment method index
  int? selectedPaymentMethodIndex;

  /// Currently selected payment method data
  Map<String, dynamic>? selectedPaymentMethod;

  // =====================================================
  // INITIALIZATION
  // =====================================================
  @override
  void initState() {
    super.initState();
    _initializePageAnimation();
    _initializeApp();

    // 🆕 Add listener to transaction ID field
    _transactionController.addListener(_onTransactionIdChanged);
  }

  /// Initialize page transition animation
  void _initializePageAnimation() {
    _pageAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation =
        Tween<Offset>(
          begin: const Offset(1.0, 0.0), // শুরু right side থেকে
          end: Offset.zero, // শেষ center এ
        ).animate(
          CurvedAnimation(
            parent: _pageAnimationController,
            curve: Curves.easeInOut,
          ),
        );
  }

  /// Initialize app - fetch all required data
  Future<void> _initializeApp() async {
    await fetchThemeColor();
    await fetchData();
    await fetchDepositInstructions();
    await _debugTokenOnStart();
  }

  /// Debug helper - check if token exists
  Future<void> _debugTokenOnStart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      debugPrint('🔍 Token exists: ${token != null}');
      if (token != null) {
        debugPrint('🔍 Token length: ${token.length}');
      }
    } catch (e) {
      debugPrint('❌ DEBUG Error: $e');
    }
  }

  // =====================================================
  // 🆕 TRANSACTION ID CHANGE LISTENER
  // =====================================================

  /// Called when transaction ID text changes
  /// Debounces the API call to check for duplicates
  void _onTransactionIdChanged() {
    // Reset the flag when user types
    if (_transactionAlreadyUsed) {
      setState(() {
        _transactionAlreadyUsed = false;
      });
    }
  }

  // =====================================================
  // DISPOSAL
  // =====================================================
  @override
  void dispose() {
    // Dispose animation controller
    _pageAnimationController.dispose();

    // Dispose text controllers
    _amountController.dispose();
    _accountController.dispose();

    // 🆕 Remove listener before disposing
    _transactionController.removeListener(_onTransactionIdChanged);
    _transactionController.dispose();

    // Dispose video controllers
    _disposeVideoControllers();

    super.dispose();
  }

  /// Dispose all video controllers safely
  void _disposeVideoControllers() {
    for (var controller in _controllers) {
      try {
        controller.dispose();
      } catch (e) {
        debugPrint('⚠️ Error disposing video controller: $e');
      }
    }
    _controllers.clear();
  }

  // =====================================================
  // PAGE NAVIGATION METHODS
  // =====================================================

  /// Navigate to deposit form when payment method is selected
  /// @param index - Selected payment method index
  void _navigateToDepositForm(int index) {
    if (!mounted) return;

    setState(() {
      selectedPaymentMethodIndex = index;
      selectedPaymentMethod = paymentMethods[index];
      _showPaymentMethodsPage = false; // Switch to deposit form
    });

    // Start slide animation
    _pageAnimationController.forward(from: 0.0);

    debugPrint(
      '📱 Navigated to deposit form for: ${selectedPaymentMethod!['method_name']}',
    );
  }

  /// Navigate back to payment methods page
  void _navigateBackToPaymentMethods() {
    if (!mounted) return;

    setState(() {
      _showPaymentMethodsPage = true; // Switch back to main page
    });

    // Reverse animation
    _pageAnimationController.reverse().then((_) {
      if (mounted) {
        setState(() {
          selectedPaymentMethodIndex = null;
          selectedPaymentMethod = null;
        });
      }
    });

    debugPrint('📱 Navigated back to payment methods');
  }

  /// Handle device back button press
  /// Returns false to prevent default back navigation when on deposit form
  Future<bool> _onWillPop() async {
    if (!_showPaymentMethodsPage) {
      // যদি deposit form page এ থাকে তাহলে main page এ যাবে
      _navigateBackToPaymentMethods();
      return false; // Don't pop the route
    }
    // Main page থেকে বের হবে
    return true; // Allow normal back navigation
  }

  /// Navigate to Deposit History Screen
  /// Opens the DepositScreen to show all deposit history
  void _navigateToDepositHistory() {
    debugPrint('📊 Navigating to Deposit History...');

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const DepositScreen()),
    );
  }

  // =====================================================
  // THEME FETCHING
  // =====================================================

  /// Fetch theme color from database
  /// Theme color dynamically controls the app appearance
  Future<void> fetchThemeColor() async {
    try {
      debugPrint('🎨 Fetching theme from database: $baseUrl/api/themechange');

      var url = Uri.parse("$baseUrl/api/themechange");
      var response = await http
          .get(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 10));

      debugPrint('🎨 Theme API Status: ${response.statusCode}');
      debugPrint('🎨 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        var jsonData = jsonDecode(response.body);

        if (jsonData['status'] == true && jsonData['data'] != null) {
          String colorCode = jsonData['data']['color_code'] ?? '#4361EE';
          String name = jsonData['data']['name'] ?? 'Custom Theme';

          if (mounted) {
            setState(() {
              themeColor = _hexToColor(colorCode);
              themeName = name;
              themeLoading = false;
            });
          }

          debugPrint('✅ Theme loaded successfully: $name ($colorCode)');
        } else {
          debugPrint('⚠️ Invalid theme data, using default');
          _setDefaultTheme();
        }
      } else {
        debugPrint('❌ Theme API failed with status: ${response.statusCode}');
        _setDefaultTheme();
      }
    } catch (e) {
      debugPrint('❌ Theme fetch error: $e');
      _setDefaultTheme();
    }
  }

  /// Set default theme when API fails
  void _setDefaultTheme() {
    if (mounted) {
      setState(() {
        themeColor = _hexToColor('#4361EE');
        themeName = 'Default Blue';
        themeLoading = false;
      });
    }
  }

  /// Convert hex color string to Color object
  /// @param hexString - Hex color code (e.g., '#4361EE')
  /// @return Color object
  Color _hexToColor(String hexString) {
    try {
      final buffer = StringBuffer();
      if (hexString.length == 6 || hexString.length == 7) {
        buffer.write('ff'); // Add alpha channel
      }
      buffer.write(hexString.replaceFirst('#', ''));
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (e) {
      debugPrint('⚠️ Invalid hex color: $hexString, using default');
      return _hexToColor('#4361EE');
    }
  }

  /// Get light version of theme color for backgrounds
  Color get themeLightColor =>
      themeColor?.withOpacity(0.1) ?? Colors.blue.withOpacity(0.1);

  /// Get gradient colors for theme
  List<Color> get themeGradient {
    if (themeColor == null) {
      return [Colors.blue, Colors.blue.shade300];
    }

    final hsl = HSLColor.fromColor(themeColor!);
    final lighter = hsl
        .withLightness((hsl.lightness + 0.1).clamp(0.0, 1.0))
        .toColor();

    return [themeColor!, lighter];
  }

  // =====================================================
  // DATA FETCHING - DEPOSIT INSTRUCTIONS
  // =====================================================

  /// Fetch deposit instructions from API
  /// These are text-based step-by-step instructions
  Future<void> fetchDepositInstructions() async {
    setState(() {
      loadingDepositInstructions = true;
    });

    try {
      debugPrint('📋 Fetching deposit instructions...');
      debugPrint('📋 URL: $baseUrl/api/depositeinstructions');

      var url = Uri.parse("$baseUrl/api/depositeinstructions");
      var response = await http
          .get(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 10));

      debugPrint('📋 Deposit Instructions Status: ${response.statusCode}');
      debugPrint('📋 Response: ${response.body}');

      if (response.statusCode == 200) {
        var jsonData = jsonDecode(response.body);

        if (jsonData['status'] == true && jsonData['data'] != null) {
          if (mounted) {
            setState(() {
              depositInstructions = jsonData['data'];
              loadingDepositInstructions = false;
            });
          }

          debugPrint(
            '✅ Deposit instructions loaded: ${depositInstructions.length} items',
          );
        } else {
          debugPrint('⚠️ No deposit instructions data');
          setState(() => loadingDepositInstructions = false);
        }
      } else {
        debugPrint('❌ Deposit instructions API failed: ${response.statusCode}');
        setState(() => loadingDepositInstructions = false);
      }
    } catch (e) {
      debugPrint('❌ Deposit instructions error: $e');
      if (mounted) {
        setState(() => loadingDepositInstructions = false);
      }
    }
  }

  // =====================================================
  // DATA FETCHING - PAYMENT METHODS & VIDEO INSTRUCTIONS
  // =====================================================

  /// Fetch payment methods and video instructions
  /// Also fetches deposit limits (min/max amounts)
  Future<void> fetchData() async {
    setState(() {
      loading = true;
      errorMessage = null;
    });

    try {
      // Fetch video instructions
      await _fetchVideoInstructions();

      // Fetch payment methods and limits
      await _fetchPaymentMethods();

      if (mounted) {
        setState(() {
          loading = false;
        });
      }

      debugPrint('✅ All data fetched successfully');
    } catch (e) {
      debugPrint('❌ Data fetch error: $e');

      if (mounted) {
        setState(() {
          loading = false;
          errorMessage = 'Network error: $e';
        });
      }
    }
  }

  /// Fetch video instructions from API
  Future<void> _fetchVideoInstructions() async {
    try {
      debugPrint('📹 Fetching video instructions...');

      var url = Uri.parse("$baseUrl/api/deposit-instructions/videos");
      var response = await http
          .get(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 10));

      debugPrint('📹 Video Instructions Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        var jsonData = jsonDecode(response.body);

        if (jsonData['success'] == true) {
          if (mounted) {
            setState(() {
              paymentMethods = jsonData['data']['payment_methods'] ?? [];
              instructions = jsonData['data']['deposit_instructions'] ?? [];
            });
          }

          _setupVideoControllers();

          debugPrint(
            '✅ Video instructions loaded: ${instructions.length} videos',
          );
        } else {
          throw Exception('Video instructions API returned false');
        }
      } else {
        throw Exception('Video instructions HTTP ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Video instructions error: $e');
      rethrow;
    }
  }

  /// Fetch payment methods and deposit limits
  Future<void> _fetchPaymentMethods() async {
    try {
      debugPrint('💳 Fetching payment methods...');

      var url = Uri.parse('$baseUrl/api/paymentmethod');
      var response = await http
          .get(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 10));

      debugPrint('💳 Payment Methods Status: ${response.statusCode}');
      debugPrint('💳 Response: ${response.body}');

      if (response.statusCode == 200) {
        var paymentData = jsonDecode(response.body);

        if (paymentData['success'] == true) {
          if (mounted) {
            setState(() {
              // Update payment methods if available
              if (paymentData['data'] != null && paymentData['data'] is List) {
                paymentMethods = paymentData['data'];
              }

              // Update deposit limits
              if (paymentData['limits'] != null) {
                minDeposit =
                    double.tryParse(
                      paymentData['limits']['min_deposit'].toString(),
                    ) ??
                    0;
                maxDeposit =
                    double.tryParse(
                      paymentData['limits']['max_deposit'].toString(),
                    ) ??
                    0;
                limitsLoaded = true;
              }
            });
          }

          debugPrint('✅ Payment methods loaded: ${paymentMethods.length}');
          debugPrint('✅ Deposit limits: $minDeposit - $maxDeposit');
        } else {
          debugPrint('⚠️ Payment methods API returned success: false');
        }
      } else {
        debugPrint('❌ Payment methods API failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Payment methods error: $e');
      rethrow;
    }
  }

  // =====================================================
  // VIDEO CONTROLLER SETUP
  // =====================================================

  /// Setup YouTube player controllers for each video instruction
  void _setupVideoControllers() {
    // Dispose existing controllers
    _disposeVideoControllers();

    debugPrint('🎬 Setting up ${instructions.length} video controllers...');

    for (var instruction in instructions) {
      if (instruction['video_url'] != null) {
        String videoUrl = instruction['video_url'].toString();
        String? videoId = YoutubePlayer.convertUrlToId(videoUrl);

        if (videoId != null && videoId.isNotEmpty) {
          var controller = YoutubePlayerController(
            initialVideoId: videoId,
            flags: const YoutubePlayerFlags(
              autoPlay: false,
              mute: false,
              hideControls: false,
              enableCaption: true,
              loop: false,
              forceHD: false,
            ),
          );
          _controllers.add(controller);

          debugPrint('✅ Video controller added for ID: $videoId');
        } else {
          debugPrint('⚠️ Invalid video URL: $videoUrl');
        }
      }
    }

    debugPrint('✅ Total video controllers setup: ${_controllers.length}');
  }

  // =====================================================
  // BOTTOM NAVIGATION
  // =====================================================

  /// Handle bottom navigation bar tap
  /// @param index - Tapped navigation item index
  void _onBottomNavTap(int index) {
    if (mounted) {
      setState(() {
        _selectedIndex = index;
      });
    }

    debugPrint('🔽 Bottom nav tapped: index $index');
  }

  // =====================================================
  // CLIPBOARD HELPER
  // =====================================================

  /// Copy text to clipboard and show snackbar
  /// @param text - Text to copy
  /// @param type - Type of text (for snackbar message)
  void _copyToClipboard(String text, String type) {
    if (text.isEmpty) {
      debugPrint('⚠️ Cannot copy empty text');
      return;
    }

    Clipboard.setData(ClipboardData(text: text));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Text('$type copied to clipboard'),
          ],
        ),
        backgroundColor: themeColor,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );

    debugPrint('📋 Copied to clipboard: $type');
  }

  // =====================================================
  // PART 2: Main UI Build Methods & Payment Methods Page
  // =====================================================

  // =====================================================
  // 🆕 CHECK DUPLICATE TRANSACTION ID
  // =====================================================

  /// Check if transaction ID is already used
  /// @param transactionId - Transaction ID to check
  /// @return true if already used, false otherwise
  Future<bool> _checkDuplicateTransactionId(String transactionId) async {
    if (transactionId.trim().isEmpty) {
      return false;
    }

    setState(() {
      _checkingTransaction = true;
    });

    try {
      debugPrint('🔍 Checking transaction ID: $transactionId');

      final token = await _getAuthToken();
      if (token == null) {
        debugPrint('⚠️ No auth token for duplicate check');
        setState(() {
          _checkingTransaction = false;
        });
        return false;
      }

      var url = Uri.parse('$baseUrl/api/check-transaction-id');
      var response = await http
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'transaction_id': transactionId.trim()}),
          )
          .timeout(const Duration(seconds: 10));

      debugPrint('🔍 Check Transaction Status: ${response.statusCode}');
      debugPrint('🔍 Response: ${response.body}');

      if (response.statusCode == 200) {
        var jsonData = jsonDecode(response.body);

        bool isDuplicate =
            jsonData['is_duplicate'] == true ||
            jsonData['exists'] == true ||
            jsonData['already_used'] == true;

        if (mounted) {
          setState(() {
            _checkingTransaction = false;
            _transactionAlreadyUsed = isDuplicate;
          });
        }

        if (isDuplicate) {
          debugPrint('⚠️ Transaction ID already used!');
          _showDuplicateTransactionDialog();
        } else {
          debugPrint('✅ Transaction ID is unique');
        }

        return isDuplicate;
      } else {
        debugPrint('⚠️ Check transaction API failed: ${response.statusCode}');
        if (mounted) {
          setState(() {
            _checkingTransaction = false;
          });
        }
        return false;
      }
    } catch (e) {
      debugPrint('❌ Check transaction error: $e');
      if (mounted) {
        setState(() {
          _checkingTransaction = false;
        });
      }
      return false;
    }
  }

  // =====================================================
  // 🆕 DUPLICATE TRANSACTION ALERT DIALOG
  // =====================================================

  /// Show alert when transaction ID is already used
  void _showDuplicateTransactionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Warning Icon
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline,
                  color: Colors.red,
                  size: 50,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Title
            const Text(
              'Already Used!',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),

            // Message
            const Text(
              'This transaction ID has already been used. Please use a different transaction ID.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: Colors.black54,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),

            // Info box
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.orange.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Each transaction ID can only be used once',
                      style: TextStyle(fontSize: 13, color: Colors.black87),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // OK Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                child: const Text(
                  'OK, I Understand',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =====================================================
  // MAIN BUILD METHOD
  // =====================================================

  @override
  Widget build(BuildContext context) {
    // Theme loading screen
    if (themeLoading) {
      return _buildThemeLoadingScreen();
    }

    // Theme error screen
    if (themeColor == null) {
      return _buildThemeErrorScreen();
    }

    // Main app with back button handling
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: Colors.grey.shade100,
        appBar: _buildAppBar(),
        bottomNavigationBar: CustomBottomNav(
          currentIndex: _selectedIndex,
          onTap: _onBottomNavTap,
        ),
        body: loading
            ? _buildLoadingWidget()
            : errorMessage != null
            ? _buildErrorWidget()
            : _buildPageContent(),
      ),
    );
  }

  // =====================================================
  // THEME LOADING SCREEN
  // =====================================================

  /// Show loading screen while theme is being fetched
  Widget _buildThemeLoadingScreen() {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text(
              'Loading theme...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =====================================================
  // THEME ERROR SCREEN
  // =====================================================

  /// Show error screen when theme loading fails
  Widget _buildThemeErrorScreen() {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Error Icon
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline,
                  size: 60,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 20),

              // Error Title
              const Text(
                'Failed to Load Theme',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 10),

              // Error Message
              const Text(
                'Please check your internet connection and try again',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 30),

              // Retry Button
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    themeLoading = true;
                    loading = true;
                  });
                  _initializeApp();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 30,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =====================================================
  // APP BAR BUILDER
  // =====================================================

  /// Build app bar with dynamic title based on current page
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: themeColor,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () {
          // যদি deposit form page এ থাকে তাহলে payment methods page এ যাবে
          if (!_showPaymentMethodsPage) {
            _navigateBackToPaymentMethods();
          } else {
            // Main page থেকে বের হবে
            Navigator.pop(context);
          }
        },
      ),
      title: Text(
        _showPaymentMethodsPage ? 'Add Balance' : 'Deposit Form',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      centerTitle: true,
      actions: [
        if (_showPaymentMethodsPage)
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              setState(() {
                themeLoading = true;
                loading = true;
              });
              _initializeApp();
            },
            tooltip: 'Refresh',
          ),
      ],
    );
  }

  // =====================================================
  // LOADING WIDGET
  // =====================================================

  /// Show loading indicator while data is being fetched
  Widget _buildLoadingWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: themeColor, strokeWidth: 3),
          const SizedBox(height: 20),
          Text(
            'Loading payment methods...',
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // =====================================================
  // ERROR WIDGET
  // =====================================================

  /// Show error widget when data fetching fails
  Widget _buildErrorWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Error Icon
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline,
                size: 60,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 20),

            // Error Message
            Text(
              errorMessage ?? 'Something went wrong',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 10),

            const Text(
              'Please check your connection and try again',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 30),

            // Retry Button
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  loading = true;
                  errorMessage = null;
                });
                fetchData();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: themeColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 30,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =====================================================
  // PAGE CONTENT SWITCHER
  // =====================================================

  /// Switch between payment methods page and deposit form page
  Widget _buildPageContent() {
    // যদি main payment methods page দেখাতে হয় তাহলে সেটা দেখাবে
    if (_showPaymentMethodsPage) {
      return _buildPaymentMethodsPage();
    }
    // না হলে deposit form page দেখাবে with animation
    else {
      return SlideTransition(
        position: _slideAnimation,
        child: _buildDepositFormPage(),
      );
    }
  }

  // =====================================================
  // MAIN PAYMENT METHODS PAGE
  // =====================================================

  /// Build the main payment methods selection page
  Widget _buildPaymentMethodsPage() {
    return RefreshIndicator(
      color: themeColor,
      onRefresh: () async {
        await fetchThemeColor();
        await fetchData();
        await fetchDepositInstructions();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),

            // Total Deposit Button
            _buildTotalDepositButton(),
            const SizedBox(height: 20),

            // Deposit Limits Info
            if (limitsLoaded) ...[
              _buildDepositLimitsInfo(),
              const SizedBox(height: 25),
            ],

            // Payment Methods Section
            if (paymentMethods.isNotEmpty) ...[
              _buildSectionHeader(
                'Payment Methods',
                Icons.payment,
                'Select a payment method to deposit',
              ),
              const SizedBox(height: 15),
              _buildPaymentMethodsGrid(),
              const SizedBox(height: 30),
            ],

            // Deposit Instructions Section
            if (depositInstructions.isNotEmpty) ...[
              _buildSectionHeader(
                'Deposit Instructions',
                Icons.receipt_long,
                'Important steps to follow',
              ),
              const SizedBox(height: 15),
              _buildDepositInstructionsCards(),
              const SizedBox(height: 30),
            ],

            // Video Instructions Section
            if (_controllers.isNotEmpty) ...[
              _buildSectionHeader(
                'Video Instructions',
                Icons.play_circle_outline,
                'Watch how to deposit',
              ),
              const SizedBox(height: 15),
              _buildAllVideoPlayers(),
              const SizedBox(height: 30),
            ],

            // Additional Instructions Section
            if (instructions.isNotEmpty) ...[
              _buildSectionHeader(
                'Additional Instructions',
                Icons.list_alt,
                'Follow these steps carefully',
              ),
              const SizedBox(height: 15),
              _buildAllInstructionsCards(),
              const SizedBox(height: 25),
            ],

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // =====================================================
  // TOTAL DEPOSIT BUTTON
  // =====================================================

  /// Build Total Deposit button to navigate to deposit history
  /// এই button ক্লিক করলে DepositScreen পেজে যাবে
  Widget _buildTotalDepositButton() {
    return InkWell(
      onTap: _navigateToDepositHistory,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [themeColor!, themeColor!.withOpacity(0.8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: themeColor!.withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon Container
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.account_balance_wallet,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),

            // Text Content
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total Deposit History',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'View all your deposit transactions',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white70,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            // Arrow Icon
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.arrow_forward_ios,
                color: Colors.white,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =====================================================
  // SECTION HEADER BUILDER
  // =====================================================

  /// Build section header with icon, title and subtitle
  Widget _buildSectionHeader(String title, IconData icon, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [themeColor!.withOpacity(0.1), themeColor!.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: themeColor!.withOpacity(0.2), width: 1),
      ),
      child: Row(
        children: [
          // Icon Container
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: themeColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),

          // Title and Subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =====================================================
  // DEPOSIT LIMITS INFO
  // =====================================================

  /// Show deposit limits (min/max amounts)
  Widget _buildDepositLimitsInfo() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Info Icon
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  themeColor!.withOpacity(0.2),
                  themeColor!.withOpacity(0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.info_outline, color: themeColor, size: 30),
          ),
          const SizedBox(width: 16),

          // Limits Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Deposit Limits',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),

                // Min/Max Tags
                Row(
                  children: [
                    // Min Amount Tag
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: Colors.green.shade200,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Min: ',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.black54,
                            ),
                          ),
                          Text(
                            '\$${minDeposit.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Max Amount Tag
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: Colors.blue.shade200,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Max: ',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.black54,
                            ),
                          ),
                          Text(
                            '\$${maxDeposit.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.bold,
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
        ],
      ),
    );
  }

  // =====================================================
  // PAYMENT METHODS GRID
  // =====================================================

  /// Build grid of payment method cards
  /// Main page এ শুধু নাম আর image দেখাবে
  Widget _buildPaymentMethodsGrid() {
    return Column(
      children: List.generate(paymentMethods.length, (index) {
        final method = paymentMethods[index];

        return Padding(
          padding: const EdgeInsets.only(bottom: 15),
          child: PaymentMethodCard(
            title: method['method_name'] ?? 'Unknown',
            imageUrl: method['photo'] ?? '',
            themeColor: themeColor!,
            onTap: () => _navigateToDepositForm(index),
            showDetails: false, // Main page এ details দেখাব না
          ),
        );
      }),
    );
  }

  // =====================================================
  // DEPOSIT INSTRUCTIONS CARDS
  // =====================================================

  /// Build deposit instructions cards
  Widget _buildDepositInstructionsCards() {
    return Column(
      children: List.generate(depositInstructions.length, (index) {
        var instruction = depositInstructions[index];

        return Padding(
          padding: const EdgeInsets.only(bottom: 15),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: themeColor!.withOpacity(0.2),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade300,
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Step Number Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [themeColor!, themeColor!.withOpacity(0.7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: themeColor!.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // Instruction Text
                Expanded(
                  child: Text(
                    instruction['deposite_instructions']?.toString() ??
                        instruction['instructions']?.toString() ??
                        'No instruction available',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade800,
                      height: 1.6,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  // =====================================================
  // PART 3: Video Players & Additional Instructions UI
  // =====================================================

  // =====================================================
  // VIDEO PLAYERS BUILDER
  // =====================================================

  /// Build all video instruction players
  Widget _buildAllVideoPlayers() {
    return Column(
      children: List.generate(_controllers.length, (index) {
        var instruction = instructions[index];
        bool hasTitle = instruction['deposite_instructions_title'] != null;

        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade300,
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Video Title Header
                if (hasTitle)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    child: Row(
                      children: [
                        // Video Number Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: themeColor!.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.play_circle_outline,
                                size: 16,
                                color: themeColor,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'Video ${index + 1}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: themeColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Video Title
                        Expanded(
                          child: Text(
                            instruction['deposite_instructions_title'],
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),

                // YouTube Video Player
                ClipRRect(
                  borderRadius: BorderRadius.only(
                    bottomLeft: const Radius.circular(16),
                    bottomRight: const Radius.circular(16),
                    topLeft: Radius.circular(hasTitle ? 0 : 16),
                    topRight: Radius.circular(hasTitle ? 0 : 16),
                  ),
                  child: YoutubePlayer(
                    controller: _controllers[index],
                    showVideoProgressIndicator: true,
                    progressIndicatorColor: themeColor!,
                    progressColors: ProgressBarColors(
                      playedColor: themeColor!,
                      handleColor: themeColor!.withOpacity(0.8),
                      bufferedColor: themeColor!.withOpacity(0.3),
                      backgroundColor: Colors.grey.shade300,
                    ),
                    bottomActions: [
                      CurrentPosition(),
                      ProgressBar(isExpanded: true),
                      RemainingDuration(),
                      const PlaybackSpeedButton(),
                      FullScreenButton(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  // =====================================================
  // ADDITIONAL INSTRUCTIONS CARDS
  // =====================================================

  /// Build additional text-based instruction cards
  Widget _buildAllInstructionsCards() {
    return Column(
      children: List.generate(instructions.length, (index) {
        var instruction = instructions[index];

        return Padding(
          padding: const EdgeInsets.only(bottom: 15),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade300,
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Instruction Title
                if (instruction['deposite_instructions_title'] != null) ...[
                  Row(
                    children: [
                      // Step Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              themeColor!.withOpacity(0.2),
                              themeColor!.withOpacity(0.1),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Step ${index + 1}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: themeColor!,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Title Text
                      Expanded(
                        child: Text(
                          instruction['deposite_instructions_title'],
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],

                // Instruction Description
                if (instruction['deposite_instructions_description'] != null)
                  Text(
                    instruction['deposite_instructions_description'],
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                      height: 1.6,
                    ),
                  ),
              ],
            ),
          ),
        );
      }),
    );
  }

  // =====================================================
  // DEPOSIT FORM PAGE (Separate page feel)
  // =====================================================

  /// Build deposit form page
  /// এটা দেখাবে যখন user কোন payment method select করবে
  Widget _buildDepositFormPage() {
    if (selectedPaymentMethod == null) return const SizedBox();

    return Container(
      color: Colors.grey.shade100,
      child: RefreshIndicator(
        color: themeColor,
        onRefresh: () async {
          await fetchData();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Selected Payment Method Display
              _buildSelectedPaymentMethodCard(),
              const SizedBox(height: 25),

              // Deposit Form
              _buildDepositForm(),
              const SizedBox(height: 30),

              // Important Notes
              _buildImportantNotes(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // =====================================================
  // SELECTED PAYMENT METHOD CARD (Form Page এ নাম্বার দেখাবে)
  // =====================================================

  /// Show selected payment method details with copy button
  Widget _buildSelectedPaymentMethodCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [themeColor!.withOpacity(0.1), themeColor!.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: themeColor!.withOpacity(0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: themeColor!.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with icon
          Row(
            children: [
              // Payment Icon
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: themeColor,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: themeColor!.withOpacity(0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.payment, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 14),

              // Payment Method Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 3),
                    Text(
                      selectedPaymentMethod!['method_name'] ?? 'N/A',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Divider
          Divider(color: themeColor!.withOpacity(0.2), height: 1),
          const SizedBox(height: 20),

          // Payment Method Number with Copy Button
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      selectedPaymentMethod!['number_type']?.toString() ??
                          selectedPaymentMethod!['field_label']?.toString() ??
                          'Account Number',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Number Display Box
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: themeColor!.withOpacity(0.2)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Icon(
                              Icons.account_balance_wallet,
                              size: 18,
                              color: themeColor,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: SelectableText(
                              selectedPaymentMethod!['method_number']
                                      ?.toString() ??
                                  'N/A',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Copy Button
              ElevatedButton(
                onPressed: () => _copyToClipboard(
                  selectedPaymentMethod!['method_number']?.toString() ?? '',
                  selectedPaymentMethod!['method_name']?.toString() ?? 'Number',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: themeColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                ),
                child: const Row(
                  children: [
                    Icon(Icons.copy, size: 18),
                    SizedBox(width: 6),
                    Text(
                      'Copy',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if ((selectedPaymentMethod!['is_exchange_rate_active'] == true ||
               selectedPaymentMethod!['is_exchange_rate_active'] == 1 ||
               selectedPaymentMethod!['is_exchange_rate_active'] == '1') &&
              (selectedPaymentMethod!['usd_rate'] != null || selectedPaymentMethod!['usd_rate_bdt'] != null)) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade400),
              ),
              child: Row(
                children: [
                  Icon(Icons.currency_exchange, size: 18, color: Colors.amber.shade800),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Exchange Rate: 1 USD = ${selectedPaymentMethod!['usd_rate_bdt'] ?? selectedPaymentMethod!['usd_rate']} BDT',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // =====================================================
  // IMPORTANT NOTES SECTION
  // =====================================================

  /// Show important notes for deposit
  Widget _buildImportantNotes() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.shade200, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Important Notes',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Note Items
          _buildNoteItem(
            'Make sure to send the exact amount you enter in the form',
          ),
          _buildNoteItem(
            'Keep your transaction screenshot ready before submitting',
          ),
          _buildNoteItem('Double check your sender account number'),
          _buildNoteItem('Each transaction ID can only be used once'),
          _buildNoteItem('Deposits are usually processed within 5-15 minutes'),
          _buildNoteItem('Contact support if you face any issues'),
        ],
      ),
    );
  }

  /// Build individual note item
  Widget _buildNoteItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bullet Point
          Container(
            margin: const EdgeInsets.only(top: 4),
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: Colors.orange,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),

          // Note Text
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =====================================================
  // MAIN DEPOSIT FORM
  // =====================================================

  /// Build the main deposit form with all input fields
  Widget _buildDepositForm() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300,
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Form Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: themeColor!.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.edit_note, color: themeColor, size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Fill Deposit Details',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        'All fields are required',
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Deposit Limits Display
            if (limitsLoaded) ...[
              _buildInlineDepositLimits(),
              const SizedBox(height: 20),
            ],

            // Amount Field
            _buildFormField(
              'Amount',
              _amountController,
              'Enter deposit amount',
              TextInputType.number,
              Icons.attach_money,
              helperText: limitsLoaded
                  ? 'Min: \$${minDeposit.toStringAsFixed(0)} - Max: \$${maxDeposit.toStringAsFixed(0)}'
                  : null,
            ),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _amountController,
              builder: (context, value, child) {
                final text = value.text.trim();
                final enteredAmount = double.tryParse(text) ?? 0;

                double? rate;
                final bool isRateActive = selectedPaymentMethod != null &&
                    (selectedPaymentMethod!['is_exchange_rate_active'] == true ||
                     selectedPaymentMethod!['is_exchange_rate_active'] == 1 ||
                     selectedPaymentMethod!['is_exchange_rate_active'] == '1');

                if (isRateActive) {
                  if (selectedPaymentMethod!['usd_rate_bdt'] != null) {
                    rate = double.tryParse(selectedPaymentMethod!['usd_rate_bdt'].toString());
                  } else if (selectedPaymentMethod!['usd_rate'] != null) {
                    final match = RegExp(r'([\d\.]+)').firstMatch(selectedPaymentMethod!['usd_rate'].toString());
                    if (match != null) {
                      rate = double.tryParse(match.group(1) ?? '');
                    }
                  }
                }

                if (enteredAmount > 0 && rate != null && rate > 0) {
                  final totalBdt = enteredAmount * rate;
                  final formattedBdt = totalBdt.toStringAsFixed(totalBdt.truncateToDouble() == totalBdt ? 0 : 2);
                  final formattedRate = rate.toStringAsFixed(rate.truncateToDouble() == rate ? 0 : 2);

                  return Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade300),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calculate, size: 18, color: Colors.green.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Total Pay: $formattedBdt BDT  (Rate: 1 USD = $formattedRate BDT)',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            const SizedBox(height: 20),

            // Sender Account Field
            _buildFormField(
              'Your Account Number',
              _accountController,
              'Enter your account number',
              TextInputType.number,
              Icons.account_balance_wallet,
              helperText: 'The account you sent money from',
            ),
            const SizedBox(height: 20),

            // 🆕 Transaction ID Field with Duplicate Check
            _buildTransactionIdField(),
            const SizedBox(height: 20),

            // Screenshot Upload Section
            const Text(
              'Transaction Screenshot *',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            _buildImagePicker(),

            // Image Preview
            if (_selectedImage != null) ...[
              const SizedBox(height: 16),
              _buildImagePreview(),
            ],

            const SizedBox(height: 28),

            // Submit Button
            _buildSubmitButton(),
          ],
        ),
      ),
    );
  }

  // =====================================================
  // INLINE DEPOSIT LIMITS (Form Page এ)
  // =====================================================

  /// Show deposit limits inline in the form
  Widget _buildInlineDepositLimits() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: themeColor!.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: themeColor!.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: themeColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Row(
              children: [
                const Text(
                  'Limits: ',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.black54,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '\$${minDeposit.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 13,
                    color: themeColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text(
                  ' - ',
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
                Text(
                  '\$${maxDeposit.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 13,
                    color: themeColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =====================================================
  // 🆕 IMPROVED DUPLICATE CHECK - PART 4 REPLACEMENT
  // =====================================================
  // এই part টি আগের Part 4 এর replacement

  // =====================================================
  // FORM FIELD BUILDER
  // =====================================================

  /// Build form text field with validation
  Widget _buildFormField(
    String label,
    TextEditingController controller,
    String hint,
    TextInputType type,
    IconData icon, {
    String? helperText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),

        TextFormField(
          controller: controller,
          keyboardType: type,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
            prefixIcon: Icon(icon, color: themeColor, size: 22),
            helperText: helperText,
            helperStyle: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: themeColor!, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 1.5),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'This field is required';
            }

            if (controller == _amountController && limitsLoaded) {
              final amount = double.tryParse(value);
              if (amount == null) {
                return 'Please enter a valid amount';
              }
              if (amount < minDeposit) {
                return 'Minimum amount is ৳${minDeposit.toStringAsFixed(0)}';
              }
              if (amount > maxDeposit) {
                return 'Maximum amount is ৳${maxDeposit.toStringAsFixed(0)}';
              }
            }

            return null;
          },
        ),
      ],
    );
  }

  // =====================================================
  // 🆕 IMPROVED TRANSACTION ID FIELD WITH AUTO-CHECK
  // =====================================================

  /// Build transaction ID field with automatic duplicate checking
  Widget _buildTransactionIdField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Transaction ID',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),

        // Text Field with Auto Check on Focus Lost
        TextFormField(
          controller: _transactionController,
          keyboardType: TextInputType.text,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
          // 🆕 Auto check when user finishes typing
          onEditingComplete: () {
            final transactionId = _transactionController.text.trim();
            if (transactionId.isNotEmpty) {
              _checkDuplicateTransactionId(transactionId);
            }
          },
          decoration: InputDecoration(
            hintText: 'Enter transaction ID',
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            filled: true,
            fillColor: _transactionAlreadyUsed
                ? Colors.red.shade50
                : const Color(0xFFF9FAFB),
            prefixIcon: Icon(
              Icons.receipt_long,
              color: _transactionAlreadyUsed ? Colors.red : themeColor,
              size: 22,
            ),
            suffixIcon: _buildTransactionSuffixIcon(),
            helperText: 'Found in your transaction receipt',
            helperStyle: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: _transactionAlreadyUsed
                    ? Colors.red.shade300
                    : Colors.grey.shade200,
                width: _transactionAlreadyUsed ? 2 : 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: _transactionAlreadyUsed ? Colors.red : themeColor!,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 1.5),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Transaction ID is required';
            }
            if (_transactionAlreadyUsed) {
              return 'This transaction ID is already used';
            }
            return null;
          },
        ),

        // 🆕 Prominent Warning Message if Already Used
        if (_transactionAlreadyUsed) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.shade300, width: 2),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.error_outline,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Already Used!',
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'This transaction ID has already been used. Please use a different one.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.black87,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // =====================================================
  // TRANSACTION SUFFIX ICON
  // =====================================================

  Widget _buildTransactionSuffixIcon() {
    if (_checkingTransaction) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: themeColor),
        ),
      );
    }

    if (_transactionAlreadyUsed) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Icon(Icons.cancel, color: Colors.red, size: 28),
      );
    }

    // Check button
    return IconButton(
      onPressed: () {
        final transactionId = _transactionController.text.trim();
        if (transactionId.isNotEmpty) {
          _checkDuplicateTransactionId(transactionId);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please enter transaction ID first'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 2),
            ),
          );
        }
      },
      icon: Icon(Icons.check_circle_outline, color: themeColor, size: 26),
      tooltip: 'Check transaction ID',
    );
  }

  // =====================================================
  // IMAGE PICKER (unchanged)
  // =====================================================

  Widget _buildImagePicker() {
    return InkWell(
      onTap: _pickImageSource,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _selectedImage != null
                ? themeColor!.withOpacity(0.3)
                : Colors.grey.shade200,
            width: _selectedImage != null ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _selectedImage != null
                    ? themeColor!.withOpacity(0.15)
                    : themeLightColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _selectedImage != null ? Icons.check_circle : Icons.add_a_photo,
                color: themeColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _selectedImage != null
                        ? 'Screenshot Uploaded'
                        : 'Upload Screenshot',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: _selectedImage != null
                          ? themeColor
                          : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _fileName,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),

            Icon(
              _selectedImage != null ? Icons.edit : Icons.arrow_forward_ios,
              size: 18,
              color: Colors.grey.shade600,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImageSource() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Text(
              'Choose Image Source',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildSourceOption(Icons.camera_alt, 'Camera', () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.camera);
                  }),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildSourceOption(Icons.photo_library, 'Gallery', () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.gallery);
                  }),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceOption(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Icon(icon, size: 40, color: themeColor),
            const SizedBox(height: 10),
            Text(
              label,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final image = await _picker.pickImage(source: source, imageQuality: 80);

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
          _fileName = image.name;
        });
        debugPrint('✅ Image selected: ${image.name}');
      }
    } catch (e) {
      debugPrint('❌ Failed to pick image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Failed to pick image: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Widget _buildImagePreview() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: themeColor!.withOpacity(0.3), width: 2),
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              _selectedImage!,
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black87,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                onPressed: () {
                  setState(() {
                    _selectedImage = null;
                    _fileName = 'No file chosen';
                  });
                },
                icon: const Icon(Icons.close, color: Colors.white, size: 20),
                tooltip: 'Remove image',
              ),
            ),
          ),
          Positioned(
            bottom: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, color: Colors.white, size: 16),
                  SizedBox(width: 6),
                  Text(
                    'Screenshot Added',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
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

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _submitForm,
        style: ElevatedButton.styleFrom(
          backgroundColor: themeColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 4,
          shadowColor: themeColor!.withOpacity(0.5),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.send_rounded, size: 22),
            SizedBox(width: 10),
            Text(
              'Submit Deposit Request',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _getAuthToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? token =
          prefs.getString('auth_token') ??
          prefs.getString('token') ??
          prefs.getString('authToken');

      if (token != null) {
        debugPrint('✅ Auth token retrieved successfully');
      } else {
        debugPrint('⚠️ No auth token found');
      }
      return token;
    } catch (e) {
      debugPrint('❌ Error getting auth token: $e');
      return null;
    }
  }

  // =====================================================
  // 🆕 IMPROVED FORM SUBMISSION - PART 5 REPLACEMENT
  // =====================================================

  // =====================================================
  // FORM SUBMISSION WITH BETTER DUPLICATE DETECTION
  // =====================================================

  Future<void> _submitForm() async {
    // Validate form
    if (!_formKey.currentState!.validate() || !limitsLoaded) {
      debugPrint('⚠️ Form validation failed');
      return;
    }

    // Check amount limits
    final amount = double.tryParse(_amountController.text) ?? 0;
    if (amount < minDeposit || amount > maxDeposit) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Amount must be between ৳${minDeposit.toStringAsFixed(0)} and ৳${maxDeposit.toStringAsFixed(0)}',
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Check if image is selected
    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please upload a transaction screenshot'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Upload',
            textColor: Colors.white,
            onPressed: _pickImageSource,
          ),
        ),
      );
      return;
    }

    // 🆕 MANDATORY DUPLICATE CHECK BEFORE SUBMISSION
    final transactionId = _transactionController.text.trim();
    debugPrint('🔍 Final duplicate check before submission...');

    final isDuplicate = await _checkDuplicateTransactionId(transactionId);

    if (isDuplicate || _transactionAlreadyUsed) {
      debugPrint('⚠️ Cannot submit: Transaction ID is duplicate');
      // Show prominent alert dialog
      _showDuplicateTransactionDialog();
      return;
    }

    debugPrint('📤 Submitting deposit form...');

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => WillPopScope(
        onWillPop: () async => false,
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: themeColor, strokeWidth: 3),
                const SizedBox(height: 16),
                const Text(
                  'Submitting your request...',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      // Get auth token
      final token = await _getAuthToken();
      if (token == null) {
        Navigator.pop(context);
        _showAuthDialog();
        return;
      }

      // Prepare multipart request
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/deposite'),
      );

      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept'] = 'application/json';

      request.fields['amount'] = _amountController.text.trim();
      request.fields['sender_account'] = _accountController.text.trim();
      request.fields['transaction_id'] = transactionId;

      request.files.add(
        await http.MultipartFile.fromPath('photo', _selectedImage!.path),
      );

      debugPrint('📤 Sending request to server...');

      var streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
      );
      var response = await http.Response.fromStream(streamedResponse);

      debugPrint('📥 Response Status: ${response.statusCode}');
      debugPrint('📥 Response Body: ${response.body}');

      if (mounted) {
        Navigator.pop(context); // Close loading dialog

        if (response.statusCode == 200 || response.statusCode == 201) {
          final data = json.decode(response.body);

          if (data['success'] == true) {
            _showSuccessDialog(
              data['message'] ?? 'Deposit request submitted successfully!',
            );

            // Clear form
            _amountController.clear();
            _accountController.clear();
            _transactionController.clear();

            setState(() {
              _selectedImage = null;
              _fileName = 'No file chosen';
              _transactionAlreadyUsed = false;
            });

            debugPrint('✅ Deposit request submitted successfully');

            Future.delayed(const Duration(seconds: 2), () {
              if (mounted) {
                _navigateBackToPaymentMethods();
              }
            });
          } else {
            // 🆕 Check if error is about duplicate transaction ID
            String errorMessage =
                data['message'] ?? 'Failed to submit deposit request';

            if (_isDuplicateError(errorMessage)) {
              _showDuplicateTransactionDialog();
            } else {
              _showErrorSnackBar(errorMessage);
            }
          }
        } else if (response.statusCode == 401) {
          _showSessionExpiredDialog();
        } else if (response.statusCode == 422) {
          final data = json.decode(response.body);
          String errorMsg = 'Validation error';

          if (data['errors'] != null) {
            final errors = data['errors'] as Map;
            errorMsg = errors.values.first[0].toString();

            // 🆕 Check if validation error is about duplicate
            if (_isDuplicateError(errorMsg)) {
              setState(() {
                _transactionAlreadyUsed = true;
              });
              _showDuplicateTransactionDialog();
              return;
            }
          } else if (data['message'] != null) {
            errorMsg = data['message'];

            if (_isDuplicateError(errorMsg)) {
              setState(() {
                _transactionAlreadyUsed = true;
              });
              _showDuplicateTransactionDialog();
              return;
            }
          }

          _showErrorSnackBar(errorMsg);
        } else if (response.statusCode == 500) {
          // 🆕 Handle 500 error - check if it's duplicate related
          try {
            final data = json.decode(response.body);
            String errorMsg = data['message'] ?? 'Server error occurred';

            if (_isDuplicateError(errorMsg)) {
              setState(() {
                _transactionAlreadyUsed = true;
              });
              _showDuplicateTransactionDialog();
              return;
            }
          } catch (e) {
            debugPrint('Failed to parse 500 error: $e');
          }

          _showErrorSnackBar(
            'Server error occurred. Please check if transaction ID is already used.',
          );
        } else {
          _showErrorSnackBar(
            'Error ${response.statusCode}: Failed to submit request',
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Submission error: $e');

      if (mounted) {
        Navigator.pop(context);

        String errorMessage = 'Network error. Please try again.';
        if (e.toString().contains('TimeoutException')) {
          errorMessage = 'Request timeout. Please check your connection.';
        }

        _showErrorSnackBar(errorMessage);
      }
    }
  }

  // =====================================================
  // 🆕 CHECK IF ERROR IS ABOUT DUPLICATE TRANSACTION
  // =====================================================

  bool _isDuplicateError(String errorMessage) {
    final lowerError = errorMessage.toLowerCase();
    return lowerError.contains('duplicate') ||
        lowerError.contains('already') ||
        lowerError.contains('exists') ||
        lowerError.contains('used') ||
        lowerError.contains('transaction id') && lowerError.contains('taken');
  }

  // =====================================================
  // ERROR SNACKBAR
  // =====================================================

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message, style: const TextStyle(fontSize: 14)),
            ),
          ],
        ),
        backgroundColor: Colors.red,
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

  // =====================================================
  // SUCCESS DIALOG
  // =====================================================

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.all(28),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 60,
                ),
              ),
            ),
            const SizedBox(height: 24),

            const Text(
              'Success!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),

            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey.shade700,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.blue.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Your deposit will be reviewed  ',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.blue.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _navigateBackToPaymentMethods();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                child: const Text(
                  'Done',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =====================================================
  // AUTH REQUIRED DIALOG
  // =====================================================

  void _showAuthDialog() {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: Colors.orange,
                size: 50,
              ),
            ),
            const SizedBox(height: 20),

            const Text(
              'Authentication Required',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            const Text(
              'Please login again to continue',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: themeColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'OK',
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

  // =====================================================
  // SESSION EXPIRED DIALOG
  // =====================================================

  void _showSessionExpiredDialog() {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_clock, color: Colors.red, size: 50),
            ),
            const SizedBox(height: 20),

            const Text(
              'Session Expired',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            const Text(
              'Your session has expired. Please login again',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: themeColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'OK',
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
}

// =====================================================
// PAYMENT METHOD CARD COMPONENT (unchanged)
// =====================================================

class PaymentMethodCard extends StatelessWidget {
  final String title;
  final String? imageUrl;
  final Color themeColor;
  final VoidCallback onTap;
  final bool showDetails;

  const PaymentMethodCard({
    super.key,
    required this.title,
    this.imageUrl,
    required this.themeColor,
    required this.onTap,
    this.showDetails = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: themeColor.withOpacity(0.2), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade200,
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              height: 70,
              width: 70,
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: imageUrl != null && imageUrl!.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        imageUrl!,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.payment,
                          color: themeColor.withOpacity(0.6),
                          size: 32,
                        ),
                      ),
                    )
                  : Icon(Icons.payment, color: themeColor, size: 32),
            ),
            const SizedBox(width: 16),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    showDetails ? 'Complete the form' : 'Tap to select',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: themeColor.withOpacity(0.85),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: themeColor.withOpacity(0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.arrow_forward, color: Colors.white, size: 18),
                  SizedBox(width: 6),
                  Text(
                    'Select',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
