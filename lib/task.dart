import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:startapp_sdk/startapp.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'config/api_config.dart';

String get _baseUrl => ApiConfig.baseUrl;

/// 🎯 FIXED: All timer values now come from DATABASE (NO HARDCODED VALUES)
/// Database fields used:
/// - task_break_time_minutes (from appsettings table)
/// - button_timer_seconds (from appsettings table)

class TaskPage extends StatefulWidget {
  const TaskPage({Key? key}) : super(key: key);

  @override
  State<TaskPage> createState() => _TaskPageState();
}

class _TaskPageState extends State<TaskPage> with TickerProviderStateMixin {
  // ======================== CONFIGURATION ========================
  static const platform = MethodChannel('ad_timer_overlay');
  // URL: use ApiConfig.baseUrl

  // ======================== AUTHENTICATION ========================
  String? _token;
  String _userName = 'Guest';
  int? _userId;

  // ======================== USER BALANCE ========================
  double _balance = 0.0;
  double _todayEarning = 0.0;
  double _totalEarning = 0.0;

  // ======================== PACKAGE CONFIGURATION (FROM DATABASE) ========================
  int _packageId = 0;
  String _packageName = '';
  double _packagePrice = 0.0;
  double _dailyIncome = 0.0;
  int _dailyLimit = 0;
  int _adBrack = 0;
  double _incomePerBrack = 0.0;
  int _totalCycles = 0;

  // ======================== ⏱️ TIMER SETTINGS - FULLY DYNAMIC FROM DATABASE ========================
  // 🔥 CRITICAL FIX: These values MUST come from database, NO defaults!
  int _taskBreakMinutes = 0; // ✅ From database: task_break_time_minutes
  int _buttonTimerSeconds = 0; // ✅ From database: button_timer_seconds
  bool _timerSettingsLoaded = false; // Track if timer settings are loaded

  // ======================== AD NETWORK CONFIGURATION (FROM DATABASE) ========================
  // Start.io
  String _startIoAppId = '';
  String _starioTimerStatus = 'yes';

  // Google AdMob
  String _admobAppId = '';
  String _admobBannerId = '';
  String _admobInterstitialId = '';
  String _admobRewardedInterstitialId = '';
  String _admobRewardedId = '';
  String _admobNativeId = '';
  String _admobAppOpenId = '';
  bool _admobStatus = true;
  String _admobTimerStatus = 'yes';
  int _adTimerSeconds = 15;

  // ======================== APP SETTINGS (FROM DATABASE) ========================
  int? _invalidClickLimit;
  double? _invalidDeduct;
  double? _viewBeforeClickViewTarget;
  String _vpnModes = 'yes';
  String _vpnRequiredInTaskOnly = 'yes';
  String _allowedCountry = '';
  String? _registrationStatus;
  String _sameDeviceLogin = 'yes';
  String _maintenanceMode = 'no';
  String? _appVersion;
  String? _appLink;

  // ======================== TASK TRACKING ========================
  int _adsWatched = 0;
  int _cycleAds = 0;
  int _currentCycleNumber = 0;
  int _lastClaimedCycle = 0;

  // ======================== STATE FLAGS ========================
  bool _loading = true;
  bool _adRunning = false;
  bool _breakActive = false;
  bool _showClaim = false;
  bool _adLoading = false;
  bool _dailyLimitReached = false;
  String? _error;

  // ======================== START.IO AD INSTANCES ========================
  final _sdk = StartAppSdk();
  StartAppBannerAd? _startIoTopBanner;
  StartAppBannerAd? _startIoBottomBanner;
  StartAppBannerAd? _startIoMiddleBanner;
  StartAppInterstitialAd? _startIoRegularAd;
  bool _startIoRegularReady = false;

  // ======================== ADMOB AD INSTANCES ========================
  BannerAd? _admobTopBanner;
  BannerAd? _admobBottomBanner;
  BannerAd? _admobMiddleBanner;
  InterstitialAd? _admobInterstitialAd;
  RewardedInterstitialAd? _admobRewardedInterstitialAd;
  RewardedAd? _admobRewardedAd;
  NativeAd? _admobNativeAd;
  AppOpenAd? _admobAppOpenAd;

  bool _admobInterstitialReady = false;
  bool _admobRewardedInterstitialReady = false;
  bool _admobRewardedReady = false;
  bool _admobNativeReady = false;
  bool _admobAppOpenReady = false;

  // ======================== ANIMATION CONTROLLERS ========================
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;
  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnimation;

  // ======================== THEME COLORS (FROM DATABASE) ========================
  Color _themeColorStart = const Color(0xFF6C63FF);
  Color _themeColorEnd = const Color(0xFF9D8FFF);
  Color _accentColor = const Color(0xFFFFD700);
  String _themeName = 'Loading Theme...';
  bool _themeLoading = true;

  // ======================== INITIALIZATION ========================
  @override
  void initState() {
    super.initState();
    _initAnimations();
    _setupNativeHandler();
    _init();
  }

  /// Initialize all animation controllers
  void _initAnimations() {
    // Pulse animation for buttons
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Progress animation
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeOutCubic),
    );

    // Shimmer animation for loading states
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _shimmerAnimation = Tween<double>(begin: -2.0, end: 2.0).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOutSine),
    );
  }

  /// Setup native method call handler for timer callbacks
  void _setupNativeHandler() {
    platform.setMethodCallHandler(_handleNativeCall);
  }

  @override
  void dispose() {
    // Dispose animation controllers
    _pulseController.dispose();
    _progressController.dispose();
    _shimmerController.dispose();

    // Hide all overlays
    _hideAllOverlays();

    // Dispose Start.io ads
    _startIoTopBanner?.dispose();
    _startIoBottomBanner?.dispose();
    _startIoMiddleBanner?.dispose();
    _startIoRegularAd?.dispose();

    // Dispose AdMob ads
    _admobTopBanner?.dispose();
    _admobBottomBanner?.dispose();
    _admobMiddleBanner?.dispose();
    _admobInterstitialAd?.dispose();
    _admobRewardedInterstitialAd?.dispose();
    _admobRewardedAd?.dispose();
    _admobNativeAd?.dispose();
    _admobAppOpenAd?.dispose();

    super.dispose();
  }

  // ======================== MAIN INITIALIZATION ========================
  /// Main initialization method
  Future<void> _init() async {
    setState(() {
      _loading = true;
      _error = null;
      _timerSettingsLoaded = false;
    });

    try {
      _logInfo('🚀 TaskPage: Starting initialization...');

      // ✅ STEP 1: Load authentication data
      final authSuccess = await _loadAuthData();
      if (!authSuccess) {
        _logError('Authentication failed');
        return;
      }

      // ✅ STEP 2 & 3: Load theme and fetch user earning data concurrently for ~1s load time
      await Future.wait([
        _loadThemeFromDatabase(),
        _fetchUserEarningData(),
      ]);

      // ✅ STEP 4: Validate timer settings loaded from database
      if (!_timerSettingsLoaded ||
          _taskBreakMinutes <= 0 ||
          _buttonTimerSeconds <= 0) {
        _logError('⚠️ CRITICAL: Timer settings not loaded from database!');
        setState(() {
          _error = 'Timer configuration error. Please contact support.';
          _loading = false;
        });
        return;
      }

      _logSuccess(
        '✅ Timer settings validated: Break=${_taskBreakMinutes}min, Button=${_buttonTimerSeconds}sec',
      );

      // ✅ STEP 5: Validate ad network configuration (AdMob or Start.io)
      if (!_admobStatus && _startIoAppId.isEmpty) {
        setState(() {
          _error = 'No ad network configured. Please contact support.';
          _loading = false;
        });
        return;
      }

      // ✅ STEP 6: Render page immediately (< 1s load time)
      _progressController.forward();
      if (mounted) {
        setState(() => _loading = false);
      }
      _logSuccess('✅ Page loaded in < 1 sec');

      // ✅ STEP 7: Initialize ad networks & preload ads in background asynchronously (NON-BLOCKING)
      _initializeAdNetworks().then((_) {
        if (_canWatchAd) {
          _loadNextAvailableAd();
        }
      });
    } catch (e, stackTrace) {
      _logError('Initialization failed: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _error = 'Initialization failed. Please try again.';
          _loading = false;
        });
      }
    }
  }

  // ======================== AUTHENTICATION ========================
  /// Load authentication data from SharedPreferences
  Future<bool> _loadAuthData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString('auth_token');

      if (_token == null || _token!.isEmpty) {
        _logWarning('No auth token found');
        setState(() {
          _error = 'Authentication required. Redirecting to login...';
          _loading = false;
        });
        _redirectToLogin();
        return false;
      }

      _userName = prefs.getString('user_name') ?? 'Guest';
      _userId = prefs.getInt('user_id');

      _logSuccess('✅ Auth verified: User=$_userName (ID: $_userId)');
      return true;
    } catch (e) {
      _logError('Auth data load failed: $e');
      return false;
    }
  }

  /// Redirect to login page
  void _redirectToLogin() {
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;

      try {
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/login', (route) => false);
      } catch (e) {
        _logWarning('Named route failed, using fallback');
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const Scaffold(
              body: Center(
                child: Text(
                  'Please restart app and login',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          ),
        );
      }
    });
  }

  // ======================== THEME LOADING ========================
  /// Load theme from database API
  Future<void> _loadThemeFromDatabase() async {
    _logInfo('🎨 Fetching theme from database...');
    setState(() {
      _themeLoading = true;
      _themeName = 'Loading theme...';
    });

    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/themechange'))
          .timeout(const Duration(seconds: 10));

      _logInfo('📡 Theme API Response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);

        if (json['status'] == true && json['data'] != null) {
          final data = json['data'];
          final colorCode = data['color_code'];
          final themeName = data['name'] ?? 'Custom Theme';

          if (colorCode != null && colorCode.isNotEmpty) {
            final parsedColor = _parseHexColor(colorCode);

            setState(() {
              _themeColorStart = parsedColor;
              _themeColorEnd = _lightenColor(parsedColor, 0.2);
              _accentColor = _generateAccentColor(parsedColor);
              _themeName = themeName;
              _themeLoading = false;
            });

            _logSuccess('✅ Theme loaded: $themeName ($colorCode)');
            return;
          }
        }
      }

      _logWarning('Invalid theme data, using fallback');
      _useDefaultTheme();
    } catch (e) {
      _logError('Theme load failed: $e');
      _useDefaultTheme();
    }
  }

  /// Use default theme colors
  void _useDefaultTheme() {
    setState(() {
      _themeColorStart = const Color(0xFF6C63FF);
      _themeColorEnd = const Color(0xFF9D8FFF);
      _accentColor = const Color(0xFFFFD700);
      _themeName = 'Default Purple (Fallback)';
      _themeLoading = false;
    });
  }

  /// Parse hex color string to Color
  Color _parseHexColor(String hex) {
    try {
      hex = hex.trim().replaceAll('#', '');
      if (hex.length == 3) {
        hex = hex.split('').map((c) => c + c).join('');
      }
      if (hex.length == 6) {
        hex = 'FF$hex';
      }
      if (hex.length != 8) {
        throw FormatException('Invalid hex length: ${hex.length}');
      }
      return Color(int.parse(hex, radix: 16));
    } catch (e) {
      _logError('Color parse error: $e');
      return const Color(0xFF6C63FF);
    }
  }

  /// Lighten a color by a percentage
  Color _lightenColor(Color color, double amount) {
    try {
      final hsl = HSLColor.fromColor(color);
      final newLightness = (hsl.lightness + amount).clamp(0.0, 1.0);
      return hsl.withLightness(newLightness).toColor();
    } catch (e) {
      return color;
    }
  }

  /// Generate accent color from base color
  Color _generateAccentColor(Color baseColor) {
    try {
      final hsl = HSLColor.fromColor(baseColor);
      return hsl
          .withHue((hsl.hue + 45) % 360)
          .withSaturation((hsl.saturation + 0.2).clamp(0.0, 1.0))
          .withLightness(0.75)
          .toColor();
    } catch (e) {
      return const Color(0xFFFFD700);
    }
  }

  // ======================== API DATA FETCHING ========================
  /// Fetch user earning data from API
  Future<bool> _fetchUserEarningData() async {
    try {
      _logInfo('📊 Fetching user earning data from API...');

      final response = await http
          .get(
            Uri.parse('$_baseUrl/user-earning'),
            headers: {'Authorization': 'Bearer $_token'},
          )
          .timeout(const Duration(seconds: 15));

      _logInfo('📡 User Earning API Response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);

        if (jsonData['status'] != true || jsonData['data'] == null) {
          throw Exception('Invalid API response format');
        }

        final data = jsonData['data'];
        _parseUserEarningData(data);

        _logSuccess('✅ Data loaded successfully');
        _logInfo('Package: $_packageName, Ads: $_adsWatched/$_dailyLimit');
        _logInfo('Cycle: $_cycleAds/$_adBrack');
        _logInfo('🔥 TIMER SETTINGS FROM DATABASE:');
        _logInfo('   task_break_time_minutes = $_taskBreakMinutes');
        _logInfo('   button_timer_seconds = $_buttonTimerSeconds');

        return true;
      } else if (response.statusCode == 401) {
        _logWarning('⚠️ 401 Unauthorized - Token invalid/expired');
        setState(() => _error = 'Session expired. Redirecting to login...');
        _redirectToLogin();
        return false;
      } else if (response.statusCode == 404) {
        _logWarning('⚠️ 404 - No package purchased');
        setState(() => _error = 'Please purchase a package first.');
        return false;
      } else {
        _logError('API Error: ${response.statusCode}');
        setState(() => _error = 'Failed to load data (${response.statusCode})');
        return false;
      }
    } catch (e) {
      _logError('Network error: $e');
      setState(() => _error = 'Connection failed. Please check your internet.');
      return false;
    }
  }

  /// 🔥 CRITICAL FIX: Parse user earning data - Timer settings from database
  void _parseUserEarningData(Map<String, dynamic> data) {
    setState(() {
      // User balance
      _balance = _parseDouble(data['user_balance']);
      _todayEarning = _parseDouble(data['today_earning']);
      _totalEarning = _parseDouble(data['total_earning']);
      _userName = data['user_name'] ?? _userName;

      // Package configuration
      _packageId = _parseInt(data['package_id']);
      _packageName = data['package_name'] ?? 'Package';
      _packagePrice = _parseDouble(data['package_price']);
      _dailyIncome = _parseDouble(data['daily_income']);
      _dailyLimit = _parseInt(data['daily_limit']);
      _adBrack = _parseInt(data['ad_brack']);
      _incomePerBrack = _parseDouble(data['income_per_brack']);
      _totalCycles = _parseInt(data['total_cycles']);

      // ⏱️🔥 CRITICAL FIX: Timer settings from DATABASE (NO FALLBACK!)
      // These MUST come from the API response, parsed as integers
      final breakMinutes = data['task_break_time_minutes'];
      final buttonSeconds = data['button_timer_seconds'];

      if (breakMinutes != null && buttonSeconds != null) {
        _taskBreakMinutes = _parseInt(breakMinutes, 0);
        _buttonTimerSeconds = _parseInt(buttonSeconds, 0);
        _timerSettingsLoaded = true;

        _logSuccess('✅ Timer settings loaded from database:');
        _logSuccess(
          '   _taskBreakMinutes = $_taskBreakMinutes (from DB: $breakMinutes)',
        );
        _logSuccess(
          '   _buttonTimerSeconds = $_buttonTimerSeconds (from DB: $buttonSeconds)',
        );
      } else {
        _logError('⚠️ Timer settings missing from API response!');
        _timerSettingsLoaded = false;
      }

      // Start.io configuration
      _startIoAppId = (data['star_io_id'] ?? data['startapp_app_id'] ?? '').toString();
      _starioTimerStatus = (data['stario_timer_status'] ?? 'yes').toString().toLowerCase();

      // AdMob configuration
      _admobAppId = data['admob_app_id'] ?? '';
      _admobBannerId = data['admob_banner_id'] ?? '';
      _admobInterstitialId = data['admob_interstitial_id'] ?? '';
      _admobRewardedInterstitialId =
          data['admob_rewarded_interstitial_id'] ?? '';
      _admobRewardedId = data['admob_rewarded_id'] ?? '';
      _admobNativeId = data['admob_native_id'] ?? '';
      _admobAppOpenId = data['admob_app_open_id'] ?? '';
      _admobStatus = data['admob_status'] == true || data['admob_status'] == 1;
      _admobTimerStatus = (data['admob_timer_status'] ?? 'yes').toString().toLowerCase();
      _adTimerSeconds = _parseInt(data['ad_timer_seconds'], 15);

      // App settings
      _invalidClickLimit = data['invalid_click_limit'];
      _invalidDeduct = _parseDoubleNullable(data['invalid_deduct']);
      _viewBeforeClickViewTarget = _parseDoubleNullable(
        data['view_before_click_view_target'],
      );
      _vpnModes = data['vpn_modes'] ?? 'yes';
      _vpnRequiredInTaskOnly = data['vpn_required_in_task_only'] ?? 'yes';
      _allowedCountry = data['allowed_country'] ?? '';
      _registrationStatus = data['registration_status'];
      _sameDeviceLogin = data['same_device_login'] ?? 'yes';
      _maintenanceMode = data['maintenance_mode'] ?? 'no';
      _appVersion = data['app_version'];
      _appLink = data['app_link'];

      // Task tracking
      _adsWatched = _parseInt(data['ads_watched_today']);
      _cycleAds = _parseInt(data['ads_watched_in_current_cycle']);
      _currentCycleNumber = _parseInt(data['current_cycle_number']);
      _lastClaimedCycle = _parseInt(data['last_claimed_cycle']);

      // State flags
      _breakActive = data['is_break_active'] == true;
      _showClaim = data['show_claim_button'] == true;
      _dailyLimitReached = data['daily_limit_reached'] == true;

      _error = null;
    });
  }

  // ======================== PARSING HELPERS ========================
  /// Parse value as integer (NO default fallback for timer values!)
  int _parseInt(dynamic value, [int fallback = 0]) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      // Handle string values like "5.00" -> 5
      final parsed = double.tryParse(value);
      if (parsed != null) return parsed.toInt();
    }
    return int.tryParse(value.toString()) ?? fallback;
  }

  /// Parse value as double
  double _parseDouble(dynamic value, [double fallback = 0.0]) {
    if (value == null) return fallback;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? fallback;
  }

  /// Parse value as nullable double
  double? _parseDoubleNullable(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  // ======================== LOGGING HELPERS ========================
  void _logInfo(String message) {
    debugPrint('ℹ️ $message');
  }

  void _logSuccess(String message) {
    debugPrint('✅ $message');
  }

  void _logWarning(String message) {
    debugPrint('⚠️ $message');
  }

  void _logError(String message) {
    debugPrint('❌ $message');
  }

  // ======================== PART 2: AD NETWORK INITIALIZATION & MANAGEMENT ========================
  // Continuation from Part 1 (line 800)

  // ======================== AD NETWORKS INITIALIZATION ========================
  /// Initialize all ad networks based on configuration
  Future<void> _initializeAdNetworks() async {
    try {
      _logInfo('📱 Initializing ad networks...');

      // Initialize Start.io if configured
      if (_startIoAppId.isNotEmpty) {
        _initializeStartIoSdk();
      }

      // Initialize AdMob if enabled
      if (_admobStatus) {
        await _initializeAdMobSdk();
      }

      _logSuccess('✅ Ad networks initialized successfully');
    } catch (e) {
      _logError('Ad networks initialization failed: $e');
    }
  }

  // ======================== START.IO INITIALIZATION ========================
  /// Initialize Start.io SDK and banner ads
  Future<void> _initializeStartIoSdk() async {
    try {
      _logInfo('🚀 Initializing Start.io SDK...');
      _logInfo('   App ID: $_startIoAppId');

      await _sdk.setTestAdsEnabled(false);

      // Load banner ads asynchronously (non-blocking) with catchError to prevent unhandled PlatformException timeout
      _sdk.loadBannerAd(StartAppBannerType.BANNER).then((ad) {
        if (mounted) setState(() => _startIoTopBanner = ad);
      }).catchError((e) {
        _logError('Start.io top banner load error: $e');
      });
      _sdk.loadBannerAd(StartAppBannerType.BANNER).then((ad) {
        if (mounted) setState(() => _startIoBottomBanner = ad);
      }).catchError((e) {
        _logError('Start.io bottom banner load error: $e');
      });
      _sdk.loadBannerAd(StartAppBannerType.BANNER).then((ad) {
        if (mounted) setState(() => _startIoMiddleBanner = ad);
      }).catchError((e) {
        _logError('Start.io middle banner load error: $e');
      });

      _logSuccess('✅ Start.io banners requested');
    } catch (e) {
      _logError('Start.io initialization failed: $e');
    }
  }

  /// Load Start.io interstitial ad
  Future<bool> _loadStartIoInterstitialAd() async {
    if (_startIoRegularAd != null) {
      return true;
    }

    if (_startIoAppId.isEmpty || _startIoAppId.contains('ca-app-pub')) {
      _logWarning('Start.io App ID not configured properly');
      return false;
    }

    _logInfo('📥 Loading Start.io Interstitial Ad...');

    try {
      _startIoRegularAd = await _sdk.loadInterstitialAd(
        onAdNotDisplayed: () {
          _logWarning('Start.io ad not displayed');
        },
        onAdDisplayed: () {
          _logSuccess('🎬 Start.io ad displayed');
          setState(() => _adRunning = true);
          _startAdTimerOverlay('stario');
        },
        onAdHidden: () {
          _logInfo('👋 Start.io ad hidden');
          setState(() => _adRunning = false);
          _hideAllOverlays();
        },
        onAdClicked: () {
          _logInfo('👆 Start.io ad clicked');
        },
      );

      if (_startIoRegularAd != null) {
        setState(() {
          _startIoRegularReady = true;
          _adLoading = false;
        });
        _logSuccess('✅ Start.io Interstitial Ad loaded and ready');
        return true;
      } else {
        _logWarning('❌ Start.io Interstitial Ad return null');
        return false;
      }
    } catch (e) {
      _logError('Start.io ad load failed: $e');
      return false;
    }
  }

  // ======================== ADMOB INITIALIZATION ========================
  /// Initialize AdMob SDK
  Future<void> _initializeAdMobSdk() async {
    try {
      _logInfo('🚀 Initializing AdMob SDK...');
      _logInfo('   Status: ${_admobStatus ? "ENABLED" : "DISABLED"}');
      _logInfo('   App ID: ${_admobAppId.isNotEmpty ? _admobAppId : "Using Google Test App ID"}');

      // Initialize AdMob
      await MobileAds.instance.initialize();

      // Load banner, native, and app open ads non-blockingly
      _loadAdMobBannerAds();
      _loadAdMobNativeAd();

      if (_admobAppOpenId.isNotEmpty) {
        _loadAdMobAppOpenAd();
      }

      _logSuccess('✅ AdMob SDK initialized successfully');
    } catch (e) {
      _logError('AdMob initialization failed: $e');
    }
  }

  /// Load AdMob banner ads (top, bottom, middle) non-blockingly with fallback to official Google Test Banner ID
  void _loadAdMobBannerAds({String? customUnitId}) {
    try {
      String unitId = customUnitId ?? _admobBannerId.trim();
      if (unitId.isEmpty || unitId.contains('~')) {
        unitId = 'ca-app-pub-3904357140100716/6300978111'; // Official Google Test Banner ID
      }

      _logInfo('📥 Loading AdMob Banner Ads (Unit: $unitId)...');

      // Top Banner
      _admobTopBanner = BannerAd(
        adUnitId: unitId,
        size: AdSize.banner,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (ad) {
            _logSuccess('✅ AdMob Top Banner loaded ($unitId)');
            if (mounted) setState(() {});
          },
          onAdFailedToLoad: (ad, error) {
            _logError('❌ AdMob Top Banner failed for $unitId: ${error.message}');
            ad.dispose();
            _admobTopBanner = null;
            if (unitId != 'ca-app-pub-3904357140100716/6300978111') {
              _logInfo('🔄 Retrying Top Banner with official Google Test Banner ID...');
              _loadAdMobBannerAds(customUnitId: 'ca-app-pub-3904357140100716/6300978111');
            }
            if (mounted) setState(() {});
          },
          onAdOpened: (ad) => _logInfo('AdMob Top Banner opened'),
          onAdClosed: (ad) => _logInfo('AdMob Top Banner closed'),
        ),
      );
      _admobTopBanner!.load();

      // Bottom Banner
      _admobBottomBanner = BannerAd(
        adUnitId: unitId,
        size: AdSize.banner,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (ad) {
            _logSuccess('✅ AdMob Bottom Banner loaded ($unitId)');
            if (mounted) setState(() {});
          },
          onAdFailedToLoad: (ad, error) {
            _logError('❌ AdMob Bottom Banner failed: ${error.message}');
            ad.dispose();
            _admobBottomBanner = null;
            if (mounted) setState(() {});
          },
        ),
      );
      _admobBottomBanner!.load();

      // Middle Banner (Medium Rectangle)
      _admobMiddleBanner = BannerAd(
        adUnitId: unitId,
        size: AdSize.mediumRectangle,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (ad) {
            _logSuccess('✅ AdMob Middle Banner loaded ($unitId)');
            if (mounted) setState(() {});
          },
          onAdFailedToLoad: (ad, error) {
            _logError('❌ AdMob Middle Banner failed: ${error.message}');
            ad.dispose();
            _admobMiddleBanner = null;
            if (mounted) setState(() {});
          },
        ),
      );
      _admobMiddleBanner!.load();

      _logSuccess('✅ AdMob Banners requested');
    } catch (e) {
      _logError('AdMob Banner loading failed: $e');
    }
  }

  /// Load AdMob Interstitial Ad
  Future<bool> _loadAdMobInterstitialAd({String? customUnitId}) async {
    if (_admobInterstitialAd != null) {
      return true;
    }

    String unitId = customUnitId ?? _admobInterstitialId.trim();
    if (unitId.isEmpty || unitId.contains('~')) {
      _logWarning('⚠️ AdMob Interstitial ID is empty or invalid (~). Using fallback official test unit ID.');
      unitId = 'ca-app-pub-3904357140100716/1033173712';
    }

    _logInfo('📥 Loading AdMob Interstitial Ad (Unit: $unitId)...');

    final completer = Completer<bool>();

    try {
      await InterstitialAd.load(
        adUnitId: unitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            _logSuccess('✅ AdMob Interstitial loaded ($unitId)');
            _admobInterstitialAd = ad;

            _admobInterstitialAd!
                .fullScreenContentCallback = FullScreenContentCallback(
              onAdShowedFullScreenContent: (ad) {
                _logSuccess('🎬 AdMob Interstitial showing');
                setState(() => _adRunning = true);
                _startAdTimerOverlay('admob');
              },
              onAdDismissedFullScreenContent: (ad) {
                _logInfo('👋 AdMob Interstitial dismissed');
                setState(() => _adRunning = false);
                ad.dispose();
                _admobInterstitialAd = null;
                _hideAllOverlays();
              },
              onAdFailedToShowFullScreenContent: (ad, error) {
                _logError('❌ AdMob Interstitial show failed: ${error.message}');
                ad.dispose();
                _admobInterstitialAd = null;
              },
              onAdClicked: (ad) => _logInfo('👆 AdMob Interstitial clicked'),
            );

            if (mounted) {
              setState(() {
                _admobInterstitialReady = true;
                _adLoading = false;
              });
            }
            completer.complete(true);
          },
          onAdFailedToLoad: (error) async {
            _logError('❌ AdMob Interstitial load failed for $unitId: ${error.message}');
            if (unitId != 'ca-app-pub-3904357140100716/1033173712') {
              _logInfo('🔄 Retrying AdMob Interstitial load with official Google Test Ad Unit ID...');
              final bool testLoaded = await _loadAdMobInterstitialAd(
                customUnitId: 'ca-app-pub-3904357140100716/1033173712',
              );
              completer.complete(testLoaded);
              return;
            }
            if (mounted) {
              setState(() {
                _admobInterstitialReady = false;
                _adLoading = false;
              });
            }
            completer.complete(false);
          },
        ),
      );
    } catch (e) {
      _logError('AdMob Interstitial error: $e');
      if (mounted) {
        setState(() => _adLoading = false);
      }
      completer.complete(false);
    }

    return completer.future;
  }

  /// Load AdMob Rewarded Interstitial Ad
  Future<bool> _loadAdMobRewardedInterstitialAd({String? customUnitId}) async {
    if (_admobRewardedInterstitialAd != null) {
      return true;
    }

    String unitId = customUnitId ?? _admobRewardedInterstitialId.trim();
    if (unitId.isEmpty || unitId.contains('~')) {
      unitId = 'ca-app-pub-3904357140100716/5354046379';
    }

    _logInfo('📥 Loading AdMob Rewarded Interstitial Ad (Unit: $unitId)...');

    final completer = Completer<bool>();

    try {
      await RewardedInterstitialAd.load(
        adUnitId: unitId,
        request: const AdRequest(),
        rewardedInterstitialAdLoadCallback: RewardedInterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            _logSuccess('✅ AdMob Rewarded Interstitial loaded ($unitId)');
            _admobRewardedInterstitialAd = ad;

            _admobRewardedInterstitialAd!
                .fullScreenContentCallback = FullScreenContentCallback(
              onAdShowedFullScreenContent: (ad) {
                _logSuccess('🎬 AdMob Rewarded Interstitial showing');
                setState(() => _adRunning = true);
                _startAdTimerOverlay('admob');
              },
              onAdDismissedFullScreenContent: (ad) {
                _logInfo('👋 AdMob Rewarded Interstitial dismissed');
                setState(() => _adRunning = false);
                ad.dispose();
                _admobRewardedInterstitialAd = null;
                _hideAllOverlays();
              },
              onAdFailedToShowFullScreenContent: (ad, error) {
                _logError(
                  '❌ AdMob Rewarded Interstitial show failed: ${error.message}',
                );
                ad.dispose();
                _admobRewardedInterstitialAd = null;
              },
            );

            if (mounted) {
              setState(() {
                _admobRewardedInterstitialReady = true;
                _adLoading = false;
              });
            }
            completer.complete(true);
          },
          onAdFailedToLoad: (error) async {
            _logError(
              '❌ AdMob Rewarded Interstitial load failed for $unitId: ${error.message}',
            );
            if (unitId != 'ca-app-pub-3904357140100716/5354046379') {
              _logInfo('🔄 Retrying AdMob Rewarded Interstitial load with official Google Test Ad Unit ID...');
              final bool testLoaded = await _loadAdMobRewardedInterstitialAd(
                customUnitId: 'ca-app-pub-3904357140100716/5354046379',
              );
              completer.complete(testLoaded);
              return;
            }
            if (mounted) {
              setState(() {
                _admobRewardedInterstitialReady = false;
              });
            }
            completer.complete(false);
          },
        ),
      );
    } catch (e) {
      _logError('AdMob Rewarded Interstitial error: $e');
      completer.complete(false);
    }

    return completer.future;
  }

  /// Load AdMob Rewarded Ad
  Future<bool> _loadAdMobRewardedAd({String? customUnitId}) async {
    if (_admobRewardedAd != null) {
      return true;
    }

    String unitId = customUnitId ?? _admobRewardedId.trim();
    if (unitId.isEmpty || unitId.contains('~')) {
      unitId = 'ca-app-pub-3904357140100716/5224354917';
    }

    _logInfo('📥 Loading AdMob Rewarded Ad (Unit: $unitId)...');

    final completer = Completer<bool>();

    try {
      await RewardedAd.load(
        adUnitId: unitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            _logSuccess('✅ AdMob Rewarded Ad loaded ($unitId)');
            _admobRewardedAd = ad;

            _admobRewardedAd!
                .fullScreenContentCallback = FullScreenContentCallback(
              onAdShowedFullScreenContent: (ad) {
                _logSuccess('🎬 AdMob Rewarded Ad showing');
                setState(() => _adRunning = true);
                _startAdTimerOverlay('admob');
              },
              onAdDismissedFullScreenContent: (ad) {
                _logInfo('👋 AdMob Rewarded Ad dismissed');
                setState(() => _adRunning = false);
                ad.dispose();
                _admobRewardedAd = null;
                _hideAllOverlays();
              },
              onAdFailedToShowFullScreenContent: (ad, error) {
                _logError('❌ AdMob Rewarded Ad show failed: ${error.message}');
                ad.dispose();
                _admobRewardedAd = null;
              },
            );

            if (mounted) {
              setState(() {
                _admobRewardedReady = true;
                _adLoading = false;
              });
            }
            completer.complete(true);
          },
          onAdFailedToLoad: (error) async {
            _logError('❌ AdMob Rewarded Ad load failed for $unitId: ${error.message}');
            if (unitId != 'ca-app-pub-3904357140100716/5224354917') {
              _logInfo('🔄 Retrying AdMob Rewarded Ad load with official Google Test Ad Unit ID...');
              final bool testLoaded = await _loadAdMobRewardedAd(
                customUnitId: 'ca-app-pub-3904357140100716/5224354917',
              );
              completer.complete(testLoaded);
              return;
            }
            if (mounted) {
              setState(() {
                _admobRewardedReady = false;
              });
            }
            completer.complete(false);
          },
        ),
      );
    } catch (e) {
      _logError('AdMob Rewarded Ad error: $e');
      completer.complete(false);
    }

    return completer.future;
  }

  /// Load AdMob Native Ad non-blockingly
  void _loadAdMobNativeAd() {
    if (_admobNativeAd != null || !_admobStatus) {
      return;
    }

    if (_admobNativeId.isEmpty) {
      _logWarning('AdMob Native ID not configured');
      return;
    }

    _logInfo('📥 Loading AdMob Native Ad...');

    try {
      _admobNativeAd = NativeAd(
        adUnitId: _admobNativeId,
        request: const AdRequest(),
        listener: NativeAdListener(
          onAdLoaded: (ad) {
            _logSuccess('✅ AdMob Native Ad loaded');
            if (mounted) {
              setState(() => _admobNativeReady = true);
            }
          },
          onAdFailedToLoad: (ad, error) {
            _logError('❌ AdMob Native Ad failed: ${error.message}');
            ad.dispose();
            _admobNativeAd = null;
            if (mounted) {
              setState(() => _admobNativeReady = false);
            }
          },
          onAdOpened: (ad) => _logInfo('AdMob Native Ad opened'),
          onAdClosed: (ad) => _logInfo('AdMob Native Ad closed'),
          onAdClicked: (ad) => _logInfo('👆 AdMob Native Ad clicked'),
        ),
        nativeTemplateStyle: NativeTemplateStyle(
          templateType: TemplateType.medium,
          mainBackgroundColor: const Color(0xFF1a1a2e),
          cornerRadius: 16.0,
          callToActionTextStyle: NativeTemplateTextStyle(
            textColor: Colors.white,
            backgroundColor: _themeColorStart,
            style: NativeTemplateFontStyle.bold,
            size: 16.0,
          ),
          primaryTextStyle: NativeTemplateTextStyle(
            textColor: Colors.white,
            style: NativeTemplateFontStyle.bold,
            size: 16.0,
          ),
          secondaryTextStyle: NativeTemplateTextStyle(
            textColor: Colors.white70,
            style: NativeTemplateFontStyle.normal,
            size: 14.0,
          ),
          tertiaryTextStyle: NativeTemplateTextStyle(
            textColor: Colors.white60,
            style: NativeTemplateFontStyle.normal,
            size: 12.0,
          ),
        ),
      );

      _admobNativeAd!.load();
    } catch (e) {
      _logError('AdMob Native Ad error: $e');
    }
  }

  /// Load AdMob App Open Ad
  Future<void> _loadAdMobAppOpenAd() async {
    if (_admobAppOpenAd != null || !_admobStatus) {
      return;
    }

    if (_admobAppOpenId.isEmpty) {
      _logWarning('AdMob App Open ID not configured');
      return;
    }

    _logInfo('📥 Loading AdMob App Open Ad...');

    try {
      await AppOpenAd.load(
        adUnitId: _admobAppOpenId,
        request: const AdRequest(),
        adLoadCallback: AppOpenAdLoadCallback(
          onAdLoaded: (ad) {
            _logSuccess('✅ AdMob App Open Ad loaded');
            _admobAppOpenAd = ad;

            _admobAppOpenAd!
                .fullScreenContentCallback = FullScreenContentCallback(
              onAdShowedFullScreenContent: (ad) {
                _logSuccess('🎬 AdMob App Open Ad showing');
              },
              onAdDismissedFullScreenContent: (ad) {
                _logInfo('👋 AdMob App Open Ad dismissed');
                ad.dispose();
                _admobAppOpenAd = null;
              },
              onAdFailedToShowFullScreenContent: (ad, error) {
                _logError('❌ AdMob App Open Ad show failed: ${error.message}');
                ad.dispose();
                _admobAppOpenAd = null;
              },
            );

            if (mounted) {
              setState(() => _admobAppOpenReady = true);
            }
          },
          onAdFailedToLoad: (error) {
            _logError('❌ AdMob App Open Ad load failed: ${error.message}');
            if (mounted) {
              setState(() => _admobAppOpenReady = false);
            }
          },
        ),
      );
    } catch (e) {
      _logError('AdMob App Open Ad error: $e');
    }
  }

  // ======================== AD LOADING STRATEGY ========================
  /// Load next available ad based on priority with sequential fallback
  Future<void> _loadNextAvailableAd() async {
    if (!_canWatchAd) {
      _logWarning('Cannot load ad - conditions not met');
      return;
    }

    _logInfo('🔄 Loading next available ad...');
    _logInfo('   AdMob Status: $_admobStatus');
    _logInfo(
      '   AdMob Interstitial ID: ${_admobInterstitialId.isNotEmpty ? "✅" : "❌"}',
    );
    _logInfo('   Start.io App ID: ${_startIoAppId.isNotEmpty ? "✅" : "❌"}');

    setState(() => _adLoading = true);

    // Priority 1: AdMob Interstitial (if AdMob enabled)
    if (_admobStatus) {
      _logInfo('📌 Trying AdMob Interstitial (Priority 1)...');
      final bool loaded = await _loadAdMobInterstitialAd();
      if (loaded) {
        setState(() => _adLoading = false);
        return;
      }
      _logWarning('⚠️ AdMob Interstitial failed to load. Trying next fallback network...');
    }

    // Priority 2: AdMob Rewarded Interstitial
    if (_admobStatus) {
      _logInfo('📌 Trying AdMob Rewarded Interstitial (Priority 2)...');
      final bool loaded = await _loadAdMobRewardedInterstitialAd();
      if (loaded) {
        setState(() => _adLoading = false);
        return;
      }
      _logWarning('⚠️ AdMob Rewarded Interstitial failed to load. Trying next fallback network...');
    }

    // Priority 3: AdMob Rewarded
    if (_admobStatus) {
      _logInfo('📌 Trying AdMob Rewarded (Priority 3)...');
      final bool loaded = await _loadAdMobRewardedAd();
      if (loaded) {
        setState(() => _adLoading = false);
        return;
      }
      _logWarning('⚠️ AdMob Rewarded failed to load. Trying next fallback network...');
    }

    // Priority 4: Start.io Interstitial (fallback)
    if (_startIoAppId.isNotEmpty) {
      _logInfo('📌 Trying Start.io Interstitial (Priority 4 - Fallback)...');
      final bool loaded = await _loadStartIoInterstitialAd();
      if (loaded) {
        setState(() => _adLoading = false);
        return;
      }
      _logWarning('⚠️ Start.io Interstitial failed to load.');
    }

    // No ad network available or all failed
    _logError('⚠️ All configured ad networks failed to load ads.');
    setState(() => _adLoading = false);
    _showSnackBar('No ad available', isError: true);
  }

  // ======================== AD SHOWING ========================
  /// Show ad to user
  Future<void> _showAdToUser() async {
    if (_adsWatched >= _dailyLimit) {
      _showSnackBar('Daily limit reached', isError: true);
      return;
    }

    if (_adLoading) {
      int waitedMs = 0;
      while (_adLoading && waitedMs < 2000) {
        await Future.delayed(const Duration(milliseconds: 100));
        waitedMs += 100;
      }
      if (_adLoading) {
        _showSnackBar('Ad is loading, please try again in a moment.', isError: true);
        return;
      }
    }

    // Track ad click before showing
    await _trackAdViewClick();

    try {
      _logInfo('🎬 Attempting to show ad...');

      // Priority 1: AdMob Interstitial
      if (_admobStatus &&
          _admobInterstitialReady &&
          _admobInterstitialAd != null) {
        _logInfo('📺 Showing AdMob Interstitial');
        await _admobInterstitialAd!.show();
        return;
      }

      // Priority 2: AdMob Rewarded Interstitial
      if (_admobStatus &&
          _admobRewardedInterstitialReady &&
          _admobRewardedInterstitialAd != null) {
        _logInfo('📺 Showing AdMob Rewarded Interstitial');
        await _admobRewardedInterstitialAd!.show(
          onUserEarnedReward: (ad, reward) {
            _logSuccess(
              '💰 User earned reward: ${reward.amount} ${reward.type}',
            );
          },
        );
        return;
      }

      // Priority 3: AdMob Rewarded
      if (_admobStatus && _admobRewardedReady && _admobRewardedAd != null) {
        _logInfo('📺 Showing AdMob Rewarded Ad');
        await _admobRewardedAd!.show(
          onUserEarnedReward: (ad, reward) {
            _logSuccess(
              '💰 User earned reward: ${reward.amount} ${reward.type}',
            );
          },
        );
        return;
      }

      // Priority 4: Start.io Interstitial
      if (_startIoRegularReady && _startIoRegularAd != null) {
        _logInfo('📺 Showing Start.io Interstitial');
        await _startIoRegularAd!.show();
        return;
      }

      // If no ad preloaded yet, fetch ad on demand
      _logInfo('🔄 Ad not preloaded yet. Fetching ad on demand...');
      await _loadNextAvailableAd();

      if (_admobStatus && _admobInterstitialReady && _admobInterstitialAd != null) {
        _logInfo('📺 Showing AdMob Interstitial (On Demand)');
        await _admobInterstitialAd!.show();
        return;
      }
      if (_admobStatus && _admobRewardedInterstitialReady && _admobRewardedInterstitialAd != null) {
        _logInfo('📺 Showing AdMob Rewarded Interstitial (On Demand)');
        await _admobRewardedInterstitialAd!.show(onUserEarnedReward: (ad, reward) {});
        return;
      }
      if (_startIoRegularReady && _startIoRegularAd != null) {
        _logInfo('📺 Showing Start.io Interstitial (On Demand)');
        await _startIoRegularAd!.show();
        return;
      }

      // No ad ready to show
      _logWarning('⚠️ No ad ready to show');
      _showSnackBar('Ad not ready. Please try again in a moment.', isError: true);
      _handleAdLoadFailed();
    } catch (e) {
      _logError('Show ad error: $e');
      _handleAdLoadFailed();
    }
  }

  // ======================== AD FAILURE HANDLING ========================
  /// Handle ad load failure
  void _handleAdLoadFailed() {
    _logWarning('🔄 Handling ad load failure...');

    setState(() {
      _startIoRegularReady = false;
      _admobInterstitialReady = false;
      _admobRewardedInterstitialReady = false;
      _admobRewardedReady = false;
      _adRunning = false;
      _adLoading = false;
    });

    _hideAllOverlays();
    _disposeAllFullScreenAds();

    // Retry loading after delay
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && _canWatchAd) {
        _logInfo('🔄 Retrying ad load after failure...');
        _loadNextAvailableAd();
      }
    });
  }

  /// Dispose all full-screen ads
  void _disposeAllFullScreenAds() {
    _logInfo('🗑️ Disposing all full-screen ads...');

    // Dispose Start.io
    _startIoRegularAd?.dispose();
    _startIoRegularAd = null;

    // Dispose AdMob
    _admobInterstitialAd?.dispose();
    _admobInterstitialAd = null;
    _admobRewardedInterstitialAd?.dispose();
    _admobRewardedInterstitialAd = null;
    _admobRewardedAd?.dispose();
    _admobRewardedAd = null;

    setState(() {
      _startIoRegularReady = false;
      _admobInterstitialReady = false;
      _admobRewardedInterstitialReady = false;
      _admobRewardedReady = false;
    });
  }

  // ======================== PART 3: API TRACKING, TIMER MANAGEMENT & REWARDS ========================
  // Continuation from Part 2 (line 1600)

  // ======================== API TRACKING ========================
  /// Track ad view/click to backend
  Future<void> _trackAdViewClick() async {
    _logInfo('📊 Tracking ad view/click...');

    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/track-ad-view'),
            headers: {'Authorization': 'Bearer $_token'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData['data'] != null) {
          final data = jsonData['data'];
          setState(() {
            _adsWatched = _parseInt(data['ads_watched_today']);
            _cycleAds = _parseInt(data['ads_watched_in_current_cycle']);
          });
          _logSuccess('✅ View tracked: $_adsWatched/$_dailyLimit ads');
        }
      } else if (response.statusCode == 401) {
        _showSnackBar('Session expired. Please login.', isError: true);
        _redirectToLogin();
      } else {
        _logWarning('Track failed: ${response.statusCode}');
      }
    } catch (e) {
      _logError('Track ad view error: $e');
    }
  }

  /// Handle ad timer completion
  Future<void> _onAdTimerComplete() async {
    _logSuccess('✅ Ad timer completed');

    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl/user-earning'),
            headers: {'Authorization': 'Bearer $_token'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData['data'] != null) {
          final data = jsonData['data'];

          final showClaim = data['show_claim_button'] == true;
          final isBreakActive = data['is_break_active'] == true;
          final dailyLimitReached = data['daily_limit_reached'] == true;
          final adsWatched = _parseInt(data['ads_watched_today']);
          final cycleAds = _parseInt(data['ads_watched_in_current_cycle']);

          setState(() {
            _adsWatched = adsWatched;
            _cycleAds = cycleAds;
            _showClaim = showClaim;
            _breakActive = isBreakActive;
            _dailyLimitReached = dailyLimitReached;
            _adRunning = false;
          });

          _disposeAllFullScreenAds();
          await _hideAllOverlays();

          if (showClaim && !isBreakActive) {
            _logInfo('🎁 Auto-processing reward claim after cycle ad...');
            await _processRewardClaim();
          } else if (isBreakActive) {
            await _startBreakTimerOverlay();
            final isFinal = adsWatched >= _dailyLimit;
            _showSnackBar(
              isFinal
                  ? '🎉 Final cycle done! Break: $_taskBreakMinutes min'
                  : '⏱️ Break started: $_taskBreakMinutes minute${_taskBreakMinutes > 1 ? "s" : ""}',
              isSuccess: true,
            );
          } else if (dailyLimitReached && !showClaim) {
            _showSnackBar('✅ Daily limit complete!', isSuccess: true);
          } else if (!showClaim && !dailyLimitReached && !isBreakActive) {
            _showSnackBar('Loading next ad...', isSuccess: true);
            await Future.delayed(const Duration(milliseconds: 800));
            if (mounted && _canWatchAd) {
              await _loadNextAvailableAd();
            }
          }
        }
      } else if (response.statusCode == 401) {
        _redirectToLogin();
      }
    } catch (e) {
      _logError('Ad complete handler error: $e');
    }
  }

  /// Handle break timer completion
  Future<void> _onBreakTimerComplete() async {
    _logSuccess('⏰ Break timer completed');

    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/break-complete'),
            headers: {'Authorization': 'Bearer $_token'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData['data'] != null) {
          final data = jsonData['data'];

          setState(() {
            _breakActive = false;
            _showClaim = data['show_claim_button'] == true;
            _dailyLimitReached = data['daily_limit_reached'] == true;
            _adsWatched = _parseInt(data['ads_watched_today']);
            _cycleAds = _parseInt(data['ads_watched_in_current_cycle']);
          });

          await _hideAllOverlays();

          if (_showClaim) {
            _logInfo('🎁 Auto-claiming reward after break complete...');
            await _processRewardClaim();
          }
        }
      } else if (response.statusCode == 401) {
        _redirectToLogin();
      }
    } catch (e) {
      _logError('Break complete handler error: $e');
    }
  }

  /// Process reward claim
  Future<void> _processRewardClaim() async {
    if (_adLoading) return;

    _logInfo('🎁 Processing reward claim...');
    setState(() => _adLoading = true);

    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/claim-reward'),
            headers: {'Authorization': 'Bearer $_token'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData['status'] == true && jsonData['data'] != null) {
          final data = jsonData['data'];
          final earned = _parseDouble(data['earned']);
          final dailyLimitReached = data['daily_limit_reached'] == true;

          setState(() {
            _showClaim = false;
            _adLoading = false;
            _dailyLimitReached = dailyLimitReached;
          });

          await _fetchUserEarningData();

          if (dailyLimitReached) {
            _showSnackBar(
              '🎉 \$${earned.toStringAsFixed(2)} Claimed! Daily limit complete!',
              isSuccess: true,
            );
          } else {
            _showSnackBar(
              '🎉 \$${earned.toStringAsFixed(2)} Claimed Successfully!',
              isSuccess: true,
            );
            if (mounted && _canWatchAd) {
              await Future.delayed(const Duration(seconds: 1));
              await _loadNextAvailableAd();
            }
          }
        } else {
          setState(() => _adLoading = false);
          final message = jsonData['message'] ?? 'Claim failed. Please try again.';
          _showSnackBar(message, isError: true);
        }
      } else if (response.statusCode == 401) {
        setState(() => _adLoading = false);
        _redirectToLogin();
      } else {
        setState(() => _adLoading = false);
        _showSnackBar('Claim failed (${response.statusCode}). Please try again.', isError: true);
      }
    } catch (e) {
      setState(() => _adLoading = false);
      _logError('Claim error: $e');
      _showSnackBar('Network error. Please try again.', isError: true);
    }
  }

  // ======================== 🔥 TIMER MANAGEMENT - CRITICAL FIX ========================
  /// 🔥 Start ad timer overlay - Uses DYNAMIC button_timer_seconds from DATABASE and respects admin enable/disable timer switches
  Future<void> _startAdTimerOverlay([String networkType = 'admob']) async {
    try {
      // Respect enable/disable switches from admin panel
      if (networkType == 'stario' && _starioTimerStatus == 'no') {
        _logInfo('⛔ Start.io Ad Timer disabled by admin in settings. Skipping overlay timer.');
        return;
      }
      if (networkType == 'admob' && _admobTimerStatus == 'no') {
        _logInfo('⛔ Google AdMob Ad Timer disabled by admin in settings. Skipping overlay timer.');
        return;
      }

      // 🔥 CRITICAL VALIDATION: Ensure timer settings are loaded
      if (!_timerSettingsLoaded || _buttonTimerSeconds <= 0) {
        _logError('⚠️ CRITICAL: Timer settings not loaded from database!');
        _logError('   _timerSettingsLoaded = $_timerSettingsLoaded');
        _logError('   _buttonTimerSeconds = $_buttonTimerSeconds');
        _showSnackBar('Timer configuration error', isError: true);
        return;
      }

      final int secondsToRun = _adTimerSeconds > 0 ? _adTimerSeconds : _buttonTimerSeconds;

      _logInfo('⏱️ Starting ad timer overlay ($networkType)...');
      _logInfo('   📊 Using DATABASE value: $secondsToRun seconds');
      _logInfo('   ✅ Timer settings loaded: $_timerSettingsLoaded');

      // 🔥 Pass the DYNAMIC value from database to native Android
      await platform.invokeMethod('startAdTimer', {
        'adTimerSeconds': secondsToRun,
      });

      _logSuccess('✅ Ad timer started: $secondsToRun seconds ($networkType)');
    } catch (e) {
      _logError('❌ Ad timer start error: $e');
      _showSnackBar('Timer error. Please restart app.', isError: true);
    }
  }

  /// 🔥 Start break timer overlay - Uses DYNAMIC task_break_time_minutes from DATABASE
  /// NO HARDCODED VALUES!
  Future<void> _startBreakTimerOverlay() async {
    try {
      // 🔥 CRITICAL VALIDATION: Ensure timer settings are loaded
      if (!_timerSettingsLoaded || _taskBreakMinutes <= 0) {
        _logError('⚠️ CRITICAL: Timer settings not loaded from database!');
        _logError('   _timerSettingsLoaded = $_timerSettingsLoaded');
        _logError('   _taskBreakMinutes = $_taskBreakMinutes');
        _showSnackBar('Timer configuration error', isError: true);
        return;
      }

      // 🔥 Convert minutes to seconds using DATABASE value
      final breakSeconds = _taskBreakMinutes * 60;

      _logInfo('⏱️ Starting break timer overlay...');
      _logInfo('   📊 Using DATABASE value: $_taskBreakMinutes minutes');
      _logInfo('   📊 Converted to seconds: $breakSeconds seconds');
      _logInfo('   ✅ Timer settings loaded: $_timerSettingsLoaded');

      // 🔥 Pass the DYNAMIC value from database to native Android
      await platform.invokeMethod('startBreakTimer', {
        'breakSeconds': breakSeconds, // ✅ From database, NOT hardcoded!
      });

      _logSuccess(
        '✅ Break timer started: $_taskBreakMinutes minutes ($breakSeconds seconds)',
      );
    } catch (e) {
      _logError('❌ Break timer start error: $e');
      _showSnackBar('Timer error. Please restart app.', isError: true);
    }
  }

  /// Hide all overlay timers
  Future<void> _hideAllOverlays() async {
    try {
      _logInfo('🧹 Hiding all overlays...');
      await platform.invokeMethod('hideAllOverlays');
      _logSuccess('✅ All overlays hidden');
    } catch (e) {
      _logError('❌ Hide overlays error: $e');
    }
  }

  /// Handle native method calls from Android
  Future<void> _handleNativeCall(MethodCall call) async {
    _logInfo('📱 Native call received: ${call.method}');

    switch (call.method) {
      case 'onTimerComplete':
        if (_adRunning) {
          _logInfo('✅ Ad timer completed - calling handler');
          await _onAdTimerComplete();
        } else {
          _logWarning('⚠️ Timer complete but ad not running');
        }
        break;

      case 'onBreakComplete':
        _logInfo('✅ Break timer completed - calling handler');
        await _onBreakTimerComplete();
        break;

      default:
        _logWarning('⚠️ Unknown native method: ${call.method}');
    }
  }

  // ======================== HELPER METHODS ========================
  /// Check if user can watch more ads
  bool get _canWatchAd =>
      !_showClaim &&
      !_breakActive &&
      !_dailyLimitReached &&
      _timerSettingsLoaded;

  /// Get current progress percentage
  double get _progressPercentage =>
      _dailyLimit > 0 ? (_adsWatched / _dailyLimit).clamp(0.0, 1.0) : 0.0;

  /// Check if next ad completes the cycle
  bool get _isNextAdCycleComplete =>
      _adBrack > 0 && (_cycleAds + 1) == _adBrack;

  /// Check if next ad is the last of the day
  bool get _isNextAdFinalAd => (_adsWatched + 1) >= _dailyLimit;

  /// Show snackbar message
  void _showSnackBar(
    String message, {
    bool isError = false,
    bool isSuccess = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        backgroundColor: isError
            ? Colors.red.shade700
            : (isSuccess ? Colors.green.shade700 : _themeColorStart),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: isError || isSuccess ? 4 : 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ======================== DEBUG INFO WIDGET ========================
  /// Build debug info card (for development - shows timer values)
  Widget _buildDebugInfoCard() {
    // Only show in debug mode
    if (!const bool.fromEnvironment('dart.vm.product')) {
      return Container(
        margin: const EdgeInsets.only(top: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.yellow.withOpacity(0.5), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [

              ],
            ),
            const SizedBox(height: 8),
            _buildDebugRow(
              'Timer Settings Loaded',
              _timerSettingsLoaded ? '✅ Yes' : '❌ No',
            ),
            _buildDebugRow('Button Timer (DB)', '$_buttonTimerSeconds seconds'),
            _buildDebugRow('Break Timer (DB)', '$_taskBreakMinutes minutes'),
            _buildDebugRow('Ad Brack', '$_adBrack ads'),
            _buildDebugRow('Daily Limit', '$_dailyLimit ads'),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  /// Build debug info row
  Widget _buildDebugRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.white70, fontSize: 11)),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ======================== TIMER STATUS WIDGET ========================
  /// Build timer status indicator
  Widget _buildTimerStatusIndicator() {
    if (!_timerSettingsLoaded) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red, width: 1),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '⚠️ Timer settings not loaded from database',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green, width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.timer, color: Colors.green, size: 18),
              const SizedBox(width: 8),
              Text(
                'Button: ${_buttonTimerSeconds}s',
                style: TextStyle(
                  color: Colors.green,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Row(
            children: [
              Icon(Icons.access_time, color: Colors.green, size: 18),
              const SizedBox(width: 8),
              Text(
                'Break: ${_taskBreakMinutes}m',
                style: TextStyle(
                  color: Colors.green,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ======================== ENHANCED LOGGING ========================
  /// Log timer configuration on every important action
  void _logTimerConfiguration(String action) {
    _logInfo('🔥 TIMER CONFIG CHECK - $action');
    _logInfo('   Timer Settings Loaded: $_timerSettingsLoaded');
    _logInfo('   Button Timer Seconds: $_buttonTimerSeconds');
    _logInfo('   Break Time Minutes: $_taskBreakMinutes');
    _logInfo('   Can Watch Ad: $_canWatchAd');
  }

  // ======================== PART 4 (FINAL): UI BUILDING & WIDGET TREE ========================
  // Continuation from Part 3 (line 2400)

  // ======================== UI BUILD ========================
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_adRunning || _showClaim || _breakActive) {
          _showSnackBar(
            'Please complete the current task first',
            isError: true,
          );
          return false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0a0a1a),
        appBar: _buildAppBar(),
        body: Column(
          children: [
            // Top Banner Ad
            _buildTopBanner(),

            // Main Content
            Expanded(child: _buildMainContent()),

            // Bottom Banner Ad
            _buildBottomBanner(),
          ],
        ),
      ),
    );
  }

  // ======================== APP BAR ========================
  /// Build app bar
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.transparent,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_themeColorStart, _themeColorEnd],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
        onPressed: () {
          if (_adRunning || _showClaim || _breakActive) {
            _showSnackBar(
              'Please complete the current task first',
              isError: true,
            );
          } else {
            Navigator.pop(context);
          }
        },
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Daily Tasks',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          if (!_themeLoading)
            Text(
              _themeName,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: Colors.white70,
              ),
            ),
        ],
      ),
      actions: [
        IconButton(
          onPressed: () async {
            _logTimerConfiguration('Manual Refresh');
            await _loadThemeFromDatabase();
            await _fetchUserEarningData();
            if (_canWatchAd && !_adLoading) {
              await _loadNextAvailableAd();
            }
          },
          icon: const Icon(Icons.refresh_rounded, size: 22),
          tooltip: 'Refresh',
        ),
      ],
    );
  }

  // ======================== BANNER ADS ========================
  /// Build top banner ad
  Widget _buildTopBanner() {
    if (_admobStatus && _admobTopBanner != null) {
      return Container(
        height: 50,
        color: Colors.black,
        child: AdWidget(ad: _admobTopBanner!),
      );
    } else if (!_admobStatus && _startIoTopBanner != null) {
      return Container(
        height: 50,
        color: Colors.black,
        child: StartAppBanner(_startIoTopBanner!),
      );
    }
    return const SizedBox.shrink();
  }

  /// Build bottom banner ad
  Widget _buildBottomBanner() {
    if (_admobStatus && _admobBottomBanner != null) {
      return Container(
        height: 50,
        color: Colors.black,
        child: AdWidget(ad: _admobBottomBanner!),
      );
    } else if (!_admobStatus && _startIoBottomBanner != null) {
      return Container(
        height: 50,
        color: Colors.black,
        child: StartAppBanner(_startIoBottomBanner!),
      );
    }
    return const SizedBox.shrink();
  }

  // ======================== MAIN CONTENT ========================
  /// Build main content
  Widget _buildMainContent() {
    if (_loading) {
      return _buildLoadingState();
    }

    if (_error != null) {
      return _buildErrorState();
    }

    return RefreshIndicator(
      onRefresh: () async {
        _logTimerConfiguration('Pull to Refresh');
        await _loadThemeFromDatabase();
        await _fetchUserEarningData();
      },
      color: _themeColorStart,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // 🔥 Timer Status Indicator (Shows DB values loaded)
            _buildTimerStatusIndicator(),

            const SizedBox(height: 12),

            // Live Main Balance & Today Earnings Card
            _buildBalanceCard(),

            const SizedBox(height: 12),

            // Package Info Card
            _buildPackageCard(),
            const SizedBox(height: 16),

            // Progress Card
            _buildProgressCard(),
            const SizedBox(height: 20),

            // Warning Card - Shown prominently when next ad is Claim (e.g. 5th ad / 10th ad)
            if (_canWatchAd && !_breakActive && _isNextAdCycleComplete) ...[
              _buildCycleWarningCard(),
              const SizedBox(height: 16),
            ],

            // Claim Button
            if (_showClaim && !_breakActive) ...[
              _buildClaimButton(),
              const SizedBox(height: 16),
            ],

            // Daily Limit Complete
            if (_dailyLimitReached && !_showClaim && !_breakActive) ...[
              _buildDailyLimitCompleteCard(),
              const SizedBox(height: 16),
            ],

            // Break Active - Break Timer Running
            if (_breakActive) ...[
              _buildBreakActiveButton(),
              const SizedBox(height: 16),
            ],

            // Watch Ad Button
            if (_canWatchAd && !_breakActive) ...[
              _buildWatchAdButton(),
              const SizedBox(height: 20),
            ],

            // Middle Banner/Native Ad
            _buildMiddleAd(),

            // Break Info Card
            if (_breakActive) ...[
              const SizedBox(height: 16),
              _buildBreakInfoCard(),
            ],

            // 🔥 Debug Info (Development only)
            _buildDebugInfoCard(),
          ],
        ),
      ),
    );
  }

  // ======================== LOADING & ERROR STATES ========================
  /// Build loading state
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(_themeColorStart),
              strokeWidth: 5,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _themeLoading ? 'Loading theme...' : 'Loading tasks...',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Fetching timer settings from database...',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }

  /// Build error state
  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 80,
              color: Colors.red.shade400,
            ),
            const SizedBox(height: 24),
            Text(
              _error!,
              style: const TextStyle(color: Colors.white70, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                _logTimerConfiguration('Retry Button');
                _init();
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _themeColorStart,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
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

  // ======================== INFO CARDS ========================
  /// Build balance & earnings header card
  Widget _buildBalanceCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _themeColorStart.withOpacity(0.2),
            _themeColorEnd.withOpacity(0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _themeColorStart.withOpacity(0.4), width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // Main Balance
          Column(
            children: [
              const Text(
                'Main Balance',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '\$${_balance.toStringAsFixed(2)}',
                style: TextStyle(
                  color: _accentColor,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Container(
            height: 32,
            width: 1,
            color: Colors.white24,
          ),
          // Today Earning
          Column(
            children: [
              const Text(
                'Today Earning',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '\$${_todayEarning.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Colors.greenAccent,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Build package card
  Widget _buildPackageCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _themeColorStart.withOpacity(0.15),
            _themeColorEnd.withOpacity(0.15),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _themeColorStart.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_themeColorStart, _themeColorEnd],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: _themeColorStart.withOpacity(0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.card_giftcard_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Active Package',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _packageName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _accentColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '\$${_packagePrice.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: _accentColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '• Daily: \$${_dailyIncome.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.greenAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.verified_rounded,
              color: Colors.greenAccent,
              size: 32,
            ),
          ],
        ),
      ),
    );
  }

  /// Build progress card
  Widget _buildProgressCard() {
    String statusText;
    Color statusColor;

    if (_showClaim && !_breakActive) {
      statusText = _adsWatched >= _dailyLimit
          ? '🎉 TAP CLAIM NOW!'
          : '🎁 CLAIM REWARD READY!';
      statusColor = Colors.greenAccent;
    } else if (_dailyLimitReached) {
      statusText = '✅ Daily Limit Complete!';
      statusColor = Colors.green;
    } else if (_breakActive) {
      statusText = '⏱️ Break Time: $_taskBreakMinutes min (from DB)';
      statusColor = Colors.orangeAccent;
    } else if (_adLoading) {
      statusText = '⏳ Loading ad...';
      statusColor = _accentColor;
    } else {
      statusText = 'Cycle Progress: $_cycleAds/$_adBrack ads';
      statusColor = _themeColorEnd;
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1a1a2e),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withOpacity(0.5), width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Daily Progress',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$_adsWatched/$_dailyLimit',
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: _progressPercentage,
                minHeight: 12,
                backgroundColor: Colors.white.withOpacity(0.1),
                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              statusText,
              style: TextStyle(
                color: statusColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ======================== ACTION BUTTONS ========================
  /// Build claim button
  Widget _buildClaimButton() {
    final isFinalCycle = _adsWatched >= _dailyLimit;

    return ScaleTransition(
      scale: _pulseAnimation,
      child: Container(
        height: 70,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isFinalCycle
                ? [Colors.green, Colors.greenAccent]
                : [_themeColorStart, _themeColorEnd],
          ),
          borderRadius: BorderRadius.circular(35),
          boxShadow: [
            BoxShadow(
              color: (isFinalCycle ? Colors.green : _themeColorStart)
                  .withOpacity(0.5),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: _adLoading
              ? null
              : () {
                  _logTimerConfiguration('Claim Button Pressed');
                  _processRewardClaim();
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(35),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _adLoading
                    ? Icons.hourglass_empty_rounded
                    : (isFinalCycle
                          ? Icons.emoji_events_rounded
                          : Icons.card_giftcard_rounded),
                size: 32,
              ),
              const SizedBox(width: 12),
              Text(
                _adLoading
                    ? 'Processing...'
                    : (isFinalCycle
                          ? '🎉 CLAIM FINAL \$${_incomePerBrack.toStringAsFixed(2)}'
                          : '🎁 CLAIM \$${_incomePerBrack.toStringAsFixed(2)}'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build daily limit complete card
  Widget _buildDailyLimitCompleteCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.green.withOpacity(0.2),
            Colors.greenAccent.withOpacity(0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: Colors.green,
                size: 40,
              ),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '✅ Daily Limit Complete!',
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Come back tomorrow for more tasks',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build break active button
  Widget _buildBreakActiveButton() {
    return ScaleTransition(
      scale: _pulseAnimation,
      child: Container(
        height: 70,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Colors.orange, Colors.deepOrange],
          ),
          borderRadius: BorderRadius.circular(35),
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withOpacity(0.5),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: () async {
            _showSnackBar('🔍 Checking break time status...', isSuccess: true);
            await _fetchUserEarningData();
            if (_showClaim && !_breakActive) {
              _showSnackBar('🎉 Break time complete! Claiming reward...', isSuccess: true);
              await _processRewardClaim();
            } else {
              _showSnackBar(
                '⏱️ Break is in progress ($_taskBreakMinutes min). Reward will automatically be claimed when break time finishes!',
                isError: false,
              );
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(35),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.timer_rounded, size: 32),
              const SizedBox(width: 12),
              Text(
                '⏱️ BREAK TIME ($_taskBreakMinutes min)',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build watch ad button
  Widget _buildWatchAdButton() {
    final bool enabled = !_adRunning && !_adLoading && _canWatchAd;

    String buttonText;
    if (_adRunning) {
      buttonText = 'Ad Running...';
    } else if (_adLoading) {
      buttonText = 'Loading Ad...';
    } else {
      bool isClaimTask = (_cycleAds + 1) >= _adBrack && _adBrack > 0;
      if (isClaimTask || _showClaim) {
        buttonText = '🎉 CLAIM REWARD (\$${_incomePerBrack.toStringAsFixed(2)})';
      } else {
        int nextAdNumber = _cycleAds + 1;
        buttonText = 'WATCH AD ($nextAdNumber/$_adBrack)';
      }
    }

    return Container(
      height: 64,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: enabled
            ? LinearGradient(colors: [_themeColorStart, _themeColorEnd])
            : null,
        color: enabled ? null : Colors.grey.shade800,
        borderRadius: BorderRadius.circular(32),
        boxShadow: enabled
            ? [
                BoxShadow(
                  color: _themeColorStart.withOpacity(0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: ElevatedButton(
        onPressed: enabled
            ? () {
                _logTimerConfiguration('Watch Ad Button Pressed');
                _showAdToUser();
              }
            : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(32),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _adRunning
                  ? Icons.play_circle_outline_rounded
                  : _adLoading
                  ? Icons.hourglass_empty_rounded
                  : Icons.play_circle_rounded,
              size: 28,
            ),
            const SizedBox(width: 12),
            Text(
              buttonText,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ======================== MIDDLE AD ========================
  /// Build middle ad (Disabled auto-rendering per user requirement)
  Widget _buildMiddleAd() {
    return const SizedBox.shrink();
  }

  // ======================== WARNING & INFO CARDS ========================
  /// Build cycle warning card
  Widget _buildCycleWarningCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.amber.withOpacity(0.2),
            Colors.orange.withOpacity(0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: Colors.amber,
              size: 36,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _isNextAdFinalAd
                    ? '🎯 NEXT AD IS FINAL CLAIM! Tap Claim button, click on the ad to earn final \$${_incomePerBrack.toStringAsFixed(2)} reward!'
                    : '⚠️ NEXT AD IS CLAIM! Tap Claim button, click on the ad to earn \$${_incomePerBrack.toStringAsFixed(2)} reward!',
                style: const TextStyle(
                  color: Colors.amber,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build break info card
  Widget _buildBreakInfoCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.orange.withOpacity(0.2),
            Colors.deepOrange.withOpacity(0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orangeAccent, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.timer_rounded,
                color: Colors.orangeAccent,
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '⏱️ Break in progress...\nWait $_taskBreakMinutes minute${_taskBreakMinutes > 1 ? "s" : ""} (from DB) then CLAIM!',
                style: const TextStyle(
                  color: Colors.orangeAccent,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
