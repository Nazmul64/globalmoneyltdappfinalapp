// ====================================================================
// 🔔 ONESIGNAL SERVICE (100% WORKING - A to Z)
// 📁 lib/services/onesignal_notification_service.dart
// ====================================================================

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'config/api_config.dart';

String get _baseUrl => ApiConfig.baseUrl;

class OneSignalNotificationService {
  static final OneSignalNotificationService _instance =
      OneSignalNotificationService._internal();

  factory OneSignalNotificationService() => _instance;
  OneSignalNotificationService._internal();

  // ✅ আপনার OneSignal App ID এখানে দিন
  static const String _oneSignalAppId = '19355887-8178-4d10-a8a3-3a6cc499968c';
  // URL: use ApiConfig.baseUrl

  final StreamController<Map<String, dynamic>> _notificationClickController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get onNotificationClick =>
      _notificationClickController.stream;

  bool _isInitialized = false;

  // ====================================================================
  // 🚀 STEP 1: INITIALIZE (main.dart থেকে কল করুন)
  // ====================================================================
  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('⚠️ OneSignal already initialized');
      return;
    }

    try {
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('🔥 ONESIGNAL INITIALIZATION STARTED');
      debugPrint('   App ID: $_oneSignalAppId');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      // ✅ Enable debug logging
      OneSignal.Debug.setLogLevel(OSLogLevel.verbose);

      // ✅ Initialize OneSignal
      OneSignal.initialize(_oneSignalAppId);
      debugPrint('✅ OneSignal.initialize() called');

      // ✅ Wait for SDK to settle
      await Future.delayed(const Duration(milliseconds: 1000));

      // ✅ Request permission
      debugPrint('📱 Requesting notification permission...');
      final hasPermission = await OneSignal.Notifications.requestPermission(
        true,
      );

      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      if (hasPermission) {
        debugPrint('✅✅✅ PERMISSION GRANTED ✅✅✅');
      } else {
        debugPrint('❌❌❌ PERMISSION DENIED ❌❌❌');
        debugPrint('   Go to Settings > Apps > Your App > Notifications');
        debugPrint('   Enable notifications manually');
      }
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      // ✅ Setup handlers
      _setupNotificationHandlers();
      _setupSubscriptionListener();

      // ✅ Wait for subscription
      await Future.delayed(const Duration(seconds: 2));
      await _checkAndDisplaySubscription();

      _isInitialized = true;

      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('✅ ONESIGNAL INITIALIZATION COMPLETE');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    } catch (e, stack) {
      debugPrint('❌ INITIALIZATION ERROR: $e');
      debugPrint('Stack: $stack');
      rethrow;
    }
  }

  // ====================================================================
  // 🔍 CHECK SUBSCRIPTION STATUS
  // ====================================================================
  Future<void> _checkAndDisplaySubscription() async {
    try {
      final subscription = OneSignal.User.pushSubscription;
      final playerId = subscription.id;
      final token = subscription.token;
      final optedIn = subscription.optedIn;

      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('📊 SUBSCRIPTION STATUS:');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      if (playerId != null) {
        debugPrint('✅ Player ID: ${playerId.substring(0, 30)}...');
        await _savePlayerIdLocally(playerId);
      } else {
        debugPrint('❌ Player ID: NULL');
        debugPrint('   PROBLEM: Device not registered!');
      }

      if (token != null) {
        debugPrint('✅ Push Token: ${token.substring(0, 30)}...');
      } else {
        debugPrint('❌ Push Token: NULL');
      }

      debugPrint('📍 Opted In: ${optedIn ?? false}');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      if (playerId == null || token == null) {
        debugPrint('⚠️⚠️⚠️ CRITICAL WARNING ⚠️⚠️⚠️');
        debugPrint('   No Player ID/Token detected!');
        debugPrint('   Possible reasons:');
        debugPrint('   1. Google Play Services not installed');
        debugPrint('   2. No internet connection');
        debugPrint('   3. Firebase/GCM blocked in country');
        debugPrint('   4. App permissions denied');
        debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      }
    } catch (e) {
      debugPrint('❌ Error checking subscription: $e');
    }
  }

  // ====================================================================
  // 🔔 NOTIFICATION HANDLERS
  // ====================================================================
  void _setupNotificationHandlers() {
    // ✅ When user CLICKS notification
    OneSignal.Notifications.addClickListener((event) {
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('🔔 NOTIFICATION CLICKED');
      debugPrint('   Title: ${event.notification.title}');
      debugPrint('   Body: ${event.notification.body}');
      debugPrint('   Data: ${event.notification.additionalData}');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      _notificationClickController.add({
        'title': event.notification.title,
        'body': event.notification.body,
        'data': event.notification.additionalData ?? {},
      });
    });

    // ✅ When notification arrives (app is OPEN)
    OneSignal.Notifications.addForegroundWillDisplayListener((event) {
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('🔔 FOREGROUND NOTIFICATION');
      debugPrint('   Title: ${event.notification.title}');
      debugPrint('   Body: ${event.notification.body}');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      // ✅ MUST CALL: Show notification when app is open
      event.preventDefault();
      event.notification.display();
    });

    // ✅ Permission changes
    OneSignal.Notifications.addPermissionObserver((state) {
      debugPrint('🔐 Permission changed: $state');
    });

    debugPrint('✅ Notification handlers registered');
  }

  // ====================================================================
  // 🔗 SUBSCRIPTION LISTENER
  // ====================================================================
  void _setupSubscriptionListener() {
    OneSignal.User.pushSubscription.addObserver((state) {
      final newId = state.current.id;
      final token = state.current.token;
      final optedIn = state.current.optedIn;

      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('🔄 SUBSCRIPTION STATE CHANGED');
      debugPrint('   Player ID: ${newId ?? "null"}');
      debugPrint('   Has Token: ${token != null}');
      debugPrint('   Opted In: $optedIn');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      if (newId != null) {
        _savePlayerIdLocally(newId);
      }
    });

    debugPrint('✅ Subscription listener registered');
  }

  // ====================================================================
  // 💾 SAVE PLAYER ID
  // ====================================================================
  Future<void> _savePlayerIdLocally(String playerId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('onesignal_player_id', playerId);
      debugPrint('✅ Player ID saved: ${playerId.substring(0, 30)}...');
    } catch (e) {
      debugPrint('❌ Error saving Player ID: $e');
    }
  }

  // ====================================================================
  // 👤 STEP 2: SET USER (Login পরে কল করুন)
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

      debugPrint('✅ OneSignal.login() called');

      // ✅ Wait for Player ID to be available
      await Future.delayed(const Duration(seconds: 3));

      // ✅ Send to backend
      final success = await _sendPlayerIdToBackend(email);

      if (success) {
        debugPrint('✅✅✅ USER SETUP COMPLETE ✅✅✅');
      } else {
        debugPrint('⚠️ Backend update failed (but OneSignal login OK)');
      }

      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    } catch (e) {
      debugPrint('❌ Error setting user: $e');
    }
  }

  // ====================================================================
  // 📤 SEND TO BACKEND
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
      debugPrint('   Player ID: ${playerId.substring(0, 30)}...');
      debugPrint('   URL: $_baseUrl/update-onesignal-player');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      final response = await http
          .post(
            Uri.parse('$_baseUrl/update-onesignal-player'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': email,
              'player_id': playerId,
              'device_type': 'android',
            }),
          )
          .timeout(const Duration(seconds: 10));

      debugPrint('📥 Response: ${response.statusCode}');
      debugPrint('📥 Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          debugPrint('✅ Backend updated successfully');
          return true;
        }
      }

      debugPrint('❌ Backend error: ${response.body}');
      return false;
    } catch (e) {
      debugPrint('❌ Backend error: $e');
      return false;
    }
  }

  // ====================================================================
  // 📥 FETCH NOTIFICATIONS
  // ====================================================================
  Future<List<Map<String, dynamic>>> fetchNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString('user_email');

      if (email == null) {
        debugPrint('⚠️ No user email');
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
          return List<Map<String, dynamic>>.from(data['notifications'] ?? []);
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
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // ====================================================================
  // 🔕 LOGOUT
  // ====================================================================
  Future<void> logout() async {
    try {
      OneSignal.logout();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_email');
      await prefs.remove('onesignal_player_id');
      debugPrint('✅ Logged out');
    } catch (e) {
      debugPrint('❌ Logout error: $e');
    }
  }

  // ====================================================================
  // 🎯 GET CURRENT PLAYER ID
  // ====================================================================
  Future<String?> getCurrentPlayerId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('onesignal_player_id');
  }

  // ====================================================================
  // 🔔 CHECK PERMISSION
  // ====================================================================
  Future<bool> hasPermission() async {
    return await OneSignal.Notifications.permission;
  }

  // ====================================================================
  // 🧹 DISPOSE
  // ====================================================================
  void dispose() {
    _notificationClickController.close();
  }
}
