// ====================================================================
// 🔔 FIREBASE NOTIFICATION SERVICE (সম্পূর্ণ - শব্দ + স্ক্রিন মেসেজ সহ)
// 📁 File: lib/services/firebase_notification_service.dart
// ====================================================================

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:typed_data'; // ✅ Int64List এর জন্য
import '../config/api_config.dart';

String get _baseUrl => ApiConfig.baseUrl;

// ====================================================================
// 🔥 BACKGROUND MESSAGE HANDLER (Top-level function)
// ====================================================================
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('🔔 Background message: ${message.notification?.title}');
}

// ====================================================================
// 🔔 FIREBASE NOTIFICATION SERVICE
// ====================================================================
class FirebaseNotificationService {
  static final FirebaseNotificationService _instance =
      FirebaseNotificationService._internal();

  factory FirebaseNotificationService() => _instance;
  FirebaseNotificationService._internal();

  FirebaseMessaging? _firebaseMessagingInstance;
  FirebaseMessaging get _firebaseMessaging {
    _firebaseMessagingInstance ??= FirebaseMessaging.instance;
    return _firebaseMessagingInstance!;
  }

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  final StreamController<Map<String, dynamic>> _notificationClickController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get onNotificationClick =>
      _notificationClickController.stream;

  // ✅ API Base URL - আপনার ব্যাকএন্ড URL দিন
  // URL: use ApiConfig.baseUrl
  static const String _firebaseAppId = '1';

  // ====================================================================
  // 🚀 INITIALIZE
  // ====================================================================
  Future<void> initialize() async {
    try {
      debugPrint('🔥 Initializing Firebase...');

      await Firebase.initializeApp();
      await _requestPermissions();
      await _createNotificationChannels(); // ✅ Channel তৈরি করুন
      await _initializeLocalNotifications();

      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );

      final token = await _firebaseMessaging.getToken();
      if (token != null) {
        debugPrint('✅ FCM Token: ${token.substring(0, 20)}...');
        await _saveFcmTokenLocally(token);
      }

      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        debugPrint('🔄 Token refreshed');
        _saveFcmTokenLocally(newToken);
        _sendTokenToBackend(newToken);
      });

      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationClick);

      final initialMessage = await _firebaseMessaging.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationClick(initialMessage);
      }

      debugPrint('✅ Firebase initialized successfully');
    } catch (e) {
      debugPrint('❌ Firebase error: $e');
      rethrow;
    }
  }

  // ====================================================================
  // 🔐 REQUEST PERMISSIONS
  // ====================================================================
  Future<void> _requestPermissions() async {
    final settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true, // ✅ শব্দ চালু
      provisional: false,
      criticalAlert: true, // ✅ জরুরী alert
    );

    debugPrint('✅ Permission: ${settings.authorizationStatus}');
  }

  // ====================================================================
  // 📢 CREATE NOTIFICATION CHANNELS (Android - শব্দ সহ)
  // ====================================================================
  Future<void> _createNotificationChannels() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel', // ID
      'High Importance Notifications', // Name
      description: 'This channel is for important notifications',
      importance: Importance.max, // ✅ Maximum importance
      playSound: true, // ✅ শব্দ চালু
      enableVibration: true, // ✅ Vibration চালু
      enableLights: true,
      ledColor: Color(0xFF2196F3),
      showBadge: true,
      sound: RawResourceAndroidNotificationSound(
        'notification',
      ), // ✅ Custom sound
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    debugPrint('✅ Notification channel created');
  }

  // ====================================================================
  // 🔔 INITIALIZE LOCAL NOTIFICATIONS
  // ====================================================================
  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      defaultPresentAlert: true,
      defaultPresentSound: true,
      defaultPresentBadge: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        if (details.payload != null) {
          try {
            final data = jsonDecode(details.payload!);
            _notificationClickController.add(data);
          } catch (e) {
            debugPrint('❌ Payload decode error: $e');
          }
        }
      },
    );

    debugPrint('✅ Local notifications initialized');
  }

  // ====================================================================
  // 📱 HANDLE FOREGROUND MESSAGE (শব্দ + স্ক্রিন মেসেজ)
  // ====================================================================
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('🔔 Foreground message received');
    debugPrint('   Title: ${message.notification?.title}');
    debugPrint('   Body: ${message.notification?.body}');

    // ✅ স্ক্রিনে মেসেজ দেখান (শব্দ সহ)
    await _showLocalNotification(message);
  }

  // ====================================================================
  // 🔔 SHOW LOCAL NOTIFICATION (শব্দ + Vibration + LED)
  // ====================================================================
  Future<void> _showLocalNotification(RemoteMessage message) async {
    try {
      final notification = message.notification;
      if (notification == null) return;

      // ✅ Android notification details (শব্দ সহ)
      final androidDetails = AndroidNotificationDetails(
        'high_importance_channel',
        'High Importance Notifications',
        channelDescription: 'Important notifications with sound',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true, // ✅ শব্দ চালু
        sound: const RawResourceAndroidNotificationSound(
          'notification',
        ), // ✅ Custom sound
        enableVibration: true,
        vibrationPattern: Int64List.fromList([
          0,
          500,
          250,
          500,
        ]), // ✅ Vibration pattern
        enableLights: true,
        ledColor: const Color(0xFF2196F3),
        ledOnMs: 1000,
        ledOffMs: 500,
        icon: '@mipmap/ic_launcher',
        largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        styleInformation: BigTextStyleInformation(
          notification.body ?? '',
          contentTitle: notification.title,
          summaryText: 'New notification',
        ),
        ticker: notification.title,
        autoCancel: true,
        ongoing: false,
        showWhen: true,
        when: DateTime.now().millisecondsSinceEpoch,
      );

      // ✅ iOS notification details (শব্দ সহ)
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'notification.aiff', // ✅ Custom sound
        badgeNumber: 1,
        interruptionLevel: InterruptionLevel.timeSensitive,
      );

      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      // ✅ Show notification
      await _localNotifications.show(
        message.hashCode,
        notification.title,
        notification.body,
        notificationDetails,
        payload: jsonEncode(message.data),
      );

      debugPrint('✅ Local notification shown with sound');
    } catch (e) {
      debugPrint('❌ Error showing notification: $e');
    }
  }

  // ====================================================================
  // 🔗 HANDLE NOTIFICATION CLICK
  // ====================================================================
  void _handleNotificationClick(RemoteMessage message) {
    debugPrint('🔔 Notification clicked: ${message.data}');
    _notificationClickController.add(message.data);
  }

  // ====================================================================
  // 💾 SAVE FCM TOKEN LOCALLY
  // ====================================================================
  Future<void> _saveFcmTokenLocally(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('fcm_token', token);
      debugPrint('✅ FCM token saved');
    } catch (e) {
      debugPrint('❌ Error saving token: $e');
    }
  }

  // ====================================================================
  // 📤 SEND TOKEN TO BACKEND (Login এর পরে)
  // ====================================================================
  Future<bool> sendTokenToBackend(String userEmail) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('fcm_token');

      if (token == null) {
        debugPrint('⚠️ No FCM token available');
        return false;
      }

      return await _sendTokenToBackend(token, userEmail: userEmail);
    } catch (e) {
      debugPrint('❌ Error sending token: $e');
      return false;
    }
  }

  // ====================================================================
  // 🌐 SEND TOKEN TO BACKEND (INTERNAL)
  // ====================================================================
  Future<bool> _sendTokenToBackend(String token, {String? userEmail}) async {
    try {
      if (userEmail == null) {
        final prefs = await SharedPreferences.getInstance();
        userEmail = prefs.getString('user_email');
      }

      if (userEmail == null) return false;

      debugPrint('📤 Sending token to backend...');

      final response = await http.post(
        Uri.parse('$_baseUrl/update-fcm-token'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': userEmail,
          'fcm_token': token,
          'device_type': 'android',
          'firebase_app_id': _firebaseAppId,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          debugPrint('✅ Token sent successfully');
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
  // 📥 FETCH NOTIFICATIONS FROM BACKEND
  // ====================================================================
  Future<List<Map<String, dynamic>>> fetchNotifications() async {
    try {
      debugPrint('📥 Fetching notifications...');

      final response = await http.post(
        Uri.parse('$_baseUrl/get-notifications'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'firebase_app_id': _firebaseAppId, 'limit': 50}),
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

      debugPrint('❌ Failed: ${response.body}');
      return [];
    } catch (e) {
      debugPrint('❌ Error: $e');
      return [];
    }
  }

  // ====================================================================
  // ✅ MARK NOTIFICATION AS READ
  // ====================================================================
  Future<bool> markAsRead(int notificationId) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/mark-notification-read'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'notification_id': notificationId,
          'firebase_app_id': _firebaseAppId,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('❌ Mark read error: $e');
      return false;
    }
  }

  // ====================================================================
  // 🧹 DISPOSE
  // ====================================================================
  void dispose() {
    _notificationClickController.close();
  }
}
