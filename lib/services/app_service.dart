// ====================================================================
// 📦 CENTRALIZED APP SERVICE
// 📁 lib/services/app_service.dart
//
// Handles: Theme Color, Mail Config, Google Ads Approval
// Uses singleton + in-memory cache to avoid repeated API calls.
// ====================================================================

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class AppService {
  // ─── Singleton ────────────────────────────────────────────────────
  static final AppService _instance = AppService._internal();
  factory AppService() => _instance;
  AppService._internal();

  static const Duration _timeout = Duration(seconds: 10);

  // ─── Cached values ────────────────────────────────────────────────
  Color? _cachedThemeColor;
  Map<String, dynamic>? _cachedMailConfig;
  String? _cachedGoogleAdsApproval;
  Map<String, dynamic>? _cachedLogoSetting;
  Map<String, dynamic>? _cachedSupportLinks;
  String? _cachedHowToWork;
  List<Map<String, dynamic>>? _cachedHomeCards;

  bool _themeLoaded = false;

  // ─── Default fallback color ───────────────────────────────────────
  static const Color defaultThemeColor = Color(0xFFE53935);

  // ====================================================================
  // 🎨 THEME COLOR
  // ====================================================================

  /// Returns the cached theme color, loading from API if necessary.
  Future<Color> getThemeColor() async {
    if (_cachedThemeColor != null) return _cachedThemeColor!;

    try {
      final response = await http
          .get(
            Uri.parse(ApiConfig.themeChange),
            headers: {'Accept': 'application/json'},
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == true && data['data'] != null) {
          String colorCode = (data['data']['color_code'] ?? '#E53935')
              .toString()
              .replaceAll('#', '');
          _cachedThemeColor =
              Color(int.parse('FF$colorCode', radix: 16));
          _themeLoaded = true;
          debugPrint('✅ [AppService] Theme color loaded: #$colorCode');
          return _cachedThemeColor!;
        }
      }
    } catch (e) {
      debugPrint('❌ [AppService] Theme load error: $e');
    }

    _cachedThemeColor = defaultThemeColor;
    _themeLoaded = true;
    return _cachedThemeColor!;
  }

  /// Returns the cached color synchronously (use after preload).
  Color get themeColorSync => _cachedThemeColor ?? defaultThemeColor;

  bool get isThemeLoaded => _themeLoaded;

  /// Pre-loads theme color at app startup.
  Future<void> preloadTheme() => getThemeColor();

  /// Clears the theme cache (call after admin changes theme).
  void clearThemeCache() {
    _cachedThemeColor = null;
    _themeLoaded = false;
  }

  // ====================================================================
  // 📧 MAIL CONFIG  (API 13.2)
  // ====================================================================

  /// Returns SMTP mail configuration from the server.
  Future<Map<String, dynamic>?> getMailConfig({bool forceRefresh = false}) async {
    if (_cachedMailConfig != null && !forceRefresh) return _cachedMailConfig;

    try {
      final response = await http
          .get(
            Uri.parse(ApiConfig.mailSetting),
            headers: {'Accept': 'application/json'},
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        if (body['success'] == true && body['data'] != null) {
          _cachedMailConfig = Map<String, dynamic>.from(body['data']);
          debugPrint('✅ [AppService] Mail config loaded');
          return _cachedMailConfig;
        }
      }
    } catch (e) {
      debugPrint('❌ [AppService] Mail config error: $e');
    }
    return null;
  }

  // ====================================================================
  // 📢 GOOGLE ADS APPROVAL  (API 13.3)
  // ====================================================================

  /// Returns Google AdSense approval script/text.
  Future<String?> getGoogleAdsApproval({bool forceRefresh = false}) async {
    if (_cachedGoogleAdsApproval != null && !forceRefresh) {
      return _cachedGoogleAdsApproval;
    }

    try {
      final response = await http
          .get(
            Uri.parse(ApiConfig.googleAdsApproval),
            headers: {'Accept': 'application/json'},
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        if (body['success'] == true && body['data'] != null) {
          _cachedGoogleAdsApproval =
              body['data']['approval_text']?.toString() ?? '';
          debugPrint('✅ [AppService] Google Ads approval loaded');
          return _cachedGoogleAdsApproval;
        }
      }
    } catch (e) {
      debugPrint('❌ [AppService] Google Ads approval error: $e');
    }
    return null;
  }

  // ====================================================================
  // 🖼️ LOGO SETTING  (API 13.1)
  // ====================================================================

  Future<Map<String, dynamic>?> getLogoSetting({bool forceRefresh = false}) async {
    if (_cachedLogoSetting != null && !forceRefresh) return _cachedLogoSetting;

    try {
      final response = await http
          .get(
            Uri.parse(ApiConfig.logoSetting),
            headers: {'Accept': 'application/json'},
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        if (body['status'] == true && body['data'] != null) {
          _cachedLogoSetting = Map<String, dynamic>.from(body['data']);
          debugPrint('✅ [AppService] Logo setting loaded');
          return _cachedLogoSetting;
        }
      }
    } catch (e) {
      debugPrint('❌ [AppService] Logo setting error: $e');
    }
    return null;
  }

  // ====================================================================
  // 🔗 SUPPORT LINKS  (API 13.5)
  // ====================================================================

  Future<Map<String, dynamic>?> getSupportLinks({bool forceRefresh = false}) async {
    if (_cachedSupportLinks != null && !forceRefresh) return _cachedSupportLinks;

    try {
      final response = await http
          .get(
            Uri.parse(ApiConfig.support),
            headers: {'Accept': 'application/json'},
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        if (body['data'] != null) {
          _cachedSupportLinks = Map<String, dynamic>.from(body['data']);
          debugPrint('✅ [AppService] Support links loaded');
          return _cachedSupportLinks;
        }
      }
    } catch (e) {
      debugPrint('❌ [AppService] Support links error: $e');
    }
    return null;
  }

  // ====================================================================
  // 📖 HOW TO WORK  (API 13.6)
  // ====================================================================

  Future<String?> getHowToWork({bool forceRefresh = false}) async {
    if (_cachedHowToWork != null && !forceRefresh) return _cachedHowToWork;

    try {
      final response = await http
          .get(
            Uri.parse(ApiConfig.howToWork),
            headers: {'Accept': 'application/json'},
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        _cachedHowToWork = body['data']?.toString() ?? '';
        debugPrint('✅ [AppService] How-to-work loaded');
        return _cachedHowToWork;
      }
    } catch (e) {
      debugPrint('❌ [AppService] How-to-work error: $e');
    }
    return null;
  }

  // ====================================================================
  // 🎴 HOME CARDS CONFIG (DYNAMIC ICONS & BACKGROUND COLORS)
  // ====================================================================

  Future<List<Map<String, dynamic>>?> getHomeCards({bool forceRefresh = false}) async {
    if (_cachedHomeCards != null && !forceRefresh) return _cachedHomeCards;

    try {
      final response = await http
          .get(
            Uri.parse(ApiConfig.homeCards),
            headers: {'Accept': 'application/json'},
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        if (body['success'] == true && body['data'] != null) {
          _cachedHomeCards = List<Map<String, dynamic>>.from(body['data']);
          debugPrint('✅ [AppService] Home cards loaded');
          return _cachedHomeCards;
        }
      }
    } catch (e) {
      debugPrint('❌ [AppService] Home cards load error: $e');
    }
    return null;
  }

  /// Maps string icon names, HTML tags (<i class="fa fa-tasks"></i>), or FontAwesome classes to Flutter IconData
  static IconData getIconData(String? iconName, {IconData fallback = Icons.help}) {
    if (iconName == null || iconName.isEmpty) return fallback;
    String clean = iconName.toLowerCase().trim();

    // Extract class from HTML string if user pasted <i class="fa fa-tasks"></i>
    if (clean.contains('class=')) {
      final reg = RegExp(r'''class=["']([^"']+)["']''');
      final match = reg.firstMatch(clean);
      if (match != null) {
        clean = match.group(1) ?? clean;
      }
    }

    clean = clean
        .replaceAll('<i', '')
        .replaceAll('</i>', '')
        .replaceAll('<span', '')
        .replaceAll('</span>', '')
        .replaceAll('class=', '')
        .replaceAll('"', '')
        .replaceAll("'", '')
        .trim();

    if (clean.contains('task')) return Icons.task_alt;
    if (clean.contains('user') || clean.contains('person') || clean.contains('profile')) return Icons.person;
    if (clean.contains('gift') || clean.contains('refer') || clean.contains('card')) return Icons.card_giftcard;
    if (clean.contains('cog') || clean.contains('setting') || clean.contains('gear') || clean.contains('option')) return Icons.settings;
    if (clean.contains('users') || clean.contains('people') || clean.contains('friend')) return Icons.people;
    if (clean.contains('money') || clean.contains('withdraw') || clean.contains('cash')) return Icons.money;
    if (clean.contains('exchange') || clean.contains('swap') || clean.contains('p2p') || clean.contains('transfer')) return Icons.swap_horiz;
    if (clean.contains('info') || clean.contains('help') || clean.contains('work')) return Icons.info;
    if (clean.contains('dollar') || clean.contains('deposit') || clean.contains('attach_money')) return Icons.attach_money;
    if (clean.contains('headphone') || clean.contains('headset') || clean.contains('support')) return Icons.support_agent;
    if (clean.contains('globe') || clean.contains('public') || clean.contains('social')) return Icons.public;
    if (clean.contains('wallet') || clean.contains('credit-card') || clean.contains('balance')) return Icons.account_balance_wallet;

    return fallback;
  }

  // ====================================================================
  // 🔄 CLEAR ALL CACHES
  // ====================================================================

  void clearAllCaches() {
    _cachedThemeColor = null;
    _cachedMailConfig = null;
    _cachedGoogleAdsApproval = null;
    _cachedLogoSetting = null;
    _cachedSupportLinks = null;
    _cachedHowToWork = null;
    _cachedHomeCards = null;
    _themeLoaded = false;
    debugPrint('🗑️ [AppService] All caches cleared');
  }
}
