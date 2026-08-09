// ====================================================================
// 🔔 ONESIGNAL NOTIFICATION SERVICE (100% WORKING - v5.3.5)
// 📁 File: lib/services/onesignal_notification_service.dart
// ====================================================================

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

String get _baseUrl => ApiConfig.baseUrl;

class OneSignalNotificationService {
  static final OneSignalNotificationService _instance =
      OneSignalNotificationService._internal();

  factory OneSignalNotificationService() => _instance;
  OneSignalNotificationService._internal();

  // ✅ CONFIGURATION
  static const String _oneSignalAppId = '19355887-8178-4d10-a8a3-3a6cc499968c';
  // URL: use ApiConfig.baseUrl

  final StreamController<Map<String, dynamic>> _notificationClickController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get onNotificationClick =>
      _notificationClickController.stream;

  bool _isInitialized = false;

  // ====================================================================
  // 🚀 INITIALIZE ONESIGNAL (MAIN ENTRY POINT)
  // ====================================================================
  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('⚠️ OneSignal already initialized');
      return;
    }

    try {
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('🔥 INITIALIZING ONESIGNAL');
      debugPrint('   App ID: $_oneSignalAppId');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      // ✅ STEP 1: Enable verbose logging
      OneSignal.Debug.setLogLevel(OSLogLevel.verbose);

      // ✅ STEP 2: Initialize OneSignal
      OneSignal.initialize(_oneSignalAppId);

      // ✅ STEP 3: Request permission IMMEDIATELY
      await Future.delayed(const Duration(milliseconds: 500));
      final hasPermission = await OneSignal.Notifications.requestPermission(
        true,
      );

      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint(
        hasPermission ? '✅ PERMISSION: GRANTED ✅' : '❌ PERMISSION: DENIED ❌',
      );
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      // ✅ STEP 4: Setup handlers
      _setupNotificationHandlers();
      _setupSubscriptionListener();

      _isInitialized = true;

      // ✅ STEP 5: Wait for subscription
      await Future.delayed(const Duration(seconds: 3));
      await _checkSubscriptionStatus();

      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('✅ ONESIGNAL INITIALIZED SUCCESSFULLY ✅');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    } catch (e) {
      debugPrint('❌ OneSignal initialization error: $e');
      rethrow;
    }
  }

  // ====================================================================
  // 🔍 CHECK SUBSCRIPTION STATUS (CRITICAL)
  // ====================================================================
  Future<void> _checkSubscriptionStatus() async {
    try {
      final subscriptionId = OneSignal.User.pushSubscription.id;
      final token = OneSignal.User.pushSubscription.token;
      final optedIn = OneSignal.User.pushSubscription.optedIn;

      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('📊 SUBSCRIPTION STATUS:');
      debugPrint('   Player ID: ${subscriptionId ?? "❌ NULL"}');
      debugPrint(
        '   Token: ${token != null ? "✅ ${token.substring(0, 20)}..." : "❌ NULL"}',
      );
      debugPrint('   Opted In: ${optedIn ?? false}');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      if (subscriptionId == null || token == null) {
        debugPrint('⚠️⚠️⚠️ WARNING: No Player ID/Token! ⚠️⚠️⚠️');
        debugPrint('   > Check AndroidManifest.xml permissions');
        debugPrint('   > Check Google Play Services');
        debugPrint('   > Try uninstall/reinstall app');
      } else {
        await _savePlayerIdLocally(subscriptionId);
      }
    } catch (e) {
      debugPrint('❌ Error checking subscription: $e');
    }
  }

  // ====================================================================
  // 🔔 SETUP NOTIFICATION HANDLERS
  // ====================================================================
  void _setupNotificationHandlers() {
    // ✅ CLICK HANDLER
    OneSignal.Notifications.addClickListener((event) {
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('🔔 NOTIFICATION CLICKED ✅');
      debugPrint('   Title: ${event.notification.title}');
      debugPrint('   Body: ${event.notification.body}');
      debugPrint('   Data: ${event.notification.additionalData}');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      _handleNotificationClick(event.notification);
    });

    // ✅ FOREGROUND HANDLER
    OneSignal.Notifications.addForegroundWillDisplayListener((event) {
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('🔔 FOREGROUND NOTIFICATION ✅');
      debugPrint('   Title: ${event.notification.title}');
      debugPrint('   Body: ${event.notification.body}');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      // ✅ MUST CALL: Display notification when app is open
      event.preventDefault();
      event.notification.display();
    });

    // ✅ PERMISSION OBSERVER
    OneSignal.Notifications.addPermissionObserver((state) {
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('🔐 PERMISSION CHANGED: $state');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    });

    debugPrint('✅ Notification handlers registered');
  }

  // ====================================================================
  // 🔗 SETUP SUBSCRIPTION LISTENER
  // ====================================================================
  void _setupSubscriptionListener() {
    OneSignal.User.pushSubscription.addObserver((state) {
      final newId = state.current.id;
      final token = state.current.token;
      final optedIn = state.current.optedIn;

      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('🔄 SUBSCRIPTION STATE CHANGED');
      debugPrint('   Player ID: ${newId ?? "null"}');
      debugPrint('   Token: ${token != null ? "✅ Available" : "❌ null"}');
      debugPrint('   Opted In: $optedIn');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      if (newId != null && token != null) {
        _savePlayerIdLocally(newId);
      }
    });

    debugPrint('✅ Subscription listener registered');
  }

  // ====================================================================
  // 🖱️ HANDLE NOTIFICATION CLICK
  // ====================================================================
  void _handleNotificationClick(OSNotification notification) {
    final additionalData = notification.additionalData ?? {};

    _notificationClickController.add({
      'title': notification.title,
      'body': notification.body,
      'data': additionalData,
    });
  }

  // ====================================================================
  // 💾 SAVE PLAYER ID LOCALLY
  // ====================================================================
  Future<void> _savePlayerIdLocally(String playerId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('onesignal_player_id', playerId);
      debugPrint('✅ Player ID saved: ${playerId.substring(0, 20)}...');
    } catch (e) {
      debugPrint('❌ Error saving Player ID: $e');
    }
  }

  // ====================================================================
  // 👤 SET EXTERNAL USER ID (Login পরে কল করুন)
  // ====================================================================
  Future<void> setExternalUserId(String email) async {
    try {
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('📤 SETTING EXTERNAL USER ID');
      debugPrint('   Email: $email');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      // ✅ Login to OneSignal
      OneSignal.login(email);

      // ✅ Save email
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_email', email);

      debugPrint('✅ External user ID set');

      // ✅ Wait and send to backend
      await Future.delayed(const Duration(seconds: 2));
      await _sendPlayerIdToBackend(email);

      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    } catch (e) {
      debugPrint('❌ Error setting external user ID: $e');
    }
  }

  // ====================================================================
  // 📤 SEND PLAYER ID TO BACKEND
  // ====================================================================
  Future<bool> _sendPlayerIdToBackend(String email) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? playerId = prefs.getString('onesignal_player_id');

      if (playerId == null) {
        playerId = OneSignal.User.pushSubscription.id;
        if (playerId != null) {
          await prefs.setString('onesignal_player_id', playerId);
        }
      }

      if (playerId == null) {
        debugPrint('⚠️ No Player ID available yet');
        return false;
      }

      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('📤 SENDING TO BACKEND');
      debugPrint('   Email: $email');
      debugPrint('   Player ID: ${playerId.substring(0, 20)}...');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      final response = await http.post(
        Uri.parse('$_baseUrl/update-onesignal-player'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'player_id': playerId,
          'device_type': 'android',
        }),
      );

      debugPrint('📥 Response: ${response.statusCode}');
      debugPrint('📥 Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          debugPrint('✅ Backend updated successfully ✅');
          return true;
        }
      }

      debugPrint('❌ Backend error: ${response.body}');
      return false;
    } catch (e) {
      debugPrint('❌ Error: $e');
      return false;
    }
  }

  // ====================================================================
  // 📥 FETCH NOTIFICATIONS
  // ====================================================================
  Future<List<Map<String, dynamic>>> fetchNotifications() async {
    try {
      debugPrint('📥 Fetching notifications...');

      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString('user_email');

      if (email == null) {
        debugPrint('⚠️ No user email found');
        return [];
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/get-notifications'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'limit': 50}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final notifications = List<Map<String, dynamic>>.from(
            data['notifications'] ?? [],
          );
          debugPrint('✅ Fetched ${notifications.length} notifications');
          return notifications;
        }
      }

      return [];
    } catch (e) {
      debugPrint('❌ Error: $e');
      return [];
    }
  }

  // ====================================================================
  // ✅ MARK AS READ
  // ====================================================================
  Future<bool> markAsRead(int notificationId) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/mark-notification-read'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'notification_id': notificationId}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('❌ Error: $e');
      return false;
    }
  }

  // ====================================================================
  // 🔕 LOGOUT
  // ====================================================================
  Future<void> logout() async {
    try {
      debugPrint('🔕 Logging out...');
      OneSignal.logout();

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_email');
      await prefs.remove('onesignal_player_id');

      debugPrint('✅ Logged out');
    } catch (e) {
      debugPrint('❌ Error: $e');
    }
  }

  // ====================================================================
  // 🧹 DISPOSE
  // ====================================================================
  void dispose() {
    _notificationClickController.close();
  }
}
