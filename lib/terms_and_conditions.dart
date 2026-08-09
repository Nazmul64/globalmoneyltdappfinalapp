// ==========================================
// Terms & Conditions Page
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

// ==================== TERMS & CONDITIONS SCREEN ====================
class TermsAndConditionsScreen extends StatefulWidget {
  const TermsAndConditionsScreen({Key? key}) : super(key: key);

  @override
  State<TermsAndConditionsScreen> createState() =>
      _TermsAndConditionsScreenState();
}

class _TermsAndConditionsScreenState extends State<TermsAndConditionsScreen> {
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
                  'Terms & Conditions',
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
                        Icons.description,
                        size: 150,
                        color: Colors.white.withOpacity(0.1),
                      ),
                    ),
                    Positioned(
                      bottom: 20,
                      left: -30,
                      child: Icon(
                        Icons.gavel,
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

                // Acceptance of Terms
                _buildSection(
                  icon: Icons.check_circle_outline,
                  title: 'Acceptance of Terms',
                  content:
                      'By accessing or using our Live Chat application, you agree to be bound by these Terms and Conditions. If you do not agree with any part of these terms, you must not use our application. Your continued use of the service constitutes acceptance of these terms and any future modifications.',
                ),

                // User Accounts
                _buildSection(
                  icon: Icons.account_circle,
                  title: 'User Accounts',
                  content:
                      'To use our chat services, you must create an account. You agree to:\n\n'
                      '• Provide accurate and complete information\n'
                      '• Maintain the security of your account credentials\n'
                      '• Immediately notify us of any unauthorized access\n'
                      '• Be responsible for all activities under your account\n'
                      '• Not share your account with others\n'
                      '• Be at least 13 years of age',
                ),

                // Acceptable Use
                _buildSection(
                  icon: Icons.thumb_up_outlined,
                  title: 'Acceptable Use Policy',
                  content:
                      'You agree NOT to use our service to:\n\n'
                      '• Send spam, unsolicited messages, or harassment\n'
                      '• Share illegal, harmful, or offensive content\n'
                      '• Impersonate others or provide false information\n'
                      '• Violate any applicable laws or regulations\n'
                      '• Upload viruses or malicious code\n'
                      '• Attempt to gain unauthorized access to our systems\n'
                      '• Interfere with the proper functioning of the service',
                ),

                // Content Ownership
                _buildSection(
                  icon: Icons.copyright,
                  title: 'Content Ownership & Rights',
                  content:
                      'You retain ownership of the content you share through our service. However, by using our application, you grant us a license to:\n\n'
                      '• Store and transmit your messages\n'
                      '• Display your content to other users as intended\n'
                      '• Make backups for service reliability\n\n'
                      'You represent that you own or have the necessary rights to all content you share and that your content does not violate any third-party rights.',
                ),

                // Service Availability
                _buildSection(
                  icon: Icons.cloud_queue,
                  title: 'Service Availability',
                  content:
                      'We strive to provide reliable service, but we cannot guarantee uninterrupted access. We reserve the right to:\n\n'
                      '• Modify or discontinue the service at any time\n'
                      '• Perform maintenance and updates\n'
                      '• Suspend accounts that violate these terms\n'
                      '• Change features or functionality\n\n'
                      'We are not liable for any service interruptions, data loss, or damages resulting from service unavailability.',
                ),

                // Limitation of Liability
                _buildSection(
                  icon: Icons.warning_amber,
                  title: 'Limitation of Liability',
                  content:
                      'Our service is provided "as is" without warranties of any kind. To the maximum extent permitted by law:\n\n'
                      '• We are not liable for any indirect, incidental, or consequential damages\n'
                      '• We do not guarantee the accuracy or reliability of user-generated content\n'
                      '• We are not responsible for user interactions or disputes\n'
                      '• Our total liability shall not exceed the amount you paid us in the past 12 months',
                ),

                // Termination
                _buildSection(
                  icon: Icons.cancel,
                  title: 'Account Termination',
                  content:
                      'Either party may terminate the account at any time:\n\n'
                      '• You can delete your account through app settings\n'
                      '• We may suspend or terminate accounts that violate these terms\n'
                      '• Upon termination, you lose access to all content and features\n'
                      '• Some provisions of these terms survive termination\n\n'
                      'We reserve the right to terminate accounts without prior notice for serious violations.',
                ),

                // Intellectual Property
                _buildSection(
                  icon: Icons.lightbulb_outline,
                  title: 'Intellectual Property',
                  content:
                      'All rights, title, and interest in the application and its original content, features, and functionality are owned by us and are protected by:\n\n'
                      '• International copyright laws\n'
                      '• Trademark laws\n'
                      '• Other intellectual property rights\n\n'
                      'You may not copy, modify, distribute, or reverse engineer any part of our service without explicit written permission.',
                ),

                // Dispute Resolution
                _buildSection(
                  icon: Icons.balance,
                  title: 'Dispute Resolution',
                  content:
                      'Any disputes arising from these terms or your use of the service will be resolved through:\n\n'
                      '• Good faith negotiation between the parties\n'
                      '• Binding arbitration if negotiation fails\n'
                      '• Governing law of the jurisdiction where our company is registered\n\n'
                      'You waive the right to participate in class action lawsuits against us.',
                ),

                // Changes to Terms
                _buildSection(
                  icon: Icons.update,
                  title: 'Changes to These Terms',
                  content:
                      'We may modify these Terms and Conditions at any time. When we do:\n\n'
                      '• We will update the "Last Updated" date\n'
                      '• Significant changes will be notified via email or in-app notification\n'
                      '• Continued use after changes constitutes acceptance\n\n'
                      'We recommend reviewing these terms periodically to stay informed of any updates.',
                ),

                // Contact Information
                // _buildSection(
                //   icon: Icons.contact_support,
                //   title: 'Contact Us',
                //   content:
                //   'If you have any questions about these Terms and Conditions, please contact us at:\n\n'
                //       '📧 Email: support@livechat.com\n'
                //       '📱 Phone: +1 (555) 123-4567\n'
                //       '🌐 Website: www.livechat.com/support\n\n'
                //       'We will respond to your inquiries within 48 hours during business days.',
                // ),

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
                        Icons.handshake,
                        size: 48,
                        color: ThemeManager.themeColorStart,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Agreement & Understanding',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: ThemeManager.themeColorStart,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'By using our service, you acknowledge that you have read, understood, and agree to be bound by these Terms and Conditions.',
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

  /// 📝 Build section widget
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
      title: 'Terms & Conditions',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.red,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
      ),
      home: const TermsAndConditionsScreen(),
    );
  }
}
