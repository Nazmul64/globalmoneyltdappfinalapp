// ====================================================================
// ✅ ONESIGNAL PUSH NOTIFICATION - PART 1/5 (FIXED DEFAULT AVATAR)
// ✅ Main Setup, Imports & OneSignal Initialization
// ✅ Lines 1-800
// ====================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

// ✅ ONESIGNAL IMPORTS
import 'package:onesignal_flutter/onesignal_flutter.dart';

// Import other pages
import 'config/api_config.dart';
import 'services/app_service.dart';
import 'addbalance.dart';
import 'membership.dart';
import 'profile.dart';
import 'task.dart';
import 'options.dart';
import 'friend_request.dart';
import 'paymenthistory.dart';
import 'p2p.dart';
import 'whychooseus.dart';
import 'withdraw.dart';
import 'reffer.dart';
import 'total_deposite.dart';
import 'support.dart';
import 'userlivechat.dart';
import 'agent_list.dart';
import 'socialpost.dart';
import 'login.dart';
import 'total_deposit_history_model.dart';
import 'privacy_policy.dart';
import 'terms_and_conditions.dart';
import 'google_ads_approval.dart';

// ====================================================================
// ✅ MAIN FUNCTION - SIMPLE INITIALIZATION
// ====================================================================

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ OneSignal will be initialized AFTER MaterialApp builds
  // Don't initialize here to avoid "initWithContext" error

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  final String authToken;

  const HomePage({super.key, this.authToken = ''});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  // ========================================
  // CONTROLLERS
  // ========================================
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _chatController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  final ScrollController _scrollController = ScrollController();

  // ========================================
  // ✅ ONESIGNAL VARIABLES
  // ========================================
  String? _oneSignalPlayerId;
  String? _oneSignalPushToken;
  bool _notificationPermissionGranted = false;
  int _notificationBadgeCount = 0;
  List<Map<String, dynamic>> _appNotifications = [];
  bool _oneSignalInitialized = false; // ✅ Track initialization

  // ========================================
  // STATE VARIABLES
  // ========================================
  int _selectedIndex = 2;
  bool _isChatOpen = false;
  bool _isBalanceVisible = false;
  bool _showEmojiPicker = false;

  // Loading States
  bool _isLoadingMessages = false;
  bool _isSendingMessage = false;
  bool _isLoadingAuth = true;
  bool _isSearching = false;

  // User Data
  String _userName = "Loading...";
  String _referralCode = "---";
  double _userBalance = 0.0;
  bool _isKycApproved = false;
  String? _profilePhotoUrl;
  String? _userEmail; // ✅ For OneSignal external user ID

  // Package & Notice
  bool _hasActivePackage = false;
  List<Map<String, dynamic>> _workNotices = [];
  List<Map<String, dynamic>> _notices = [];

  // Notification Count
  int _notificationCount = 0;

  // Theme Colors
  Color? _primaryColor;
  Color? _secondaryColor;
  Color? _searchButtonColor;

  // Friend Search
  bool _showSearchResults = false;
  List<Map<String, dynamic>> _searchResults = [];
  Timer? _searchDebounce;

  // Typing Animation
  String _typingText = '';
  int _typingIndex = 0;
  final String _fullText = 'Search your friend';
  bool _isTypingForward = true;
  Timer? _typingTimer;
  Timer? _messageRefreshTimer;

  // Emojis
  final List<String> _emojis = [
    '😀',
    '😃',
    '😄',
    '😁',
    '😆',
    '😅',
    '🤣',
    '😂',
    '🙂',
    '🙃',
    '😉',
    '😊',
    '😇',
    '🥰',
    '😍',
    '🤩',
    '😘',
    '😗',
    '😚',
    '😙',
    '😋',
    '😛',
    '😜',
    '🤪',
    '😝',
    '🤑',
    '🤗',
    '🤭',
    '🤫',
    '🤔',
    '🤐',
    '🤨',
    '😐',
    '😑',
    '😶',
    '😏',
    '😒',
    '🙄',
    '😬',
    '🤥',
    '😌',
    '😔',
    '😪',
    '🤤',
    '😴',
    '😷',
    '🤒',
    '🤕',
    '🤢',
    '🤮',
    '🤧',
    '🥵',
    '🥶',
    '😶‍🌫️',
    '😵',
    '😵‍💫',
    '🤯',
    '🤠',
    '🥳',
    '😎',
    '🤓',
    '🧐',
    '😕',
    '😟',
    '🙁',
    '☹️',
    '😮',
    '😯',
    '😲',
    '😳',
    '🥺',
    '😦',
    '😧',
    '😨',
    '😰',
    '😥',
    '😢',
    '😭',
    '😱',
    '😖',
    '👍',
    '👎',
    '👏',
    '🙌',
    '🤝',
    '🙏',
    '💪',
    '✨',
    '🎉',
    '🎊',
    '❤️',
    '💕',
    '💖',
    '💗',
    '💓',
    '💞',
    '💝',
    '🔥',
    '⭐',
    '🌟',
  ];

  // Chat Messages
  List<Map<String, dynamic>> _messages = [];
  int _currentPage = 1;
  int _totalPages = 1;
  bool _hasMoreMessages = true;

  // ========================================
  // ✅ API CONFIGURATION
  // ========================================
  // URL: use ApiConfig.baseUrl
  static const String fetchMessagesUrl = '${ApiConfig.baseUrl}/usertoadminchat/fetch';
  static const String sendMessageUrl = '${ApiConfig.baseUrl}/usertoadminchat/send';
  static const String markReadUrl = '${ApiConfig.baseUrl}/usertoadminchat/mark-read';
  static const String searchUserUrl = '${ApiConfig.baseUrl}/user-search';
  static const String sendFriendRequestUrl = '${ApiConfig.baseUrl}/user/friend/request';
  static const String cancelFriendRequestUrl = '${ApiConfig.baseUrl}/cancel/friend/request';
  static const String userBalanceShowUrl = '${ApiConfig.baseUrl}/userbalanceshow';
  static const String workNoticesUrl = '${ApiConfig.baseUrl}/worknotices';
  static const String themeChangeUrl = '${ApiConfig.baseUrl}/themechange';
  static const String friendRequestCountUrl = '${ApiConfig.baseUrl}/friend/requests/count';

  // ✅ ONESIGNAL API ENDPOINTS
  static const String updateOneSignalPlayerIdUrl =
      '${ApiConfig.baseUrl}/update-onesignal-player-id';
  static const String getNotificationsUrl = '${ApiConfig.baseUrl}/get-notifications';

  // ✅ DEFAULT AVATAR URL - FIXED PATH
  static const String defaultAvatarUrl = ApiConfig.defaultAvatar;

  // ✅ PROFILE IMAGE PATH
  static const String profileImagePath = '${ApiConfig.mediaBaseUrl}/uploads/profile/';

  // Auth with SharedPreferences
  String? _authToken;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _startTypingAnimation();
    _initializeAuth();

    // ✅ Initialize OneSignal AFTER first frame is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeOneSignalAfterBuild();
    });

    _scrollController.addListener(_scrollListener);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    _chatController.dispose();
    _scrollController.dispose();
    _typingTimer?.cancel();
    _messageRefreshTimer?.cancel();
    _searchDebounce?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // App came to foreground - refresh notifications
      if (_oneSignalInitialized) {
        _fetchAppNotifications();
      }
    }
  }

  // ====================================================================
  // ✅ ONESIGNAL INITIALIZATION (AFTER BUILD) - THIS IS THE FIX!
  // ====================================================================

  Future<void> _initializeOneSignalAfterBuild() async {
    if (_oneSignalInitialized) return; // Prevent double initialization

    try {
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('🔥 INITIALIZING ONESIGNAL (AFTER BUILD)');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      // ✅ REPLACE THIS WITH YOUR ONESIGNAL APP ID FROM DASHBOARD
      const String oneSignalAppId = "19355887-8178-4d10-a8a3-3a6cc499968c";

      // ⚠️ IMPORTANT: Get your App ID from:
      // https://app.onesignal.com/ → Settings → Keys & IDs

      // ✅ Enable debug logging (optional - remove in production)
      OneSignal.Debug.setLogLevel(OSLogLevel.verbose);

      // ✅ Initialize OneSignal
      OneSignal.initialize(oneSignalAppId);

      // ✅ Request notification permission
      OneSignal.Notifications.requestPermission(true);

      setState(() {
        _oneSignalInitialized = true;
      });

      print('✅ OneSignal initialized successfully');

      // ✅ Setup handlers and get player ID
      await Future.wait([_setupOneSignalHandlers(), _getOneSignalPlayerId()]);

      // ✅ Fetch existing notifications
      await _fetchAppNotifications();

      print('✅ OneSignal setup complete');
    } catch (e) {
      print('❌ OneSignal initialization error: $e');
      setState(() {
        _oneSignalInitialized = false;
      });
    }
  }

  // ====================================================================
  // ✅ SETUP ONESIGNAL HANDLERS
  // ====================================================================

  Future<void> _setupOneSignalHandlers() async {
    try {
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('🔔 SETTING UP ONESIGNAL HANDLERS');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      // ✅ Check permission status
      final permissionStatus = OneSignal.Notifications.permission;
      setState(() {
        _notificationPermissionGranted = permissionStatus;
      });
      print('✅ Permission status: $permissionStatus');

      // ✅ FOREGROUND NOTIFICATION HANDLER
      // This is called when a notification arrives while app is open
      OneSignal.Notifications.addForegroundWillDisplayListener((event) {
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        print('🔔 FOREGROUND NOTIFICATION RECEIVED');
        print('Title: ${event.notification.title}');
        print('Body: ${event.notification.body}');
        print('Additional Data: ${event.notification.additionalData}');
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

        // ✅ Update badge count
        setState(() {
          _notificationBadgeCount++;
        });

        // ✅ Refresh notifications list from server
        _fetchAppNotifications();

        // ✅ Display the notification (this shows it in status bar)
        event.notification.display();
      });

      // ✅ NOTIFICATION CLICKED HANDLER
      // This is called when user taps on a notification
      OneSignal.Notifications.addClickListener((event) {
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        print('👆 NOTIFICATION CLICKED');
        print('Title: ${event.notification.title}');
        print('Body: ${event.notification.body}');
        print('Additional Data: ${event.notification.additionalData}');
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

        // ✅ Handle the click
        _handleNotificationClick(event.notification.additionalData ?? {});
      });

      // ✅ PERMISSION OBSERVER
      // This is called when notification permission changes
      OneSignal.Notifications.addPermissionObserver((state) {
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        print('🔔 NOTIFICATION PERMISSION CHANGED');
        print('Has Permission: $state');
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

        setState(() {
          _notificationPermissionGranted = state;
        });
      });

      print('✅ OneSignal handlers setup complete');
    } catch (e) {
      print('❌ Setup handlers error: $e');
    }
  }

  // ====================================================================
  // ✅ GET ONESIGNAL PLAYER ID & SEND TO SERVER
  // ====================================================================

  Future<void> _getOneSignalPlayerId() async {
    try {
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('🔍 GETTING ONESIGNAL PLAYER ID');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      // ✅ Get OneSignal User ID (Player ID / Subscription ID)
      final userId = OneSignal.User.pushSubscription.id;

      if (userId != null && userId.isNotEmpty) {
        setState(() {
          _oneSignalPlayerId = userId;
          _notificationPermissionGranted = true;
        });

        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        print('✅ ONESIGNAL PLAYER ID RECEIVED');
        print('Player ID: ${userId.substring(0, 20)}...');
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

        // ✅ Get push token (optional - for debugging)
        final pushToken = OneSignal.User.pushSubscription.token;
        if (pushToken != null) {
          setState(() => _oneSignalPushToken = pushToken);
          print('✅ Push Token: ${pushToken.substring(0, 50)}...');
        }

        // ✅ Save to SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('onesignal_player_id', userId);
        if (pushToken != null) {
          await prefs.setString('onesignal_push_token', pushToken);
        }

        // ✅ Send to server if user is logged in
        if (_isLoggedIn && _userEmail != null) {
          await _sendPlayerIdToServer(userId);
        } else {
          print('⚠️ User not logged in yet - will send Player ID after login');
        }
      } else {
        print('⚠️ OneSignal Player ID is null - waiting for subscription...');
      }

      // ✅ Listen for subscription changes
      OneSignal.User.pushSubscription.addObserver((state) {
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        print('🔄 ONESIGNAL SUBSCRIPTION CHANGED');
        print('Previous ID: ${state.previous.id}');
        print('Current ID: ${state.current.id}');
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

        if (state.current.id != null) {
          setState(() => _oneSignalPlayerId = state.current.id);

          // Save to SharedPreferences
          SharedPreferences.getInstance().then((prefs) {
            prefs.setString('onesignal_player_id', state.current.id!);
          });

          // Send to server if logged in
          if (_isLoggedIn && _userEmail != null) {
            _sendPlayerIdToServer(state.current.id!);
          }
        }
      });

      print('✅ Player ID listener registered');
    } catch (e) {
      print('❌ OneSignal Player ID error: $e');
      setState(() => _notificationPermissionGranted = false);
    }
  }

  // ====================================================================
  // ✅ SEND ONESIGNAL PLAYER ID TO SERVER
  // ====================================================================

  Future<void> _sendPlayerIdToServer(String playerId) async {
    if (_userEmail == null || _userEmail!.isEmpty) {
      print('⚠️ Cannot send Player ID: User email is empty');
      return;
    }

    try {
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('📤 SENDING ONESIGNAL PLAYER ID TO SERVER');
      print('Email: $_userEmail');
      print('Player ID: ${playerId.substring(0, 20)}...');
      print('Device: ${Platform.isAndroid ? "Android" : "iOS"}');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      final response = await http
          .post(
            Uri.parse(updateOneSignalPlayerIdUrl),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: json.encode({
              'email': _userEmail,
              'onesignal_player_id': playerId,
              'device_type': Platform.isAndroid ? 'android' : 'ios',
            }),
          )
          .timeout(const Duration(seconds: 10));

      print('📥 Server Response: ${response.statusCode}');
      print('📥 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          print('✅ OneSignal Player ID sent to server successfully');
          print('✅ Server Data: ${data['data']}');
        } else {
          print('⚠️ Server returned success=false: ${data['message']}');
        }
      } else {
        print('❌ Failed to send Player ID: ${response.statusCode}');
        print('❌ Response: ${response.body}');
      }
    } catch (e) {
      print('❌ Error sending Player ID: $e');
    }
  }

  // ====================================================================
  // ✅ HANDLE NOTIFICATION CLICK
  // ====================================================================

  void _handleNotificationClick(Map<String, dynamic> additionalData) {
    try {
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('👆 HANDLING NOTIFICATION CLICK');
      print('Data: $additionalData');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      // ✅ Handle action_url if present
      if (additionalData['action_url'] != null &&
          additionalData['action_url'].toString().isNotEmpty) {
        final actionUrl = additionalData['action_url'].toString();

        print('🔗 Opening URL: $actionUrl');

        // Open URL in browser
        launchUrl(Uri.parse(actionUrl), mode: LaunchMode.externalApplication);
      } else {
        // No action URL - show notifications dialog
        print('📱 No action URL - showing notifications dialog');
        _showNotificationsDialog();
      }

      // ✅ Clear badge
      setState(() => _notificationBadgeCount = 0);
    } catch (e) {
      print('❌ Error handling notification click: $e');
    }
  }

  // ====================================================================
  // ✅ FETCH APP NOTIFICATIONS FROM SERVER
  // ====================================================================

  Future<void> _fetchAppNotifications() async {
    try {
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('📤 FETCHING APP NOTIFICATIONS FROM SERVER');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      final response = await http
          .get(
            Uri.parse(getNotificationsUrl),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 10));

      print('📥 Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('📥 Response Data: $data');

        if (data['success'] == true) {
          final List<dynamic> notifications = data['notifications'] ?? [];

          setState(() {
            _appNotifications = notifications.map((notif) {
              return {
                'title': notif['title'] ?? '',
                'message': notif['message'] ?? '',
                'image_url': notif['image_url'],
                'action_url': notif['action_url'],
                'sent_at': notif['sent_at'],
              };
            }).toList();
          });

          print('✅ Fetched ${_appNotifications.length} notifications');
          print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        } else {
          print('⚠️ Server returned success=false');
        }
      } else {
        print('❌ Failed to fetch notifications: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error fetching notifications: $e');
    }
  }

  // ====================================================================
  // ✅ FIXED BUILD PROFILE PHOTO URL WITH DEFAULT AVATAR SUPPORT
  // ====================================================================

  /// ✅ CRITICAL FIX: Properly handles default avatar display
  /// This ensures that:
  /// 1. If photo is null/empty → shows default avatar
  /// 2. If photo is "default.png" → shows default avatar
  /// 3. If photo is valid URL → shows user's actual photo
  /// 4. Removes duplicate extensions (.jpg.jpg)
  String? _buildProfilePhotoUrl(dynamic photo) {
    try {
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('📸 BUILDING PROFILE PHOTO URL');
      print('Raw input: "$photo"');

      // ✅ STEP 1: Handle null or empty photo
      if (photo == null || photo.toString().trim().isEmpty) {
        print('⚠️ Photo is null/empty → Using DEFAULT AVATAR');
        print('✅ Default Avatar URL: $defaultAvatarUrl');
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        return defaultAvatarUrl;
      }

      String photoStr = photo.toString().trim();
      print('📥 Trimmed photo string: "$photoStr"');

      // ✅ STEP 2: Check if it's the default.png marker
      if (photoStr == 'default.png' ||
          photoStr.endsWith('/default.png') ||
          photoStr.contains('default.png')) {
        print('⚠️ Photo is default.png → Using DEFAULT AVATAR');
        print('✅ Default Avatar URL: $defaultAvatarUrl');
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        return defaultAvatarUrl;
      }

      // ✅ STEP 3: Check if already a full URL
      if (photoStr.startsWith('http://') || photoStr.startsWith('https://')) {
        print('✅ Photo is already full URL: $photoStr');
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        return photoStr;
      }

      // ✅ STEP 4: Clean up the path
      // Remove any "uploads/profile/" prefix
      photoStr = photoStr.replaceAll('uploads/profile/', '');
      photoStr = photoStr.replaceAll(RegExp(r'^/+'), '');

      // ✅ STEP 5: Fix double extensions (.jpg.jpg → .jpg)
      photoStr = photoStr.replaceAllMapped(
        RegExp(
          r'\.(jpg|jpeg|png|gif|webp)\.(jpg|jpeg|png|gif|webp)$',
          caseSensitive: false,
        ),
        (match) => '.${match.group(1)}',
      );

      // ✅ STEP 6: Build full URL
      final fullUrl = '$profileImagePath$photoStr';

      print('🔧 Cleaned photo string: "$photoStr"');
      print('🔗 Final URL: $fullUrl');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      return fullUrl;
    } catch (e) {
      print('❌ Error in _buildProfilePhotoUrl: $e');
      print('⚠️ Falling back to DEFAULT AVATAR');
      print('✅ Default Avatar URL: $defaultAvatarUrl');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      return defaultAvatarUrl;
    }
  }

  // ====================================================================
  // ✅ ONESIGNAL PUSH NOTIFICATION - PART 2/5 (FIXED DEFAULT AVATAR)
  // ✅ Auth, Theme, User Data & Avatar Widget
  // ✅ Lines 801-1600
  // ====================================================================

  // ====================================================================
  // ✅ AUTH & THEME INITIALIZATION
  // ====================================================================

  Map<String, Map<String, dynamic>> _homeCardSettings = {};

  Future<void> _initializeAuth() async {
    try {
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('🔐 INITIALIZING AUTH & THEME');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      await Future.wait([_loadAuthToken(), _fetchThemeColors(), _fetchHomeCards()]);

      if (_isLoggedIn) {
        _fetchUserDataInBackground();
        _fetchWorkNoticesInBackground();
        _fetchNotificationCountInBackground();

        // ✅ Send OneSignal Player ID to server after login
        if (_oneSignalInitialized &&
            _oneSignalPlayerId != null &&
            _oneSignalPlayerId!.isNotEmpty) {
          await _sendPlayerIdToServer(_oneSignalPlayerId!);
        }
      }
    } catch (e) {
      print('❌ Init error: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingAuth = false);
      }
    }
  }

  void _fetchUserDataInBackground() {
    _fetchUserData().then((_) {
      if (mounted) setState(() {});
    });
  }

  void _fetchWorkNoticesInBackground() {
    _fetchWorkNotices().then((_) {
      if (mounted) setState(() {});
    });
  }

  void _fetchNotificationCountInBackground() {
    _fetchNotificationCount().then((_) {
      if (mounted) setState(() {});
    });
  }

  // ✅ Load token from SharedPreferences
  Future<void> _loadAuthToken() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();

      String? token = widget.authToken.isNotEmpty ? widget.authToken : null;

      if (token == null || token.isEmpty) {
        token = prefs.getString('auth_token');
      } else {
        await prefs.setString('auth_token', token);
      }

      bool isValid = false;
      if (token != null &&
          token.isNotEmpty &&
          token != 'login' &&
          token != 'null' &&
          token != 'undefined' &&
          token.length > 10) {
        isValid = true;
      }

      _authToken = isValid ? token : null;
      _isLoggedIn = isValid;

      print(
        '🔐 Auth Status: ${_isLoggedIn ? "LOGGED IN ✅" : "NOT LOGGED IN ❌"}',
      );
      if (_authToken != null) {
        print(
          '🔑 Token: ${_authToken!.substring(0, _min(_authToken!.length, 20))}...',
        );
      }
    } catch (e) {
      print('❌ Token load error: $e');
      _authToken = null;
      _isLoggedIn = false;
    }
  }

  int _min(int a, int b) => a < b ? a : b;

  // ========================================
  // THEME FETCHING
  // ========================================

  Future<void> _fetchThemeColors() async {
    try {
      print('🎨 Fetching theme...');

      final response = await http
          .get(
            Uri.parse(themeChangeUrl),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == true && data['data'] != null) {
          final String colorCode = data['data']['color_code'];

          _primaryColor = _parseColor(colorCode);
          _secondaryColor = _generateSecondaryColor(_primaryColor!);
          _searchButtonColor = _primaryColor;

          print('✅ Theme loaded: $colorCode');
        }
      }
    } catch (e) {
      print('❌ Theme error: $e');
    }
  }

  Color _parseColor(String? hexColor) {
    if (hexColor == null || hexColor.isEmpty) {
      return Colors.grey;
    }

    try {
      String colorString = hexColor.replaceAll('#', '');
      if (colorString.length == 6) {
        colorString = 'FF$colorString';
      }
      return Color(int.parse(colorString, radix: 16));
    } catch (e) {
      print('❌ Color parse error: $e');
      return Colors.grey;
    }
  }

  Color _generateSecondaryColor(Color primary) {
    final hslColor = HSLColor.fromColor(primary);
    final lighter = hslColor.withLightness(
      (hslColor.lightness + 0.15).clamp(0.0, 1.0),
    );
    return lighter.toColor();
  }

  // ========================================
  // FETCH DYNAMIC HOME CARDS SETTINGS
  // ========================================

  Future<void> _fetchHomeCards() async {
    try {
      print('🎴 Fetching home card settings...');
      final response = await http
          .get(
            Uri.parse(ApiConfig.homeCards),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final List list = data['data'];
          final Map<String, Map<String, dynamic>> map = {};
          for (var item in list) {
            if (item['key'] != null) {
              map[item['key'].toString()] = Map<String, dynamic>.from(item);
            }
          }
          if (mounted) {
            setState(() {
              _homeCardSettings = map;
            });
          }
          print('✅ Home cards settings loaded (${map.length} cards)');
        }
      }
    } catch (e) {
      print('❌ Home cards settings fetch error: $e');
    }
  }

  // ========================================
  // FETCH NOTIFICATION COUNT
  // ========================================

  Future<void> _fetchNotificationCount() async {
    if (!_isLoggedIn || _authToken == null) return;

    try {
      print('🔔 Fetching notification count...');

      final response = await http
          .get(
            Uri.parse(friendRequestCountUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_authToken',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true) {
          if (mounted) {
            setState(() {
              _notificationCount = data['data']['pending_requests_count'] ?? 0;
            });
          }
          print('✅ Notification count: $_notificationCount');
        }
      }
    } catch (e) {
      print('❌ Notification count error: $e');
    }
  }

  // ========================================
  // ✅ USER DATA FETCH WITH EMAIL & PHOTO (FIXED DEFAULT AVATAR)
  // ========================================

  Future<void> _fetchUserData() async {
    if (!_isLoggedIn || _authToken == null) return;

    try {
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('📤 FETCHING USER DATA');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      final response = await http
          .get(
            Uri.parse(userBalanceShowUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_authToken',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true) {
          final userData = data['data'];

          if (mounted) {
            setState(() {
              _userName = userData['user']['name'] ?? 'User';
              _userEmail =
                  userData['user']['email']; // ✅ Store email for OneSignal
              _userBalance =
                  double.tryParse(userData['balance'].toString()) ?? 0.0;
              _referralCode = userData['ref_code']?.toString() ?? '---';
              _isKycApproved = userData['kyc_approved'] == true;

              // ✅ CRITICAL: Use the fixed _buildProfilePhotoUrl method
              _profilePhotoUrl = _buildProfilePhotoUrl(
                userData['profile_photo'],
              );
            });
          }

          print('✅ User loaded: $_userName');
          print('✅ User email: $_userEmail');
          print('📸 Profile Photo URL: $_profilePhotoUrl');

          // ✅ Set OneSignal external user ID (email)
          if (_oneSignalInitialized &&
              _userEmail != null &&
              _userEmail!.isNotEmpty) {
            try {
              OneSignal.login(_userEmail!);
              print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
              print('✅ ONESIGNAL EXTERNAL USER ID SET');
              print('Email/External ID: $_userEmail');
              print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
            } catch (e) {
              print('⚠️ Could not set OneSignal external ID: $e');
            }
          }

          // ✅ Send OneSignal Player ID after getting user email
          if (_oneSignalInitialized &&
              _oneSignalPlayerId != null &&
              _userEmail != null) {
            await _sendPlayerIdToServer(_oneSignalPlayerId!);
          }
        }
      } else if (response.statusCode == 401) {
        await _handleUnauthorized();
      }
    } catch (e) {
      print('❌ User data error: $e');
    }
  }

  // ========================================
  // FETCH WORK NOTICES
  // ========================================

  Future<void> _fetchWorkNotices() async {
    if (!_isLoggedIn || _authToken == null) return;

    try {
      final response = await http
          .get(
            Uri.parse(workNoticesUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_authToken',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true) {
          final responseData = data['data'];

          if (mounted) {
            setState(() {
              _hasActivePackage = responseData['has_active_package'] == true;

              _workNotices =
                  (responseData['work_notices'] as List?)
                      ?.map(
                        (notice) => {
                          'id': notice['id'],
                          'title': notice['title'] ?? '',
                          'description': notice['description'] ?? '',
                        },
                      )
                      .toList() ??
                  [];

              _notices =
                  (responseData['notices'] as List?)
                      ?.map(
                        (notice) => {
                          'id': notice['id'],
                          'title': notice['title'] ?? '',
                          'description': notice['description'] ?? '',
                        },
                      )
                      .toList() ??
                  [];
            });
          }

          print('✅ Notices loaded');
        }
      }
    } catch (e) {
      print('❌ Notices error: $e');
    }
  }

  // ========================================
  // HELPER METHODS
  // ========================================

  Future<void> _refreshAuthStatus() async {
    print('🔄 Refreshing...');
    await Future.wait([_loadAuthToken(), _fetchThemeColors()]);

    if (_isLoggedIn) {
      _fetchUserDataInBackground();
      _fetchWorkNoticesInBackground();
      _fetchNotificationCountInBackground();

      // ✅ Refresh notifications
      if (_oneSignalInitialized) {
        _fetchAppNotifications();
      }
    }

    if (mounted) setState(() {});
  }

  Future<void> _handleUnauthorized() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
      await prefs.remove('onesignal_player_id'); // ✅ Clear OneSignal ID too
    } catch (e) {
      print('❌ Error clearing token: $e');
    }

    setState(() {
      _isLoggedIn = false;
      _authToken = null;
      _userEmail = null;
    });

    // ✅ Logout from OneSignal
    if (_oneSignalInitialized) {
      try {
        OneSignal.logout();
        print('✅ OneSignal logout successful');
      } catch (e) {
        print('⚠️ OneSignal logout error: $e');
      }
    }

    _showErrorSnackBar('Session expired. Please login again.');

    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _startTypingAnimation() {
    _typingTimer = Timer.periodic(const Duration(milliseconds: 150), (timer) {
      if (!mounted) return;

      setState(() {
        if (_isTypingForward) {
          if (_typingIndex < _fullText.length) {
            _typingText = _fullText.substring(0, _typingIndex + 1);
            _typingIndex++;
          } else {
            Future.delayed(const Duration(seconds: 2), () {
              if (mounted) _isTypingForward = false;
            });
          }
        } else {
          if (_typingIndex > 0) {
            _typingIndex--;
            _typingText = _fullText.substring(0, _typingIndex);
          } else {
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted) _isTypingForward = true;
            });
          }
        }
      });
    });
  }

  // ====================================================================
  // ✅ SHOW NOTIFICATIONS DIALOG
  // Displays all app notifications in a beautiful dialog
  // ====================================================================

  void _showNotificationsDialog() {
    final primaryColor = _primaryColor ?? Colors.blue;
    final secondaryColor = _secondaryColor ?? Colors.blueAccent;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primaryColor, secondaryColor],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.3),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.notifications_active,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Notifications',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (_notificationBadgeCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$_notificationBadgeCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () {
                        setState(() => _notificationBadgeCount = 0);
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              ),
              // Notifications List
              Expanded(
                child: _appNotifications.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.notifications_off_outlined,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No notifications yet',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'You\'ll see notifications here',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _appNotifications.length,
                        itemBuilder: (context, index) {
                          final notif = _appNotifications[index];
                          return _buildNotificationCard(notif, primaryColor);
                        },
                      ),
              ),
              // Footer
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _notificationBadgeCount = 0;
                          _appNotifications.clear();
                        });
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Clear All'),
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ====================================================================
  // ✅ BUILD NOTIFICATION CARD
  // ====================================================================

  Widget _buildNotificationCard(
    Map<String, dynamic> notif,
    Color primaryColor,
  ) {
    final hasImage =
        notif['image_url'] != null && notif['image_url'].toString().isNotEmpty;
    final hasAction =
        notif['action_url'] != null &&
        notif['action_url'].toString().isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade100,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image if present
          if (hasImage)
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
              child: Image.network(
                notif['image_url'],
                width: double.infinity,
                height: 150,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 150,
                  color: Colors.grey.shade200,
                  child: const Center(
                    child: Icon(Icons.broken_image, size: 50),
                  ),
                ),
              ),
            ),
          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            primaryColor.withOpacity(0.2),
                            primaryColor.withOpacity(0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.notifications,
                        color: primaryColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        notif['title'] ?? 'Notification',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  notif['message'] ?? '',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatNotificationTime(notif['sent_at']),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    if (hasAction)
                      TextButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          launchUrl(
                            Uri.parse(notif['action_url']),
                            mode: LaunchMode.externalApplication,
                          );
                        },
                        icon: const Icon(Icons.open_in_new, size: 16),
                        label: const Text('Open Link'),
                        style: TextButton.styleFrom(
                          foregroundColor: primaryColor,
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

  // ====================================================================
  // ✅ FORMAT NOTIFICATION TIME
  // ====================================================================

  String _formatNotificationTime(String? timestamp) {
    if (timestamp == null) return '';

    try {
      final DateTime dateTime = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inMinutes < 1) {
        return 'Just now';
      } else if (difference.inHours < 1) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inDays < 1) {
        return '${difference.inHours}h ago';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
      }
    } catch (e) {
      return '';
    }
  }

  // ====================================================================
  // ✅ FIXED USER PHOTO AVATAR WIDGET WITH DEFAULT AVATAR SUPPORT
  // ====================================================================

  /// ✅ CRITICAL FIX: Properly displays user avatar with fallback to default
  /// This widget ensures:
  /// 1. Shows user's uploaded photo if available
  /// 2. Falls back to default avatar (uploads/avator.jpg) if not
  /// 3. Shows user's first letter as ultra-fallback
  /// 4. Handles loading states gracefully
  Widget _buildUserPhotoAvatar({
    required String? photoUrl,
    required String? userName,
    double size = 60,
  }) {
    final primaryColor = _primaryColor ?? Colors.blue;
    final secondaryColor = _secondaryColor ?? Colors.blueAccent;

    // ✅ Get first letter for fallback display
    String firstLetter = 'U';
    if (userName != null && userName.isNotEmpty) {
      firstLetter = userName[0].toUpperCase();
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            primaryColor.withOpacity(0.2),
            secondaryColor.withOpacity(0.1),
          ],
        ),
        shape: BoxShape.circle,
        border: Border.all(color: primaryColor.withOpacity(0.3), width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: photoUrl != null && photoUrl.isNotEmpty
            ? Image.network(
                photoUrl,
                width: size,
                height: size,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: SizedBox(
                      width: size * 0.4,
                      height: size * 0.4,
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                            : null,
                        strokeWidth: 2,
                        color: primaryColor,
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  // ✅ CRITICAL: On error, show first letter instead of broken image
                  print('⚠️ Image load error for: $photoUrl');
                  print('⚠️ Error: $error');
                  print('✅ Falling back to first letter display');

                  return Container(
                    color: primaryColor.withOpacity(0.1),
                    child: Center(
                      child: Text(
                        firstLetter,
                        style: TextStyle(
                          fontSize: size * 0.4,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                    ),
                  );
                },
              )
            : Container(
                color: primaryColor.withOpacity(0.1),
                child: Center(
                  child: Text(
                    firstLetter,
                    style: TextStyle(
                      fontSize: size * 0.4,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  // ====================================================================
  // ✅ ONESIGNAL PUSH NOTIFICATION - PART 3/5 (FIXED DEFAULT AVATAR)
  // ✅ Friend Search, Task Handling & Image Upload
  // ✅ Lines 1601-2400
  // ====================================================================

  // ========================================
  // ✅ START TASK WITH PACKAGE CHECK
  // ========================================

  void _handleStartTaskClick() async {
    if (!_isLoggedIn) {
      _showErrorSnackBar('Please log in first.');
      return;
    }

    if (!_hasActivePackage) {
      if (_notices.isEmpty) {
        _showErrorSnackBar('No notices available.');
        return;
      }
      _showGeneralNoticesDialog();
      return;
    }

    if (_workNotices.isEmpty) {
      _showErrorSnackBar('No work notices available.');
      return;
    }
    _showWorkNoticesDialog();
  }

  void _showWorkNoticesDialog() {
    final primaryColor = _primaryColor ?? Colors.blue;
    final secondaryColor = _secondaryColor ?? Colors.blueAccent;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [primaryColor, secondaryColor]),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: const Text(
            '📋 You have received a work notice!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        contentPadding: EdgeInsets.zero,
        content: Container(
          width: double.maxFinite,
          constraints: const BoxConstraints(maxHeight: 400),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _workNotices.length,
            itemBuilder: (context, index) {
              final notice = _workNotices[index];
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: primaryColor.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notice['title'],
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      notice['description'],
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: TextStyle(color: primaryColor)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TaskPage()),
              );
              if (mounted) {
                _fetchUserDataInBackground();
                _fetchWorkNoticesInBackground();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Start work',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showGeneralNoticesDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.orange, Colors.deepOrange],
            ),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: const Text(
            '⚠️ Package required',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        contentPadding: EdgeInsets.zero,
        content: Container(
          width: double.maxFinite,
          constraints: const BoxConstraints(maxHeight: 400),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _notices.length,
            itemBuilder: (context, index) {
              final notice = _notices[index];
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notice['title'],
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepOrange,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      notice['description'],
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => OptionsPage()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Buy Package',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // ========================================
  // ✅ FRIEND SEARCH
  // ========================================

  void _onSearchChanged() {
    if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();

    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      final query = _searchController.text.trim();
      if (query.isNotEmpty) {
        _searchUsers(query);
      } else {
        setState(() {
          _showSearchResults = false;
          _searchResults = [];
        });
      }
    });
  }

  Future<void> _searchUsers(String query) async {
    if (!_isLoggedIn || _authToken == null) {
      _showErrorSnackBar('Please log in first.');
      return;
    }

    setState(() => _isSearching = true);

    try {
      print('🔍 Searching users for: "$query"');

      final response = await http
          .get(
            Uri.parse('$searchUserUrl?q=$query'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_authToken',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 10));

      print('📥 Search API Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('📦 Response data: ${data.toString()}');

        if (data['success'] == true) {
          final List<dynamic> users = data['data'] ?? [];
          print('👥 Found ${users.length} users');

          setState(() {
            _searchResults = users.map((user) {
              final rawPhoto = user['photo'];

              // ✅ CRITICAL: Use _buildProfilePhotoUrl for consistent photo handling
              final photoUrl = _buildProfilePhotoUrl(rawPhoto);

              print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
              print('👤 Processing search result user:');
              print('Name: ${user['name']}');
              print('Raw photo from API: "$rawPhoto"');
              print('Processed photo URL: "$photoUrl"');
              print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

              return {
                'id': user['id'],
                'name': user['name'] ?? 'Unknown',
                'photo':
                    photoUrl, // ✅ This will be defaultAvatarUrl if no photo
                'friend_status': user['friend_status'] ?? 'none',
                'request_sent_by_me': user['request_sent_by_me'] ?? false,
              };
            }).toList();
            _showSearchResults = true;
          });

          print('✅ Search complete: ${_searchResults.length} users processed');
        } else {
          setState(() {
            _searchResults = [];
            _showSearchResults = true;
          });
        }
      } else if (response.statusCode == 401) {
        await _handleUnauthorized();
      } else {
        _showErrorSnackBar('Search failed');
      }
    } catch (e) {
      print('❌ Search Error: $e');
      _showErrorSnackBar('Search failed. Please try again.');
    } finally {
      setState(() => _isSearching = false);
    }
  }

  // ========================================
  // ✅ FRIEND REQUEST METHODS
  // ========================================

  Future<void> _sendFriendRequest(int receiverId, int index) async {
    if (!_isLoggedIn) return;

    try {
      print('📤 Sending friend request to user ID: $receiverId');

      final response = await http
          .post(
            Uri.parse(sendFriendRequestUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_authToken',
              'Accept': 'application/json',
            },
            body: json.encode({'receiver_id': receiverId}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true) {
          setState(() {
            _searchResults[index]['friend_status'] = 'pending';
            _searchResults[index]['request_sent_by_me'] = true;
          });

          _fetchNotificationCountInBackground();
          _showSuccessSnackBar('Friend request sent successfully! ✅');
        } else {
          _showErrorSnackBar(data['message'] ?? 'Failed to send request');
        }
      } else {
        _showErrorSnackBar('Failed to send request');
      }
    } catch (e) {
      print('❌ Send Friend Request Error: $e');
      _showErrorSnackBar('Network error. Please try again.');
    }
  }

  Future<void> _cancelFriendRequest(int receiverId, int index) async {
    if (!_isLoggedIn) return;

    try {
      print('📤 Canceling friend request to user ID: $receiverId');

      final response = await http
          .post(
            Uri.parse(cancelFriendRequestUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_authToken',
              'Accept': 'application/json',
            },
            body: json.encode({'receiver_id': receiverId}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true) {
          setState(() {
            _searchResults[index]['friend_status'] = 'none';
            _searchResults[index]['request_sent_by_me'] = false;
          });

          _fetchNotificationCountInBackground();
          _showSuccessSnackBar('Friend request canceled ✅');
        } else {
          _showErrorSnackBar(data['message'] ?? 'Failed to cancel');
        }
      } else {
        _showErrorSnackBar('Failed to cancel request');
      }
    } catch (e) {
      print('❌ Cancel Friend Request Error: $e');
      _showErrorSnackBar('Network error. Please try again.');
    }
  }

  // ========================================
  // ✅ CAMERA & GALLERY IMAGE PICKER
  // ========================================

  void _showImageSourceDialog() {
    if (!_isLoggedIn) {
      _showErrorSnackBar('Please log in first.');
      return;
    }

    final primaryColor = _primaryColor ?? Colors.blue;
    final secondaryColor = _secondaryColor ?? Colors.blueAccent;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Select Image Source',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [primaryColor, secondaryColor],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.camera_alt, color: Colors.white),
                  ),
                  title: const Text(
                    'Camera',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  subtitle: const Text('Take a new photo'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImageFromCamera();
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [primaryColor, secondaryColor],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.photo_library, color: Colors.white),
                  ),
                  title: const Text(
                    'Gallery',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  subtitle: const Text('Choose from gallery'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImageFromGallery();
                  },
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  // ========================================
  // ✅ PICK IMAGE FROM CAMERA
  // ========================================

  Future<void> _pickImageFromCamera() async {
    if (!_isLoggedIn) {
      _showErrorSnackBar('Please log in first.');
      return;
    }

    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image != null) {
        final imageFile = File(image.path);

        final fileSize = await imageFile.length();
        if (fileSize > 5 * 1024 * 1024) {
          _showErrorSnackBar('Image too large! Max 5MB');
          return;
        }

        print('📸 Camera image captured: ${image.path}');
        setState(() => _showEmojiPicker = false);

        await _sendMessageToAPI('', type: 'image', imageFile: imageFile);
      }
    } catch (e) {
      print('❌ Camera error: $e');
      _showErrorSnackBar('Unable to open camera');
    }
  }

  // ========================================
  // ✅ PICK IMAGE FROM GALLERY
  // ========================================

  Future<void> _pickImageFromGallery() async {
    if (!_isLoggedIn) {
      _showErrorSnackBar('Please log in first.');
      return;
    }

    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image != null) {
        final imageFile = File(image.path);

        final fileSize = await imageFile.length();
        if (fileSize > 5 * 1024 * 1024) {
          _showErrorSnackBar('Image too large! Max 5MB');
          return;
        }

        print('✅ Gallery image selected: ${image.path}');
        setState(() => _showEmojiPicker = false);

        await _sendMessageToAPI('', type: 'image', imageFile: imageFile);
      }
    } catch (e) {
      print('❌ Gallery error: $e');
      _showErrorSnackBar('Unable to select image');
    }
  }

  // ========================================
  // ✅ CHAT MESSAGE SCROLL & FETCH
  // ========================================

  void _scrollListener() {
    if (_scrollController.position.pixels <=
        _scrollController.position.minScrollExtent + 50) {
      if (_hasMoreMessages && !_isLoadingMessages) {
        _loadMoreMessages();
      }
    }
  }

  Future<void> _fetchMessages({int page = 1}) async {
    if (_isLoadingMessages || !_isLoggedIn) return;

    setState(() => _isLoadingMessages = true);

    try {
      print('📤 Fetching messages (page $page)...');

      final response = await http
          .get(
            Uri.parse('$fetchMessagesUrl?page=$page&per_page=20'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_authToken',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 10));

      print('📥 Fetch Messages Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true) {
          final List<dynamic> messagesData = data['data']['messages'] ?? [];
          final pagination = data['data']['pagination'];

          print('📦 Received ${messagesData.length} messages');

          setState(() {
            if (page == 1) {
              _messages = _parseMessages(messagesData);
            } else {
              _messages.insertAll(0, _parseMessages(messagesData));
            }

            _currentPage = pagination['current_page'] ?? 1;
            _totalPages = pagination['last_page'] ?? 1;
            _hasMoreMessages = _currentPage < _totalPages;
          });

          print('✅ Messages loaded successfully');
          if (page == 1) _scrollToBottom();
        }
      } else if (response.statusCode == 401) {
        await _handleUnauthorized();
      }
    } catch (e) {
      print('❌ Fetch Messages Error: $e');
    } finally {
      setState(() => _isLoadingMessages = false);
    }
  }

  List<Map<String, dynamic>> _parseMessages(List<dynamic> messagesData) {
    return messagesData.map((msg) {
      final messageType = msg['message_type'] ?? 'text';
      final rawImageUrl = msg['image_url'];

      String? imageUrl;
      if (messageType == 'image' &&
          rawImageUrl != null &&
          rawImageUrl.toString().isNotEmpty) {
        imageUrl = rawImageUrl.toString();
      }

      return {
        'id': msg['id'],
        'sender': msg['sender_type'] == 'admin' ? 'Admin' : 'You',
        'message': msg['message'] ?? '',
        'time': _formatTime(msg['created_at']),
        'type': messageType,
        'image_url': imageUrl,
        'is_read': msg['is_read'] ?? false,
      };
    }).toList();
  }

  String _formatTime(String? timestamp) {
    if (timestamp == null) return '';
    try {
      final DateTime dateTime = DateTime.parse(timestamp);
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return '';
    }
  }

  Future<void> _loadMoreMessages() async {
    if (_hasMoreMessages && !_isLoadingMessages) {
      await _fetchMessages(page: _currentPage + 1);
    }
  }

  // ====================================================================
  // ✅ ONESIGNAL PUSH NOTIFICATION - PART 4/5 (FIXED DEFAULT AVATAR)
  // ✅ Send Message API, Chat Overlay & Navigation
  // ✅ Lines 2401-3200
  // ====================================================================

  // ========================================
  // ✅ SEND MESSAGE TO API (TEXT OR IMAGE)
  // ========================================

  Future<void> _sendMessageToAPI(
    String message, {
    String type = 'text',
    File? imageFile,
  }) async {
    if (_isSendingMessage || !_isLoggedIn) return;

    setState(() => _isSendingMessage = true);

    String? tempImagePath;
    int? tempMessageId;

    if (type == 'image' && imageFile != null) {
      tempImagePath = imageFile.path;
      tempMessageId = DateTime.now().millisecondsSinceEpoch;

      final tempMessage = {
        'id': tempMessageId,
        'sender': 'You',
        'message': 'Image',
        'time': _formatTime(DateTime.now().toIso8601String()),
        'type': 'image',
        'image_url': null,
        'local_image_path': tempImagePath,
        'is_read': false,
        'is_uploading': true,
      };

      setState(() {
        _messages.add(tempMessage);
      });

      _scrollToBottom();

      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('✅ INSTANT IMAGE PREVIEW ADDED TO CHAT');
      print('📁 Local path: $tempImagePath');
      print('🆔 Temp ID: $tempMessageId');
      print('⏳ Now uploading to server...');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    }

    try {
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('📤 SENDING MESSAGE TO SERVER');
      print('Type: $type');
      if (type == 'text') {
        print('Message: $message');
      } else if (type == 'image' && imageFile != null) {
        print('Image file: ${imageFile.path}');
        print('Image size: ${await imageFile.length()} bytes');
      }
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      var request = http.MultipartRequest('POST', Uri.parse(sendMessageUrl));

      request.headers['Authorization'] = 'Bearer $_authToken';
      request.headers['Accept'] = 'application/json';

      request.fields['message_type'] = type;

      if (type == 'text') {
        request.fields['message'] = message;
      } else if (type == 'image' && imageFile != null) {
        request.fields['message'] = 'Image';

        var imageStream = http.ByteStream(imageFile.openRead());
        var imageLength = await imageFile.length();
        var multipartFile = http.MultipartFile(
          'image',
          imageStream,
          imageLength,
          filename: imageFile.path.split('/').last,
        );
        request.files.add(multipartFile);

        print('✅ Image attached to request');
        print('📁 Will be saved to: uploads/adminchat/');
      }

      print('📡 Sending request to: $sendMessageUrl');
      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 20),
      );
      final response = await http.Response.fromStream(streamedResponse);

      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('📥 UPLOAD RESPONSE');
      print('Status: ${response.statusCode}');
      print('Body: ${response.body}');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);

        if (data['success'] == true) {
          final messageData = data['data'];

          if (type == 'image' && messageData['image_url'] != null) {
            final serverImageUrl = messageData['image_url'];

            print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
            print('✅ IMAGE UPLOADED SUCCESSFULLY!');
            print('📥 Server image_url: "$serverImageUrl"');
            print('📁 Server location: uploads/adminchat/');
            print('🔄 Updating temporary message with server URL...');
            print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

            setState(() {
              final tempMsgIndex = _messages.indexWhere(
                (msg) =>
                    msg['id'] == tempMessageId && msg['is_uploading'] == true,
              );

              if (tempMsgIndex != -1) {
                _messages[tempMsgIndex] = {
                  'id': messageData['id'],
                  'sender': 'You',
                  'message': 'Image',
                  'time': _formatTime(messageData['created_at']),
                  'type': 'image',
                  'image_url': serverImageUrl,
                  'local_image_path': null,
                  'is_read': false,
                  'is_uploading': false,
                };

                print(
                  '✅ Message updated with server URL at index: $tempMsgIndex',
                );
              } else {
                print('⚠️ Could not find temp message to update');
              }
            });

            _showSuccessSnackBar('Image uploaded successfully! ✅');
          } else if (type == 'text') {
            final newMessage = {
              'id': messageData['id'],
              'sender': 'You',
              'message': message,
              'time': _formatTime(messageData['created_at']),
              'type': 'text',
              'image_url': null,
              'is_read': false,
            };

            setState(() {
              _messages.add(newMessage);
            });

            _scrollToBottom();
            _showSuccessSnackBar('Message sent ✅');
          }
        } else {
          print('⚠️ API returned success=false');

          if (type == 'image' && tempMessageId != null) {
            setState(() {
              _messages.removeWhere(
                (msg) =>
                    msg['id'] == tempMessageId && msg['is_uploading'] == true,
              );
            });
          }

          _showErrorSnackBar(data['message'] ?? 'Failed to send message');
        }
      } else {
        print('❌ HTTP Error: ${response.statusCode}');

        if (type == 'image' && tempMessageId != null) {
          setState(() {
            _messages.removeWhere(
              (msg) =>
                  msg['id'] == tempMessageId && msg['is_uploading'] == true,
            );
          });
        }

        _showErrorSnackBar('Error: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Send Message Error: $e');

      if (type == 'image' && tempMessageId != null) {
        setState(() {
          _messages.removeWhere(
            (msg) => msg['id'] == tempMessageId && msg['is_uploading'] == true,
          );
        });
      }

      _showErrorSnackBar('Failed to send message');
    } finally {
      setState(() => _isSendingMessage = false);
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _startMessageRefresh() {
    _messageRefreshTimer?.cancel();
    _messageRefreshTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_isChatOpen && !_isLoadingMessages && _isLoggedIn) {
        _fetchMessages(page: 1);
      }
    });
  }

  void _stopMessageRefresh() {
    _messageRefreshTimer?.cancel();
  }

  void _copyReferralCode() {
    Clipboard.setData(ClipboardData(text: _referralCode));
    _showSuccessSnackBar('Referral code copied successfully! 📋');
  }

  void _toggleChat() async {
    if (_isLoadingAuth) {
      _showErrorSnackBar('Please Wait...');
      return;
    }

    await _refreshAuthStatus();

    if (!_isLoggedIn) {
      _showErrorSnackBar('Please log in first to start chatting.');
      return;
    }

    setState(() => _isChatOpen = !_isChatOpen);

    if (_isChatOpen) {
      _fetchMessages(page: 1);
      _startMessageRefresh();
    } else {
      _stopMessageRefresh();
    }
  }

  void _toggleBalance() =>
      setState(() => _isBalanceVisible = !_isBalanceVisible);
  void _toggleEmojiPicker() =>
      setState(() => _showEmojiPicker = !_showEmojiPicker);

  void _addEmoji(String emoji) => _chatController.text += emoji;

  void _sendMessage() {
    if (_chatController.text.trim().isEmpty || !_isLoggedIn) return;

    final messageText = _chatController.text.trim();
    _chatController.clear();
    setState(() => _showEmojiPicker = false);

    _sendMessageToAPI(messageText, type: 'text');
  }

  void _navigateToProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfilePage()),
    );
  }

  void _onBottomNavTap(int index) async {
    setState(() => _selectedIndex = index);

    switch (index) {
      case 0:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ProfilePage()),
        );
        break;
      case 1:
        try {
          SharedPreferences prefs = await SharedPreferences.getInstance();
          String? token = prefs.getString('auth_token');

          if (token != null && token.isNotEmpty) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => WithdrawScreen(authToken: token),
              ),
            );
          } else {
            _showErrorSnackBar("Please login first");
          }
        } catch (e) {
          print('❌ Error loading token: $e');
          _showErrorSnackBar("Please login first");
        }
        break;
      case 3:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => UserLiveChatScreen()),
        );
        break;
      case 4:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AgentListScreen()),
        );
        break;
    }
  }

  // ========================================
  // ✅ UI BUILD METHODS
  // ========================================

  @override
  Widget build(BuildContext context) {
    if (_isLoadingAuth) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: _primaryColor ?? Colors.blue),
              const SizedBox(height: 16),
              const Text('Loading...', style: TextStyle(fontSize: 16)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: _buildAppBar(),
      drawer: _buildDrawer(),
      body: Stack(
        children: [
          _buildHomeContent(),
          if (_isChatOpen) _buildChatOverlay(),
          if (_showSearchResults) _buildSearchResultsOverlay(),
        ],
      ),
      bottomNavigationBar: _buildBottomNavBar(),
      floatingActionButton: _isChatOpen ? null : _buildChatFAB(),
    );
  }

  // ========================================
  // ✅ APPBAR WITH NOTIFICATION BADGES
  // ========================================

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: Builder(
        builder: (context) => IconButton(
          icon: const Icon(Icons.menu, color: Colors.black),
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
      ),
      title: _buildSearchBox(),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.orange),
          onPressed: _refreshAuthStatus,
          tooltip: 'Refresh',
        ),
        // ✅ Friend Request Notification Badge
        Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.people_outline, color: Colors.black),
              onPressed: () async {
                try {
                  final prefs = await SharedPreferences.getInstance();
                  String? token = prefs.getString('auth_token');

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FriendRequestsPage(authToken: token),
                    ),
                  ).then((_) {
                    _fetchNotificationCountInBackground();
                  });
                } catch (e) {
                  print('❌ Error getting token: $e');
                }
              },
            ),
            if (_notificationCount > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  child: Text(
                    _notificationCount > 99 ? '99+' : '$_notificationCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
        // ✅ OneSignal Push Notification Badge
        Stack(
          children: [
            IconButton(
              icon: const Icon(
                Icons.notifications_outlined,
                color: Colors.black,
              ),
              onPressed: () {
                _showNotificationsDialog();
                setState(() => _notificationBadgeCount = 0);
              },
            ),
            if (_notificationBadgeCount > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.orange,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  child: Text(
                    _notificationBadgeCount > 99
                        ? '99+'
                        : '$_notificationBadgeCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildSearchBox() {
    final searchButtonColor = _searchButtonColor ?? Colors.blue;

    return Row(
      children: [
        Expanded(
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: _typingText,
                        hintStyle: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 10,
                        ),
                      ),
                      style: const TextStyle(fontSize: 14),
                      onSubmitted: (value) {
                        if (value.trim().isNotEmpty) {
                          _searchUsers(value.trim());
                        }
                      },
                    ),
                  ),
                ),
                if (_isSearching)
                  Container(
                    margin: const EdgeInsets.all(4),
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: searchButtonColor,
                    ),
                  )
                else
                  Container(
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          searchButtonColor,
                          searchButtonColor.withOpacity(0.8),
                        ],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.search,
                        color: Colors.white,
                        size: 20,
                      ),
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        if (_searchController.text.trim().isNotEmpty) {
                          _searchUsers(_searchController.text.trim());
                        }
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ========================================
  // ✅ CHAT OVERLAY
  // ========================================

  Widget _buildChatOverlay() {
    return Positioned.fill(
      child: GestureDetector(
        onTap: () {},
        child: Container(
          color: Colors.black.withOpacity(0.3),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: MediaQuery.of(context).size.height * 0.65,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildChatHeader(),
                  _buildChatMessages(),
                  if (_showEmojiPicker) _buildEmojiPicker(),
                  _buildChatInput(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChatHeader() {
    final primaryColor = _primaryColor ?? Colors.blue;
    final secondaryColor = _secondaryColor ?? Colors.blueAccent;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [primaryColor, secondaryColor]),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: _toggleChat,
          ),
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.white,
            child: Text(
              'A',
              style: TextStyle(
                color: primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Live Chat Support',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Online',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () => _fetchMessages(page: 1),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: _toggleChat,
          ),
        ],
      ),
    );
  }

  // ========================================
  // ✅ BOTTOM NAVIGATION BAR
  // ========================================

  Widget _buildBottomNavBar() {
    final primaryColor = _primaryColor ?? Colors.blue;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300,
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onBottomNavTap,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: primaryColor,
        unselectedItemColor: Colors.grey,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        elevation: 0,
        backgroundColor: Colors.white,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet),
            label: 'Withdraw',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Friend Chat'),
          BottomNavigationBarItem(
            icon: Icon(Icons.support_agent),
            label: 'Agent',
          ),
        ],
      ),
    );
  }

  // ========================================
  // ✅ FLOATING ACTION BUTTON
  // ========================================

  Widget _buildChatFAB() {
    final primaryColor = _primaryColor ?? Colors.blue;

    return FloatingActionButton(
      onPressed: _toggleChat,
      backgroundColor: primaryColor,
      child: const Icon(Icons.chat, color: Colors.white),
    );
  }

  // ====================================================================
  // ✅ ONESIGNAL PUSH NOTIFICATION - PART 5/5 (FINAL - FIXED DEFAULT AVATAR)
  // ✅ Drawer, Home UI, Chat Messages & Custom Widgets
  // ✅ Lines 3201-END
  // ====================================================================

  // ========================================
  // ✅ SEARCH RESULTS OVERLAY WITH DEFAULT AVATAR SUPPORT
  // ========================================

  Widget _buildSearchResultsOverlay() {
    final primaryColor = _primaryColor ?? Colors.blue;
    final secondaryColor = _secondaryColor ?? Colors.blueAccent;

    return Positioned.fill(
      child: Material(
        color: Colors.black.withOpacity(0.5),
        child: GestureDetector(
          onTap: () {
            setState(() {
              _showSearchResults = false;
              _searchController.clear();
            });
          },
          child: Center(
            child: GestureDetector(
              onTap: () {},
              child: Container(
                width: MediaQuery.of(context).size.width * 0.9,
                height: MediaQuery.of(context).size.height * 0.7,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [primaryColor, secondaryColor],
                        ),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Search Results',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white),
                            onPressed: () {
                              setState(() {
                                _showSearchResults = false;
                                _searchController.clear();
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _searchResults.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.search_off,
                                    size: 64,
                                    color: Colors.grey.shade400,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No user found',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _searchResults.length,
                              itemBuilder: (context, index) {
                                final user = _searchResults[index];
                                return _buildSearchUserCard(user, index);
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// ✅ CRITICAL: Search User Card with proper avatar display (default avatar support)
  Widget _buildSearchUserCard(Map<String, dynamic> user, int index) {
    final primaryColor = _primaryColor ?? Colors.blue;

    final friendStatus = user['friend_status'] ?? 'none';
    final requestSentByMe = user['request_sent_by_me'] ?? false;

    String buttonText = 'Add Friend';
    Color buttonColor = primaryColor;
    IconData buttonIcon = Icons.person_add;
    VoidCallback? onPressed;

    if (friendStatus == 'friend' || friendStatus == 'accepted') {
      buttonText = 'Message';
      buttonColor = Colors.green;
      buttonIcon = Icons.chat;
      onPressed = () {
        setState(() => _showSearchResults = false);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const UserLiveChatScreen()),
        );
      };
    } else if (friendStatus == 'pending' && requestSentByMe) {
      buttonText = 'Cancel';
      buttonColor = Colors.orange;
      buttonIcon = Icons.cancel;
      onPressed = () => _cancelFriendRequest(user['id'], index);
    } else if (friendStatus == 'pending' && !requestSentByMe) {
      buttonText = 'Accept';
      buttonColor = Colors.blue;
      buttonIcon = Icons.check;
      onPressed = () async {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('auth_token');

        if (token == null || token.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please login first'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() => _showSearchResults = false);
          return;
        }

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FriendRequestsPage(authToken: token),
          ),
        );
        setState(() => _showSearchResults = false);
      };
    } else {
      onPressed = () => _sendFriendRequest(user['id'], index);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade100,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // ✅ CRITICAL: Use _buildUserPhotoAvatar with default avatar support
            _buildUserPhotoAvatar(
              photoUrl:
                  user['photo'], // This will be defaultAvatarUrl if no photo
              userName: user['name'],
              size: 60,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user['name'] ?? 'Unknown',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              decoration: BoxDecoration(
                gradient: onPressed != null
                    ? LinearGradient(
                        colors: [buttonColor, buttonColor.withOpacity(0.8)],
                      )
                    : null,
                color: onPressed == null ? Colors.grey.shade300 : null,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onPressed,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(buttonIcon, size: 18, color: Colors.white),
                        const SizedBox(width: 6),
                        Text(
                          buttonText,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ========================================
  // ✅ DRAWER WITH ONESIGNAL STATUS
  // ========================================

  Drawer _buildDrawer() {
    final primaryColor = _primaryColor ?? Colors.blue;
    final secondaryColor = _secondaryColor ?? Colors.blueAccent;

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [primaryColor, secondaryColor]),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Text(
                  "globalmoneyltd",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _isLoggedIn
                            ? Colors.green.withOpacity(0.3)
                            : Colors.red.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isLoggedIn ? Icons.check_circle : Icons.cancel,
                            color: Colors.white,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _isLoggedIn ? 'Logged In' : 'Please Login',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // ✅ OneSignal Notification Status
                    if (_isLoggedIn && _oneSignalInitialized)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _notificationPermissionGranted
                              ? Colors.blue.withOpacity(0.3)
                              : Colors.orange.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _notificationPermissionGranted
                                  ? Icons.notifications_active
                                  : Icons.notifications_off,
                              color: Colors.white,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _notificationPermissionGranted
                                  ? 'Push ON'
                                  : 'Push OFF',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
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
          ListTile(
            leading: Icon(Icons.person, color: primaryColor),
            title: const Text("Profile"),
            onTap: () {
              Navigator.pop(context);
              _navigateToProfile();
            },
          ),
          ListTile(
            leading: Icon(Icons.money, color: primaryColor),
            title: const Text("Withdraw"),
            onTap: () async {
              Navigator.pop(context);
              try {
                SharedPreferences prefs = await SharedPreferences.getInstance();
                String? token = prefs.getString('auth_token');

                if (token != null && token.isNotEmpty) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => WithdrawScreen(authToken: token),
                    ),
                  );
                } else {
                  _showErrorSnackBar("Please login first");
                }
              } catch (e) {
                print('❌ Error loading token: $e');
                _showErrorSnackBar("Please login first");
              }
            },
          ),
          ListTile(
            leading: Stack(
              children: [
                Icon(Icons.people, color: primaryColor),
                if (_notificationCount > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 12,
                        minHeight: 12,
                      ),
                      child: Text(
                        _notificationCount > 9 ? '9+' : '$_notificationCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            title: const Text("Friend Requests"),
            onTap: () async {
              Navigator.pop(context);

              final prefs = await SharedPreferences.getInstance();
              final token = prefs.getString('auth_token');

              if (token == null || token.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please login first'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FriendRequestsPage(authToken: token),
                ),
              ).then((_) {
                _fetchNotificationCountInBackground();
              });
            },
          ),
          // ✅ OneSignal Notifications Menu Item
          ListTile(
            leading: Stack(
              children: [
                Icon(Icons.notifications_active, color: primaryColor),
                if (_notificationBadgeCount > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.orange,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 12,
                        minHeight: 12,
                      ),
                      child: Text(
                        _notificationBadgeCount > 9
                            ? '9+'
                            : '$_notificationBadgeCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            title: const Text("Push Notifications"),
            trailing: _notificationBadgeCount > 0
                ? Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$_notificationBadgeCount new',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                : null,
            onTap: () {
              Navigator.pop(context);
              _showNotificationsDialog();
              setState(() => _notificationBadgeCount = 0);
            },
          ),
          ListTile(
            leading: Icon(Icons.add_card, color: primaryColor),
            title: const Text("Add Balance"),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => AddBalancePage()),
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.card_membership, color: primaryColor),
            title: const Text("Membership"),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => MembershipPage()),
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.settings, color: primaryColor),
            title: const Text("Agent Registration"),
            onTap: () async {
              Navigator.pop(context);
              final Uri url = Uri.parse(ApiConfig.agentLoginUrl);
              try {
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.inAppBrowserView);
                } else {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                }
              } catch (e) {
                try {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                } catch (err) {
                  debugPrint('URL launch error: $err');
                }
              }
            },
          ),
          ListTile(
            leading: Icon(Icons.privacy_tip, color: primaryColor),
            title: const Text("Privacy & Policy"),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => PrivacyPolicyScreen()),
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.description, color: primaryColor),
            title: const Text("Terms & Conditions"),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => TermsAndConditionsScreen()),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: Icon(
              _isLoggedIn ? Icons.logout : Icons.login,
              color: _isLoggedIn ? Colors.red : Colors.green,
            ),
            title: Text(
              _isLoggedIn ? "Log Out" : "Log In",
              style: TextStyle(color: _isLoggedIn ? Colors.red : Colors.green),
            ),
            onTap: () async {
              if (_isLoggedIn) {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Logout'),
                    content: const Text('Are you sure you want to logout?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () async {
                          try {
                            SharedPreferences prefs =
                                await SharedPreferences.getInstance();
                            await prefs.remove('auth_token');
                            await prefs.remove(
                              'onesignal_player_id',
                            ); // ✅ Clear OneSignal ID
                          } catch (e) {
                            print('❌ Error clearing token: $e');
                          }

                          setState(() {
                            _isLoggedIn = false;
                            _authToken = null;
                            _userEmail = null;
                          });

                          // ✅ Logout from OneSignal
                          if (_oneSignalInitialized) {
                            try {
                              OneSignal.logout();
                              print('✅ OneSignal logout successful');
                            } catch (e) {
                              print('⚠️ OneSignal logout error: $e');
                            }
                          }

                          Navigator.pop(context);
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const LoginScreen(),
                            ),
                            (route) => false,
                          );
                          _showSuccessSnackBar('Logged out successfully');
                        },
                        child: const Text(
                          'Logout',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                );
              } else {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  // ========================================
  // ✅ HOME CONTENT
  // ========================================

  Widget _buildHomeContent() {
    return SafeArea(
      child: Column(
        children: [
          _buildHomeUserCard(),
          const SizedBox(height: 24),
          _buildDashboardGrid(),
        ],
      ),
    );
  }

  // ========================================
  // ✅ HOME USER CARD WITH DEFAULT AVATAR SUPPORT
  // ========================================

  Widget _buildHomeUserCard() {
    final headerSetting = _homeCardSettings['header'];
    Color headerBg = _primaryColor ?? Colors.blue;
    Color headerSecondary = _secondaryColor ?? Colors.blueAccent;
    Color? customHeaderTextColor;

    if (headerSetting != null) {
      if (headerSetting['bg_color'] != null && headerSetting['bg_color'].toString().isNotEmpty) {
        headerBg = _parseColor(headerSetting['bg_color'].toString());
        headerSecondary = _generateSecondaryColor(headerBg);
      }
      final String? textCol = (headerSetting['text_color'] ?? headerSetting['title_color'])?.toString();
      if (textCol != null && textCol.isNotEmpty) {
        customHeaderTextColor = _parseColor(textCol);
      }
    }

    final double bgLuminance = headerBg.computeLuminance();
    final bool isLightHeader = bgLuminance > 0.45;
    Color textColor = customHeaderTextColor ?? (isLightHeader ? const Color(0xFF1D1B1B) : Colors.white);
    if (isLightHeader && textColor.computeLuminance() > 0.6) {
      textColor = const Color(0xFF1D1B1B);
    } else if (!isLightHeader && textColor.computeLuminance() < 0.2) {
      textColor = Colors.white;
    }
    final Color subTextColor = textColor.withOpacity(isLightHeader ? 0.85 : 0.75);

    return GestureDetector(
      onTap: _toggleBalance,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [headerBg, headerSecondary]),
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(24),
            bottomRight: Radius.circular(24),
          ),
        ),
        child: Row(
          children: [
            // ✅ CRITICAL: Use _buildUserPhotoAvatar with default avatar support
            _buildUserPhotoAvatar(
              photoUrl:
                  _profilePhotoUrl, // Will show defaultAvatarUrl if no photo
              userName: _userName,
              size: 60,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _userName,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _StatusBadge(
                        label: _isKycApproved ? "Verified" : "Unverified",
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: _copyReferralCode,
                    child: Row(
                      children: [
                        Text(
                          _referralCode,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.copy, color: subTextColor, size: 14),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  AnimatedCrossFade(
                    firstChild: Row(
                      children: [
                        Text(
                          "Tap to view balance",
                          style: TextStyle(color: textColor, fontSize: 12),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.keyboard_arrow_down,
                          color: textColor,
                          size: 16,
                        ),
                      ],
                    ),
                    secondChild: Row(
                      children: [
                        Text(
                          "Balance: ",
                          style: TextStyle(color: subTextColor, fontSize: 12),
                        ),
                        Text(
                          "\$$_userBalance",
                          style: TextStyle(
                            color: textColor,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.keyboard_arrow_up,
                          color: textColor,
                          size: 16,
                        ),
                      ],
                    ),
                    crossFadeState: _isBalanceVisible
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    duration: const Duration(milliseconds: 300),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ========================================
  // ✅ DASHBOARD GRID
  // ========================================

  Widget _buildCardButton({
    required String key,
    required IconData defaultIcon,
    required String defaultTitle,
    required VoidCallback onTap,
    required Color primaryColor,
    required Color secondaryColor,
  }) {
    final setting = _homeCardSettings[key];
    final String label = (setting != null && setting['title'] != null && setting['title'].toString().isNotEmpty)
        ? setting['title'].toString()
        : defaultTitle;

    final IconData icon = (setting != null && setting['icon'] != null && setting['icon'].toString().isNotEmpty)
        ? AppService.getIconData(setting['icon'].toString(), fallback: defaultIcon)
        : defaultIcon;

    Color? customBgColor;
    if (setting != null && setting['bg_color'] != null && setting['bg_color'].toString().isNotEmpty) {
      customBgColor = _parseColor(setting['bg_color'].toString());
    }

    Color? customIconColor;
    if (setting != null && setting['icon_color'] != null && setting['icon_color'].toString().isNotEmpty) {
      customIconColor = _parseColor(setting['icon_color'].toString());
    }

    Color? customTextColor;
    if (setting != null) {
      final String? colorStr = (setting['text_color'] ?? setting['title_color'])?.toString();
      if (colorStr != null && colorStr.isNotEmpty) {
        customTextColor = _parseColor(colorStr);
      }
    }

    String? imageUrl;
    final String? iconType = setting != null ? setting['icon_type']?.toString() : null;
    final String? imgPath = setting != null ? (setting['image_url'] ?? setting['image'])?.toString() : null;
    if (iconType == 'image' && imgPath != null && imgPath.isNotEmpty) {
      imageUrl = ApiConfig.mediaUrl(imgPath);
    }

    return _DashboardButton(
      icon: icon,
      imageUrl: imageUrl,
      label: label,
      onTap: onTap,
      primaryColor: primaryColor,
      secondaryColor: secondaryColor,
      customBgColor: customBgColor,
      customIconColor: customIconColor,
      customTextColor: customTextColor,
    );
  }

  Widget _buildDashboardGrid() {
    final primaryColor = _primaryColor ?? Colors.blue;
    final secondaryColor = _secondaryColor ?? Colors.blueAccent;

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: GridView.count(
          crossAxisCount: 3,
          mainAxisSpacing: 20,
          crossAxisSpacing: 20,
          children: [
            _buildCardButton(
              key: "start_task",
              defaultIcon: Icons.task_alt,
              defaultTitle: "Start Task",
              onTap: _handleStartTaskClick,
              primaryColor: primaryColor,
              secondaryColor: secondaryColor,
            ),
            _buildCardButton(
              key: "profile",
              defaultIcon: Icons.person,
              defaultTitle: "Profile",
              onTap: _navigateToProfile,
              primaryColor: primaryColor,
              secondaryColor: secondaryColor,
            ),
            _buildCardButton(
              key: "refer",
              defaultIcon: Icons.card_giftcard,
              defaultTitle: "Refer",
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ReferralScreen()),
              ),
              primaryColor: primaryColor,
              secondaryColor: secondaryColor,
            ),
            _buildCardButton(
              key: "option",
              defaultIcon: Icons.settings,
              defaultTitle: "Option",
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => OptionsPage()),
              ),
              primaryColor: primaryColor,
              secondaryColor: secondaryColor,
            ),
            _buildCardButton(
              key: "friend_request",
              defaultIcon: Icons.people,
              defaultTitle: "Friend Request",
              onTap: () async {
                final prefs = await SharedPreferences.getInstance();
                final token = prefs.getString('auth_token');

                if (token == null || token.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please login first'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => FriendRequestsPage(authToken: token),
                  ),
                ).then((_) {
                  _fetchNotificationCountInBackground();
                });
              },
              primaryColor: primaryColor,
              secondaryColor: secondaryColor,
            ),
            _buildCardButton(
              key: "withdraw",
              defaultIcon: Icons.money,
              defaultTitle: "Withdraw",
              onTap: () async {
                final prefs = await SharedPreferences.getInstance();
                final token = prefs.getString('auth_token');

                if (token == null || token.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please login first'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => WithdrawScreen(authToken: token),
                  ),
                ).then((_) {
                  _fetchNotificationCountInBackground();
                });
              },
              primaryColor: primaryColor,
              secondaryColor: secondaryColor,
            ),
            _buildCardButton(
              key: "p2p",
              defaultIcon: Icons.swap_horiz,
              defaultTitle: "P2P",
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => P2PPage()),
              ),
              primaryColor: primaryColor,
              secondaryColor: secondaryColor,
            ),
            _buildCardButton(
              key: "how_to_work",
              defaultIcon: Icons.info,
              defaultTitle: "How To Work",
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => WhyChooseUs()),
              ),
              primaryColor: primaryColor,
              secondaryColor: secondaryColor,
            ),
            _buildCardButton(
              key: "total_deposit",
              defaultIcon: Icons.attach_money,
              defaultTitle: "Total Deposit",
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => DepositScreen()),
              ),
              primaryColor: primaryColor,
              secondaryColor: secondaryColor,
            ),
            _buildCardButton(
              key: "support",
              defaultIcon: Icons.support_agent,
              defaultTitle: "Support",
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => SupportCenterPage()),
              ),
              primaryColor: primaryColor,
              secondaryColor: secondaryColor,
            ),
            _buildCardButton(
              key: "social_post",
              defaultIcon: Icons.public,
              defaultTitle: "SocialPost",
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => SocialFeedScreen()),
              ),
              primaryColor: primaryColor,
              secondaryColor: secondaryColor,
            ),
            _buildCardButton(
              key: "total_withdraw",
              defaultIcon: Icons.account_balance_wallet,
              defaultTitle: "Total Withdraw",
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => MyWithdrawalScreen()),
              ),
              primaryColor: primaryColor,
              secondaryColor: secondaryColor,
            ),
          ],
        ),
      ),
    );
  }

  // ========================================
  // ✅ CHAT MESSAGES DISPLAY
  // ========================================

  Widget _buildChatMessages() {
    final primaryColor = _primaryColor ?? Colors.blue;

    return Expanded(
      child: Container(
        color: Colors.grey.shade100,
        child: _isLoadingMessages && _messages.isEmpty
            ? Center(child: CircularProgressIndicator(color: primaryColor))
            : _messages.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.chat_bubble_outline,
                      size: 64,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No messages available.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final message = _messages[index];
                  final isAdmin = message['sender'] == 'Admin';
                  final isUser = message['sender'] == 'You';

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      mainAxisAlignment: isUser
                          ? MainAxisAlignment.end
                          : MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isAdmin)
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: primaryColor,
                            child: const Text(
                              'A',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        if (isAdmin) const SizedBox(width: 8),
                        Flexible(
                          child: Column(
                            crossAxisAlignment: isUser
                                ? CrossAxisAlignment.end
                                : CrossAxisAlignment.start,
                            children: [
                              if (isAdmin)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        primaryColor,
                                        primaryColor.withOpacity(0.8),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text(
                                    'Admin',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 4),
                              Container(
                                padding: message['type'] == 'image'
                                    ? const EdgeInsets.all(4)
                                    : const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  gradient: isUser
                                      ? LinearGradient(
                                          colors: [
                                            primaryColor.withOpacity(0.2),
                                            primaryColor.withOpacity(0.1),
                                          ],
                                        )
                                      : null,
                                  color: isUser ? null : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.grey.shade300,
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: message['type'] == 'image'
                                    ? _buildImageMessage(message, primaryColor)
                                    : Text(
                                        message['message']!,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Colors.black87,
                                        ),
                                      ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    message['time'] ?? '',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  if (isUser) const SizedBox(width: 4),
                                  if (isUser)
                                    Icon(
                                      message['is_read']
                                          ? Icons.done_all
                                          : Icons.done,
                                      size: 14,
                                      color: message['is_read']
                                          ? Colors.blue
                                          : Colors.grey.shade600,
                                    ),
                                  if (message['is_uploading'] == true) ...[
                                    const SizedBox(width: 4),
                                    SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (isUser) const SizedBox(width: 8),
                        if (isUser)
                          // ✅ CRITICAL: Use _buildUserPhotoAvatar
                          _buildUserPhotoAvatar(
                            photoUrl: _profilePhotoUrl,
                            userName: _userName,
                            size: 36,
                          ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _buildImageMessage(Map<String, dynamic> message, Color primaryColor) {
    final localPath = message['local_image_path'];
    final serverUrl = message['image_url'];
    final isUploading = message['is_uploading'] == true;

    if (isUploading && localPath != null) {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(File(localPath), width: 200, fit: BoxFit.cover),
          ),
          Positioned(
            bottom: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Uploading...',
                    style: TextStyle(color: Colors.white, fontSize: 10),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    if (serverUrl != null) {
      return GestureDetector(
        onTap: () {
          showDialog(
            context: context,
            builder: (context) => Dialog(
              backgroundColor: Colors.black,
              child: Stack(
                children: [
                  Center(
                    child: Image.network(
                      serverUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) =>
                          const Center(
                            child: Icon(
                              Icons.broken_image,
                              color: Colors.white,
                              size: 100,
                            ),
                          ),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: IconButton(
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 30,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            serverUrl,
            width: 200,
            height: 200,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              width: 200,
              height: 200,
              color: Colors.grey.shade200,
              child: const Center(child: Icon(Icons.broken_image, size: 50)),
            ),
          ),
        ),
      );
    }

    return Container(
      width: 200,
      height: 200,
      color: Colors.grey.shade200,
      child: const Center(child: Icon(Icons.image, size: 50)),
    );
  }

  Widget _buildEmojiPicker() {
    return Container(
      height: 200,
      color: Colors.grey.shade100,
      child: GridView.builder(
        padding: const EdgeInsets.all(8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 8,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
        ),
        itemCount: _emojis.length,
        itemBuilder: (context, index) => GestureDetector(
          onTap: () => _addEmoji(_emojis[index]),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(_emojis[index], style: const TextStyle(fontSize: 24)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChatInput() {
    final primaryColor = _primaryColor ?? Colors.blue;
    final secondaryColor = _secondaryColor ?? Colors.blueAccent;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300,
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              icon: Icon(
                _showEmojiPicker
                    ? Icons.keyboard
                    : Icons.emoji_emotions_outlined,
                color: primaryColor,
              ),
              onPressed: _toggleEmojiPicker,
            ),
            IconButton(
              icon: Icon(Icons.camera_alt, color: primaryColor),
              onPressed: _showImageSourceDialog,
              tooltip: 'Camera/Gallery',
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _chatController,
                  decoration: const InputDecoration(
                    hintText: 'Type a message...',
                    border: InputBorder.none,
                    isDense: true,
                  ),
                  maxLines: null,
                  textInputAction: TextInputAction.newline,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [primaryColor, secondaryColor],
                ),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: _isSendingMessage
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send, color: Colors.white),
                onPressed: _isSendingMessage ? null : _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }
} // End of _HomePageState class

// ====================================================================
// ✅ CUSTOM WIDGETS
// ====================================================================

class _StatusBadge extends StatelessWidget {
  final String label;
  const _StatusBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _DashboardButton extends StatelessWidget {
  final IconData icon;
  final String? imageUrl;
  final String label;
  final VoidCallback onTap;
  final Color primaryColor;
  final Color secondaryColor;
  final Color? customBgColor;
  final Color? customIconColor;
  final Color? customTextColor;

  const _DashboardButton({
    required this.icon,
    this.imageUrl,
    required this.label,
    required this.onTap,
    required this.primaryColor,
    required this.secondaryColor,
    this.customBgColor,
    this.customIconColor,
    this.customTextColor,
  });

  @override
  Widget build(BuildContext context) {
    final bgColors = customBgColor != null
        ? [customBgColor!, customBgColor!]
        : [primaryColor, secondaryColor];
    final shadowColor = customBgColor ?? primaryColor;

    // Check if background is light or dark to guarantee readable text & clean icon background
    final double bgLuminance = customBgColor != null
        ? customBgColor!.computeLuminance()
        : primaryColor.computeLuminance();
    final bool isLightBg = bgLuminance > 0.45;

    Color effectiveTextColor = customTextColor ??
        (isLightBg ? const Color(0xFF1D1B1B) : Colors.white);

    // ✅ CRITICAL FAILSAFE: If text color is white/near-white AND card background is light, override to dark text!
    if (isLightBg && effectiveTextColor.computeLuminance() > 0.6) {
      effectiveTextColor = const Color(0xFF1D1B1B);
    } else if (!isLightBg && effectiveTextColor.computeLuminance() < 0.2) {
      effectiveTextColor = Colors.white;
    }

    Color effectiveIconColor = customIconColor ??
        (isLightBg ? const Color(0xFF1D1B1B) : Colors.white);

    // ✅ CRITICAL FAILSAFE: If icon color is white/near-white AND card background is light, override icon color to dark!
    if (isLightBg && effectiveIconColor.computeLuminance() > 0.6) {
      effectiveIconColor = const Color(0xFF1D1B1B);
    } else if (!isLightBg && effectiveIconColor.computeLuminance() < 0.2) {
      effectiveIconColor = Colors.white;
    }

    final Color iconBoxBg = isLightBg
        ? (customIconColor != null ? customIconColor!.withOpacity(0.12) : Colors.black.withOpacity(0.06))
        : Colors.white.withOpacity(0.2);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: bgColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: shadowColor.withOpacity(0.25),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconBoxBg,
                shape: BoxShape.circle,
              ),
              child: (imageUrl != null && imageUrl!.isNotEmpty)
                  ? Image.network(
                      imageUrl!,
                      width: 28,
                      height: 28,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) =>
                          Icon(icon, color: effectiveIconColor, size: 28),
                    )
                  : Icon(icon, color: effectiveIconColor, size: 28),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: effectiveTextColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
