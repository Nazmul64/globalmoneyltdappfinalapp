// ====================================================================
// 🚀 MAIN APP (OneSignal + Firebase Together)
// 📁 lib/main.dart
// ====================================================================

import 'package:flutter/material.dart';
import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/onesignal_notification_service.dart';
import 'services/firebase_notification_service.dart';
import 'services/app_service.dart';
import 'login.dart';
import 'home_page.dart';
import 'friend_request.dart';
import 'screens/support_live_chat_screen.dart';
import 'p2p.dart';
import 'socialpost.dart';
import 'p2p_withdraw_history.dart';
import 'total_deposite.dart';
import 'notification_service.dart';

// ====================================================================
// 🔥 FIREBASE BACKGROUND MESSAGE HANDLER
// ====================================================================
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundMessageHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('🔥 Firebase Background Message: ${message.notification?.title}');
}

void main() async {
  // ✅ CRITICAL: Must call first
  WidgetsFlutterBinding.ensureInitialized();

  try {
    debugPrint('═══════════════════════════════════════════════════');
    debugPrint('🚀 APP STARTING');
    debugPrint('═══════════════════════════════════════════════════');

    // ✅ STEP 1: Initialize Firebase
    debugPrint('🔥 Initializing Firebase...');
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundMessageHandler);
    debugPrint('✅ Firebase initialized');

    // ✅ STEP 2, 3, 4: Concurrently initialize Notification Services & App Theme for sub-1s boot
    debugPrint('⚡ Initializing Services in Parallel...');
    await Future.wait([
      FirebaseNotificationService().initialize(),
      OneSignalNotificationService().initialize(),
      AppService().preloadTheme(),
    ]);

    debugPrint('═══════════════════════════════════════════════════');
    debugPrint('✅ ALL SERVICES INITIALIZED SUCCESSFULLY');
    debugPrint('   - Firebase ✓');
    debugPrint('   - Firebase Messaging ✓');
    debugPrint('   - OneSignal ✓');
    debugPrint('   - App Theme ✓');
    debugPrint('═══════════════════════════════════════════════════');
  } catch (e, stack) {
    debugPrint('❌ App initialization error: $e');
    debugPrint('Stack: $stack');
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription<Map<String, dynamic>>? _oneSignalSubscription;
  StreamSubscription<Map<String, dynamic>>? _firebaseSubscription;

  @override
  void initState() {
    super.initState();

    // ✅ Setup notification listeners after widget tree builds
    Future.delayed(const Duration(milliseconds: 300), () {
      _initNotificationListeners();
    });
  }

  @override
  void dispose() {
    _oneSignalSubscription?.cancel();
    _firebaseSubscription?.cancel();
    super.dispose();
  }

  // ====================================================================
  // 🔔 INIT NOTIFICATION LISTENERS (Both Services)
  // ====================================================================
  void _initNotificationListeners() {
    try {
      debugPrint('═══════════════════════════════════════════════════');
      debugPrint('🔔 SETTING UP NOTIFICATION LISTENERS');
      debugPrint('═══════════════════════════════════════════════════');

      // ✅ OneSignal Listener
      final oneSignalService = OneSignalNotificationService();
      _oneSignalSubscription = oneSignalService.onNotificationClick.listen(
            (data) {
          debugPrint('═══════════════════════════════════════════════════');
          debugPrint('🔔 ONESIGNAL NOTIFICATION CLICKED');
          debugPrint('   Title: ${data['title']}');
          debugPrint('   Body: ${data['body']}');
          debugPrint('   Data: ${data['data']}');
          debugPrint('═══════════════════════════════════════════════════');

          _handleNotificationClick(data);
        },
      );

      // ✅ Firebase Listener
      final firebaseService = FirebaseNotificationService();
      _firebaseSubscription = firebaseService.onNotificationClick.listen(
            (data) {
          debugPrint('═══════════════════════════════════════════════════');
          debugPrint('🔥 FIREBASE NOTIFICATION CLICKED');
          debugPrint('   Data: $data');
          debugPrint('═══════════════════════════════════════════════════');

          _handleNotificationClick(data);
        },
      );

      debugPrint('✅ Both notification listeners setup complete');
      debugPrint('═══════════════════════════════════════════════════');
    } catch (e) {
      debugPrint('❌ Listener setup error: $e');
    }
  }

  // ====================================================================
  // ====================================================================
  // 🖱️ HANDLE NOTIFICATION CLICK
  // ====================================================================
  void _handleNotificationClick(Map<String, dynamic> data) async {
    final payload = data['data'] is Map<String, dynamic>
        ? data['data'] as Map<String, dynamic>
        : data;

    final String type = (payload['type'] ?? data['type'] ?? '').toString().toLowerCase();
    final actionUrl = (payload['action_url'] ?? data['action_url']) as String?;

    debugPrint('🔔 Processing notification click...');
    debugPrint('   Type: $type');
    debugPrint('   Payload: $payload');
    debugPrint('   Action URL: $actionUrl');

    final currentState = navigatorKey.currentState;
    if (currentState == null) {
      debugPrint('⚠️ Navigator state is null');
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';

    // 1. Handle by explicit notification 'type'
    switch (type) {
      case 'friend_request':
        currentState.push(
          MaterialPageRoute(
            builder: (context) => FriendRequestsPage(authToken: token),
          ),
        );
        return;

      case 'friend_accepted':
      case 'new_post':
        currentState.push(
          MaterialPageRoute(
            builder: (context) => const SocialFeedScreen(),
          ),
        );
        return;

      case 'chat_message':
        currentState.push(
          MaterialPageRoute(
            builder: (context) => HomePage(authToken: token),
          ),
        );
        return;

      case 'admin_message':
        currentState.push(
          MaterialPageRoute(
            builder: (context) => const SupportLiveChatScreen(),
          ),
        );
        return;

      case 'p2p_order':
        currentState.push(
          MaterialPageRoute(
            builder: (context) => const P2PPage(),
          ),
        );
        return;

      case 'deposit':
        currentState.push(
          MaterialPageRoute(
            builder: (context) => const DepositScreen(),
          ),
        );
        return;

      case 'withdraw':
        currentState.push(
          MaterialPageRoute(
            builder: (context) => const P2PHistoryPage(),
          ),
        );
        return;
    }

    // 2. Handle by action_url fallback
    if (actionUrl != null && actionUrl.isNotEmpty) {
      if (actionUrl.contains('/profile')) {
        currentState.push(MaterialPageRoute(builder: (_) => HomePage(authToken: token)));
      } else if (actionUrl.contains('/post/')) {
        currentState.push(MaterialPageRoute(builder: (_) => const SocialFeedScreen()));
      } else if (actionUrl.contains('/messages')) {
        currentState.push(MaterialPageRoute(builder: (_) => HomePage(authToken: token)));
      } else {
        currentState.push(MaterialPageRoute(builder: (_) => const NotificationsScreen()));
      }
      return;
    }

    // 3. Default fallback to notifications screen
    currentState.push(
      MaterialPageRoute(
        builder: (context) => const NotificationsScreen(),
      ),
    );
  }

  // ====================================================================
  // 🎨 BUILD UI
  // ====================================================================
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Global Money',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: true,
          backgroundColor: Colors.blue,
          iconTheme: IconThemeData(color: Colors.white),
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      home: const LoginScreen(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomePage(),
        '/notifications': (context) => const NotificationsScreen(),
        '/social-feed': (context) => const SocialFeedScreen(),
        '/p2p': (context) => const P2PPage(),
        '/support-chat': (context) => const SupportLiveChatScreen(),
        '/wallet-history': (context) => const P2PHistoryPage(),
      },
    );
  }
}