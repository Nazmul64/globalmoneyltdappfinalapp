import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:startapp_sdk/startapp.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'config/api_config.dart';

class VideoTaskPage extends StatefulWidget {
  final int breakTimeMinutes;
  final int viewBeforeClickTarget;
  final int adTimerSeconds;
  final int adBrack;
  final int currentAdsWatched;
  final int adsRemainingForReward;
  final String startIoId;

  const VideoTaskPage({
    Key? key,
    required this.breakTimeMinutes,
    required this.viewBeforeClickTarget,
    required this.adTimerSeconds,
    required this.adBrack,
    required this.currentAdsWatched,
    required this.adsRemainingForReward,
    required this.startIoId,
  }) : super(key: key);

  @override
  State<VideoTaskPage> createState() => _VideoTaskPageState();
}

class _VideoTaskPageState extends State<VideoTaskPage>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  // =========================== CONSTANTS ===========================
  static const platform = MethodChannel('ad_timer_overlay');
  static const String _baseUrl = ApiConfig.baseUrl;

  // =========================== STATE ===========================
  late final int _requiredAds;
  int _adsCompleted = 0;
  int _currentAdViews = 0;
  bool _canClick = false;
  bool _isAdActive = false;
  bool _isAdLoading = false;
  bool _adsReady = false;
  bool _willGetReward = false;
  bool _isDisposing = false; // ✅ NEW: Track disposal state

  String? _authToken;
  final StartAppSdk _sdk = StartAppSdk();

  StartAppBannerAd? _topBanner;
  StartAppBannerAd? _bottomBanner;
  StartAppInterstitialAd? _interstitial;

  // =========================== ANIMATIONS ===========================
  late final AnimationController _progressController;
  late final Animation<double> _progressAnimation;

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  // =========================== LIFECYCLE ===========================
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _requiredAds = widget.viewBeforeClickTarget;

    _setupAnimations();
    _setupNativeListener();
    _initializeTask();
  }

  void _setupAnimations() {
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _progressAnimation = CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeOutCubic,
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.94, end: 1.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  void _setupNativeListener() {
    platform.setMethodCallHandler((call) async {
      // ✅ Ignore if disposing
      if (_isDisposing || !mounted) return null;

      switch (call.method) {
        case 'onTimerComplete':
          await _handleAdTimerComplete();
          break;
        case 'onBreakComplete':
          await _handleBreakComplete();
          break;
        case 'onAdClicked':
          await _handleNativeAdClick();
          break;
      }
      return null;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isDisposing || !mounted) return;

    if (state == AppLifecycleState.resumed) {
      // ✅ Only reload if not in ad and not disposing
      if (!_isAdLoading && _interstitial == null && !_isAdActive) {
        _loadInterstitial();
      }
    } else if (state == AppLifecycleState.paused) {
      // ✅ Hide overlays when app goes to background
      if (_isAdActive) {
        _hideAllOverlays();
      }
    }
  }

  @override
  void dispose() {
    _isDisposing = true; // ✅ Mark as disposing
    WidgetsBinding.instance.removeObserver(this);

    // ✅ Clean up animations safely
    if (_progressController.isAnimating) _progressController.stop();
    if (_pulseController.isAnimating) _pulseController.stop();

    _progressController.dispose();
    _pulseController.dispose();

    // ✅ Clean up overlays and ads
    _hideAllOverlays();
    _topBanner?.dispose();
    _bottomBanner?.dispose();
    _interstitial?.dispose();

    super.dispose();
  }

  // =========================== INITIALIZATION ===========================
  Future<void> _initializeTask() async {
    await _loadAuthToken();
    if (widget.startIoId.isEmpty) {
      _showSnackBar('Start.io ID not configured', error: true);
      return;
    }

    await _sdk.setTestAdsEnabled(false); // Set true for testing
    await Future.wait([_loadBanners(), _loadInterstitial()]);
  }

  Future<void> _loadAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    _authToken = prefs.getString('auth_token');
  }

  Future<void> _loadBanners() async {
    if (_isDisposing || !mounted) return;

    try {
      _sdk.loadBannerAd(StartAppBannerType.BANNER).then((ad) {
        if (mounted && !_isDisposing) setState(() => _topBanner = ad);
      }).catchError((e) {
        debugPrint('Top banner load error: $e');
      });
      _sdk.loadBannerAd(StartAppBannerType.BANNER).then((ad) {
        if (mounted && !_isDisposing) setState(() => _bottomBanner = ad);
      }).catchError((e) {
        debugPrint('Bottom banner load error: $e');
      });
    } catch (e) {
      debugPrint('Banner load error: $e');
    }
  }

  // =========================== AD LOADING & SHOW ===========================
  Future<void> _loadInterstitial() async {
    if (_isDisposing || !mounted || _isAdLoading || _interstitial != null)
      return;

    setState(() {
      _isAdLoading = true;
      _adsReady = false;
    });

    try {
      _interstitial = await _sdk.loadInterstitialAd(
        onAdNotDisplayed: () {
          if (!_isDisposing && mounted) {
            _handleAdFailure('Ad not ready');
          }
        },
        onAdDisplayed: () {
          if (!_isDisposing && mounted) {
            setState(() => _isAdActive = true);
            _startAdTimerOverlay();
          }
        },
        onAdHidden: () {
          if (!_isDisposing && mounted) {
            setState(() => _isAdActive = false);
          }
        },
        onAdClicked: () => debugPrint('Ad clicked via SDK'),
      );

      if (mounted && !_isDisposing) {
        setState(() {
          _isAdLoading = false;
          _adsReady = true;
        });
      }
    } catch (e) {
      if (!_isDisposing && mounted) {
        _handleAdFailure('Failed to load ad');
        _scheduleReload();
      }
    }
  }

  void _handleAdFailure(String message) {
    if (_isDisposing || !mounted) return;

    setState(() {
      _isAdLoading = false;
      _adsReady = false;
      _isAdActive = false;
    });
    _hideAllOverlays();
    _showSnackBar(message, error: true);
    _scheduleReload();
  }

  void _scheduleReload() {
    if (_isDisposing) return;

    Future.delayed(const Duration(seconds: 4), () {
      if (mounted && !_isDisposing && !_isAdLoading) {
        _loadInterstitial();
      }
    });
  }

  Future<void> _showAd() async {
    if (_isDisposing || !mounted) return;

    if (!_adsReady || _interstitial == null || _isAdActive) {
      _showSnackBar('Ad not ready yet...', error: true);
      return;
    }

    try {
      await _interstitial!.show();
    } catch (e) {
      if (!_isDisposing && mounted) {
        _handleAdFailure('Failed to show ad');
      }
    }
  }

  // =========================== NATIVE OVERLAYS ===========================
  Future<void> _startAdTimerOverlay() async {
    if (_isDisposing) return;

    try {
      await platform.invokeMethod('startAdTimer', {
        'adTimerSeconds': widget.adTimerSeconds,
      });
    } catch (e) {
      debugPrint('Failed to start ad timer overlay: $e');
    }
  }

  Future<void> _startBreakTimerOverlay({required bool showClickButton}) async {
    if (_isDisposing) return;

    final seconds = widget.breakTimeMinutes * 60;
    try {
      if (showClickButton) {
        await platform.invokeMethod('startBreakTimerWithClick', {
          'breakSeconds': seconds,
          'adUrl': 'https://start.io',
        });
      } else {
        await platform.invokeMethod('startBreakTimer', {
          'breakSeconds': seconds,
        });
      }
    } catch (e) {
      debugPrint('Break timer error: $e');
    }
  }

  Future<void> _hideAllOverlays() async {
    try {
      await platform.invokeMethod('hideAllOverlays');
    } catch (e) {
      debugPrint('Hide overlays error: $e');
    }
  }

  // =========================== EVENT HANDLERS ===========================
  Future<void> _handleAdTimerComplete() async {
    if (_isDisposing || !mounted) return;

    await _trackAdView();
    await _startBreakTimerOverlay(showClickButton: _canClick);
  }

  Future<void> _handleBreakComplete() async {
    if (_isDisposing || !mounted) return;

    setState(() => _isAdActive = false);
    _hideAllOverlays();
    _showSnackBar('Break complete! Ready for next ad', success: true);
    _loadInterstitial();
  }

  Future<void> _handleNativeAdClick() async {
    if (_isDisposing || !mounted) return;

    if (!_canClick) {
      _showSnackBar(
        'Need ${widget.viewBeforeClickTarget} views first!',
        error: true,
      );
      return;
    }

    await _claimReward();

    if (mounted && !_isDisposing) {
      setState(() {
        _currentAdViews = 0;
        _canClick = false;
        _adsCompleted++;
        final total = widget.currentAdsWatched + _adsCompleted;
        _willGetReward = (total % widget.adBrack) == 0;
      });

      _progressController.forward(from: 0.0);
    }
  }

  // =========================== API CALLS ===========================
  Future<void> _trackAdView() async {
    if (_authToken == null || _isDisposing) return;

    try {
      final res = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/track-ad-view'),
            headers: {'Authorization': 'Bearer $_authToken'},
          )
          .timeout(const Duration(seconds: 10));

      if (_isDisposing || !mounted) return;

      if (res.statusCode == 200 && jsonDecode(res.body)['status'] == true) {
        final data = jsonDecode(res.body)['data'];
        setState(() {
          _currentAdViews = data['current_views'] ?? 0;
          _canClick = data['can_claim'] == true;
        });
      }
    } catch (e) {
      debugPrint('Track view error: $e');
    }
  }

  Future<void> _claimReward() async {
    if (_authToken == null || _isDisposing) return;

    try {
      final res = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/watch-ad'),
            headers: {'Authorization': 'Bearer $_authToken'},
          )
          .timeout(const Duration(seconds: 10));

      if (_isDisposing || !mounted) return;

      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        if (json['status'] == true) {
          final earned =
              double.tryParse(json['data']['earned'].toString()) ?? 0.0;
          final rewarded = json['data']['reward_given'] == true;
          _showSnackBar(
            rewarded
                ? '৳${earned.toStringAsFixed(2)} Earned!'
                : 'Ad completed! ${json['data']['ads_remaining_for_reward']} more to reward',
            success: rewarded,
          );
        }
      }
    } catch (e) {
      debugPrint('Claim reward error: $e');
    }
  }

  // =========================== UI HELPERS ===========================
  void _showSnackBar(
    String message, {
    bool error = false,
    bool success = false,
  }) {
    if (!mounted || _isDisposing) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error
            ? Colors.red.shade600
            : success
            ? Colors.green
            : Colors.orange,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: success || error ? 3 : 2),
      ),
    );
  }

  bool get _taskCompleted => _adsCompleted >= _requiredAds;

  // ✅✅✅ FIXED: Proper task completion with cleanup ✅✅✅
  Future<void> _completeTask() async {
    if (!_taskCompleted || _isDisposing) return;

    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('✅ TASK COMPLETION STARTED');
    debugPrint('   Ads Completed: $_adsCompleted/$_requiredAds');
    debugPrint('   Will Get Reward: $_willGetReward');

    // ✅ Hide overlays before navigation
    await _hideAllOverlays();

    // ✅ Small delay to ensure overlays are hidden
    await Future.delayed(const Duration(milliseconds: 300));

    if (mounted && !_isDisposing) {
      debugPrint('✅ Navigating back with result: true');
      Navigator.pop(context, true);
    }

    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  }

  // =========================== BUILD ===========================
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // ✅ Allow back if ad is not active
        if (!_isAdActive) {
          await _hideAllOverlays();
          return true;
        }

        // ✅ Show message if ad is running
        _showSnackBar('Please wait for ad to complete', error: true);
        return false;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0f0f23),
        body: Column(
          children: [
            // Top Banner
            if (_topBanner != null)
              Container(
                color: Colors.black,
                height: 60,
                child: StartAppBanner(_topBanner!),
              ),

            // Main Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildProgressCard(),
                    const SizedBox(height: 24),
                    if (!_taskCompleted) _buildViewTracker(),
                    if (_canClick && !_isAdActive && !_taskCompleted)
                      _buildClickReadyBadge(),
                    const SizedBox(height: 32),
                    _buildWatchAdButton(),
                    if (_taskCompleted) ...[
                      const SizedBox(height: 20),
                      _buildCompleteButton(),
                    ],
                  ],
                ),
              ),
            ),

            // Bottom Banner
            if (_bottomBanner != null)
              Container(
                color: Colors.black,
                height: 60,
                child: StartAppBanner(_bottomBanner!),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressCard() {
    return FadeTransition(
      opacity: _progressAnimation,
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _taskCompleted ? Colors.green : Colors.orange,
            width: 3,
          ),
        ),
        child: Column(
          children: [
            Text(
              '$_adsCompleted / $_requiredAds',
              style: const TextStyle(
                fontSize: 52,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const Text(
              'Ads Completed',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: _adsCompleted / _requiredAds.clamp(1, 999),
              minHeight: 14,
              borderRadius: BorderRadius.circular(8),
              backgroundColor: Colors.grey.shade800,
              valueColor: AlwaysStoppedAnimation(
                _taskCompleted ? Colors.green : Colors.orange,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewTracker() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue, width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.visibility, color: Colors.blue, size: 26),
          const SizedBox(width: 12),
          Text(
            'Views: $_currentAdViews / ${widget.viewBeforeClickTarget}',
            style: const TextStyle(
              color: Colors.blue,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClickReadyBadge() {
    return ScaleTransition(
      scale: _pulseAnimation,
      child: Container(
        margin: const EdgeInsets.only(top: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.green.shade600, Colors.green.shade800],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.greenAccent, width: 3),
          boxShadow: [
            BoxShadow(color: Colors.green.withOpacity(0.5), blurRadius: 20),
          ],
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.touch_app, color: Colors.white, size: 32),
            SizedBox(width: 12),
            Text(
              'Ready to Click & Earn!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWatchAdButton() {
    final canWatch =
        !_isAdActive && !_isAdLoading && _adsReady && !_taskCompleted;

    return SizedBox(
      height: 70,
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: canWatch ? _showAd : null,
        icon: Icon(
          _isAdActive ? Icons.play_circle : Icons.play_circle_fill,
          size: 40,
          color: Colors.white,
        ),
        label: Text(
          _isAdActive
              ? 'Ad Running...'
              : _isAdLoading
              ? 'Loading Ad...'
              : _adsReady
              ? (_canClick
                    ? 'Watch & Click to Earn'
                    : 'Watch ${widget.adTimerSeconds}s Ad')
              : 'Ad Not Ready',
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _canClick && _adsReady
              ? Colors.green.shade600
              : Colors.orange.shade600,
          disabledBackgroundColor: Colors.grey.shade700,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(35),
          ),
          elevation: 15,
        ),
      ),
    );
  }

  Widget _buildCompleteButton() {
    return SizedBox(
      width: double.infinity,
      height: 64,
      child: ElevatedButton.icon(
        onPressed: _completeTask,
        icon: Icon(
          _willGetReward ? Icons.card_giftcard : Icons.check_circle,
          size: 38,
        ),
        label: Text(
          _willGetReward ? 'Claim Your Reward!' : 'Task Complete!',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _willGetReward
              ? Colors.green.shade600
              : Colors.blue.shade600,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(32),
          ),
          elevation: 15,
        ),
      ),
    );
  }
}
