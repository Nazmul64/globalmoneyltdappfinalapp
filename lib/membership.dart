import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'addbalance.dart';
import 'config/api_config.dart';

String get _baseUrl => ApiConfig.mediaBaseUrl;

/// ================================
/// PART 1: App Theme & Models
/// ================================

class AppTheme {
  static const activeGreen = Color(0xFF09A372);
  static const success = Color(0xFF10B981);
  static const warning = Color(0xFFF59E0B);
  static const error = Color(0xFFEF4444);
  static const info = Color(0xFF3B82F6);
  static const background = Color(0xFFF5F7FA);
  static const textPrimary = Color(0xFF1F2937);
  static const textSecondary = Color(0xFF6B7280);
  static const border = Color(0xFFE5E7EB);

  static Color primary = Color(0xFFFF6F61);
  static Color secondary = Color(0xFFFF8A5C);

  static LinearGradient get primaryGradient => LinearGradient(
    colors: [primary, secondary],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static Future<void> loadThemeFromApi(String baseUrl) async {
    try {
      final url = Uri.parse("$baseUrl/api/themechange");
      final res = await http
          .get(url, headers: {'Accept': 'application/json'})
          .timeout(Duration(seconds: 10));

      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        if (json['status'] == true && json['data'] != null) {
          final colorCode = json['data']['color_code']?.toString() ?? '#FF6F61';
          primary = _hexToColor(colorCode);
          secondary = _lightenColor(primary, 0.1);
        }
      }
    } catch (e) {
      debugPrint('⚠️ Theme load failed: $e');
    }
  }

  static Color _hexToColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }

  static Color _lightenColor(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withLightness((hsl.lightness + amount).clamp(0.0, 1.0))
        .toColor();
  }
}

/// ================================
/// Models
/// ================================
class PackageModel {
  final int id;
  final String name;
  final double price;
  final double dailyIncome;
  final int dailyLimit;
  final int validity;
  final String? photo;

  PackageModel({
    required this.id,
    required this.name,
    required this.price,
    required this.dailyIncome,
    required this.dailyLimit,
    required this.validity,
    this.photo,
  });

  factory PackageModel.fromJson(Map<String, dynamic> json) {
    return PackageModel(
      id: json['id'] ?? 0,
      name: json['package_name']?.toString() ?? 'Unknown',
      price: _parseDouble(json['price']),
      dailyIncome: _parseDouble(json['daily_income']),
      dailyLimit: int.tryParse(json['daily_limit']?.toString() ?? '0') ?? 0,
      validity: int.tryParse(json['validity']?.toString() ?? '0') ?? 0,
      photo: json['photo_url']?.toString() ?? json['photo']?.toString(),
    );
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      final parsed = double.tryParse(value);
      return parsed ?? 0.0;
    }
    return 0.0;
  }

  String? getPhotoUrl(String baseUrl) {
    if (photo == null || photo!.isEmpty) return null;
    if (photo!.startsWith('http://') || photo!.startsWith('https://'))
      return photo;
    return '$baseUrl/$photo';
  }

  String get validityFormatted {
    if (validity < 30) return '$validity Days';
    if (validity < 365) return '${(validity / 30).floor()} Months';
    return '${(validity / 365).floor()} Years';
  }
}

class UserPackageModel {
  final int id;
  final int packageId;
  final String packageName;
  final double amount;
  final double dailyIncome;
  final int validity;
  final String? photo;

  UserPackageModel({
    required this.id,
    required this.packageId,
    required this.packageName,
    required this.amount,
    required this.dailyIncome,
    required this.validity,
    this.photo,
  });

  factory UserPackageModel.fromJson(Map<String, dynamic> json) {
    return UserPackageModel(
      id: json['id'] ?? 0,
      packageId: json['package_id'] ?? 0,
      packageName: json['package_name']?.toString() ?? 'Unknown',
      amount: PackageModel._parseDouble(json['amount']),
      dailyIncome: PackageModel._parseDouble(json['daily_income']),
      validity: int.tryParse(json['validity']?.toString() ?? '0') ?? 0,
      photo: json['photo_url']?.toString() ?? json['photo']?.toString(),
    );
  }

  String? getPhotoUrl(String baseUrl) {
    if (photo == null || photo!.isEmpty) return null;
    if (photo!.startsWith('http://') || photo!.startsWith('https://'))
      return photo;
    return '$baseUrl/$photo';
  }

  String get validityFormatted {
    if (validity < 30) return '$validity Days';
    if (validity < 365) return '${(validity / 30).floor()} Months';
    return '${(validity / 365).floor()} Years';
  }
}

class UserBalance {
  final double balance;

  UserBalance({required this.balance});

  factory UserBalance.fromJson(Map<String, dynamic> json) {
    final balanceValue = json['balance'];
    double parsedBalance = 0.0;

    if (balanceValue != null) {
      if (balanceValue is double) {
        parsedBalance = balanceValue;
      } else if (balanceValue is int) {
        parsedBalance = balanceValue.toDouble();
      } else if (balanceValue is String) {
        parsedBalance = double.tryParse(balanceValue) ?? 0.0;
      }
    }

    return UserBalance(balance: parsedBalance);
  }
}

enum SnackBarType { success, error, info, warning }

/// ================================
/// PART 2: Helper Widgets
/// Part 1 import করুন এর উপরে
/// ================================

class PackageImage extends StatelessWidget {
  final String? imageUrl;
  final double height;
  final double? width;
  final BorderRadius? borderRadius;

  const PackageImage({
    Key? key,
    this.imageUrl,
    this.height = 100,
    this.width,
    this.borderRadius,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final br = borderRadius ?? BorderRadius.circular(10);
    if (imageUrl == null || imageUrl!.isEmpty) return _placeholder(br);

    return ClipRRect(
      borderRadius: br,
      child: Image.network(
        imageUrl!,
        height: height,
        width: width ?? double.infinity,
        fit: BoxFit.cover,
        loadingBuilder: (_, child, progress) =>
            progress == null ? child : _loading(br),
        errorBuilder: (_, __, ___) => _placeholder(br),
      ),
    );
  }

  Widget _loading(BorderRadius br) {
    return Container(
      height: height,
      width: width ?? double.infinity,
      decoration: BoxDecoration(color: AppTheme.background, borderRadius: br),
      child: Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation(AppTheme.primary),
        ),
      ),
    );
  }

  Widget _placeholder(BorderRadius br) {
    return Container(
      height: height,
      width: width ?? double.infinity,
      decoration: BoxDecoration(color: AppTheme.background, borderRadius: br),
      child: Icon(
        Icons.image_outlined,
        color: AppTheme.textSecondary.withOpacity(0.3),
        size: 40,
      ),
    );
  }
}

class PackageDetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const PackageDetailRow({
    Key? key,
    required this.icon,
    required this.label,
    required this.value,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 11, color: AppTheme.textSecondary),
          SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 9, color: AppTheme.textSecondary),
          ),
          Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class PackageCard extends StatelessWidget {
  final PackageModel package;
  final String baseUrl;
  final VoidCallback onTap;
  final bool isCurrent;
  final bool isUpdate;
  final bool hasActivePackage;

  const PackageCard({
    Key? key,
    required this.package,
    required this.baseUrl,
    required this.onTap,
    this.isCurrent = false,
    this.isUpdate = false,
    this.hasActivePackage = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final photoUrl = package.getPhotoUrl(baseUrl);
    final screenWidth = MediaQuery.of(context).size.width;
    final imageHeight = screenWidth > 600 ? 90.0 : 75.0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCurrent
              ? AppTheme.activeGreen
              : hasActivePackage
                  ? Colors.grey.shade300
                  : AppTheme.primary.withOpacity(0.3),
          width: isCurrent ? 2 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (isCurrent
                    ? AppTheme.activeGreen
                    : hasActivePackage
                        ? Colors.black
                        : AppTheme.primary)
                .withOpacity(0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isCurrent ? null : onTap,
          borderRadius: BorderRadius.circular(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (photoUrl != null && photoUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(14),
                    topRight: Radius.circular(14),
                  ),
                  child: Stack(
                    children: [
                      PackageImage(
                        imageUrl: photoUrl,
                        height: imageHeight,
                        width: double.infinity,
                      ),
                      if (isCurrent)
                        Positioned(
                          top: 6,
                          right: 6,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.activeGreen,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.verified_rounded,
                                  size: 10,
                                  color: Colors.white,
                                ),
                                SizedBox(width: 2),
                                Text(
                                  "ACTIVE",
                                  style: TextStyle(
                                    fontSize: 8,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isCurrent &&
                          (photoUrl == null || photoUrl.isEmpty)) ...[
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.activeGreen,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.verified_rounded,
                                size: 10,
                                color: Colors.white,
                              ),
                              SizedBox(width: 2),
                              Text(
                                "ACTIVE",
                                style: TextStyle(
                                  fontSize: 8,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 4),
                      ],
                      Text(
                        package.name,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 5),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          "\$${package.price.toStringAsFixed(2)}",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Spacer(),
                      PackageDetailRow(
                        icon: Icons.trending_up_rounded,
                        label: "Daily Earn",
                        value: "\$${package.dailyIncome.toStringAsFixed(2)}",
                      ),
                      PackageDetailRow(
                        icon: Icons.calendar_today_rounded,
                        label: "Daily Ads",
                        value: "${package.dailyLimit}",
                      ),
                      PackageDetailRow(
                        icon: Icons.timer_outlined,
                        label: "Validity",
                        value: package.validityFormatted,
                      ),
                      SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        height: 32,
                        child: isCurrent
                            ? Container(
                                decoration: BoxDecoration(
                                  color: AppTheme.activeGreen.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: AppTheme.activeGreen.withOpacity(
                                      0.3,
                                    ),
                                    width: 1.5,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.check_circle_rounded,
                                      size: 13,
                                      color: AppTheme.activeGreen,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      "Current Plan",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                        color: AppTheme.activeGreen,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : hasActivePackage
                                ? Container(
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade200,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: onTap,
                                        borderRadius: BorderRadius.circular(8),
                                        child: Container(
                                          alignment: Alignment.center,
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.block,
                                                size: 13,
                                                color: Colors.grey.shade600,
                                              ),
                                              SizedBox(width: 4),
                                              Text(
                                                "Unavailable",
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 11,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  )
                                : Container(
                                    decoration: BoxDecoration(
                                      gradient: AppTheme.primaryGradient,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: onTap,
                                        borderRadius: BorderRadius.circular(8),
                                        child: Container(
                                          alignment: Alignment.center,
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons
                                                    .shopping_cart_checkout_rounded,
                                                size: 13,
                                                color: Colors.white,
                                              ),
                                              SizedBox(width: 4),
                                              Text(
                                                "Buy Now",
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 11,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
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
    );
  }
}

/// ================================
/// PART 3: Main Widget State & API Calls
/// Part 1 এবং Part 2 import করুন এর উপরে
/// ================================

class MembershipPage extends StatefulWidget {
  const MembershipPage({Key? key}) : super(key: key);

  @override
  State<MembershipPage> createState() => _MembershipPageState();
}

class _MembershipPageState extends State<MembershipPage>
    with SingleTickerProviderStateMixin {
  List<PackageModel> _packages = [];
  UserPackageModel? _currentPackage;
  UserBalance? _userBalance;
  String? _authToken;
  bool _isLoading = true;
  bool _isPurchasing = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // URL: use ApiConfig.mediaBaseUrl
  static const Duration _timeout = Duration(seconds: 15);

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 600),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _initializeData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
    if (mounted) setState(() => _isLoading = true);

    final prefs = await SharedPreferences.getInstance();
    _authToken = prefs.getString('auth_token');

    debugPrint('🔍 Token: ${_authToken != null ? "Yes" : "No"}');

    await AppTheme.loadThemeFromApi(_baseUrl);

    if (_isLoggedIn) {
      await Future.wait([
        _fetchPackages(),
        _fetchUserBalance(),
        _fetchCurrentPackage(),
      ]);
    } else {
      await _fetchPackages();
    }

    if (mounted) {
      setState(() => _isLoading = false);
      _animationController.forward();
    }
  }

  Map<String, String> _headers({bool auth = false}) {
    final h = {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
    if (auth && _authToken != null && _authToken!.isNotEmpty) {
      h['Authorization'] = 'Bearer $_authToken';
    }
    return h;
  }

  bool get _isLoggedIn => _authToken != null && _authToken!.trim().isNotEmpty;

  Future<void> _fetchPackages() async {
    final url = Uri.parse("$_baseUrl/api/packageshow");
    try {
      final res = await http.get(url, headers: _headers()).timeout(_timeout);
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        if (json['success'] == true) {
          final data = json['data'] as List<dynamic>;
          if (mounted) {
            setState(() {
              _packages = data.map((x) => PackageModel.fromJson(x)).toList();
            });
          }
          debugPrint('✅ Packages: ${_packages.length}');
        }
      }
    } catch (e) {
      debugPrint('❌ Fetch packages: $e');
    }
  }

  Future<void> _fetchUserBalance() async {
    if (!_isLoggedIn) return;

    final url = Uri.parse("$_baseUrl/api/user/balance");
    try {
      final res = await http
          .get(url, headers: _headers(auth: true))
          .timeout(_timeout);

      debugPrint('📊 Balance Status: ${res.statusCode}');

      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        debugPrint('📊 Balance Response: ${json.toString()}');

        if (json['success'] == true && json['data'] != null) {
          if (mounted) {
            setState(() {
              _userBalance = UserBalance.fromJson(json['data']);
            });
          }
          debugPrint('✅ Balance: \$${_userBalance!.balance}');
        }
      } else if (res.statusCode == 401) {
        debugPrint('❌ Unauthorized');
        _showSnack("Session expired. Please login again.", SnackBarType.error);
      }
    } catch (e) {
      debugPrint('❌ Balance error: $e');
    }
  }

  Future<void> _fetchCurrentPackage() async {
    if (!_isLoggedIn) {
      debugPrint('ℹ️ Not logged in, skipping current package fetch');
      return;
    }

    final url = Uri.parse("$_baseUrl/api/user/current-package");
    try {
      final res = await http
          .get(url, headers: _headers(auth: true))
          .timeout(_timeout);

      debugPrint('📦 Current Package Status: ${res.statusCode}');
      debugPrint('📦 Response Body: ${res.body}');

      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);

        if (json['success'] == true && json['data'] != null) {
          if (mounted) {
            setState(() {
              _currentPackage = UserPackageModel.fromJson(json['data']);
            });
          }
          debugPrint(
            '✅ Current Package Found: ${_currentPackage!.packageName} (ID: ${_currentPackage!.packageId})',
          );
        } else {
          if (mounted) {
            setState(() => _currentPackage = null);
          }
          debugPrint('ℹ️ No active package (success=false or data=null)');
        }
      } else if (res.statusCode == 404) {
        if (mounted) {
          setState(() => _currentPackage = null);
        }
        debugPrint('ℹ️ No package found (404)');
      } else if (res.statusCode == 401) {
        debugPrint('❌ Unauthorized - token may be invalid');
        _showSnack("Session expired. Please login again.", SnackBarType.error);
      } else {
        debugPrint('⚠️ Unexpected status code: ${res.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Fetch current package error: $e');
      if (mounted) {
        setState(() => _currentPackage = null);
      }
    }
  }

  Future<void> _handlePackageAction(PackageModel package) async {
    debugPrint('🎯 Handle Package Action: ${package.name} (ID: ${package.id})');
    debugPrint(
      '🎯 Current Package: ${_currentPackage?.packageName ?? "None"} (ID: ${_currentPackage?.packageId ?? "N/A"})',
    );

    if (!_isLoggedIn) {
      _showLoginRequiredDialog();
      return;
    }

    if (_currentPackage != null) {
      if (_currentPackage?.packageId == package.id) {
        debugPrint('⚠️ User already has this package');
        _showAlreadyPurchasedDialog(package);
      } else {
        debugPrint('⚠️ Single membership constraint');
        _showSingleMembershipConstraintDialog();
      }
      return;
    }

    if (_userBalance == null || _userBalance!.balance < package.price) {
      debugPrint('⚠️ Insufficient balance');
      _showInsufficientBalanceDialog(package.price);
      return;
    }

    final confirm = await _showConfirmationDialog(package, false);
    if (confirm != true) {
      debugPrint('❌ User cancelled purchase');
      return;
    }

    await _processPackageAction(package, false);
  }

  void _showSingleMembershipConstraintDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.info_outline, color: Colors.orange, size: 24),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                "মেম্বারশিপ সীমাবদ্ধতা",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          "একটি অ্যাকাউন্টে একটি মেম্বারশিপ প্রযোজ্য। আপনি ইতিমধ্যে '${_currentPackage?.packageName ?? "Active Membership"}' ক্রয় করেছেন।",
          style: const TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("ঠিক আছে",
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _processPackageAction(
    PackageModel package,
    bool isUpdate,
  ) async {
    if (mounted) setState(() => _isPurchasing = true);

    final url = Uri.parse("$_baseUrl/api/packagebuy/${package.id}");
    try {
      debugPrint('💳 Attempting purchase: ${package.name} (ID: ${package.id})');

      final res = await http
          .post(url, headers: _headers(auth: true))
          .timeout(_timeout);

      debugPrint('💳 Purchase status: ${res.statusCode}');
      debugPrint('💳 Response: ${res.body}');

      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        if (json['success'] == true) {
          final packageData = (json['data'] as Map<String, dynamic>?) ??
              {
                'package_id': package.id,
                'package_name': package.name,
                'photo_url': package.getPhotoUrl(_baseUrl),
                'daily_income': package.dailyIncome,
                'daily_limit': package.dailyLimit,
              };

          _showMembershipSuccessDialog(packageData);
        } else {
          _showSnack(
            json['message']?.toString() ?? 'Purchase failed',
            SnackBarType.error,
          );
        }
      } else if (res.statusCode == 400) {
        final json = jsonDecode(res.body);
        _showSnack(
          json['message']?.toString() ??
              "You already have an active membership!",
          SnackBarType.warning,
        );
      } else if (res.statusCode == 401) {
        _showSnack("Session expired. Please login again.", SnackBarType.error);
      } else {
        try {
          final json = jsonDecode(res.body);
          _showSnack(
            json['message']?.toString() ?? "Server error (${res.statusCode})",
            SnackBarType.error,
          );
        } catch (e) {
          _showSnack("Server error (${res.statusCode})", SnackBarType.error);
        }
      }
    } catch (e) {
      debugPrint('❌ Purchase error: $e');
      _showSnack("Network error: ${e.toString()}", SnackBarType.error);
    } finally {
      if (mounted) setState(() => _isPurchasing = false);
    }
  }

  /// 🎉 Celebration animation & success dialog on purchase
  void _showMembershipSuccessDialog(Map<String, dynamic> packageData) {
    final photoUrl = packageData['photo_url'] ?? packageData['photo'];
    final name = packageData['package_name'] ?? packageData['name'] ?? 'Membership';
    final dailyIncome = packageData['daily_income']?.toString() ?? '0.00';
    final dailyLimit = packageData['daily_limit']?.toString() ?? '0';

    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: "Success",
      pageBuilder: (ctx, anim1, anim2) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E2D),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withOpacity(0.35),
                    blurRadius: 25,
                    spreadRadius: 6,
                  )
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.stars_rounded,
                      color: Colors.amber,
                      size: 60,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    "Congratulations!",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    "Membership Buy Successful",
                    style: TextStyle(
                      color: Color(0xFF09A372),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (photoUrl != null && photoUrl.toString().isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withOpacity(0.2)),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          photoUrl.toString().startsWith('http')
                              ? photoUrl.toString()
                              : '$_baseUrl/$photoUrl',
                          height: 90,
                          width: 140,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.workspace_premium,
                            size: 60,
                            color: Colors.amber,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 14),
                  Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      "Daily Income: \$$dailyIncome  |  Daily Ads: $dailyLimit",
                      style: TextStyle(
                        color: Colors.grey.shade300,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        elevation: 0,
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _initializeData();
                      },
                      child: const Text(
                        "Start Earning Now",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showSnack(String msg, SnackBarType t) {
    if (!mounted) return;

    Color bgColor;
    IconData icon;
    switch (t) {
      case SnackBarType.success:
        bgColor = AppTheme.success;
        icon = Icons.check_circle_rounded;
      case SnackBarType.error:
        bgColor = AppTheme.error;
        icon = Icons.error_rounded;
      case SnackBarType.info:
        bgColor = AppTheme.info;
        icon = Icons.info_rounded;
      case SnackBarType.warning:
        bgColor = AppTheme.warning;
        icon = Icons.warning_rounded;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: bgColor,
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                msg,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        duration: Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: EdgeInsets.all(16),
      ),
    );
  }

  /// ================================
  /// PART 4: Dialog Methods
  /// Part 3 এর সাথে যুক্ত করুন (_MembershipPageState class এর মধ্যে)
  /// ================================

  void _showAlreadyPurchasedDialog(PackageModel package) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Container(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.activeGreen.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle_rounded,
                  color: AppTheme.activeGreen,
                  size: 48,
                ),
              ),
              SizedBox(height: 16),
              Text(
                "Already Purchased!",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              SizedBox(height: 8),
              Text(
                "You already have this package active.",
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ),
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.activeGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppTheme.activeGreen.withOpacity(0.3),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      package.name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.verified_rounded,
                          color: AppTheme.activeGreen,
                          size: 16,
                        ),
                        SizedBox(width: 6),
                        Text(
                          "Currently Active",
                          style: TextStyle(
                            color: AppTheme.activeGreen,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),
              Text(
                "Please choose a different package to upgrade.",
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
              SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      "Got It",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool?> _showConfirmationDialog(
    PackageModel package,
    bool isUpdate,
  ) async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Container(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    Icon(
                      isUpdate
                          ? Icons.upgrade_rounded
                          : Icons.shopping_cart_checkout_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                    SizedBox(height: 6),
                    Text(
                      isUpdate ? "Upgrade Package" : "Purchase Package",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),
              Text(
                package.name,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                "\$${package.price.toStringAsFixed(2)}",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                ),
              ),
              SizedBox(height: 16),
              if (_userBalance != null)
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.background,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Your Balance:", style: TextStyle(fontSize: 12)),
                      Text(
                        "\$${_userBalance!.balance.toStringAsFixed(2)}",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text("Cancel"),
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          "Confirm",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showInsufficientBalanceDialog(double requiredAmount) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Container(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.account_balance_wallet_outlined,
                color: AppTheme.error,
                size: 48,
              ),
              SizedBox(height: 14),
              Text(
                "Insufficient Balance",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                "You don't have enough balance to purchase this package.",
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary),
              ),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Your Balance:", style: TextStyle(fontSize: 12)),
                        Text(
                          "\$${_userBalance?.balance.toStringAsFixed(2) ?? '0.00'}",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.error,
                          ),
                        ),
                      ],
                    ),
                    Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Need More:",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          "\$${(requiredAmount - (_userBalance?.balance ?? 0)).toStringAsFixed(2)}",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AppTheme.error,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text("Cancel"),
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AddBalancePage(),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          "Deposit Now",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLoginRequiredDialog() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Container(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline_rounded, color: AppTheme.error, size: 48),
              SizedBox(height: 14),
              Text(
                "Login Required",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                "You need to login to purchase packages.",
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary),
              ),
              SizedBox(height: 16),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _showSnack("Please login first", SnackBarType.info);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    "OK",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// ================================
  /// PART 5: UI Build Methods & Main Build
  /// Part 4 এর সাথে যুক্ত করুন (_MembershipPageState class এর মধ্যে)
  /// ================================

  Widget _buildAuthBadge() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _isLoggedIn
            ? Colors.white.withOpacity(0.2)
            : Colors.red.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _isLoggedIn ? Icons.check_circle_rounded : Icons.cancel_rounded,
            size: 12,
            color: Colors.white,
          ),
          SizedBox(width: 3),
          Text(
            _isLoggedIn ? "Logged In" : "Guest",
            style: TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCard(double padding) {
    if (_userBalance == null) return SizedBox.shrink();

    return Container(
      margin: EdgeInsets.symmetric(horizontal: padding),
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.08),
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.primary.withOpacity(0.1),
              AppTheme.secondary.withOpacity(0.1),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: AppTheme.primary.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.account_balance_wallet_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Available Balance",
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    "\$${_userBalance!.balance.toStringAsFixed(2)}",
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
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

  Widget _buildCurrentPackageCard(double padding) {
    if (_currentPackage == null) return SizedBox.shrink();

    return Container(
      margin: EdgeInsets.symmetric(horizontal: padding),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.activeGreen, AppTheme.activeGreen.withOpacity(0.8)],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppTheme.activeGreen.withOpacity(0.2),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.verified_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _currentPackage!.packageName,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      "Active Package",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _packageInfo(
                'Investment',
                '\$${_currentPackage!.amount.toStringAsFixed(2)}',
              ),
              _packageInfo(
                'Daily Income',
                '\$${_currentPackage!.dailyIncome.toStringAsFixed(2)}',
              ),
              _packageInfo('Validity', _currentPackage!.validityFormatted),
            ],
          ),
        ],
      ),
    );
  }

  Widget _packageInfo(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.inventory_2_outlined,
              size: 48,
              color: AppTheme.primary,
            ),
          ),
          SizedBox(height: 16),
          Text(
            'No packages available',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Check back later for new packages',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _loadingOverlay() {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Container(
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
                strokeWidth: 3,
              ),
              SizedBox(height: 16),
              Text(
                "Processing...",
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              SizedBox(height: 4),
              Text(
                "Please wait...",
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth > 600 ? 3 : 2;
    final horizontalPadding = screenWidth > 600 ? 20.0 : 14.0;
    final childAspectRatio = screenWidth > 600 ? 0.72 : 0.58;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 90,
                floating: false,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                    ),
                    child: SafeArea(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          horizontalPadding,
                          12,
                          horizontalPadding,
                          0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "Membership",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  "Choose your plan",
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                _buildAuthBadge(),
                                SizedBox(width: 6),
                                IconButton(
                                  icon: Icon(
                                    Icons.refresh_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  onPressed: () async {
                                    await _initializeData();
                                    _showSnack("Refreshed", SnackBarType.info);
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                backgroundColor: AppTheme.primary,
              ),
              if (_isLoading)
                SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppTheme.primary,
                      ),
                    ),
                  ),
                )
              else ...[
                if (_isLoggedIn && _userBalance != null) ...[
                  SliverToBoxAdapter(child: SizedBox(height: 14)),
                  SliverToBoxAdapter(
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: _buildBalanceCard(horizontalPadding),
                    ),
                  ),
                ],
                if (_isLoggedIn &&
                    (_userBalance == null || _userBalance!.balance <= 0)) ...[
                  SliverToBoxAdapter(child: SizedBox(height: 14)),
                  SliverToBoxAdapter(
                    child: Container(
                      margin: EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                      ),
                      padding: EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.warning.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppTheme.warning.withOpacity(0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: AppTheme.warning,
                            size: 24,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "No Balance Available",
                                  style: TextStyle(
                                    color: AppTheme.warning,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 3),
                                Text(
                                  "Please deposit money to purchase packages",
                                  style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 11,
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
                if (_currentPackage != null) ...[
                  SliverToBoxAdapter(child: SizedBox(height: 18)),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                      ),
                      child: Text(
                        "Your Active Package",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(child: SizedBox(height: 10)),
                  SliverToBoxAdapter(
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: _buildCurrentPackageCard(horizontalPadding),
                    ),
                  ),
                ],
                SliverToBoxAdapter(child: SizedBox(height: 18)),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                    ),
                    child: Text(
                      _currentPackage != null
                          ? "All Membership Packages"
                          : "Available Packages",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(child: SizedBox(height: 10)),
                if (_packages.isEmpty)
                  SliverFillRemaining(child: _emptyState())
                else
                  SliverPadding(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                    ),
                    sliver: SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        childAspectRatio: childAspectRatio,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      delegate: SliverChildBuilderDelegate((_, i) {
                        final p = _packages[i];
                        final isCurrent = _currentPackage?.packageId == p.id;
                        debugPrint(
                          '🎨 Building card for ${p.name} (ID: ${p.id}) - isCurrent: $isCurrent',
                        );
                        return FadeTransition(
                          opacity: _fadeAnimation,
                          child: PackageCard(
                            package: p,
                            baseUrl: _baseUrl,
                            onTap: () => _handlePackageAction(p),
                            isCurrent: isCurrent,
                            isUpdate: false,
                            hasActivePackage: _currentPackage != null,
                          ),
                        );
                      }, childCount: _packages.length),
                    ),
                  ),
                SliverToBoxAdapter(child: SizedBox(height: 18)),
              ],
            ],
          ),
          if (_isPurchasing) _loadingOverlay(),
        ],
      ),
    );
  }

  // Class শেষ
}
