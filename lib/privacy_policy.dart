// ==========================================
// Privacy & Policy Page
// Professional Design with Theme Integration
// ==========================================

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'config/api_config.dart';

String get _baseUrl => ApiConfig.baseUrl;

// ==================== THEME MANAGER ====================
/// 🎨 Copy this from your main file or import it
class ThemeManager {
  // URL: use ApiConfig.baseUrl

  // Default fallback colors
  static Color defaultColorStart = const Color(0xFFFF6F61);
  static Color defaultColorEnd = const Color(0xFFFF8A5C);

  // Current theme colors
  static Color themeColorStart = defaultColorStart;
  static Color themeColorEnd = defaultColorEnd;
  static String themeName = 'Default Theme';
  static bool isThemeLoaded = false;

  /// 🎨 Database থেকে theme load করো
  static Future<bool> loadThemeFromDatabase() async {
    debugPrint('🎨 [ThemeManager] Loading theme...');

    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/themechange'))
          .timeout(const Duration(seconds: 10));

      debugPrint('📡 Response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);

        if (json['status'] == true && json['data'] != null) {
          final data = json['data'];
          final colorCode = data['color_code'];
          final name = data['name'] ?? 'Custom Theme';

          if (colorCode != null && colorCode.isNotEmpty) {
            final parsedColor = _hexToColor(colorCode);
            themeColorStart = parsedColor;
            themeColorEnd = _lightenColor(parsedColor, 0.15);
            themeName = name;
            isThemeLoaded = true;

            debugPrint('✅ Theme loaded: $name');
            return true;
          }
        }
      }

      debugPrint('⚠️ Using default theme');
      _useDefaultTheme();
      return false;
    } catch (e) {
      debugPrint('❌ Error: $e');
      _useDefaultTheme();
      return false;
    }
  }

  static void _useDefaultTheme() {
    themeColorStart = defaultColorStart;
    themeColorEnd = defaultColorEnd;
    themeName = 'Default Theme';
    isThemeLoaded = true;
  }

  static Color _hexToColor(String hex) {
    try {
      hex = hex.trim().replaceAll('#', '');
      if (hex.length == 3) {
        hex = hex.split('').map((c) => c + c).join('');
      }
      if (hex.length == 6) hex = 'FF$hex';
      if (hex.length != 8) throw FormatException('Invalid hex');
      return Color(int.parse(hex, radix: 16));
    } catch (e) {
      return defaultColorStart;
    }
  }

  static Color _lightenColor(Color color, double amount) {
    try {
      final hsl = HSLColor.fromColor(color);
      return hsl
          .withLightness((hsl.lightness + amount).clamp(0.0, 1.0))
          .toColor();
    } catch (e) {
      return color;
    }
  }

  static BoxDecoration getGradientDecoration({
    double opacity = 1.0,
    BorderRadius? borderRadius,
  }) {
    return BoxDecoration(
      gradient: LinearGradient(
        colors: [
          themeColorStart.withOpacity(opacity),
          themeColorEnd.withOpacity(opacity),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: borderRadius,
    );
  }

  static BoxDecoration getLightGradientDecoration({
    BorderRadius? borderRadius,
    Border? border,
  }) {
    return BoxDecoration(
      gradient: LinearGradient(
        colors: [
          themeColorStart.withOpacity(0.1),
          themeColorEnd.withOpacity(0.1),
        ],
      ),
      borderRadius: borderRadius,
      border: border,
    );
  }

  static Gradient getGradient() {
    return LinearGradient(
      colors: [themeColorStart, themeColorEnd],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  static BoxShadow getShadow({double opacity = 0.3, double blur = 8}) {
    return BoxShadow(
      color: themeColorStart.withOpacity(opacity),
      blurRadius: blur,
      offset: const Offset(0, 2),
    );
  }
}

// ==================== PRIVACY POLICY SCREEN ====================
class PrivacyPolicyScreen extends StatefulWidget {
  const PrivacyPolicyScreen({Key? key}) : super(key: key);

  @override
  State<PrivacyPolicyScreen> createState() => _PrivacyPolicyScreenState();
}

class _PrivacyPolicyScreenState extends State<PrivacyPolicyScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    setState(() => _isLoading = true);
    await ThemeManager.loadThemeFromDatabase();
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(
              ThemeManager.themeColorStart,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // 🎨 Modern App Bar with Gradient
          SliverAppBar(
            expandedHeight: 200,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: ThemeManager.themeColorStart,
            flexibleSpace: Container(
              decoration: ThemeManager.getGradientDecoration(),
              child: FlexibleSpaceBar(
                title: const Text(
                  'Privacy & Policy',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                centerTitle: true,
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(decoration: ThemeManager.getGradientDecoration()),
                    Positioned(
                      top: 60,
                      right: -30,
                      child: Icon(
                        Icons.security,
                        size: 150,
                        color: Colors.white.withOpacity(0.1),
                      ),
                    ),
                    Positioned(
                      bottom: 20,
                      left: -30,
                      child: Icon(
                        Icons.privacy_tip,
                        size: 120,
                        color: Colors.white.withOpacity(0.1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),

          // 📄 Content
          SliverToBoxAdapter(
            child: Column(
              children: [
                // Last Updated Badge
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: ThemeManager.getLightGradientDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: ThemeManager.themeColorStart.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.update,
                          size: 16,
                          color: ThemeManager.themeColorStart,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Last Updated: January 04, 2026',
                          style: TextStyle(
                            color: ThemeManager.themeColorStart,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Introduction
                _buildSection(
                  icon: Icons.info_outline,
                  title: 'Introduction',
                  content:
                      'Welcome to our Live Chat application. We are committed to protecting your privacy and ensuring the security of your personal information. This Privacy Policy explains how we collect, use, disclose, and safeguard your information when you use our mobile application and services.',
                ),

                // Information We Collect
                _buildSection(
                  icon: Icons.folder_open,
                  title: 'Information We Collect',
                  content:
                      'We collect information that you provide directly to us, including:\n\n'
                      '• Personal Information: Name, email address, phone number, and profile photo\n'
                      '• Chat Messages: Text messages, images, and other content you share\n'
                      '• Device Information: Device type, operating system, and unique device identifiers\n'
                      '• Usage Data: How you interact with our app and services',
                ),

                // How We Use Your Information
                _buildSection(
                  icon: Icons.settings,
                  title: 'How We Use Your Information',
                  content:
                      'We use the information we collect to:\n\n'
                      '• Provide and maintain our chat services\n'
                      '• Send and receive messages between users\n'
                      '• Verify user accounts and prevent fraud\n'
                      '• Improve and personalize your experience\n'
                      '• Send notifications and updates\n'
                      '• Analyze usage patterns to enhance our services',
                ),

                // Data Security
                _buildSection(
                  icon: Icons.security,
                  title: 'Data Security',
                  content:
                      'We implement appropriate technical and organizational measures to protect your personal information against unauthorized access, alteration, disclosure, or destruction. This includes:\n\n'
                      '• Encrypted data transmission (SSL/TLS)\n'
                      '• Secure server infrastructure\n'
                      '• Regular security audits\n'
                      '• Access controls and authentication\n'
                      '• Data backup and recovery systems',
                ),

                // Information Sharing
                _buildSection(
                  icon: Icons.share,
                  title: 'Information Sharing',
                  content:
                      'We do not sell, trade, or rent your personal information to third parties. We may share your information only in the following circumstances:\n\n'
                      '• With your consent or at your direction\n'
                      '• With service providers who assist in operating our app\n'
                      '• To comply with legal obligations\n'
                      '• To protect our rights and prevent fraud',
                ),

                // Your Rights
                _buildSection(
                  icon: Icons.gavel,
                  title: 'Your Rights',
                  content:
                      'You have the right to:\n\n'
                      '• Access your personal information\n'
                      '• Correct inaccurate data\n'
                      '• Request deletion of your data\n'
                      '• Export your data\n'
                      '• Opt-out of marketing communications\n'
                      '• Withdraw consent at any time',
                ),

                // Data Retention
                _buildSection(
                  icon: Icons.timer,
                  title: 'Data Retention',
                  content:
                      'We retain your personal information for as long as necessary to provide our services and fulfill the purposes outlined in this policy. When you delete your account, we will delete or anonymize your personal information within 30 days, except where we are required to retain it by law.',
                ),

                // Children\'s Privacy
                _buildSection(
                  icon: Icons.child_care,
                  title: 'Children\'s Privacy',
                  content:
                      'Our service is not intended for users under the age of 13. We do not knowingly collect personal information from children under 13. If you are a parent or guardian and believe your child has provided us with personal information, please contact us immediately.',
                ),

                // Changes to This Policy
                _buildSection(
                  icon: Icons.update,
                  title: 'Changes to This Policy',
                  content:
                      'We may update this Privacy Policy from time to time. We will notify you of any changes by posting the new Privacy Policy on this page and updating the "Last Updated" date. You are advised to review this Privacy Policy periodically for any changes.',
                ),

                // Footer
                Container(
                  margin: const EdgeInsets.all(24),
                  padding: const EdgeInsets.all(20),
                  decoration: ThemeManager.getLightGradientDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: ThemeManager.themeColorStart.withOpacity(0.2),
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.verified_user,
                        size: 48,
                        color: ThemeManager.themeColorStart,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Your Privacy Matters',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: ThemeManager.themeColorStart,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'We are committed to protecting your data and respecting your privacy rights.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 📝 Build section widgetPri
  Widget _buildSection({
    required IconData icon,
    required String title,
    required String content,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: ThemeManager.getLightGradientDecoration(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: ThemeManager.getGradient(),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [ThemeManager.getShadow(opacity: 0.3, blur: 8)],
                  ),
                  child: Icon(icon, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: ThemeManager.themeColorStart,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Section Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              content,
              style: TextStyle(
                fontSize: 14,
                height: 1.6,
                color: Colors.grey[800],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== MAIN (FOR TESTING) ====================
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ThemeManager.loadThemeFromDatabase();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Privacy & Policy',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.red,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
      ),
      home: const PrivacyPolicyScreen(),
    );
  }
}
