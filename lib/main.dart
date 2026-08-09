// ====================================================================
// 🚀 MAIN APP (OneSignal + Firebase Together)
// 📁 lib/main.dart
// ====================================================================

import 'package:flutter/material.dart';
import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'services/onesignal_notification_service.dart';
import 'services/firebase_notification_service.dart';
import 'services/app_service.dart';
import 'login.dart';
import 'home_page.dart';

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

    // ✅ STEP 2: Initialize Firebase Notification Service
    debugPrint('🔥 Initializing Firebase Notification Service...');
    await FirebaseNotificationService().initialize();
    debugPrint('✅ Firebase Notification Service initialized');

    // ✅ STEP 3: Initialize OneSignal
    debugPrint('🔔 Initializing OneSignal...');
    await OneSignalNotificationService().initialize();
    debugPrint('✅ OneSignal initialized');

    // ✅ STEP 4: Preload App Theme Color (cached in AppService singleton)
    debugPrint('🎨 Preloading theme color...');
    await AppService().preloadTheme();
    debugPrint('✅ Theme color preloaded');

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
  // 🖱️ HANDLE NOTIFICATION CLICK
  // ====================================================================
  void _handleNotificationClick(Map<String, dynamic> data) {
    final actionUrl = data['data']?['action_url'] as String? ??
        data['action_url'] as String?;

    debugPrint('🔔 Processing notification click...');
    debugPrint('   Action URL: $actionUrl');

    // ✅ Default: Navigate to notifications screen if no action URL
    if (actionUrl == null || actionUrl.isEmpty) {
      debugPrint('➡️  No action URL - navigating to /notifications');
      _navigateTo('/notifications');
      return;
    }

    // ✅ Handle specific URLs
    if (actionUrl.contains('/profile')) {
      debugPrint('➡️  Navigating to /profile');
      _navigateTo('/profile');
    } else if (actionUrl.contains('/post/')) {
      final postId = actionUrl.split('/').last;
      debugPrint('➡️  Navigating to /post with ID: $postId');
      _navigateToWithArgs('/post', postId);
    } else if (actionUrl.contains('/messages')) {
      debugPrint('➡️  Navigating to /messages');
      _navigateTo('/messages');
    } else if (actionUrl.contains('/notifications')) {
      debugPrint('➡️  Navigating to /notifications');
      _navigateTo('/notifications');
    } else {
      debugPrint('➡️  Unknown URL - navigating to /notifications');
      _navigateTo('/notifications');
    }
  }

  // ====================================================================
  // 🧭 NAVIGATION HELPERS
  // ====================================================================
  void _navigateTo(String route) {
    final currentState = navigatorKey.currentState;
    if (currentState != null) {
      currentState.pushNamed(route);
    } else {
      debugPrint('⚠️  Navigator state is null');
    }
  }

  void _navigateToWithArgs(String route, dynamic arguments) {
    final currentState = navigatorKey.currentState;
    if (currentState != null) {
      currentState.pushNamed(route, arguments: arguments);
    } else {
      debugPrint('⚠️  Navigator state is null');
    }
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
        // '/notifications': (context) => const NotificationsScreen(),
      },
    );
  }
}