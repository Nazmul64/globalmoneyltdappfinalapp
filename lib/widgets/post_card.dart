import 'package:flutter/material.dart';
import '../models/post_model.dart';
import '../services/api_service.dart';
import '../widgets/comment_sheet.dart';
import '../widgets/edit_post_sheet.dart';

class PostCard extends StatefulWidget {
  final Post post;
  final int? currentUserId; // ✅ ADDED: Current user ID from parent
  final Function(Post) onPostUpdated;
  final Function(int) onPostDeleted;

  const PostCard({
    Key? key,
    required this.post,
    this.currentUserId, // ✅ ADDED: Accept current user ID
    required this.onPostUpdated,
    required this.onPostDeleted,
  }) : super(key: key);

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  late Post _post;
  bool _isLiking = false;
  Color _themeColor = const Color(0xFF4361EE); // Default color
  bool _isLoadingTheme = true;

  @override
  void initState() {
    super.initState();
    _post = widget.post;
    _loadTheme();
  }

  @override
  void didUpdateWidget(PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post != widget.post) {
      setState(() {
        _post = widget.post;
      });
    }
  }

  /// ✅ Load theme color from database via API
  Future<void> _loadTheme() async {
    try {
      final themeData = await ApiService.getTheme();
      if (mounted && themeData['status'] == true) {
        final colorCode = themeData['data']['color_code'] ?? '#4361EE';
        setState(() {
          _themeColor = _hexToColor(colorCode);
          _isLoadingTheme = false;
        });
        print('🎨 Theme color applied: $colorCode');
      } else {
        if (mounted) {
          setState(() {
            _themeColor = const Color(0xFF4361EE);
            _isLoadingTheme = false;
          });
        }
      }
    } catch (e) {
      print('❌ Theme load error: $e');
      if (mounted) {
        setState(() {
          _themeColor = const Color(0xFF4361EE);
          _isLoadingTheme = false;
        });
      }
    }
  }

  /// ✅ Convert hex color string to Color object
  Color _hexToColor(String hexString) {
    try {
      final buffer = StringBuffer();
      if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
      buffer.write(hexString.replaceFirst('#', ''));
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (e) {
      print('❌ Hex color parse error: $e');
      return const Color(0xFF4361EE); // Fallback to default
    }
  }

  /// ✅ Check if current user owns this post
  bool get _isPostOwner {
    if (widget.currentUserId == null) {
      print('⚠️ Current user ID is null');
      return false;
    }

    final isOwner = widget.currentUserId == _post.userId;
    print('🔍 Post owner check: Current user ID: ${widget.currentUserId}, Post user ID: ${_post.userId}, Is owner: $isOwner');
    return isOwner;
  }

  /// ✅ Toggle like/unlike with optimistic UI update
  Future<void> _toggleLike() async {
    if (_isLiking) return;

    final previousLikeState = _post.isLiked;
    final previousLikesCount = _post.likesCount;

    // Optimistic update
    setState(() {
      _isLiking = true;
      _post = Post(
        id: _post.id,
        userId: _post.userId,
        content: _post.content,
        image: _post.image,
        video: _post.video,
        privacy: _post.privacy,
        isActive: _post.isActive,
        likesCount: _post.isLiked ? _post.likesCount - 1 : _post.likesCount + 1,
        commentsCount: _post.commentsCount,
        sharesCount: _post.sharesCount,
        createdAt: _post.createdAt,
        updatedAt: _post.updatedAt,
        user: _post.user,
        comments: _post.comments,
        isLiked: !_post.isLiked,
      );
    });

    final result = await ApiService.toggleLike(_post.id);

    if (mounted) {
      setState(() {
        _isLiking = false;
        if (result['success']) {
          _post = Post(
            id: _post.id,
            userId: _post.userId,
            content: _post.content,
            image: _post.image,
            video: _post.video,
            privacy: _post.privacy,
            isActive: _post.isActive,
            likesCount: result['likes_count'] ?? _post.likesCount,
            commentsCount: _post.commentsCount,
            sharesCount: _post.sharesCount,
            createdAt: _post.createdAt,
            updatedAt: _post.updatedAt,
            user: _post.user,
            comments: _post.comments,
            isLiked: result['liked'] ?? _post.isLiked,
          );
          widget.onPostUpdated(_post);
        } else {
          // Revert on failure
          _post = Post(
            id: _post.id,
            userId: _post.userId,
            content: _post.content,
            image: _post.image,
            video: _post.video,
            privacy: _post.privacy,
            isActive: _post.isActive,
            likesCount: previousLikesCount,
            commentsCount: _post.commentsCount,
            sharesCount: _post.sharesCount,
            createdAt: _post.createdAt,
            updatedAt: _post.updatedAt,
            user: _post.user,
            comments: _post.comments,
            isLiked: previousLikeState,
          );
        }
      });
    }
  }

  /// ✅ Show comment bottom sheet
  void _showCommentSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CommentSheet(
        postId: _post.id,
        currentUserId: widget.currentUserId, // ✅ Pass current user ID
        onCommentAdded: (newCommentsCount) {
          if (mounted) {
            setState(() {
              _post = Post(
                id: _post.id,
                userId: _post.userId,
                content: _post.content,
                image: _post.image,
                video: _post.video,
                privacy: _post.privacy,
                isActive: _post.isActive,
                likesCount: _post.likesCount,
                commentsCount: newCommentsCount,
                sharesCount: _post.sharesCount,
                createdAt: _post.createdAt,
                updatedAt: _post.updatedAt,
                user: _post.user,
                comments: _post.comments,
                isLiked: _post.isLiked,
              );
              widget.onPostUpdated(_post);
            });
          }
        },
      ),
    );
  }

  /// ✅ Show edit post bottom sheet
  void _showEditSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EditPostSheet(
        post: _post,
        onPostUpdated: (Post updatedPost) {
          if (mounted) {
            setState(() {
              _post = updatedPost;
            });
            widget.onPostUpdated(updatedPost);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Post updated successfully! ✅'),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
                duration: Duration(seconds: 2),
              ),
            );
          }
        },
      ),
    ).catchError((error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${error.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }

  /// ✅ Share post
  void _sharePost() async {
    final result = await ApiService.sharePost(_post.id);
    if (mounted) {
      if (result['success']) {
        setState(() {
          _post = Post(
            id: _post.id,
            userId: _post.userId,
            content: _post.content,
            image: _post.image,
            video: _post.video,
            privacy: _post.privacy,
            isActive: _post.isActive,
            likesCount: _post.likesCount,
            commentsCount: _post.commentsCount,
            sharesCount: result['shares_count'] ?? _post.sharesCount,
            createdAt: _post.createdAt,
            updatedAt: _post.updatedAt,
            user: _post.user,
            comments: _post.comments,
            isLiked: _post.isLiked,
          );
          widget.onPostUpdated(_post);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Post shared! 🔄'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to share'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// ✅ Delete post with confirmation
  void _deletePost() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Post'),
        content: const Text('Are you sure you want to delete this post?'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: _themeColor)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Deleting post...'),
                  duration: Duration(seconds: 1),
                ),
              );

              final result = await ApiService.deletePost(_post.id);

              if (mounted) {
                if (result['success']) {
                  widget.onPostDeleted(_post.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(result['message'] ?? 'Post deleted! 🗑️'),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(result['message'] ?? 'Failed to delete'),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ==========================================
          // POST HEADER
          // ==========================================
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // User avatar with profile image support & fallback
                ClipOval(
                  child: (_post.user?.fullAvatarUrl != null &&
                          _post.user!.fullAvatarUrl!.isNotEmpty &&
                          !_post.user!.fullAvatarUrl!.endsWith('/uploads/avator.jpg') &&
                          !_post.user!.fullAvatarUrl!.endsWith('/avator.jpg'))
                      ? Image.network(
                          _post.user!.fullAvatarUrl!,
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Image.asset(
                              'assets/avator.jpg',
                              width: 40,
                              height: 40,
                              fit: BoxFit.cover,
                            );
                          },
                        )
                      : Image.asset(
                          'assets/avator.jpg',
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _post.user?.name ?? 'Unknown User',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            _post.timeAgo,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            _post.privacy == 'public'
                                ? Icons.public
                                : _post.privacy == 'friends'
                                ? Icons.people
                                : Icons.lock,
                            size: 12,
                            color: Colors.grey[600],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // ✅ Show menu ONLY if user is the post owner
                if (_isPostOwner)
                  PopupMenuButton(
                    icon: const Icon(Icons.more_horiz),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 20, color: _themeColor),
                            const SizedBox(width: 12),
                            const Text('Edit Post'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, size: 20, color: Colors.red),
                            SizedBox(width: 12),
                            Text(
                              'Delete Post',
                              style: TextStyle(color: Colors.red),
                            ),
                          ],
                        ),
                      ),
                    ],
                    onSelected: (value) {
                      if (value == 'edit') {
                        _showEditSheet();
                      } else if (value == 'delete') {
                        _deletePost();
                      }
                    },
                  ),
              ],
            ),
          ),

          // ==========================================
          // POST CONTENT
          // ==========================================
          if (_post.content != null && _post.content!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(
                _post.content!,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: Colors.black87,
                ),
              ),
            ),

          // ==========================================
          // POST IMAGE
          // ==========================================
          if (_post.fullImageUrl != null)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(0),
                child: Image.network(
                  _post.fullImageUrl!,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 250,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.broken_image,
                              size: 48,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Failed to load image',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      height: 250,
                      color: Colors.grey[100],
                      child: Center(
                        child: CircularProgressIndicator(
                          color: _themeColor,
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                              : null,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

          // ==========================================
          // POST VIDEO
          // ==========================================
          if (_post.fullVideoUrl != null)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              height: 200,
              decoration: const BoxDecoration(
                color: Colors.black,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    Icons.play_circle_outline,
                    size: 64,
                    color: _themeColor.withOpacity(0.9),
                  ),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Video',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // ==========================================
          // STATS BAR (Likes, Comments, Shares)
          // ==========================================
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                if (_post.likesCount > 0) ...[
                  Icon(
                    Icons.thumb_up,
                    size: 16,
                    color: _themeColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${_post.likesCount}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                const Spacer(),
                if (_post.commentsCount > 0)
                  Text(
                    '${_post.commentsCount} Comment${_post.commentsCount > 1 ? 's' : ''}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                if (_post.commentsCount > 0 && _post.sharesCount > 0)
                  Text(
                    ' • ',
                    style: TextStyle(color: Colors.grey[400]),
                  ),
                if (_post.sharesCount > 0)
                  Text(
                    '${_post.sharesCount} Share${_post.sharesCount > 1 ? 's' : ''}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
              ],
            ),
          ),

          Divider(height: 1, color: Colors.grey[200]),

          // ==========================================
          // ACTION BUTTONS (Like, Comment, Share)
          // ==========================================
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildActionButton(
                  _post.isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                  'Like',
                  _post.isLiked ? _themeColor : Colors.grey[700]!,
                  _toggleLike,
                ),
                _buildActionButton(
                  Icons.chat_bubble_outline,
                  'Comment',
                  Colors.grey[700]!,
                  _showCommentSheet,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// ✅ Build action button widget
  Widget _buildActionButton(
      IconData icon,
      String label,
      Color color,
      VoidCallback onTap,
      ) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}