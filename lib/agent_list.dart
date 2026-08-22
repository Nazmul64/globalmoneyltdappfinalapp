import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'agent_chat.dart';
import 'helpers/user_session.dart';
import 'config/api_config.dart';

class AgentListScreen extends StatefulWidget {
  const AgentListScreen({Key? key}) : super(key: key);

  @override
  State<AgentListScreen> createState() => _AgentListScreenState();
}

class _AgentListScreenState extends State<AgentListScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> agents = [];
  List<Map<String, dynamic>> filteredAgents = [];
  bool isLoading = true;
  String errorMessage = '';
  bool isConnectionTested = false;

  // ✅ Session data - will be loaded from SharedPreferences
  String? authToken;
  int? currentUserId;
  String? userName;

  Color primaryColor = const Color(0xFF4361EE);
  Color primaryColorLight = const Color(0xFF4361EE).withOpacity(0.1);
  Color primaryColorDark = const Color(0xFF3651CE);
  bool isThemeLoading = true;

  final String apiBaseUrl = ApiConfig.baseUrl;

  @override
  void initState() {
    super.initState();
    _initializeScreen();
    _searchController.addListener(_filterAgents);
  }

  Future<void> _initializeScreen() async {
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('🔄 AGENT LIST SCREEN - INITIALIZING');

    // ✅ Load session data from SharedPreferences
    await _loadSessionData();

    debugPrint('📊 Session Status:');
    debugPrint('   - Logged In: ${authToken != null && currentUserId != null}');
    debugPrint('   - User ID: $currentUserId');
    debugPrint('   - User Name: $userName');
    debugPrint('   - Has Token: ${authToken != null}');
    if (authToken != null && authToken!.length > 20) {
      debugPrint('   - Token Preview: ${authToken!.substring(0, 20)}...');
    }
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    await _loadThemeColors();
    await _testConnection();
    await fetchAgents();
  }

  // ✅ Load session data from SharedPreferences
  Future<void> _loadSessionData() async {
    try {
      authToken = await UserSession.getAuthToken();
      currentUserId = await UserSession.getUserId();
      userName = await UserSession.getUserName();

      debugPrint('✅ Session data loaded from storage');
    } catch (e) {
      debugPrint('❌ Error loading session data: $e');
    }
  }

  Future<void> _loadThemeColors() async {
    try {
      debugPrint('🎨 Fetching theme colors from: $apiBaseUrl/themechange');

      final response = await http
          .get(
            Uri.parse('$apiBaseUrl/themechange'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);

        if (jsonData['status'] == true && jsonData['data'] != null) {
          String colorCode = jsonData['data']['color_code'] ?? '#4361EE';

          if (colorCode.startsWith('#')) {
            colorCode = colorCode.substring(1);
          }

          final colorValue = int.parse('FF$colorCode', radix: 16);

          setState(() {
            primaryColor = Color(colorValue);
            primaryColorLight = Color(colorValue).withOpacity(0.1);
            primaryColorDark = Color(colorValue).withOpacity(0.8);
            isThemeLoading = false;
          });

          debugPrint('✅ Theme loaded successfully: $colorCode');
        } else {
          _setDefaultTheme();
        }
      } else {
        debugPrint('⚠️ Theme API returned status: ${response.statusCode}');
        _setDefaultTheme();
      }
    } catch (e) {
      debugPrint('❌ Error loading theme: $e');
      _setDefaultTheme();
    }
  }

  void _setDefaultTheme() {
    setState(() {
      primaryColor = const Color(0xFF4361EE);
      primaryColorLight = const Color(0xFF4361EE).withOpacity(0.1);
      primaryColorDark = const Color(0xFF3651CE);
      isThemeLoading = false;
    });
    debugPrint('⚠️ Using default theme colors');
  }

  Future<void> _testConnection() async {
    try {
      debugPrint('🔍 Testing connection to: $apiBaseUrl/test');

      final response = await http
          .get(
            Uri.parse('$apiBaseUrl/test'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        debugPrint('✅ Server connection successful!');
        setState(() {
          isConnectionTested = true;
        });
      } else {
        debugPrint('⚠️ Server responded with status: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Connection test failed: $e');
      setState(() {
        isConnectionTested = false;
      });
    }
  }

  Future<void> fetchAgents() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      debugPrint('📡 Fetching agents from: $apiBaseUrl/agentlist');
      debugPrint(
        '   Using Token: ${authToken != null ? "${authToken!.substring(0, 20)}..." : "NO TOKEN"}',
      );

      final response = await http
          .get(
            Uri.parse('$apiBaseUrl/agentlist'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              if (authToken != null) 'Authorization': 'Bearer $authToken',
            },
          )
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              throw TimeoutException('Request timeout after 15 seconds');
            },
          );

      debugPrint('📥 Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);

        if (jsonData['status'] == true) {
          List<dynamic> agentsData = jsonData['data'] ?? [];

          setState(() {
            agents = agentsData.map((agent) {
              return _parseAgentData(agent);
            }).toList();

            filteredAgents = List.from(agents);
            isLoading = false;
          });

          debugPrint('✅ Successfully loaded ${agents.length} agents');

          await _fetchAllFriendRequestStatus();

          if (agents.isEmpty) {
            setState(() {
              errorMessage = 'No approved agents available at the moment.';
            });
          }
        } else {
          setState(() {
            errorMessage = jsonData['message'] ?? 'Failed to load agents';
            isLoading = false;
          });
          debugPrint('⚠️ API returned status false: ${jsonData['message']}');
        }
      } else {
        setState(() {
          errorMessage =
              'Server error: ${response.statusCode}\n\n'
              'Please check:\n'
              '• Laravel server is running\n'
              '• API routes are properly configured\n'
              '• Database connection is active';
          isLoading = false;
        });
        debugPrint('❌ Server error: ${response.statusCode}');
      }
    } on SocketException catch (e) {
      setState(() {
        errorMessage =
            'Cannot connect to server!\n\n'
            '🔧 Troubleshooting:\n'
            '1. Ensure Laravel server is running (php artisan serve)\n'
            '2. Verify API URL: $apiBaseUrl\n'
            '3. Check your internet/network connection\n'
            '4. For real device, use your PC\'s local IP address\n'
            '5. Disable VPN if active';
        isLoading = false;
      });
      debugPrint('❌ SocketException: $e');
    } on TimeoutException catch (e) {
      setState(() {
        errorMessage =
            'Request timeout!\n\nServer is not responding within 15 seconds.';
        isLoading = false;
      });
      debugPrint('❌ TimeoutException: $e');
    } catch (e) {
      setState(() {
        errorMessage = 'Unexpected error occurred:\n\n$e';
        isLoading = false;
      });
      debugPrint('❌ Unexpected error: $e');
    }
  }

  Future<void> _fetchAllFriendRequestStatus() async {
    // ✅ Check if user is logged in
    final isLoggedIn = await UserSession.isLoggedIn();
    if (!isLoggedIn) {
      debugPrint('⚠️ Cannot fetch friend request status - User not logged in');
      return;
    }

    for (var agent in agents) {
      await _checkFriendRequestStatus(agent['id']);
    }
  }

  Future<void> _checkFriendRequestStatus(int agentId) async {
    if (authToken == null) return;

    try {
      final response = await http
          .get(
            Uri.parse('$apiBaseUrl/check-friend-request/$agentId'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $authToken',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);

        if (jsonData['status'] == true) {
          setState(() {
            final index = agents.indexWhere((a) => a['id'] == agentId);
            if (index != -1) {
              agents[index]['friend_request_status'] =
                  jsonData['data']['status'] ?? 'none';
              agents[index]['request_id'] = jsonData['data']['request_id'];

              final filteredIndex = filteredAgents.indexWhere(
                (a) => a['id'] == agentId,
              );
              if (filteredIndex != -1) {
                filteredAgents[filteredIndex]['friend_request_status'] =
                    jsonData['data']['status'] ?? 'none';
                filteredAgents[filteredIndex]['request_id'] =
                    jsonData['data']['request_id'];
              }
            }
          });
          debugPrint(
            '✅ Friend request status for agent $agentId: ${jsonData['data']['status']}',
          );
        }
      }
    } catch (e) {
      debugPrint(
        '❌ Error checking friend request status for agent $agentId: $e',
      );
    }
  }

  Map<String, dynamic> _parseAgentData(dynamic agent) {
    String agentName = agent['name']?.toString() ?? 'Unknown Agent';
    String nameInitial = agentName.length >= 2
        ? agentName.substring(0, 2).toUpperCase()
        : agentName.substring(0, 1).toUpperCase();

    bool isVerified = false;
    String kycStatus = 'pending';

    if (agent['agentkyc'] != null) {
      kycStatus =
          agent['agentkyc']['status']?.toString().toLowerCase() ?? 'pending';
      isVerified = kycStatus == 'verified' || kycStatus == 'approved';
    }

    return {
      'id': agent['id'] ?? 0,
      'name': agentName,
      'name_initial': nameInitial,
      'agent_id': '#AG${(agent['id'] ?? 0).toString().padLeft(3, '0')}',
      'email': agent['email']?.toString() ?? 'N/A',
      'phone': agent['phone']?.toString() ?? 'N/A',
      'status': agent['status']?.toString() ?? 'offline',
      'verified': isVerified,
      'kyc_status': kycStatus,
      'profile_image': agent['photo']?.toString(),
      'friend_request_status': 'none',
      'request_id': null,
    };
  }

  Future<void> _sendFriendRequest(Map<String, dynamic> agent) async {
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('📤 SENDING FRIEND REQUEST');
    debugPrint('   Agent: ${agent['name']} (ID: ${agent['id']})');
    debugPrint('   Current Status: ${agent['friend_request_status']}');

    // ✅ Check if user is logged in
    final isLoggedIn = await UserSession.isLoggedIn();
    if (!isLoggedIn) {
      debugPrint('❌ FAILED: User not logged in');
      _showSnackBar('Please login first!', Colors.red);
      return;
    }

    if (authToken == null || authToken!.isEmpty) {
      debugPrint('❌ FAILED: No auth token available');
      _showSnackBar('Authentication error. Please login again.', Colors.red);
      return;
    }

    try {
      // ✅ IMMEDIATELY UPDATE UI TO PENDING STATE
      setState(() {
        final index = agents.indexWhere((a) => a['id'] == agent['id']);
        if (index != -1) {
          agents[index]['friend_request_status'] = 'pending';

          final filteredIndex = filteredAgents.indexWhere(
            (a) => a['id'] == agent['id'],
          );
          if (filteredIndex != -1) {
            filteredAgents[filteredIndex]['friend_request_status'] = 'pending';
          }
        }
      });

      debugPrint('🔄 UI Updated to PENDING state');

      final response = await http
          .post(
            Uri.parse('$apiBaseUrl/agent-friend-request'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $authToken',
            },
            body: json.encode({'receiver_id': agent['id']}),
          )
          .timeout(const Duration(seconds: 15));

      debugPrint('📥 Response Status: ${response.statusCode}');
      debugPrint('📥 Response Body: ${response.body}');

      final jsonData = json.decode(response.body);

      if (response.statusCode == 200 && jsonData['status'] == true) {
        // ✅ CONFIRM PENDING STATUS WITH REQUEST ID
        setState(() {
          final index = agents.indexWhere((a) => a['id'] == agent['id']);
          if (index != -1) {
            agents[index]['friend_request_status'] = 'pending';
            agents[index]['request_id'] = jsonData['data']['id'];

            final filteredIndex = filteredAgents.indexWhere(
              (a) => a['id'] == agent['id'],
            );
            if (filteredIndex != -1) {
              filteredAgents[filteredIndex]['friend_request_status'] =
                  'pending';
              filteredAgents[filteredIndex]['request_id'] =
                  jsonData['data']['id'];
            }
          }
        });

        debugPrint('✅ SUCCESS: Friend request sent');
        debugPrint('   Request ID: ${jsonData['data']['id']}');
        debugPrint('   New Status: pending');
        debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

        _showSnackBar(
          'Friend request sent to ${agent['name']}!',
          const Color(0xFF4CAF50),
        );
      } else {
        // ❌ IF FAILED, REVERT BACK TO 'none'
        setState(() {
          final index = agents.indexWhere((a) => a['id'] == agent['id']);
          if (index != -1) {
            agents[index]['friend_request_status'] = 'none';

            final filteredIndex = filteredAgents.indexWhere(
              (a) => a['id'] == agent['id'],
            );
            if (filteredIndex != -1) {
              filteredAgents[filteredIndex]['friend_request_status'] = 'none';
            }
          }
        });

        String errorMsg =
            jsonData['message'] ?? 'Failed to send friend request';
        debugPrint('❌ FAILED: $errorMsg');
        debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        _showSnackBar(errorMsg, Colors.red);
      }
    } catch (e) {
      // ❌ IF ERROR, REVERT BACK TO 'none'
      setState(() {
        final index = agents.indexWhere((a) => a['id'] == agent['id']);
        if (index != -1) {
          agents[index]['friend_request_status'] = 'none';

          final filteredIndex = filteredAgents.indexWhere(
            (a) => a['id'] == agent['id'],
          );
          if (filteredIndex != -1) {
            filteredAgents[filteredIndex]['friend_request_status'] = 'none';
          }
        }
      });

      debugPrint('❌ ERROR: $e');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      _showSnackBar('Failed to send request. Please try again.', Colors.red);
    }
  }

  void _showSnackBar(String message, Color backgroundColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _filterAgents() {
    String query = _searchController.text.toLowerCase().trim();

    setState(() {
      if (query.isEmpty) {
        filteredAgents = List.from(agents);
      } else {
        filteredAgents = agents.where((agent) {
          return agent['name'].toString().toLowerCase().contains(query) ||
              agent['agent_id'].toString().toLowerCase().contains(query) ||
              agent['phone'].toString().toLowerCase().contains(query) ||
              agent['email'].toString().toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  Future<void> _refreshData() async {
    await _loadSessionData(); // ✅ Reload session data
    await _loadThemeColors();
    await fetchAgents();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: primaryColor,
      elevation: 2,
      shadowColor: primaryColor.withOpacity(0.3),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text(
        'Agent List',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 18,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.white),
          onPressed: _refreshData,
          tooltip: 'Refresh',
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: primaryColor.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: primaryColor.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Icon(Icons.search, color: primaryColor, size: 22),
            ),
            Expanded(
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'Search by name, ID, phone or email...',
                  hintStyle: TextStyle(color: Color(0xFFBDBDBD), fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            if (_searchController.text.isNotEmpty)
              IconButton(
                icon: Icon(Icons.clear, size: 20, color: primaryColor),
                onPressed: () => _searchController.clear(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (isLoading) return _buildLoadingState();
    if (errorMessage.isNotEmpty && agents.isEmpty) return _buildErrorState();
    return _buildAgentsList();
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: primaryColor),
          const SizedBox(height: 16),
          const Text(
            'Loading agents...',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 80, color: Colors.red.shade300),
            const SizedBox(height: 24),
            const Text(
              'Connection Error',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Text(
                errorMessage,
                textAlign: TextAlign.left,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.black87,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _refreshData,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAgentsList() {
    return RefreshIndicator(
      onRefresh: _refreshData,
      color: primaryColor,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSupportBanner(),
          const SizedBox(height: 24),
          _buildAgentsHeader(),
          const SizedBox(height: 16),
          if (filteredAgents.isEmpty)
            _buildEmptyState()
          else
            ...filteredAgents.map((agent) => _buildAgentCard(agent)).toList(),
        ],
      ),
    );
  }

  Widget _buildSupportBanner() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor, primaryColorDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const Row(
        children: [
          Icon(Icons.headset_mic, color: Colors.white, size: 32),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '24/7 Support Available',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Connect with verified agents for instant support',
                  style: TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAgentsHeader() {
    return Row(
      children: [
        Icon(Icons.people, color: primaryColor, size: 22),
        const SizedBox(width: 8),
        Text(
          'Available Agents (${filteredAgents.length})',
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: Color(0xFF212121),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48.0),
        child: Column(
          children: [
            Icon(Icons.search_off, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              'No agents found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Try adjusting your search or check back later',
              style: TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAgentCard(Map<String, dynamic> agent) {
    final bool isOnline =
        agent['status'].toString().toLowerCase() == 'approved';
    final String requestStatus = agent['friend_request_status'] ?? 'none';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAgentHeader(agent),
          const SizedBox(height: 12),
          _buildContactInfo(agent),
          const SizedBox(height: 12),
          _buildStatusBadge(isOnline),
          const SizedBox(height: 16),
          _buildActionButtons(agent, requestStatus),
        ],
      ),
    );
  }

  Widget _buildAgentHeader(Map<String, dynamic> agent) {
    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: primaryColor.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipOval(
            child: agent['profile_image'] != null &&
                    agent['profile_image'].toString().trim().isNotEmpty &&
                    !agent['profile_image'].toString().endsWith('/uploads/avator.jpg') &&
                    !agent['profile_image'].toString().endsWith('/avator.jpg')
                ? Image.network(
                    ApiConfig.avatarUrl(agent['profile_image'].toString()),
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Image.asset(
                        'assets/avator.jpg',
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                      );
                    },
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Image.asset(
                        'assets/avator.jpg',
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                      );
                    },
                  )
                : Image.asset(
                    'assets/avator.jpg',
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                  ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      agent['name'],
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF212121),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildVerificationBadge(agent['verified']),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                agent['agent_id'],
                style: const TextStyle(fontSize: 13, color: Color(0xFF757575)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVerificationBadge(bool isVerified) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isVerified ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isVerified ? const Color(0xFF4CAF50) : const Color(0xFFD32F2F),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isVerified ? Icons.verified : Icons.cancel,
            size: 11,
            color: isVerified
                ? const Color(0xFF4CAF50)
                : const Color(0xFFD32F2F),
          ),
          const SizedBox(width: 4),
          Text(
            isVerified ? 'VERIFIED' : 'UNVERIFIED',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: isVerified
                  ? const Color(0xFF4CAF50)
                  : const Color(0xFFD32F2F),
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactInfo(Map<String, dynamic> agent) {
    if (agent['phone'] == 'N/A' && agent['email'] == 'N/A') {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: primaryColorLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: primaryColor.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (agent['phone'] != 'N/A')
            Row(
              children: [
                Icon(Icons.phone, size: 15, color: primaryColor),
                const SizedBox(width: 8),
                Text(
                  agent['phone'],
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF424242),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          if (agent['phone'] != 'N/A' && agent['email'] != 'N/A')
            const SizedBox(height: 8),
          if (agent['email'] != 'N/A')
            Row(
              children: [
                Icon(Icons.email, size: 15, color: primaryColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    agent['email'],
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF424242),
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(bool isOnline) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isOnline ? const Color(0xFFE8F5E9) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isOnline ? const Color(0xFF4CAF50) : Colors.grey.shade400,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isOnline ? const Color(0xFF4CAF50) : Colors.grey,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            isOnline ? 'Available' : 'Offline',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isOnline ? const Color(0xFF4CAF50) : Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(Map<String, dynamic> agent, String requestStatus) {
    debugPrint(
      '🎨 Building buttons for ${agent['name']} - Status: $requestStatus',
    );

    if (requestStatus == 'accepted') {
      return Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4CAF50), Color(0xFF66BB6A)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4CAF50).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, size: 18, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    'Friend',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _openChat(agent),
              icon: const Icon(
                Icons.chat_bubble,
                size: 18,
                color: Colors.white,
              ),
              label: const Text(
                'Live Chat',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2196F3),
                foregroundColor: Colors.white,
                elevation: 2,
                shadowColor: const Color(0xFF2196F3).withOpacity(0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      );
    }

    if (requestStatus == 'pending') {
      return Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFA726), Color(0xFFFFB74D)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFA726).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.schedule, size: 18, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    'Waiting For Accept',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _openChat(agent),
              icon: const Icon(
                Icons.chat_bubble,
                size: 18,
                color: Colors.white,
              ),
              label: const Text(
                'Live Chat',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2196F3),
                foregroundColor: Colors.white,
                elevation: 2,
                shadowColor: const Color(0xFF2196F3).withOpacity(0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _sendFriendRequest(agent),
            icon: const Icon(Icons.person_add, size: 18, color: Colors.white),
            label: const Text(
              'Send Request',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              elevation: 2,
              shadowColor: primaryColor.withOpacity(0.4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ],
    );
  }

  void _openChat(Map<String, dynamic> agent) {
    debugPrint(
      '🚀 Opening chat with agent: ${agent['name']} (ID: ${agent['id']})',
    );
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AgentLiveChatScreen()),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
