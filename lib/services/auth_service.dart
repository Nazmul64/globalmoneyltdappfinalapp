import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  static const String _keyToken = 'auth_token';
  static const String _keyUserUuid = 'user_uuid';
  static const String _keyFirstName = 'user_first_name';
  static const String _keyLastName = 'user_last_name';
  static const String _keyPhone = 'user_phone';
  static const String _keyLicenseStatus = 'license_status';

  // ── Local Token & Data Getters ────────────────────────────────────
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyToken);
  }

  Future<String?> getUserUuid() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserUuid);
  }

  Future<String> getLicenseStatus() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyLicenseStatus) ?? 'inactive';
  }

  Future<bool> isLicenseActive() async {
    final status = await getLicenseStatus();
    return status.toLowerCase() == 'active';
  }

  Future<Map<String, String?>> getUserProfile() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'uuid': prefs.getString(_keyUserUuid),
      'first_name': prefs.getString(_keyFirstName),
      'last_name': prefs.getString(_keyLastName),
      'phone': prefs.getString(_keyPhone),
      'license_status': prefs.getString(_keyLicenseStatus) ?? 'inactive',
    };
  }

  // ── Request Headers Helper ─────────────────────────────────────────
  Future<Map<String, String>> _getHeaders({bool auth = true}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (auth) {
      final token = await getToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  // ── 1. First-Time Support Registration ────────────────────────────
  Future<Map<String, dynamic>> registerSupportUser({
    required String firstName,
    required String lastName,
    required String phone,
  }) async {
    try {
      final url = Uri.parse(ApiConfig.v1SupportRegister);
      final response = await http.post(
        url,
        headers: await _getHeaders(auth: false),
        body: jsonEncode({
          'first_name': firstName.trim(),
          'last_name': lastName.trim(),
          'phone': phone.trim(),
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_keyToken, data['token'] ?? '');
        
        final user = data['user'] ?? {};
        await prefs.setString(_keyUserUuid, user['id'] ?? '');
        await prefs.setString(_keyFirstName, user['first_name'] ?? '');
        await prefs.setString(_keyLastName, user['last_name'] ?? '');
        await prefs.setString(_keyPhone, user['phone'] ?? '');
        
        final status = data['license_status'] ?? 'inactive';
        await prefs.setString(_keyLicenseStatus, status);

        return {
          'success': true,
          'user': user,
          'token': data['token'],
          'license_status': status,
        };
      }

      return {
        'success': false,
        'message': data['message'] ?? 'Registration failed. Please check inputs.',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Unable to connect to server. Please check your internet connection.',
      };
    }
  }

  // ── 2. Refresh User & License Status ─────────────────────────────
  Future<String> refreshLicenseStatus() async {
    try {
      final token = await getToken();
      if (token == null || token.isEmpty) return 'inactive';

      final url = Uri.parse(ApiConfig.v1LicenseStatus);
      final response = await http.get(url, headers: await _getHeaders(auth: true));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final status = data['status'] ?? 'inactive';
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_keyLicenseStatus, status);
          return status;
        }
      }
    } catch (e) {
      // Return cached status on network error
    }
    return getLicenseStatus();
  }

  // ── 3. Activate License Key ───────────────────────────────────────
  Future<Map<String, dynamic>> activateLicense(String licenseKey) async {
    try {
      final token = await getToken();
      if (token == null || token.isEmpty) {
        return {
          'success': false,
          'message': 'Please register with Support first to activate a license.'
        };
      }

      final url = Uri.parse(ApiConfig.v1LicenseActivate);
      final response = await http.post(
        url,
        headers: await _getHeaders(auth: true),
        body: jsonEncode({'license_key': licenseKey.trim()}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        final status = data['license_status'] ?? 'active';
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_keyLicenseStatus, status);

        return {
          'success': true,
          'message': data['message'] ?? 'License activated successfully.',
          'license_status': status,
        };
      }

      return {
        'success': false,
        'message': data['message'] ?? 'License activation failed.',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Unable to connect to server. Please check your internet connection.',
      };
    }
  }

  // ── 4. Verify QR Token ────────────────────────────────────────────
  Future<Map<String, dynamic>> verifyQrToken(String qrToken) async {
    try {
      final token = await getToken();
      if (token == null || token.isEmpty) {
        return {
          'success': false,
          'message': 'Authentication required. Please connect via Support first.',
        };
      }

      final url = Uri.parse(ApiConfig.v1QrVerify);
      final response = await http.post(
        url,
        headers: await _getHeaders(auth: true),
        body: jsonEncode({'token': qrToken.trim()}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'message': data['message'] ?? 'QR Verified successfully.',
          'redirect_url': data['redirect_url'],
          'token': data['token'],
        };
      }

      return {
        'success': false,
        'message': data['message'] ?? 'Invalid or unauthorized QR code.',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Unable to connect to server. Please check your internet connection.',
      };
    }
  }

  // ── 5. Clear Auth / Logout ────────────────────────────────────────
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyToken);
    await prefs.remove(_keyUserUuid);
    await prefs.remove(_keyFirstName);
    await prefs.remove(_keyLastName);
    await prefs.remove(_keyPhone);
    await prefs.remove(_keyLicenseStatus);
  }
}
