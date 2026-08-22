import 'package:flutter/material.dart';
import '../models/comment_model.dart';
import '../services/api_service.dart';

class CommentSheet extends StatefulWidget {
  final int postId;
  final int? currentUserId; // ✅ ADDED: Current user ID
  final Function(int) onCommentAdded;

  const CommentSheet({
    Key? key,
    required this.postId,
    this.currentUserId, // ✅ ADDED: Accept current user ID
    required this.onCommentAdded,
  }) : super(key: key);

  @override
  State<CommentSheet> createState() => _CommentSheetState();
}

class _CommentSheetState extends State<CommentSheet> {
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Comment> _comments = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _isSending = false;
  int _currentPage = 1;
  bool _hasMoreData = true;

  @override
  void initState() {
    super.initState();
    _loadComments();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 100) {
      if (!_isLoadingMore && _hasMoreData) {
        _loadMoreComments();
      }
    }
  }

  Future<void> _loadComments() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _currentPage = 1;
    });

    final result = await ApiService.getComments(widget.postId, page: 1);

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result['success']) {
          _comments = result['comments'];
          final pagination = result['pagination'];
          _hasMoreData = pagination['current_page'] < pagination['last_page'];
        }
      });
    }
  }

  Future<void> _loadMoreComments() async {
    if (_isLoadingMore || !_hasMoreData) return;

    setState(() {
      _isLoadingMore = true;
    });

    final nextPage = _currentPage + 1;
    final result = await ApiService.getComments(widget.postId, page: nextPage);

    if (mounted) {
      setState(() {
        _isLoadingMore = false;
        if (result['success']) {
          _comments.addAll(result['comments']);
          _currentPage = nextPage;
          final pagination = result['pagination'];
          _hasMoreData = pagination['current_page'] < pagination['last_page'];
        }
      });
    }
  }

  Future<void> _addComment() async {
    if (_commentController.text.trim().isEmpty || _isSending) return;

    final commentText = _commentController.text.trim();
    _commentController.clear();

    setState(() => _isSending = true);

    final result = await ApiService.addComment(widget.postId, commentText);

    if (mounted) {
      setState(() => _isSending = false);

      if (result['success']) {
        setState(() {
          _comments.insert(0, result['comment']);
        });
        widget.onCommentAdded(result['comments_count']);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Comment added!')),
        );
      } else {
        _commentController.text = commentText;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Failed to add comment')),
        );
      }
    }
  }

  Future<void> _deleteComment(int commentId, int index) async {
    final result = await ApiService.deleteComment(widget.postId, commentId);

    if (mounted) {
      if (result['success']) {
        setState(() {
          _comments.removeAt(index);
        });
        widget.onCommentAdded(result['comments_count']);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Comment deleted!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Failed to delete comment')),
        );
      }
    }
  }

  /// ✅ Check if current user owns the comment
  bool _isCommentOwner(Comment comment) {
    if (widget.currentUserId == null) return false;
    return widget.currentUserId == comment.userId;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Comments',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Comments List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _comments.isEmpty
                ? const Center(
              child: Text(
                'No comments yet',
                style: TextStyle(color: Colors.grey),
              ),
            )
                : ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _comments.length + (_isLoadingMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _comments.length) {
                  return const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final comment = _comments[index];
                return _buildCommentItem(comment, index);
              },
            ),
          ),

          // Comment Input
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey[200]!)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: InputDecoration(
                      hintText: 'Write a comment...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    maxLines: null,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: _isSending
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Icon(Icons.send),
                  color: Colors.blue,
                  onPressed: _isSending ? null : _addComment,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentItem(Comment comment, int index) {
    final isOwner = _isCommentOwner(comment);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipOval(
            child: (comment.user?.fullAvatarUrl != null &&
                    comment.user!.fullAvatarUrl!.isNotEmpty)
                ? Image.network(
                    comment.user!.fullAvatarUrl!,
                    width: 36,
                    height: 36,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Image.asset(
                        'assets/avator.jpg',
                        width: 36,
                        height: 36,
                        fit: BoxFit.cover,
                      );
                    },
                  )
                : Image.asset(
                    'assets/avator.jpg',
                    width: 36,
                    height: 36,
                    fit: BoxFit.cover,
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        comment.user?.name ?? 'Unknown User',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        comment.comment,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      comment.timeAgo,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    // ✅ Only show delete button for comment owner
                    if (isOwner) ...[
                      const SizedBox(width: 16),
                      InkWell(
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Delete Comment'),
                              content: const Text('Are you sure you want to delete this comment?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    _deleteComment(comment.id, index);
                                  },
                                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                          );
                        },
                        child: Text(
                          'Delete',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}