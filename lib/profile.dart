// ==================== PROFILE PAGE - WITH KYC VERIFICATION STATUS ====================
// File: profile_page.dart
// Features: Dynamic theme + Themed AppBar + Profile management + KYC Status API Integration

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

// Screens
import 'update_profile.dart';
import 'kyc_submit.dart';
import 'password_change.dart';
import 'config/api_config.dart';

String get baseUrl => ApiConfig.mediaBaseUrl;

// ==================== CONSTANTS ====================
const Color defaultThemeColor = Color(0xFF4361EE);

// ==================== MAIN WIDGET ====================
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // ==================== STATE VARIABLES ====================
  Color themeColor = defaultThemeColor;
  Color lightThemeColor = const Color(0xFF6C8BFF);

  // User Profile Data
  String userName = "Loading...";
  String userEmail = "Loading...";
  String userMobile = "";
  String profilePhoto = "";
  bool isVerified = false; // ✅ Changed to boolean for accurate status
  String joinDate = "N/A";
  String userRole = "user";
  int? userId; // ✅ Added to store user ID

  // UI State
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  @override
  void dispose() {
    super.dispose();
  }

  // ==================== DATA INITIALIZATION ====================
  Future<void> _initializeData() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      await _fetchThemeColor();
      await _fetchProfileData();
      // ✅ Fetch KYC verification status after getting user ID
      if (userId != null) {
        await _fetchKycVerificationStatus();
      }
    } catch (e) {
      _handleError('Initialization failed: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  // ==================== API CALLS ====================
  Future<void> _fetchThemeColor() async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/api/themechange'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final colorCode = data['data']?['color_code'] ?? "#4361EE";
        if (mounted) {
          setState(() {
            themeColor = _hexToColor(colorCode);
            lightThemeColor = _getLightColor(themeColor);
          });
        }
      } else {
        if (mounted) {
          setState(() {
            themeColor = defaultThemeColor;
            lightThemeColor = const Color(0xFF6C8BFF);
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          themeColor = defaultThemeColor;
          lightThemeColor = const Color(0xFF6C8BFF);
        });
      }
    }
  }

  Future<void> _fetchProfileData() async {
    try {
      final token = await _getAuthToken();
      if (token == null || token.isEmpty) {
        throw Exception("Authentication token not found. Please login again.");
      }

      final response = await http
          .get(
            Uri.parse('$baseUrl/api/profile'),
            headers: {
              "Accept": "application/json",
              "Authorization": "Bearer $token",
            },
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 401) {
        throw Exception("Session expired. Please login again.");
      }
      if (response.statusCode == 403) {
        throw Exception("Access denied. Please check your permissions.");
      }
      if (response.statusCode != 200) {
        throw Exception(
          "Failed to fetch profile. Status: ${response.statusCode}",
        );
      }

      final responseBody = json.decode(response.body);

      if (responseBody['success'] != true) {
        throw Exception(responseBody['message'] ?? "Failed to load profile");
      }

      final data = responseBody['data'];
      if (data == null) {
        throw Exception("Invalid response format");
      }

      // ✅ Parse join date
      String formattedJoinDate = "N/A";
      try {
        if (data['created_at'] != null) {
          DateTime joinDateTime = DateTime.parse(data['created_at']);
          formattedJoinDate =
              "${joinDateTime.day.toString().padLeft(2, '0')}-"
              "${joinDateTime.month.toString().padLeft(2, '0')}-"
              "${joinDateTime.year}";
        }
      } catch (e) {
        formattedJoinDate = "N/A";
      }

      if (mounted) {
        setState(() {
          // ✅ Store user ID for KYC verification check
          userId = data['id'] != null
              ? int.tryParse(data['id'].toString())
              : null;

          userName = data['name']?.toString() ?? "User";
          userEmail = data['email']?.toString() ?? "No email";
          userRole = data['role']?.toString() ?? "user";
          profilePhoto = data['photo']?.toString() ?? "";
          userMobile = data['mobile']?.toString() ?? "";
          joinDate = formattedJoinDate;
          errorMessage = null;
        });
      }
    } catch (e) {
      print("Error fetching profile: $e");
      if (mounted) {
        _handleError(e.toString().replaceAll('Exception: ', ''));
      }
    }
  }

  // ✅ NEW: Fetch KYC Verification Status from API
  Future<void> _fetchKycVerificationStatus() async {
    if (userId == null) return;

    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/api/user/$userId/verify-status'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (mounted) {
          setState(() {
            // ✅ Get verified status from API response
            isVerified = data['verified'] == true;
          });
        }

        print("KYC Verification Status: ${data['verified']}");
        print("Message: ${data['message']}");
      } else {
        print("Failed to fetch KYC status: ${response.statusCode}");
        if (mounted) {
          setState(() {
            isVerified = false;
          });
        }
      }
    } catch (e) {
      print("Error fetching KYC verification status: $e");
      if (mounted) {
        setState(() {
          isVerified = false;
        });
      }
    }
  }

  // ==================== HELPER METHODS ====================
  Future<String?> _getAuthToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('token') ??
          prefs.getString('auth_token') ??
          prefs.getString('user_token') ??
          prefs.getString('access_token');
    } catch (e) {
      return null;
    }
  }

  Color _hexToColor(String hex) {
    try {
      hex = hex.replaceAll("#", "").replaceAll(" ", "");
      if (hex.length == 6) return Color(int.parse("FF$hex", radix: 16));
      if (hex.length == 8) return Color(int.parse(hex, radix: 16));
      return defaultThemeColor;
    } catch (e) {
      return defaultThemeColor;
    }
  }

  Color _getLightColor(Color color) {
    return Color.alphaBlend(Colors.white.withOpacity(0.3), color);
  }

  List<Color> get _gradientColors => [themeColor, lightThemeColor];

  void _handleError(String message) {
    if (mounted) {
      setState(() => errorMessage = message);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: () {
              if (mounted) {
                _refresh();
              }
            },
          ),
        ),
      );
    }
  }

  Future<void> _refresh() async {
    if (mounted) {
      await _initializeData();
    }
  }

  // ==================== UI BUILD METHODS ====================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: _buildThemedAppBar(),
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: themeColor,
        child: _buildContent(),
      ),
    );
  }

  PreferredSizeWidget _buildThemedAppBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(60),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: themeColor.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios,
              color: Colors.white,
              size: 20,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            "Profile",
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          centerTitle: true,
          actions: [
            Container(
              margin: const EdgeInsets.only(right: 8),
              child: IconButton(
                icon: const Icon(
                  Icons.refresh_rounded,
                  color: Colors.white,
                  size: 24,
                ),
                onPressed: isLoading ? null : _refresh,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (isLoading) return _buildLoadingView();
    if (errorMessage != null) return _buildErrorView();
    return _buildProfileContent();
  }

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: themeColor),
          const SizedBox(height: 16),
          Text(
            'Loading profile...',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 80,
                color: Colors.red.shade400,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Failed to Load Profile',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              errorMessage ?? 'Unknown error occurred',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: _gradientColors),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: themeColor.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                label: const Text(
                  'Try Again',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileContent() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        children: [
          _buildProfileHeader(),
          const SizedBox(height: 16),
          _buildOptionsSection(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ==================== PROFILE HEADER ====================
  Widget _buildProfileHeader() {
    return Container(
      padding: const EdgeInsets.all(28),
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: themeColor.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildProfilePhoto(),
          const SizedBox(height: 18),
          _buildUserNameWithBadge(),
          const SizedBox(height: 10),
          _buildContactInfo(),
          const SizedBox(height: 14),
          _buildJoinDateBadge(),
        ],
      ),
    );
  }

  Widget _buildProfilePhoto() {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: CircleAvatar(
        radius: 54,
        backgroundImage: profilePhoto.isNotEmpty
            ? NetworkImage(profilePhoto)
            : null,
        backgroundColor: Colors.white,
        child: profilePhoto.isEmpty
            ? Icon(Icons.person_rounded, size: 64, color: Colors.grey.shade400)
            : null,
      ),
    );
  }

  Widget _buildUserNameWithBadge() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(
          child: Text(
            userName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
        const SizedBox(width: 10),
        _buildVerificationBadge(),
      ],
    );
  }

  // ✅ FIXED: Verification badge now uses isVerified boolean from API
  Widget _buildVerificationBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isVerified
            ? Colors.green.withOpacity(0.25)
            : Colors.orange.withOpacity(0.25),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isVerified ? Colors.green : Colors.orange,
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isVerified ? Icons.verified_rounded : Icons.pending_rounded,
            color: isVerified ? Colors.green : Colors.orange,
            size: 18,
          ),
          const SizedBox(width: 5),
          Text(
            isVerified ? "Verified" : "Unverified",
            style: TextStyle(
              color: isVerified ? Colors.green : Colors.orange,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactInfo() {
    return Column(
      children: [
        // Mobile Number - Shows ONLY if available
        if (userMobile.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.phone_android_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  userMobile,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        // Email
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.email_rounded, color: Colors.white70, size: 16),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                userEmail,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildJoinDateBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.calendar_today_rounded,
            color: Colors.white70,
            size: 14,
          ),
          const SizedBox(width: 7),
          Text(
            "Joined: $joinDate",
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ==================== OPTIONS SECTION ====================
  Widget _buildOptionsSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildOptionItem(
            icon: Icons.person_rounded,
            text: "Update Profile",
            nextPage: const UpdateProfilePage(),
            isFirst: true,
          ),
          _buildDivider(),
          _buildOptionItem(
            icon: Icons.verified_rounded,
            text: "KYC Verification",
            nextPage: const KycSubmitPage(),
          ),
          _buildDivider(),
          _buildOptionItem(
            icon: Icons.lock_rounded,
            text: "Change Password",
            nextPage: const PasswordChangePage(),
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() => Divider(
    height: 1,
    thickness: 1,
    color: Colors.grey.shade200,
    indent: 16,
    endIndent: 16,
  );

  Widget _buildOptionItem({
    required IconData icon,
    required String text,
    required Widget nextPage,
    bool isFirst = false,
    bool isLast = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => nextPage),
          );
          if (mounted) {
            _refresh();
          }
        },
        borderRadius: BorderRadius.vertical(
          top: isFirst ? const Radius.circular(14) : Radius.zero,
          bottom: isLast ? const Radius.circular(14) : Radius.zero,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      themeColor.withOpacity(0.15),
                      lightThemeColor.withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: themeColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
