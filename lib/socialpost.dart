import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/post_model.dart';
import '../services/api_service.dart';
import '../widgets/post_card.dart';
import '../widgets/create_post_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'config/api_config.dart';

class SocialFeedScreen extends StatefulWidget {
  const SocialFeedScreen({Key? key}) : super(key: key);

  @override
  State<SocialFeedScreen> createState() => _SocialFeedScreenState();
}

class _SocialFeedScreenState extends State<SocialFeedScreen> {
  // Posts data
  List<Post> _posts = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  int _currentPage = 1;
  bool _hasMoreData = true;
  final ScrollController _scrollController = ScrollController();

  // Theme
  Color _themeColor = const Color(0xFF4361EE);
  bool _isLoadingTheme = true;

  // User profile
  String _userProfilePicture = '';
  String _userName = 'User';
  bool _isUserVerified = false;
  bool _isLoadingUserData = true;
  int? _currentUserId;

  // API Base URL - ✅ FIXED: Removed space before /api
  // URL: use ApiConfig.baseUrl

  @override
  void initState() {
    super.initState();
    _initializeScreen();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // ========================================
  // INITIALIZATION
  // ========================================

  Future<void> _initializeScreen() async {
    await Future.wait([
      _loadThemeColor(),
      _loadCurrentUserData(),
      _loadPosts(),
    ]);
  }

  // ========================================
  // USER DATA LOADING
  // ========================================

  Future<void> _loadCurrentUserData() async {
    try {
      setState(() => _isLoadingUserData = true);

      final prefs = await SharedPreferences.getInstance();
      _currentUserId = prefs.getInt('user_id');
      _userName = prefs.getString('user_name') ?? 'User';

      if (_currentUserId == null) {
        setState(() => _isLoadingUserData = false);
        return;
      }

      await Future.wait([
        _loadUserProfilePicture(),
        _loadUserVerificationStatus(_currentUserId!),
      ]);

      setState(() => _isLoadingUserData = false);
    } catch (e) {
      print('❌ Error loading user data: $e');
      setState(() => _isLoadingUserData = false);
    }
  }

  Future<void> _loadUserProfilePicture() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) {
        print('⚠️ No auth token found');
        return;
      }

      final url = _currentUserId != null
          ? '${ApiConfig.baseUrl}/userphotoshow?user_id=$_currentUserId'
          : '${ApiConfig.baseUrl}/userphotoshow';

      final response = await http
          .get(
            Uri.parse(url),
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if ((data['status'] == true || data['success'] == true) && mounted) {
          String photoUrl = (data['photo'] ??
                  data['data']?['photo'] ??
                  data['data']?['avatar'] ??
                  '')
              .toString();

          if (photoUrl.isNotEmpty) {
            photoUrl = ApiConfig.avatarUrl(photoUrl);
          }

          setState(() {
            _userProfilePicture = photoUrl;
          });
          print('✅ Profile picture loaded: $_userProfilePicture');
        }
      } else {
        print('⚠️ Failed to load profile picture: ${response.statusCode}');
        print('Response: ${response.body}');
      }
    } catch (e) {
      print('❌ Error loading profile picture: $e');
    }
  }

  Future<void> _loadUserVerificationStatus(int userId) async {
    try {
      final response = await http
          .get(
            Uri.parse('${ApiConfig.baseUrl}/user/$userId/verify-status'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == true && mounted) {
          setState(() {
            _isUserVerified = data['verified'] ?? false;
          });
          print('✅ Verification status: $_isUserVerified');
        }
      } else {
        print('⚠️ Failed to load verification status: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error loading verification status: $e');
    }
  }

  // ========================================
  // THEME LOADING
  // ========================================

  Future<void> _loadThemeColor() async {
    try {
      setState(() => _isLoadingTheme = true);

      final response = await http
          .get(
            Uri.parse(ApiConfig.themeChange),
            headers: {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == true && data['data'] != null && mounted) {
          final colorCode = data['data']['color_code'] as String;
          setState(() {
            _themeColor = _parseColor(colorCode);
            _isLoadingTheme = false;
          });
          print('✅ Theme color loaded: $colorCode');
        } else {
          setState(() => _isLoadingTheme = false);
        }
      } else {
        setState(() => _isLoadingTheme = false);
      }
    } catch (e) {
      print('❌ Theme load error: $e');
      setState(() => _isLoadingTheme = false);
    }
  }

  Color _parseColor(String colorCode) {
    try {
      String hexColor = colorCode.replaceAll('#', '');
      if (hexColor.length == 6) {
        return Color(int.parse('FF$hexColor', radix: 16));
      }
      return const Color(0xFF4361EE);
    } catch (e) {
      return const Color(0xFF4361EE);
    }
  }

  // ========================================
  // POSTS LOADING
  // ========================================

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMoreData) {
        _loadMorePosts();
      }
    }
  }

  Future<void> _loadPosts() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _currentPage = 1;
    });

    try {
      final result = await ApiService.getPosts(page: 1, perPage: 10);

      if (mounted) {
        setState(() {
          _isLoading = false;
          if (result['success'] == true) {
            _posts = List<Post>.from(result['posts'] ?? []);
            final pagination = result['pagination'];
            if (pagination != null) {
              _hasMoreData =
                  pagination['current_page'] < pagination['last_page'];
            }
            print('✅ Loaded ${_posts.length} posts');
          } else {
            _showErrorSnackBar(result['message'] ?? 'Failed to load posts');
          }
        });
      }
    } catch (e) {
      print('❌ Error loading posts: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorSnackBar('Error loading posts: $e');
      }
    }
  }

  Future<void> _loadMorePosts() async {
    if (_isLoadingMore || !_hasMoreData) return;

    setState(() => _isLoadingMore = true);

    try {
      final nextPage = _currentPage + 1;
      final result = await ApiService.getPosts(page: nextPage, perPage: 10);

      if (mounted) {
        setState(() {
          _isLoadingMore = false;
          if (result['success'] == true) {
            final newPosts = List<Post>.from(result['posts'] ?? []);
            _posts.addAll(newPosts);
            _currentPage = nextPage;
            final pagination = result['pagination'];
            if (pagination != null) {
              _hasMoreData =
                  pagination['current_page'] < pagination['last_page'];
            }
            print('✅ Loaded ${newPosts.length} more posts (Page $nextPage)');
          }
        });
      }
    } catch (e) {
      print('❌ Error loading more posts: $e');
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  Future<void> _refreshPosts() async {
    print('🔄 Refreshing posts...');
    await Future.wait([
      _loadThemeColor(),
      _loadCurrentUserData(),
      _loadPosts(),
    ]);
  }

  // ========================================
  // POST ACTIONS
  // ========================================

  void _showCreatePostSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CreatePostSheet(
        onPostCreated: (Post newPost) {
          if (mounted) {
            setState(() {
              _posts.insert(0, newPost);
            });
            _showSuccessSnackBar('Post created successfully!');
          }
        },
      ),
    );
  }

  void _onPostUpdated(Post updatedPost) {
    if (!mounted) return;

    setState(() {
      final index = _posts.indexWhere((p) => p.id == updatedPost.id);
      if (index != -1) {
        _posts[index] = updatedPost;
        print('✅ Post updated: ${updatedPost.id}');
      }
    });
  }

  void _onPostDeleted(int postId) {
    if (!mounted) return;

    setState(() {
      _posts.removeWhere((p) => p.id == postId);
      print('🗑️ Post deleted: $postId');
    });
    _showSuccessSnackBar('Post deleted successfully!');
  }

  // ========================================
  // UI HELPERS
  // ========================================

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: _themeColor,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ========================================
  // BUILD METHOD
  // ========================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: _buildAppBar(),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshPosts,
          color: _themeColor,
          child: _buildBody(),
        ),
      ),
    );
  }

  // ========================================
  // APP BAR
  // ========================================

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text(
        'Social Feed',
        style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
      ),
      backgroundColor: _themeColor,
      foregroundColor: Colors.white,
      elevation: 0.5,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.of(context).pop(),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search, color: Colors.white),
          onPressed: () => _showSuccessSnackBar('Search coming soon!'),
        ),
        IconButton(
          icon: const Icon(Icons.notifications_outlined, color: Colors.white),
          onPressed: () => _showSuccessSnackBar('Notifications coming soon!'),
        ),
      ],
    );
  }

  // ========================================
  // BODY
  // ========================================

  Widget _buildBody() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: _themeColor));
    }

    if (_posts.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: _posts.length + 2,
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildCreatePostInput();
        }

        if (index == _posts.length + 1) {
          return _isLoadingMore
              ? Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Center(
                    child: CircularProgressIndicator(color: _themeColor),
                  ),
                )
              : const SizedBox(height: 16);
        }

        final post = _posts[index - 1];
        return PostCard(
          key: ValueKey(post.id),
          post: post,
          currentUserId: _currentUserId, // ✅ PASS current user ID
          onPostUpdated: _onPostUpdated,
          onPostDeleted: _onPostDeleted,
        );
      },
    );
  }

  // ========================================
  // EMPTY STATE
  // ========================================

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.post_add, size: 80, color: _themeColor.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text(
            'No posts yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Be the first to create a post!',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showCreatePostSheet,
            icon: const Icon(Icons.add),
            label: const Text('Create Post'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _themeColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              elevation: 2,
            ),
          ),
        ],
      ),
    );
  }

  // ========================================
  // CREATE POST INPUT
  // ========================================

  Widget _buildCreatePostInput() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Info Row
            Row(
              children: [
                _buildProfilePicture(),
                const SizedBox(width: 12),
                Expanded(child: _buildUserInfo()),
              ],
            ),
            const SizedBox(height: 12),
            // Input Field
            _buildInputField(),
          ],
        ),
      ),
    );
  }

  // ========================================
  // PROFILE PICTURE
  // ========================================

  Widget _buildProfilePicture() {
    String avatarUrl = '';
    if (_userProfilePicture.isNotEmpty) {
      avatarUrl = _userProfilePicture.startsWith('http')
          ? _userProfilePicture
          : ApiConfig.avatarUrl(_userProfilePicture);
    }
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: _themeColor.withOpacity(0.3), width: 2),
      ),
      child: ClipOval(
        child: avatarUrl.isNotEmpty
            ? Image.network(
                avatarUrl,
                width: 44,
                height: 44,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  print('❌ Failed to load top profile image: $error | URL: $avatarUrl');
                  return Container(
                    width: 44,
                    height: 44,
                    color: _themeColor.withOpacity(0.1),
                    alignment: Alignment.center,
                    child: Text(
                      _userName.isNotEmpty ? _userName[0].toUpperCase() : 'U',
                      style: TextStyle(
                        color: _themeColor,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                },
              )
            : Container(
                width: 44,
                height: 44,
                color: _themeColor.withOpacity(0.1),
                alignment: Alignment.center,
                child: Text(
                  _userName.isNotEmpty ? _userName[0].toUpperCase() : 'U',
                  style: TextStyle(
                    color: _themeColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
      ),
    );
  }

  // ========================================
  // USER INFO
  // ========================================

  Widget _buildUserInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                _userName,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            _buildVerificationBadge(),
          ],
        ),
      ],
    );
  }

  // ========================================
  // VERIFICATION BADGE
  // ========================================

  Widget _buildVerificationBadge() {
    if (_isUserVerified) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue.withOpacity(0.3), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.verified, color: Colors.blue, size: 14),
            SizedBox(width: 4),
            Text(
              'Verified',
              style: TextStyle(
                fontSize: 11,
                color: Colors.blue,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.withOpacity(0.3), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.info_outline, color: Colors.grey[600], size: 14),
            const SizedBox(width: 4),
            Text(
              'Unverified',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }
  }

  // ========================================
  // INPUT FIELD
  // ========================================

  Widget _buildInputField() {
    return GestureDetector(
      onTap: _showCreatePostSheet,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.grey[300]!, width: 1),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                "What's on your mind?",
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
            ),
            Icon(Icons.image_outlined, color: _themeColor, size: 22),
          ],
        ),
      ),
    );
  }
}
