import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'config/api_config.dart';

// ============================================
// MODEL CLASSES
// ============================================

class Stepguide {
  final int id;
  final String title;
  final String description;
  final String? icon;
  final int serialNumber;
  final String? createdAt;
  final String? updatedAt;

  Stepguide({
    required this.id,
    required this.title,
    required this.description,
    this.icon,
    required this.serialNumber,
    this.createdAt,
    this.updatedAt,
  });

  factory Stepguide.fromJson(Map<String, dynamic> json) {
    return Stepguide(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      icon: json['icon'],
      serialNumber: json['serial_number'] ?? 0,
      createdAt: json['created_at'],
      updatedAt: json['updated_at'],
    );
  }
}

class Whychooseu {
  final int id;
  final String title;
  final String description;
  final String? icon;
  final String? createdAt;
  final String? updatedAt;

  Whychooseu({
    required this.id,
    required this.title,
    required this.description,
    this.icon,
    this.createdAt,
    this.updatedAt,
  });

  factory Whychooseu.fromJson(Map<String, dynamic> json) {
    return Whychooseu(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      icon: json['icon'],
      createdAt: json['created_at'],
      updatedAt: json['updated_at'],
    );
  }
}

// ============================================
// API SERVICE
// ============================================

class HowToWorkService {
  String get baseUrl {
    if (Platform.isAndroid) {
      return ApiConfig.baseUrl;
    } else if (Platform.isIOS) {
      return ApiConfig.baseUrl;
    } else {
      return ApiConfig.baseUrl;
    }
  }

  // 🎨 Fetch Theme Color from Database
  Future<Color> fetchThemeColor() async {
    try {
      final themeUrl = baseUrl.replaceAll('/api', '') + '/api/themechange';
      print('🎨 Fetching theme from: $themeUrl');

      final response = await http
          .get(Uri.parse(themeUrl), headers: {'Accept': 'application/json'})
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception('Theme fetch timeout');
            },
          );

      print('🎨 Theme Status: ${response.statusCode}');
      print('🎨 Theme Response: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == true && data['data'] != null) {
          String colorCode = data['data']['color_code'] ?? '#4361EE';

          // Remove # if exists
          colorCode = colorCode.replaceAll('#', '');

          // Convert hex to Color
          final int colorValue = int.parse('FF$colorCode', radix: 16);
          final Color themeColor = Color(colorValue);

          print('✅ Theme loaded: $colorCode');
          return themeColor;
        }
      }

      // Return default color if failed
      return const Color(0xFF4361EE);
    } catch (e) {
      print('💥 Theme fetch error: $e');
      return const Color(0xFF4361EE); // Default fallback
    }
  }

  Future<Map<String, dynamic>> fetchHowToWork() async {
    try {
      print('🌐 Attempting to connect to: $baseUrl/howtowork');

      final response = await http
          .get(
            Uri.parse('$baseUrl/howtowork'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception(
                'Connection timeout! Check if Laravel server is running',
              );
            },
          );

      print('✅ Response Status: ${response.statusCode}');
      print('📦 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        print('🔍 Parsed Data: $data');

        if (data['success'] == true) {
          List<Stepguide> stepguides = (data['stepguides'] as List)
              .map((item) => Stepguide.fromJson(item))
              .toList();

          List<Whychooseu> whychooseus = (data['whychooseus'] as List)
              .map((item) => Whychooseu.fromJson(item))
              .toList();

          print('✅ Loaded ${stepguides.length} stepguides');
          print('✅ Loaded ${whychooseus.length} whychooseus');

          return {
            'success': true,
            'stepguides': stepguides,
            'whychooseus': whychooseus,
          };
        } else {
          throw Exception(data['message'] ?? 'API returned success: false');
        }
      } else {
        throw Exception(
          'Server error: ${response.statusCode}\nResponse: ${response.body}',
        );
      }
    } on http.ClientException catch (e) {
      print('❌ ClientException: $e');
      throw Exception(
        'Network error: Cannot connect to server. Make sure Laravel is running!',
      );
    } on FormatException catch (e) {
      print('❌ FormatException: $e');
      throw Exception('Invalid response format from server');
    } catch (e) {
      print('❌ Error in fetchHowToWork: $e');
      throw Exception('Connection failed: $e');
    }
  }
}

// ============================================
// MAIN SCREEN
// ============================================

class WhyChooseUs extends StatefulWidget {
  const WhyChooseUs({Key? key}) : super(key: key);

  @override
  State<WhyChooseUs> createState() => _WhyChooseUsState();
}

class _WhyChooseUsState extends State<WhyChooseUs> {
  final HowToWorkService _apiService = HowToWorkService();

  bool _isLoading = true;
  String? _errorMessage;
  List<Stepguide> _stepguides = [];
  List<Whychooseu> _whychooseus = [];

  // 🎨 Dynamic Theme Colors
  Color primaryColor = const Color(0xFF4361EE); // Default fallback
  Color lightPrimaryColor = const Color(0xFF4361EE);
  bool isThemeLoaded = false;

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  // Initialize: Load Theme first, then Data
  Future<void> _initializeScreen() async {
    await _loadTheme();
    await _loadData();
  }

  // 🎨 Load Theme Color
  Future<void> _loadTheme() async {
    try {
      final themeColor = await _apiService.fetchThemeColor();

      if (mounted) {
        setState(() {
          primaryColor = themeColor;
          lightPrimaryColor = _lightenColor(themeColor, 0.1);
          isThemeLoaded = true;
        });
        print('✅ Theme applied: ${primaryColor.value.toRadixString(16)}');
      }
    } catch (e) {
      print('💥 Theme load error: $e');
      // Keep default colors
    }
  }

  // Helper: Lighten color
  Color _lightenColor(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withLightness((hsl.lightness + amount).clamp(0.0, 1.0))
        .toColor();
  }

  // Load Data
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await _apiService.fetchHowToWork();

      if (mounted) {
        setState(() {
          _stepguides = result['stepguides'];
          _whychooseus = result['whychooseus'];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  // Refresh: Reload Theme + Data
  Future<void> _refreshAll() async {
    await _loadTheme();
    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],

      // ✅ FIXED: AppBar now uses dynamic theme color
      appBar: AppBar(
        backgroundColor: primaryColor, // 🎨 Theme color applied here
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Why Choose Us",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _refreshAll,
          ),
        ],
      ),

      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: primaryColor),
                  const SizedBox(height: 16),
                  const Text(
                    'Loading data...',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          : _errorMessage != null
          ? _buildErrorWidget()
          : RefreshIndicator(
              color: primaryColor,
              onRefresh: _refreshAll,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Step by Step Guide Section
                    _sectionHeader(Icons.list, "Step by Step Guide"),
                    const SizedBox(height: 16),

                    // Display Step Guides from API
                    if (_stepguides.isNotEmpty)
                      ..._stepguides.asMap().entries.map((entry) {
                        final step = entry.value;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _buildStepCard(
                            stepNumber: step.serialNumber.toString(),
                            title: step.title,
                            description: step.description,
                            icon: step.icon,
                          ),
                        );
                      })
                    else
                      _buildEmptyState('No step guides available'),

                    const SizedBox(height: 30),

                    // Why Choose Us Section
                    _sectionHeader(Icons.star, "Why Choose Us"),
                    const SizedBox(height: 20),

                    // Display Why Choose Us items from API
                    if (_whychooseus.isNotEmpty)
                      ..._whychooseus.map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: _buildWhyChooseUsCard(
                            title: item.title,
                            description: item.description,
                            icon: item.icon,
                          ),
                        ),
                      )
                    else
                      _buildEmptyState('No reasons available'),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }

  // Empty State Widget
  Widget _buildEmptyState(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
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
          Icon(Icons.inbox_outlined, size: 60, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  // Error Widget
  Widget _buildErrorWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 60, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              'Failed to load data',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _errorMessage ?? 'Unknown error',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red[700], fontSize: 13),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _refreshAll,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Section Header Widget
  Widget _sectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, color: primaryColor, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  // Step Card Widget
  Widget _buildStepCard({
    required String stepNumber,
    required String title,
    required String description,
    String? icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: primaryColor, width: 4)),
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
          Row(
            children: [
              // Step Number Circle
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: primaryColor,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    stepNumber,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Title
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Description
          Padding(
            padding: const EdgeInsets.only(left: 56),
            child: Text(
              description,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[700],
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Why Choose Us Card Widget
  Widget _buildWhyChooseUsCard({
    required String title,
    required String description,
    String? icon,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
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
          // Icon Circle
          Container(
            width: 75,
            height: 75,
            decoration: BoxDecoration(
              color: primaryColor,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.star, color: Colors.white, size: 35),
          ),
          const SizedBox(height: 18),

          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 14),

          Text(
            description,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[700],
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
