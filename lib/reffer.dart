import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:io';
import 'config/api_config.dart';

// URL: use ApiConfig.mediaBaseUrl

class ReferralScreen extends StatefulWidget {
  const ReferralScreen({Key? key}) : super(key: key);

  @override
  State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<ReferralScreen> {
  // 🎨 Dynamic Theme Color - Applied A-Z everywhere
  Color themeColor = const Color(0xFFE53935);
  bool themeLoaded = false;

  // 📊 Referral Data
  int totalReferrals = 0;
  int activeUsers = 0;
  double totalEarnings = 0.0;
  String referralCode = '';
  String referralLink = '';
  List<Map<String, dynamic>> referralUsers = [];

  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  /// 🎯 Initialize Theme and Referral Data
  Future<void> _initializeData() async {
    await Future.wait([fetchThemeColor(), fetchReferralData()]);
  }

  /// 🎨 Fetch Dynamic Theme Color
  Future<void> fetchThemeColor() async {
    try {
      print('🎨 Fetching theme from: ${ApiConfig.themeChange}');

      final response = await http
          .get(
            Uri.parse(ApiConfig.themeChange),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 10));

      print('🎨 Theme Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == true && data['data'] != null) {
          final colorCode = data['data']['color_code'] ?? '#E53935';

          setState(() {
            themeColor = _hexToColor(colorCode);
            themeLoaded = true;
          });

          print('✅ Theme loaded: $colorCode');
        } else {
          _setDefaultTheme();
        }
      } else {
        _setDefaultTheme();
      }
    } on SocketException {
      print('❌ Network error for theme');
      _setDefaultTheme();
    } on TimeoutException {
      print('❌ Timeout for theme');
      _setDefaultTheme();
    } catch (e) {
      print('❌ Theme fetch error: $e');
      _setDefaultTheme();
    }
  }

  void _setDefaultTheme() {
    if (mounted) {
      setState(() {
        themeColor = const Color(0xFFE53935);
        themeLoaded = true;
      });
    }
  }

  Color _hexToColor(String hexString) {
    try {
      final buffer = StringBuffer();
      if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
      buffer.write(hexString.replaceFirst('#', ''));
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (e) {
      print('❌ Color parse error: $e');
      return const Color(0xFFE53935);
    }
  }

  /// Get lighter shade of theme color
  Color get themeLightColor => themeColor.withOpacity(0.15);

  /// Get darker shade of theme color
  Color get themeDarkColor {
    final hsl = HSLColor.fromColor(themeColor);
    return hsl.withLightness((hsl.lightness - 0.1).clamp(0.0, 1.0)).toColor();
  }

  /// Get gradient colors based on theme
  List<Color> get themeGradient {
    final hsl = HSLColor.fromColor(themeColor);
    final lighter = hsl
        .withLightness((hsl.lightness + 0.1).clamp(0.0, 1.0))
        .toColor();
    return [themeColor, lighter];
  }

  /// Get Auth Token
  Future<String?> _getAuthToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? token =
          prefs.getString('auth_token') ??
          prefs.getString('token') ??
          prefs.getString('authToken');

      if (token == null) {
        print('⚠️ Token not found! Available keys: ${prefs.getKeys()}');
      } else {
        print('✅ Token found: ${token.length} characters');
      }

      return token;
    } catch (e) {
      print('❌ Error getting token: $e');
      return null;
    }
  }

  /// 📡 Fetch Referral Data from API
  Future<void> fetchReferralData() async {
    if (mounted) {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });
    }

    try {
      // Get auth token
      final token = await _getAuthToken();

      if (token == null || token.isEmpty) {
        throw Exception('Authentication token not found. Please login again.');
      }

      print('🔍 Fetching referrals from: ${ApiConfig.totalReffer}');

      final response = await http
          .get(
            Uri.parse(ApiConfig.totalReffer),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 15));

      print('📊 Referral Status: ${response.statusCode}');
      print('📦 Referral Response: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == true) {
          final List<dynamic> users = data['referral_users'] ?? [];

          // Parse referral code and link from response
          String code = data['referral_code']?.toString() ??
              data['ref_code']?.toString() ??
              data['data']?['referral_code']?.toString() ??
              data['data']?['ref_code']?.toString() ??
              '';

          String link = data['referral_link']?.toString() ??
              data['data']?['referral_link']?.toString() ??
              '';

          if (code.isEmpty) {
            final prefs = await SharedPreferences.getInstance();
            code = prefs.getString('referral_code') ??
                prefs.getString('ref_code') ??
                prefs.getString('user_id') ??
                '';
          }

          if (link.isEmpty && code.isNotEmpty) {
            link = '${ApiConfig.mediaBaseUrl}/register?ref=$code';
          }

          // Get active users from API response or calculate
          int active = data['active_users'] ?? 0;
          if (active == 0) {
            active = users.where((user) => user['status'] == 'active').length;
          }

          // Get total earnings from API response
          double earnings = 0.0;
          if (data['total_earnings'] != null) {
            earnings =
                double.tryParse(data['total_earnings'].toString()) ?? 0.0;
          } else {
            for (var user in users) {
              earnings +=
                  double.tryParse(user['earning']?.toString() ?? '0') ?? 0.0;
            }
          }

          if (mounted) {
            setState(() {
              referralCode = code;
              referralLink = link;
              totalReferrals = data['total_referrals'] ?? users.length;
              activeUsers = active;
              totalEarnings = earnings;
              referralUsers = users.map((user) {
                return {
                  'id': user['id'] ?? 0,
                  'name': user['name'] ?? 'Unknown',
                  'email': user['email'] ?? 'N/A',
                  'phone': user['phone'] ?? 'N/A',
                  'status': user['status'] ?? 'inactive',
                  'created_at': user['created_at'] ?? '',
                  'earning':
                      double.tryParse(user['earning']?.toString() ?? '0') ??
                      0.0,
                  'is_verified': user['is_verified'] ?? false,
                };
              }).toList();
              isLoading = false;
              errorMessage = null;
            });
          }

          print('✅ Loaded ${totalReferrals} referrals, code: $referralCode');
          print('👥 Active users: $activeUsers');
          print('💰 Total earnings: \$$earnings');
        } else {
          throw Exception(data['message'] ?? 'Failed to load referrals');
        }
      } else if (response.statusCode == 401) {
        throw Exception('Session expired. Please login again.');
      } else if (response.statusCode == 404) {
        throw Exception('API endpoint not found. Check your backend routes.');
      } else {
        throw Exception(
          'Server error (${response.statusCode}): ${response.body}',
        );
      }
    } on SocketException {
      if (mounted) {
        setState(() {
          isLoading = false;
          errorMessage = 'Network error. Check your internet connection.';
        });
      }
      print('❌ Socket Exception: Network error');
    } on TimeoutException {
      if (mounted) {
        setState(() {
          isLoading = false;
          errorMessage = 'Request timeout. Server not responding.';
        });
      }
      print('❌ Timeout Exception');
    } on FormatException catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
          errorMessage = 'Invalid response from server.';
        });
      }
      print('❌ Format Exception: $e');
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
          errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
      print('❌ Referral fetch error: $e');
    }
  }

  /// 🔄 Refresh all data
  Future<void> _refreshData() async {
    await _initializeData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: themeColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Referral",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _refreshData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        color: themeColor,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              // Header Section with gradient
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: themeGradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(12, 20, 12, 20),
                child: isLoading
                    ? _buildLoadingStats()
                    : Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              value: totalReferrals.toString(),
                              label: 'Total\nReferrals',
                              icon: Icons.people,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildStatCard(
                              value: activeUsers.toString(),
                              label: 'Active Users',
                              icon: Icons.person_add_alt_1,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildStatCard(
                              value: '\$${totalEarnings.toStringAsFixed(0)}',
                              label: 'Total\nEarnings',
                              icon: Icons.attach_money,
                              showStripes: true,
                            ),
                          ),
                        ],
                      ),
              ),

              // Referral Code & Link Sharing Card
              _buildReferralCodeCard(),

              // Table Section
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.people, color: themeColor, size: 20),
                        const SizedBox(width: 6),
                        const Text(
                          'Your Referrals',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const Spacer(),
                        if (!isLoading && referralUsers.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: themeLightColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: themeColor.withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              '${referralUsers.length} User${referralUsers.length != 1 ? 's' : ''}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: themeColor,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(height: 450, child: _buildReferralTable()),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingStats() {
    return Row(
      children: [
        Expanded(child: _buildLoadingStatCard()),
        const SizedBox(width: 8),
        Expanded(child: _buildLoadingStatCard()),
        const SizedBox(width: 8),
        Expanded(child: _buildLoadingStatCard()),
      ],
    );
  }

  Widget _buildLoadingStatCard() {
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            color: Colors.white,
            strokeWidth: 2.5,
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String value,
    required String label,
    required IconData icon,
    bool showStripes = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: themeColor.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          if (showStripes)
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: CustomPaint(
                size: const Size(30, double.infinity),
                painter: DiagonalStripesPainter(themeColor),
              ),
            ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: themeColor, size: 24),
              const SizedBox(height: 6),
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: themeColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w500,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReferralCodeCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(color: themeColor.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: themeLightColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.share_rounded, color: themeColor, size: 18),
              ),
              const SizedBox(width: 8),
              const Text(
                'Your Referral Code & Link',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Referral Code Box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Referral Code',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        referralCode.isNotEmpty
                            ? referralCode
                            : (isLoading ? 'Loading...' : 'N/A'),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: themeColor,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: referralCode.isEmpty
                      ? null
                      : () {
                          Clipboard.setData(ClipboardData(text: referralCode));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: const [
                                  Icon(Icons.check_circle,
                                      color: Colors.white, size: 18),
                                  SizedBox(width: 8),
                                  Text("Referral code copied!"),
                                ],
                              ),
                              backgroundColor: Colors.green.shade700,
                              duration: const Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: const Text('Copy Code'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: themeColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Referral Link Box & Share
          if (referralLink.isNotEmpty)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: referralLink));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: const [
                              Icon(Icons.check_circle,
                                  color: Colors.white, size: 18),
                              SizedBox(width: 8),
                              Text("Referral link copied!"),
                            ],
                          ),
                          backgroundColor: Colors.green.shade700,
                          duration: const Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    icon: Icon(Icons.link_rounded, size: 16, color: themeColor),
                    label: Text(
                      'Copy Link',
                      style: TextStyle(
                          color: themeColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 13),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: themeColor.withOpacity(0.5)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      final shareText =
                          'Join me on GlobalAds and earn daily! Use my referral code: $referralCode or register here: $referralLink';
                      Share.share(shareText);
                    },
                    icon: const Icon(Icons.share_rounded, size: 16),
                    label: const Text(
                      'Share Link',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: themeDarkColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildReferralTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Table Header
          Container(
            decoration: BoxDecoration(
              color: themeColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            child: Row(
              children: [
                SizedBox(width: 30, child: _buildTableHeaderText('#')),
                Expanded(flex: 2, child: _buildTableHeaderText('User')),
                Expanded(child: _buildTableHeaderText('Status')),
                Expanded(child: _buildTableHeaderText('Joined')),
                Expanded(child: _buildTableHeaderText('Earning')),
              ],
            ),
          ),

          // Table Body
          Expanded(
            child: isLoading
                ? _buildLoadingState()
                : errorMessage != null
                ? _buildErrorState()
                : referralUsers.isEmpty
                ? _buildEmptyState()
                : _buildReferralList(),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: themeColor, strokeWidth: 3),
          const SizedBox(height: 16),
          Text(
            'Loading referrals...',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline,
                size: 40,
                color: Colors.red[400],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Failed to Load',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage ?? 'Failed to load referrals',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: fetchReferralData,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: themeColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: themeLightColor,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.person_off_outlined, size: 50, color: themeColor),
          ),
          const SizedBox(height: 16),
          Text(
            'No Referrals Yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start referring friends to earn rewards!',
            style: TextStyle(fontSize: 13, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildReferralList() {
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: referralUsers.length,
      separatorBuilder: (context, index) =>
          Divider(height: 1, thickness: 1, color: Colors.grey[200]),
      itemBuilder: (context, index) {
        final user = referralUsers[index];
        final number = index + 1;

        // Format date
        String joinedDate = 'N/A';
        try {
          if (user['created_at'] != null &&
              user['created_at'].toString().isNotEmpty) {
            final dateStr = user['created_at'].toString();
            final date = DateTime.parse(dateStr);
            joinedDate =
                '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
          }
        } catch (e) {
          print('Date parse error: $e');
          joinedDate = 'N/A';
        }

        final isActive = user['status']?.toString().toLowerCase() == 'active';

        return Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          color: index % 2 == 0 ? Colors.white : Colors.grey.shade50,
          child: Row(
            children: [
              // Serial Number
              SizedBox(
                width: 30,
                child: Text(
                  number.toString(),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),

              // User Info
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            user['name']?.toString() ?? 'Unknown',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (user['is_verified'] == true) ...[
                          const SizedBox(width: 4),
                          Icon(Icons.verified, size: 14, color: themeColor),
                        ],
                      ],
                    ),
                    if (user['phone'] != null && user['phone'] != 'N/A')
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          user['phone'].toString(),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),

              // Status
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isActive
                        ? Colors.green.withOpacity(0.1)
                        : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: isActive
                          ? Colors.green.withOpacity(0.3)
                          : Colors.grey.withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    user['status']?.toString().toUpperCase() ?? 'N/A',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: isActive ? Colors.green[700] : Colors.grey[700],
                      letterSpacing: 0.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),

              // Joined Date
              Expanded(
                child: Text(
                  joinedDate,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

              // Earning
              Expanded(
                child: Text(
                  '\$${(user['earning'] ?? 0.0).toStringAsFixed(0)}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: themeColor,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTableHeaderText(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: Colors.white,
        letterSpacing: 0.3,
      ),
      textAlign: TextAlign.center,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class DiagonalStripesPainter extends CustomPainter {
  final Color color;

  DiagonalStripesPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.15)
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke;

    for (double i = -size.height; i < size.width + size.height; i += 12) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
