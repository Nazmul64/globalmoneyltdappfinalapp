// ==================== USER SESSION - SharedPreferences Storage ====================
// File: helpers/user_session.dart
// ✅ Cache support for instant access + Persistent storage
// ✅ এখন অ্যাপ বন্ধ করার পরেও ডেটা থাকবে

import 'package:shared_preferences/shared_preferences.dart';

class UserSession {
  // Storage Keys
  static const String _keyUserId = 'user_id';
  static const String _keyUserName = 'user_name';
  static const String _keyUserEmail = 'user_email';
  static const String _keyAuthToken = 'auth_token';

  // ✅ In-memory cache for instant synchronous access
  static int? _cachedUserId;
  static String? _cachedUserName;
  static String? _cachedUserEmail;
  static String? _cachedAuthToken;
  static bool _isInitialized = false;

  // ==========================================
  // INITIALIZATION - Call this on app start
  // ==========================================
  static Future<void> initialize() async {
    if (_isInitialized) {
      print('⚠️ UserSession already initialized');
      return;
    }

    try {
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('🔄 Initializing UserSession...');

      final prefs = await SharedPreferences.getInstance();

      _cachedUserId = prefs.getInt(_keyUserId);
      _cachedUserName = prefs.getString(_keyUserName);
      _cachedUserEmail = prefs.getString(_keyUserEmail);
      _cachedAuthToken = prefs.getString(_keyAuthToken);

      _isInitialized = true;

      if (_cachedUserId != null) {
        print('✅ User session restored from storage');
        print('   User ID: $_cachedUserId');
        print('   Name: $_cachedUserName');
        print('   Status: LOGGED IN (Persistent)');
      } else {
        print('ℹ️ No saved session found');
        print('   Status: LOGGED OUT');
      }
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    } catch (e) {
      print('❌ Failed to initialize UserSession: $e');
      _isInitialized = true; // Mark as initialized even on error
    }
  }

  // ==========================================
  // SAVE SESSION - Save user data to storage
  // ==========================================
  static Future<bool> saveSession({
    required int userId,
    required String name,
    required String token,
    String? email,
  }) async {
    try {
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('💾 Saving user session to storage...');
      print('   User ID: $userId');
      print('   Name: $name');
      if (email != null) print('   Email: $email');

      final prefs = await SharedPreferences.getInstance();

      // Save to persistent storage
      await prefs.setInt(_keyUserId, userId);
      await prefs.setString(_keyUserName, name);
      await prefs.setString(_keyAuthToken, token);
      if (email != null) {
        await prefs.setString(_keyUserEmail, email);
      }

      // Update cache for instant access
      _cachedUserId = userId;
      _cachedUserName = name;
      _cachedAuthToken = token;
      _cachedUserEmail = email;
      _isInitialized = true;

      print('✅ Session saved successfully');
      print('   ✅ Data will persist after app closes');
      print('   ✅ Cache updated for instant access');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      return true;
    } catch (e) {
      print('❌ Failed to save session: $e');
      return false;
    }
  }

  // ==========================================
  // SYNCHRONOUS GETTERS - Instant access from cache
  // ==========================================

  /// Get auth token (synchronous from cache)
  static String? getAuthTokenSync() {
    if (!_isInitialized) {
      print('⚠️ UserSession not initialized! Call initialize() first');
    }
    return _cachedAuthToken;
  }

  /// Get user ID (synchronous from cache)
  static int? getUserIdSync() {
    if (!_isInitialized) {
      print('⚠️ UserSession not initialized! Call initialize() first');
    }
    return _cachedUserId;
  }

  /// Get user name (synchronous from cache)
  static String? getUserNameSync() {
    if (!_isInitialized) {
      print('⚠️ UserSession not initialized! Call initialize() first');
    }
    return _cachedUserName;
  }

  /// Get user email (synchronous from cache)
  static String? getUserEmailSync() {
    if (!_isInitialized) {
      print('⚠️ UserSession not initialized! Call initialize() first');
    }
    return _cachedUserEmail;
  }

  /// Check if user is logged in (synchronous from cache)
  static bool isLoggedInSync() {
    if (!_isInitialized) {
      print('⚠️ UserSession not initialized! Call initialize() first');
      return false;
    }
    return _cachedUserId != null &&
        _cachedAuthToken != null &&
        _cachedAuthToken!.isNotEmpty;
  }

  /// Check if post belongs to current user (synchronous)
  static bool isPostOwner(int postUserId) {
    if (!_isInitialized) {
      print('⚠️ UserSession not initialized! Call initialize() first');
      return false;
    }
    return _cachedUserId != null && _cachedUserId == postUserId;
  }

  /// Check if user owns content (synchronous, flexible)
  static bool isOwner(dynamic ownerId) {
    if (!_isInitialized) {
      print('⚠️ UserSession not initialized! Call initialize() first');
      return false;
    }

    if (ownerId == null || _cachedUserId == null) return false;

    // Handle both int and String IDs
    if (ownerId is int) return _cachedUserId == ownerId;
    if (ownerId is String) {
      final ownerIdInt = int.tryParse(ownerId);
      return ownerIdInt != null && _cachedUserId == ownerIdInt;
    }

    return false;
  }

  // ==========================================
  // ASYNC GETTERS - For compatibility
  // ==========================================

  /// Get auth token (async from storage)
  static Future<String?> getAuthToken() async {
    try {
      // Return from cache if available
      if (_isInitialized && _cachedAuthToken != null) {
        return _cachedAuthToken;
      }

      // Otherwise load from storage
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_keyAuthToken);

      if (_isInitialized) {
        _cachedAuthToken = token;
      }

      return token;
    } catch (e) {
      print('❌ Failed to get auth token: $e');
      return null;
    }
  }

  /// Get current user ID (async from storage)
  static Future<int?> getUserId() async {
    try {
      // Return from cache if available
      if (_isInitialized && _cachedUserId != null) {
        return _cachedUserId;
      }

      // Otherwise load from storage
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt(_keyUserId);

      if (_isInitialized) {
        _cachedUserId = userId;
      }

      return userId;
    } catch (e) {
      print('❌ Failed to get user ID: $e');
      return null;
    }
  }

  /// Get current user name (async from storage)
  static Future<String?> getUserName() async {
    try {
      // Return from cache if available
      if (_isInitialized && _cachedUserName != null) {
        return _cachedUserName;
      }

      // Otherwise load from storage
      final prefs = await SharedPreferences.getInstance();
      final userName = prefs.getString(_keyUserName);

      if (_isInitialized) {
        _cachedUserName = userName;
      }

      return userName;
    } catch (e) {
      print('❌ Failed to get user name: $e');
      return null;
    }
  }

  /// Get current user email (async from storage)
  static Future<String?> getUserEmail() async {
    try {
      // Return from cache if available
      if (_isInitialized && _cachedUserEmail != null) {
        return _cachedUserEmail;
      }

      // Otherwise load from storage
      final prefs = await SharedPreferences.getInstance();
      final userEmail = prefs.getString(_keyUserEmail);

      if (_isInitialized) {
        _cachedUserEmail = userEmail;
      }

      return userEmail;
    } catch (e) {
      print('❌ Failed to get user email: $e');
      return null;
    }
  }

  /// Check if user is logged in (async from storage)
  static Future<bool> isLoggedIn() async {
    try {
      // Use cache if initialized
      if (_isInitialized) {
        return isLoggedInSync();
      }

      // Otherwise load from storage
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt(_keyUserId);
      final token = prefs.getString(_keyAuthToken);
      final name = prefs.getString(_keyUserName);

      return userId != null && token != null && token.isNotEmpty && name != null;
    } catch (e) {
      print('❌ Failed to check login status: $e');
      return false;
    }
  }

  // ==========================================
  // UTILITY METHODS
  // ==========================================

  /// Get complete session info for debugging
  static Future<Map<String, dynamic>> getDebugInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = _cachedAuthToken ?? prefs.getString(_keyAuthToken);

      return {
        'initialized': _isInitialized,
        'user_id': _cachedUserId ?? prefs.getInt(_keyUserId),
        'user_name': _cachedUserName ?? prefs.getString(_keyUserName),
        'user_email': _cachedUserEmail ?? prefs.getString(_keyUserEmail),
        'has_token': token != null,
        'token_length': token?.length ?? 0,
        'token_preview': token != null && token.length > 20
            ? '${token.substring(0, 20)}...'
            : token,
        'is_logged_in': await isLoggedIn(),
        'cache_status': _isInitialized ? 'Active' : 'Not Initialized',
        'storage_type': 'SharedPreferences (Persistent)',
      };
    } catch (e) {
      print('❌ Failed to get debug info: $e');
      return {'error': e.toString()};
    }
  }

  /// Print debug info to console
  static Future<void> printDebugInfo() async {
    final info = await getDebugInfo();
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('📊 UserSession Debug Info:');
    info.forEach((key, value) {
      print('   $key: $value');
    });
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  }

  /// Clear session on logout
  static Future<void> clearSession() async {
    try {
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('🚪 LOGGING OUT - Clearing session...');

      final prefs = await SharedPreferences.getInstance();

      // Clear from storage
      await prefs.remove(_keyUserId);
      await prefs.remove(_keyUserName);
      await prefs.remove(_keyUserEmail);
      await prefs.remove(_keyAuthToken);

      // Clear cache
      _cachedUserId = null;
      _cachedUserName = null;
      _cachedUserEmail = null;
      _cachedAuthToken = null;

      print('✅ Session cleared successfully');
      print('   User ID: null');
      print('   Token: null');
      print('   Cache: cleared');
      print('   Status: LOGGED OUT');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    } catch (e) {
      print('❌ Failed to clear session: $e');
    }
  }

  /// Update user data without changing token
  static Future<void> updateUserData({
    String? name,
    String? email,
  }) async {
    try {
      final isLoggedInNow = await isLoggedIn();
      if (!isLoggedInNow) {
        print('⚠️ Cannot update user data: Not logged in');
        return;
      }

      final prefs = await SharedPreferences.getInstance();

      if (name != null) {
        await prefs.setString(_keyUserName, name);
        _cachedUserName = name;
      }
      if (email != null) {
        await prefs.setString(_keyUserEmail, email);
        _cachedUserEmail = email;
      }

      print('✅ User data updated in storage & cache');
      if (name != null) print('   Name: $name');
      if (email != null) print('   Email: $email');
    } catch (e) {
      print('❌ Failed to update user data: $e');
    }
  }

  /// Check token validity (basic check)
  static Future<bool> hasValidToken() async {
    try {
      final token = await getAuthToken();
      return token != null && token.isNotEmpty && token.length > 10;
    } catch (e) {
      print('❌ Failed to check token validity: $e');
      return false;
    }
  }

  /// Check token validity (synchronous from cache)
  static bool hasValidTokenSync() {
    if (!_isInitialized) return false;
    return _cachedAuthToken != null &&
        _cachedAuthToken!.isNotEmpty &&
        _cachedAuthToken!.length > 10;
  }

  /// Get session status
  static Future<String> getSessionStatus() async {
    try {
      if (!_isInitialized) {
        return 'Not Initialized';
      }
      final isLoggedInNow = await isLoggedIn();
      if (!isLoggedInNow) return 'Not Logged In';
      return 'Active Session (Persistent + Cached)';
    } catch (e) {
      return 'Error checking status';
    }
  }

  /// Get session status (synchronous from cache)
  static String getSessionStatusSync() {
    if (!_isInitialized) {
      return 'Not Initialized';
    }
    if (!isLoggedInSync()) {
      return 'Not Logged In';
    }
    return 'Active Session (Cached)';
  }

  /// Force reload from storage (refresh cache)
  static Future<void> reload() async {
    try {
      print('🔄 Reloading UserSession from storage...');
      _isInitialized = false;
      await initialize();
    } catch (e) {
      print('❌ Failed to reload session: $e');
    }
  }
}