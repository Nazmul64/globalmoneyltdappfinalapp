import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'config/api_config.dart';
import 'addbalance.dart';
import 'membership.dart';

class OptionsPage extends StatefulWidget {
  const OptionsPage({super.key});

  @override
  State<OptionsPage> createState() => _OptionsPageState();
}

class _OptionsPageState extends State<OptionsPage>
    with SingleTickerProviderStateMixin {
  // ========================================
  // STATE VARIABLES
  // ========================================

  // Membership Instructions Data
  String _membershipTitle = "Loading...";
  String _membershipDescription = "Please wait...";
  bool _isLoadingInstructions = true;
  String _errorMessage = "";

  // Theme Colors - NO HARDCODED DEFAULTS
  Color? _primaryColor;
  Color? _secondaryColor;
  Color? _accentColor;
  bool _isLoadingTheme = false;

  // Animation Controller - Nullable to avoid LateInitializationError
  AnimationController? _animationController;
  Animation<double>? _fadeAnimation;
  Animation<Offset>? _slideAnimation;

  // API Configuration
  static const String depositInstructionsUrl = '${ApiConfig.baseUrl}/deposit-instructions';
  static const String themeChangeUrl = '${ApiConfig.baseUrl}/themechange';

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _initializePage();
  }

  @override
  void dispose() {
    _animationController?.dispose();
    super.dispose();
  }

  // ========================================
  // INITIALIZATION
  // ========================================

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController!, curve: Curves.easeIn),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(parent: _animationController!, curve: Curves.easeOut),
        );

    _animationController!.forward();
  }

  Future<void> _initializePage() async {
    await Future.wait([_fetchThemeColors(), _fetchInstructions()]);
  }

  // ========================================
  // FETCH THEME FROM DATABASE
  // ========================================

  Future<void> _fetchThemeColors() async {
    setState(() => _isLoadingTheme = true);

    try {
      print('🎨 [OPTIONS] Fetching theme colors from database...');

      final response = await http
          .get(
            Uri.parse(themeChangeUrl),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 10));

      print('📥 [OPTIONS] Theme Response Status: ${response.statusCode}');
      print('📥 [OPTIONS] Theme Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == true && data['data'] != null) {
          final themeData = data['data'];
          final String colorCode = themeData['color_code'];

          setState(() {
            _primaryColor = _parseColor(colorCode);
            _secondaryColor = _generateSecondaryColor(_primaryColor!);
            _accentColor = _generateAccentColor(_primaryColor!);
          });

          print('✅ [OPTIONS] Theme Colors Loaded:');
          print('   Primary: $_primaryColor');
          print('   Secondary: $_secondaryColor');
          print('   Accent: $_accentColor');
        } else {
          print('⚠️ [OPTIONS] No theme data, using fallback');
          _applyFallbackTheme();
        }
      } else {
        print('⚠️ [OPTIONS] Theme API error: ${response.statusCode}');
        _applyFallbackTheme();
      }
    } on SocketException {
      print('❌ [OPTIONS] No internet for theme');
      _applyFallbackTheme();
    } on TimeoutException {
      print('❌ [OPTIONS] Theme API timeout');
      _applyFallbackTheme();
    } catch (e) {
      print('❌ [OPTIONS] Theme fetch error: $e');
      _applyFallbackTheme();
    } finally {
      setState(() => _isLoadingTheme = false);
    }
  }

  void _applyFallbackTheme() {
    setState(() {
      _primaryColor = const Color(0xFFFF6F61);
      _secondaryColor = const Color(0xFFFF8A5C);
      _accentColor = const Color(0xFFFF9B7B);
    });
    print('⚙️ [OPTIONS] Applied fallback theme');
  }

  Color _parseColor(String? hexColor) {
    if (hexColor == null || hexColor.isEmpty) {
      return const Color(0xFFFF6F61);
    }

    try {
      String colorString = hexColor.replaceAll('#', '');
      if (colorString.length == 6) {
        colorString = 'FF$colorString';
      }
      return Color(int.parse(colorString, radix: 16));
    } catch (e) {
      print('❌ [OPTIONS] Color parse error: $e');
      return const Color(0xFFFF6F61);
    }
  }

  Color _generateSecondaryColor(Color primary) {
    final hslColor = HSLColor.fromColor(primary);
    return hslColor
        .withLightness((hslColor.lightness + 0.1).clamp(0.0, 1.0))
        .toColor();
  }

  Color _generateAccentColor(Color primary) {
    final hslColor = HSLColor.fromColor(primary);
    return hslColor
        .withLightness((hslColor.lightness + 0.15).clamp(0.0, 1.0))
        .toColor();
  }

  // ========================================
  // FETCH MEMBERSHIP INSTRUCTIONS
  // ========================================

  Future<void> _fetchInstructions() async {
    setState(() {
      _isLoadingInstructions = true;
      _errorMessage = "";
    });

    try {
      print('📤 [OPTIONS] Fetching membership instructions...');

      final response = await http
          .get(
            Uri.parse(depositInstructionsUrl),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 10));

      print('📥 [OPTIONS] Instructions Status: ${response.statusCode}');
      print('📥 [OPTIONS] Instructions Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['data'] != null && data['data'].isNotEmpty) {
          setState(() {
            _membershipTitle =
                data['data'][0]['member_ship_instructions_title'] ??
                'Membership Instructions';
            _membershipDescription =
                data['data'][0]['member_ship_instructions_description'] ??
                'No description available.';
            _isLoadingInstructions = false;
            _errorMessage = "";
          });
          print('✅ [OPTIONS] Instructions loaded successfully');
        } else {
          setState(() {
            _membershipTitle = "No Data Available";
            _membershipDescription =
                "No membership instructions found in database.";
            _isLoadingInstructions = false;
            _errorMessage = "No data found in database";
          });
          print('⚠️ [OPTIONS] No instructions data found');
        }
      } else {
        setState(() {
          _membershipTitle = "Server Error";
          _membershipDescription =
              "Failed to load membership instructions. Please try again later.";
          _isLoadingInstructions = false;
          _errorMessage = "HTTP Error: ${response.statusCode}";
        });
        print('❌ [OPTIONS] HTTP Error: ${response.statusCode}');
      }
    } on SocketException {
      setState(() {
        _membershipTitle = "Connection Error";
        _membershipDescription =
            "Unable to connect to server. Please check your internet connection.";
        _isLoadingInstructions = false;
        _errorMessage = "No internet connection";
      });
      print('❌ [OPTIONS] No internet connection');
    } on TimeoutException {
      setState(() {
        _membershipTitle = "Timeout Error";
        _membershipDescription =
            "Server is taking too long to respond. Please try again.";
        _isLoadingInstructions = false;
        _errorMessage = "Request timeout";
      });
      print('❌ [OPTIONS] Request timeout');
    } catch (e) {
      setState(() {
        _membershipTitle = "Error";
        _membershipDescription =
            "An unexpected error occurred. Please try again later.";
        _isLoadingInstructions = false;
        _errorMessage = e.toString();
      });
      print('❌ [OPTIONS] Error: $e');
    }
  }

  // ========================================
  // REFRESH DATA
  // ========================================

  Future<void> _refreshData() async {
    _animationController?.reset();
    await _initializePage();
    _animationController?.forward();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Data refreshed successfully! ✅'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // ========================================
  // NAVIGATION METHODS
  // ========================================

  void _navigateToAddBalance() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddBalancePage()),
    );
  }

  void _navigateToMembership() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MembershipPage()),
    );
  }

  // ========================================
  // BUILD METHOD
  // ========================================

  @override
  Widget build(BuildContext context) {
    // Safe fallback for theme colors
    final primaryColor = _primaryColor ?? const Color(0xFFFF6F61);
    final secondaryColor = _secondaryColor ?? const Color(0xFFFF8A5C);
    final accentColor = _accentColor ?? const Color(0xFFFF9B7B);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: _buildAppBar(primaryColor),
      body: _isLoadingTheme
          ? _buildLoadingScreen(primaryColor)
          : RefreshIndicator(
              color: primaryColor,
              onRefresh: _refreshData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: _fadeAnimation == null || _slideAnimation == null
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeader(primaryColor),
                          const SizedBox(height: 30),
                          _buildOptionCards(
                            primaryColor,
                            secondaryColor,
                            accentColor,
                          ),
                          const SizedBox(height: 30),
                          _buildInstructionsCard(primaryColor),
                          const SizedBox(height: 20),
                        ],
                      )
                    : FadeTransition(
                        opacity: _fadeAnimation!,
                        child: SlideTransition(
                          position: _slideAnimation!,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildHeader(primaryColor),
                              const SizedBox(height: 30),
                              _buildOptionCards(
                                primaryColor,
                                secondaryColor,
                                accentColor,
                              ),
                              const SizedBox(height: 30),
                              _buildInstructionsCard(primaryColor),
                              const SizedBox(height: 20),
                            ],
                          ),
                        ),
                      ),
              ),
            ),
    );
  }

  // ========================================
  // UI COMPONENTS
  // ========================================

  PreferredSizeWidget _buildAppBar(Color primaryColor) {
    return AppBar(
      backgroundColor: primaryColor,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new,
          color: Colors.white,
          size: 22,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text(
        'Options',
        style: TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
      centerTitle: true,
      actions: [
        IconButton(
          icon: const Icon(
            Icons.refresh_rounded,
            color: Colors.white,
            size: 26,
          ),
          onPressed: _refreshData,
          tooltip: 'Refresh',
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildLoadingScreen(Color primaryColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: primaryColor, strokeWidth: 3),
          const SizedBox(height: 20),
          const Text(
            'Loading options...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.black54,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor, primaryColor.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.settings_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Account Options',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Manage your account settings',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionCards(
    Color primaryColor,
    Color secondaryColor,
    Color accentColor,
  ) {
    return Row(
      children: [
        Expanded(
          child: _OptionCard(
            icon: Icons.add_circle_rounded,
            label: 'Add Balance',
            subtitle: 'Top up your account',
            primaryColor: primaryColor,
            secondaryColor: secondaryColor,
            onTap: _navigateToAddBalance,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _OptionCard(
            icon: Icons.shopping_bag_rounded,
            label: 'Buy Membership',
            subtitle: 'Upgrade your plan',
            primaryColor: primaryColor,
            secondaryColor: accentColor,
            onTap: _navigateToMembership,
          ),
        ),
      ],
    );
  }

  Widget _buildInstructionsCard(Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primaryColor, primaryColor.withOpacity(0.7)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.info_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _membershipTitle,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    if (_isLoadingInstructions)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
              ),
              if (_errorMessage.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.warning_rounded,
                    color: Colors.orange,
                    size: 22,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),

          // Divider
          Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.grey.shade200,
                  Colors.grey.shade100,
                  Colors.grey.shade200,
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Description
          if (_isLoadingInstructions)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: CircularProgressIndicator(
                  color: primaryColor,
                  strokeWidth: 2,
                ),
              ),
            )
          else
            Text(
              _membershipDescription,
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey.shade700,
                height: 1.6,
                letterSpacing: 0.3,
              ),
            ),

          // Error Message (Debug)
          if (_errorMessage.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: Colors.red.shade700,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red.shade700,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Retry Button (if error)
          if (_errorMessage.isNotEmpty) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _fetchInstructions,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Retry Loading'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ========================================
// CUSTOM OPTION CARD WIDGET
// ========================================

class _OptionCard extends StatefulWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color primaryColor;
  final Color secondaryColor;
  final VoidCallback onTap;

  const _OptionCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.primaryColor,
    required this.secondaryColor,
    required this.onTap,
  });

  @override
  State<_OptionCard> createState() => _OptionCardState();
}

class _OptionCardState extends State<_OptionCard>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  Animation<double>? _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(parent: _controller!, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    setState(() => _isPressed = true);
    _controller?.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    _controller?.reverse();
    widget.onTap();
  }

  void _handleTapCancel() {
    setState(() => _isPressed = false);
    _controller?.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return _scaleAnimation == null
        ? _buildCard()
        : ScaleTransition(scale: _scaleAnimation!, child: _buildCard());
  }

  Widget _buildCard() {
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [widget.primaryColor, widget.secondaryColor],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: widget.primaryColor.withOpacity(0.4),
              blurRadius: _isPressed ? 8 : 15,
              offset: Offset(0, _isPressed ? 2 : 6),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(widget.icon, color: Colors.white, size: 40),
            ),
            const SizedBox(height: 16),
            Text(
              widget.label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
