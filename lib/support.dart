import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'config/api_config.dart';

String get baseUrl => ApiConfig.mediaBaseUrl;

class SupportCenterPage extends StatefulWidget {
  const SupportCenterPage({super.key});

  @override
  State<SupportCenterPage> createState() => _SupportCenterPageState();
}

class _SupportCenterPageState extends State<SupportCenterPage>
    with SingleTickerProviderStateMixin {
  List<SupportItem> supportItems = [];
  bool isLoading = true;
  String? errorMessage;

  // 🎨 100% Database Theme
  Color? themeColor;
  bool themeLoaded = false;
  String themeName = 'Loading...';

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
        );

    _animationController.forward();
  }

  Future<void> _loadData() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    await Future.wait([_fetchThemeColor(), _fetchSupportData()]);

    setState(() {
      isLoading = false;
    });
  }

  /// 🎨 Fetch Theme Color from Database
  Future<void> _fetchThemeColor() async {
    try {
      print('🎨 Fetching theme from: $baseUrl/api/themechange');

      final response = await http
          .get(
            Uri.parse('$baseUrl/api/themechange'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 10));

      print('🎨 Theme Status: ${response.statusCode}');
      print('🎨 Theme Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == true && data['data'] != null) {
          final colorCode = data['data']['color_code'];
          final name = data['data']['name'] ?? 'Custom Theme';

          if (colorCode != null && colorCode.toString().isNotEmpty) {
            setState(() {
              themeColor = _hexToColor(colorCode.toString());
              themeName = name;
              themeLoaded = true;
            });

            print('✅ Theme loaded: $name ($colorCode)');
          }
        }
      }
    } catch (e) {
      print('❌ Theme error: $e');
      setState(() {
        themeColor = const Color(0xFF4361EE);
        themeName = 'Default';
        themeLoaded = true;
      });
    }
  }

  Color _hexToColor(String hexString) {
    try {
      final buffer = StringBuffer();
      if (hexString.length == 6 || hexString.length == 7) {
        buffer.write('ff');
      }
      buffer.write(hexString.replaceFirst('#', ''));
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (e) {
      return const Color(0xFF4361EE);
    }
  }

  /// 📞 Fetch Support Data from Database (NO AUTH)
  Future<void> _fetchSupportData() async {
    try {
      print('📞 Fetching support data from: $baseUrl/api/support');

      final response = await http
          .get(
            Uri.parse('$baseUrl/api/support'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 10));

      print('📞 Support Status: ${response.statusCode}');
      print('📞 Support Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == true) {
          final List<dynamic> dataList = data['data'] ?? [];

          setState(() {
            supportItems = dataList.map((item) {
              return SupportItem(
                id: item['id']?.toString() ?? '',
                name: item['name']?.toString() ?? 'Unknown',
                urlLink: item['url_link']?.toString() ?? '',
                icon: item['icon']?.toString() ?? 'fas fa-question-circle',
                createdAt: item['created_at']?.toString() ?? '',
                updatedAt: item['updated_at']?.toString() ?? '',
              );
            }).toList();

            errorMessage = null;
          });

          print('✅ ${supportItems.length} support items loaded');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Support error: $e');
      setState(() {
        errorMessage = 'Failed to load support data';
      });
    }
  }

  Future<void> _launchURL(String url, String name) async {
    if (url.isEmpty) {
      _showErrorSnackbar('Invalid URL');
      return;
    }

    try {
      String finalUrl = url;
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        finalUrl = 'https://$url';
      }

      print('🔗 Launching: $finalUrl');

      final uri = Uri.parse(finalUrl);

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        HapticFeedback.mediumImpact();
        _showSuccessSnackbar('Opening $name...');
      } else {
        throw Exception('Cannot launch URL');
      }
    } catch (e) {
      print('❌ Launch error: $e');
      _showErrorSnackbar('Failed to open link');
    }
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Color get safeThemeColor => themeColor ?? const Color(0xFF4361EE);
  Color get themeLightColor => safeThemeColor.withOpacity(0.1);

  List<Color> get themeGradient {
    final hsl = HSLColor.fromColor(safeThemeColor);
    final lighter = hsl
        .withLightness((hsl.lightness + 0.1).clamp(0.0, 1.0))
        .toColor();
    return [safeThemeColor, lighter];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: themeGradient,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.pop(context);
              },
            ),
          ),
          const Expanded(
            child: Text(
              'Support Center',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.refresh, color: Colors.white),
              onPressed: isLoading ? null : _loadData,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (isLoading) return _buildLoadingState();
    if (errorMessage != null) return _buildErrorState();
    if (supportItems.isEmpty) return _buildEmptyState();

    return RefreshIndicator(
      onRefresh: _loadData,
      color: safeThemeColor,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _buildHeaderCard(),
              const SizedBox(height: 24),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 1.1,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: supportItems.length,
                itemBuilder: (context, index) {
                  return _buildSupportCard(supportItems[index]);
                },
              ),
              const SizedBox(height: 24),
              _buildFooterInfo(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [themeLightColor, themeLightColor.withOpacity(0.5)],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.support_agent, size: 48, color: safeThemeColor),
          ),
          const SizedBox(height: 16),
          const Text(
            'How can we help you?',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose a support option below to get assistance',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildSupportCard(SupportItem item) {
    return InkWell(
      onTap: () {
        HapticFeedback.mediumImpact();
        _launchURL(item.urlLink, item.name);
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: safeThemeColor.withOpacity(0.1),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(color: safeThemeColor.withOpacity(0.2), width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [themeLightColor, themeLightColor.withOpacity(0.5)],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getIconFromString(item.icon),
                size: 40,
                color: safeThemeColor,
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                item.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: safeThemeColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Tap to open',
                    style: TextStyle(
                      fontSize: 12,
                      color: safeThemeColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_forward, size: 12, color: safeThemeColor),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIconFromString(String iconString) {
    final iconMap = {
      'fas fa-question-circle': Icons.help_outline,
      'fas fa-phone': Icons.phone,
      'fas fa-envelope': Icons.email,
      'fas fa-comments': Icons.chat_bubble_outline,
      'fas fa-headset': Icons.headset_mic,
      'fab fa-whatsapp': Icons.chat,
      'fab fa-telegram': Icons.telegram,
      'fab fa-facebook': Icons.facebook,
      'fas fa-briefcase': Icons.work_outline,
      'fa-briefcase': Icons.business_center,
    };

    return iconMap[iconString.toLowerCase()] ?? Icons.support_agent;
  }

  Widget _buildFooterInfo() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          const Icon(Icons.info_outline, color: Colors.white, size: 32),
          const SizedBox(height: 12),
          const Text(
            'Need more help?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Our support team is available 24/7 to assist you',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(40),
        margin: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: safeThemeColor, strokeWidth: 3),
            const SizedBox(height: 24),
            const Text('Loading Support Center...'),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        margin: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 64,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Failed to Load',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 12),
            Text(errorMessage ?? 'Unknown error', textAlign: TextAlign.center),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: safeThemeColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 32,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(40),
        margin: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.support_agent, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 24),
            Text(
              'No Support Options',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SupportItem {
  final String id;
  final String name;
  final String urlLink;
  final String icon;
  final String createdAt;
  final String updatedAt;

  SupportItem({
    required this.id,
    required this.name,
    required this.urlLink,
    required this.icon,
    required this.createdAt,
    required this.updatedAt,
  });
}
