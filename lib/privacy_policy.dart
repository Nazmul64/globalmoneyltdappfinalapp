// ==========================================
// Privacy & Policy Page
// Fully Dynamic — Loaded from Admin Backend
// Professional Design with Theme Integration
// ==========================================

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'config/api_config.dart';

String get _baseUrl => ApiConfig.baseUrl;

// ==================== THEME MANAGER ====================
class ThemeManager {
  // Default fallback colors
  static Color defaultColorStart = const Color(0xFFFF6F61);
  static Color defaultColorEnd = const Color(0xFFFF8A5C);

  // Current theme colors
  static Color themeColorStart = defaultColorStart;
  static Color themeColorEnd = defaultColorEnd;
  static String themeName = 'Default Theme';
  static bool isThemeLoaded = false;

  /// Load active theme from database
  static Future<bool> loadThemeFromDatabase() async {
    debugPrint('🎨 [ThemeManager] Loading theme...');

    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/themechange'))
          .timeout(const Duration(seconds: 10));

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
            return true;
          }
        }
      }

      _useDefaultTheme();
      return false;
    } catch (e) {
      debugPrint('❌ [ThemeManager] Error: $e');
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

// ==================== DATA MODEL ====================
class PrivacyPolicyItem {
  final int? id;
  final String title;
  final String description;
  final String? updatedAt;

  PrivacyPolicyItem({
    this.id,
    required this.title,
    required this.description,
    this.updatedAt,
  });

  factory PrivacyPolicyItem.fromJson(Map<String, dynamic> json) {
    return PrivacyPolicyItem(
      id: json['id'] is int ? json['id'] : int.tryParse('${json['id']}'),
      title: json['title'] ?? 'Privacy Policy',
      description: json['description'] ?? json['content'] ?? '',
      updatedAt: json['updated_at'] ?? json['created_at'],
    );
  }
}

// ==================== PRIVACY POLICY SCREEN ====================
class PrivacyPolicyScreen extends StatefulWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  State<PrivacyPolicyScreen> createState() => _PrivacyPolicyScreenState();
}

class _PrivacyPolicyScreenState extends State<PrivacyPolicyScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<PrivacyPolicyItem> _policies = [];
  String? _lastUpdated;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    await ThemeManager.loadThemeFromDatabase();
    await _fetchPrivacyPolicy();

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  /// 📡 Fetch Privacy Policy from API
  Future<void> _fetchPrivacyPolicy() async {
    try {
      final url = ApiConfig.privacyPolicy;
      debugPrint('📡 Fetching Privacy Policy from: $url');

      final response = await http.get(Uri.parse(url)).timeout(
            const Duration(seconds: 12),
          );

      debugPrint('📡 Privacy API Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final List<PrivacyPolicyItem> fetchedList = [];

        // Check if multiple policies returned in 'policies' array
        if (json['policies'] != null && json['policies'] is List) {
          final list = json['policies'] as List;
          for (var item in list) {
            if (item is Map<String, dynamic>) {
              fetchedList.add(PrivacyPolicyItem.fromJson(item));
            }
          }
        }

        // Check main 'data' field
        if (json['data'] != null && json['data'] is Map<String, dynamic>) {
          final mainItem = PrivacyPolicyItem.fromJson(json['data']);
          if (mainItem.description.trim().isNotEmpty) {
            // Add if not already present
            if (!fetchedList.any((p) => p.title == mainItem.title && p.description == mainItem.description)) {
              fetchedList.insert(0, mainItem);
            }
            if (mainItem.updatedAt != null) {
              _lastUpdated = mainItem.updatedAt;
            }
          }
        }

        if (fetchedList.isNotEmpty) {
          _policies = fetchedList;
          _lastUpdated ??= fetchedList.first.updatedAt;
        } else {
          _errorMessage = 'No privacy policy content available.';
        }
      } else {
        _errorMessage = 'Failed to load Privacy Policy (${response.statusCode})';
      }
    } catch (e) {
      debugPrint('❌ Privacy API Fetch Error: $e');
      _errorMessage = 'Unable to connect to server. Please check your internet connection.';
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
      backgroundColor: const Color(0xFFF8F9FA),
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: ThemeManager.themeColorStart,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // 🎨 Modern App Bar with Gradient
            SliverAppBar(
              expandedHeight: 180,
              floating: false,
              pinned: true,
              elevation: 0,
              backgroundColor: ThemeManager.themeColorStart,
              flexibleSpace: Container(
                decoration: ThemeManager.getGradientDecoration(),
                child: FlexibleSpaceBar(
                  title: const Text(
                    'Privacy Policy',
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
                        top: 50,
                        right: -20,
                        child: Icon(
                          Icons.security_outlined,
                          size: 140,
                          color: Colors.white.withOpacity(0.12),
                        ),
                      ),
                      Positioned(
                        bottom: 10,
                        left: -20,
                        child: Icon(
                          Icons.privacy_tip_outlined,
                          size: 110,
                          color: Colors.white.withOpacity(0.12),
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

            // 📄 Body Content
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                child: Column(
                  children: [
                    // Last Updated Badge if available
                    if (_lastUpdated != null && _lastUpdated!.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
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
                              'Last Updated: $_lastUpdated',
                              style: TextStyle(
                                color: ThemeManager.themeColorStart,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Error View with Retry Button
                    if (_errorMessage != null && _policies.isEmpty)
                      _buildErrorWidget(),

                    // Dynamic Policies List (Loaded from Admin Panel DB)
                    if (_policies.isNotEmpty)
                      ..._policies.map((policy) => _buildPolicyCard(policy)),

                    // Footer Banner
                    _buildFooterWidget(),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ❌ Error Card
  Widget _buildErrorWidget() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      margin: const EdgeInsets.symmetric(vertical: 20),
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
        children: [
          Icon(Icons.info_outline, size: 54, color: Colors.orange.shade400),
          const SizedBox(height: 12),
          Text(
            _errorMessage ?? 'No privacy policy content available.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, color: Colors.black87),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh, color: Colors.white),
            label: const Text('Try Again', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: ThemeManager.themeColorStart,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  /// 📝 Policy Card (Render Title and HTML Description from DB)
  Widget _buildPolicyCard(PrivacyPolicyItem policy) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header with Title
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
                    boxShadow: [ThemeManager.getShadow(opacity: 0.25, blur: 6)],
                  ),
                  child: const Icon(Icons.description, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    policy.title,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: ThemeManager.themeColorStart,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Section Content (Rich HTML Text Parser)
          Padding(
            padding: const EdgeInsets.all(18),
            child: DynamicHtmlContent(htmlContent: policy.description),
          ),
        ],
      ),
    );
  }

  /// 🛡️ Footer Card
  Widget _buildFooterWidget() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
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
            size: 44,
            color: ThemeManager.themeColorStart,
          ),
          const SizedBox(height: 10),
          Text(
            'Your Privacy Matters',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: ThemeManager.themeColorStart,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'We are committed to protecting your data and respecting your privacy rights.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ==================== DYNAMIC HTML CONTENT RENDERER ====================
/// Clean, robust Flutter parser that converts HTML output from Summernote editor into native Flutter Widgets!
class DynamicHtmlContent extends StatelessWidget {
  final String htmlContent;

  const DynamicHtmlContent({super.key, required this.htmlContent});

  @override
  Widget build(BuildContext context) {
    if (htmlContent.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    final blocks = _parseHtmlToBlocks(htmlContent);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: blocks.map((block) {
        if (block.type == _BlockType.heading) {
          return Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 8),
            child: Text(
              block.text,
              style: TextStyle(
                fontSize: block.level == 1 ? 20 : (block.level == 2 ? 18 : 16),
                fontWeight: FontWeight.bold,
                color: ThemeManager.themeColorStart,
                height: 1.3,
              ),
            ),
          );
        } else if (block.type == _BlockType.listItem) {
          return Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 6, right: 8),
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: ThemeManager.themeColorStart,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Expanded(
                  child: _buildRichText(block.text),
                ),
              ],
            ),
          );
        } else {
          // Paragraph / Normal Block
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _buildRichText(block.text),
          );
        }
      }).toList(),
    );
  }

  /// Renders styled inline text (handles <b>, <strong>, <i>, <em>, <u>)
  Widget _buildRichText(String text) {
    final spans = _parseInlineSpans(text);
    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontSize: 14,
          height: 1.6,
          color: Colors.grey[850],
          fontFamily: 'Roboto',
        ),
        children: spans,
      ),
    );
  }

  /// Parse raw HTML into structural blocks
  List<_ContentBlock> _parseHtmlToBlocks(String html) {
    String cleanHtml = html
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'");

    // Replace <br> and <br/> with line break tag
    cleanHtml = cleanHtml.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');

    final List<_ContentBlock> blocks = [];

    // Split HTML tags using regular expression
    final RegExp tagExp = RegExp(
      r'<(h[1-6]|p|li|ul|ol|div|blockquote)[^>]*>(.*?)</\1>|<(h[1-6]|p|li)[^>]*/>|([^<]+)',
      caseSensitive: false,
      dotAll: true,
    );

    final matches = tagExp.allMatches(cleanHtml);

    for (final match in matches) {
      final tag = match.group(1)?.toLowerCase();
      final content = match.group(2) ?? match.group(4) ?? '';
      final trimmed = content.trim();

      if (trimmed.isEmpty) continue;

      if (tag != null && tag.startsWith('h')) {
        int level = int.tryParse(tag.substring(1)) ?? 2;
        blocks.add(_ContentBlock(
          type: _BlockType.heading,
          text: _stripTags(trimmed),
          level: level,
        ));
      } else if (tag == 'li') {
        blocks.add(_ContentBlock(
          type: _BlockType.listItem,
          text: trimmed,
        ));
      } else {
        // If content contains sub-tags like <li> or <p>, process lines
        final lines = trimmed.split('\n');
        for (var line in lines) {
          final tLine = line.trim();
          if (tLine.isNotEmpty) {
            blocks.add(_ContentBlock(
              type: _BlockType.paragraph,
              text: tLine,
            ));
          }
        }
      }
    }

    // Fallback if regex matched nothing
    if (blocks.isEmpty && cleanHtml.trim().isNotEmpty) {
      final plain = _stripTags(cleanHtml);
      for (var paragraph in plain.split('\n')) {
        if (paragraph.trim().isNotEmpty) {
          blocks.add(_ContentBlock(
            type: _BlockType.paragraph,
            text: paragraph.trim(),
          ));
        }
      }
    }

    return blocks;
  }

  /// Strip remaining outer tags for titles
  String _stripTags(String html) {
    return html.replaceAll(RegExp(r'<[^>]*>'), '').trim();
  }

  /// Parse inline HTML tags for RichText formatting
  List<TextSpan> _parseInlineSpans(String text) {
    final List<TextSpan> spans = [];

    final RegExp inlineExp = RegExp(
      r'<(b|strong|i|em|u)[^>]*>(.*?)</\1>|([^<]+)',
      caseSensitive: false,
      dotAll: true,
    );

    final matches = inlineExp.allMatches(text);

    for (final match in matches) {
      final tag = match.group(1)?.toLowerCase();
      final innerContent = match.group(2) ?? match.group(3) ?? '';
      final cleanText = _stripTags(innerContent);

      if (cleanText.isEmpty) continue;

      if (tag == 'b' || tag == 'strong') {
        spans.add(TextSpan(
          text: cleanText,
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ));
      } else if (tag == 'i' || tag == 'em') {
        spans.add(TextSpan(
          text: cleanText,
          style: const TextStyle(fontStyle: FontStyle.italic),
        ));
      } else if (tag == 'u') {
        spans.add(TextSpan(
          text: cleanText,
          style: const TextStyle(decoration: TextDecoration.underline),
        ));
      } else {
        spans.add(TextSpan(text: cleanText));
      }
    }

    if (spans.isEmpty && text.trim().isNotEmpty) {
      spans.add(TextSpan(text: _stripTags(text)));
    }

    return spans;
  }
}

enum _BlockType { paragraph, heading, listItem }

class _ContentBlock {
  final _BlockType type;
  final String text;
  final int level;

  _ContentBlock({required this.type, required this.text, this.level = 2});
}

// ==================== MAIN (FOR STANDALONE TESTING) ====================
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ThemeManager.loadThemeFromDatabase();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Privacy Policy',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.red,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF8F9FA),
      ),
      home: const PrivacyPolicyScreen(),
    );
  }
}
