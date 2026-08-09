// lib/models/post_model.dart

import 'user_model.dart';
import 'comment_model.dart';
import '../config/api_config.dart';

class Post {
  final int id;
  final int userId;
  final String? content;
  final String? image;
  final String? video;
  final String privacy;
  final bool isActive;
  final int likesCount;
  final int commentsCount;
  final int sharesCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final User? user;
  final List<Comment>? comments;
  bool isLiked;

  Post({
    required this.id,
    required this.userId,
    this.content,
    this.image,
    this.video,
    required this.privacy,
    required this.isActive,
    required this.likesCount,
    required this.commentsCount,
    required this.sharesCount,
    required this.createdAt,
    required this.updatedAt,
    this.user,
    this.comments,
    this.isLiked = false,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: _parseId(json['id']),
      userId: _parseId(json['user_id']),
      content: json['content']?.toString(),
      image: json['image']?.toString(),
      video: json['video']?.toString(),
      privacy: json['privacy']?.toString() ?? 'public',
      isActive: json['is_active'] == true || json['is_active'] == 1,
      likesCount: _parseInt(json['likes_count']),
      commentsCount: _parseInt(json['comments_count']),
      sharesCount: _parseInt(json['shares_count']),
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseDateTime(json['updated_at']),
      user: json['user'] != null ? User.fromJson(json['user']) : null,
      comments: json['comments'] != null
          ? (json['comments'] as List).map((c) => Comment.fromJson(c)).toList()
          : null,
      isLiked: json['is_liked'] == true || json['is_liked'] == 1,
    );
  }

  // Helper to parse ID safely
  static int _parseId(dynamic id) {
    if (id == null) return 0;
    if (id is int) return id;
    if (id is String) return int.tryParse(id) ?? 0;
    return 0;
  }

  // Helper to parse integers safely
  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  // Helper to parse DateTime safely
  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (e) {
        return DateTime.now();
      }
    }
    return DateTime.now();
  }

  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays > 365) {
      final years = (difference.inDays / 365).floor();
      return '$years year${years > 1 ? 's' : ''} ago';
    } else if (difference.inDays > 30) {
      final months = (difference.inDays / 30).floor();
      return '$months month${months > 1 ? 's' : ''} ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  String? get fullImageUrl {
    final img = image;
    if (img == null || img.isEmpty) return null;
    if (img.startsWith('http')) return img;
    return ApiConfig.mediaUrl(img);
  }

  String? get fullVideoUrl {
    final vid = video;
    if (vid == null || vid.isEmpty) return null;
    if (vid.startsWith('http')) return vid;
    return ApiConfig.mediaUrl(vid);
  }

  String get privacyLabel {
    switch (privacy.toLowerCase()) {
      case 'public':
        return 'Public';
      case 'friends':
        return 'Friends';
      case 'only_me':
        return 'Only Me';
      default:
        return 'Public';
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'content': content,
      'image': image,
      'video': video,
      'privacy': privacy,
      'is_active': isActive,
      'likes_count': likesCount,
      'comments_count': commentsCount,
      'shares_count': sharesCount,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'user': user?.toJson(),
      'is_liked': isLiked,
    };
  }

  Post copyWith({
    int? id,
    int? userId,
    String? content,
    String? image,
    String? video,
    String? privacy,
    bool? isActive,
    int? likesCount,
    int? commentsCount,
    int? sharesCount,
    DateTime? createdAt,
    DateTime? updatedAt,
    User? user,
    List<Comment>? comments,
    bool? isLiked,
  }) {
    return Post(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      content: content ?? this.content,
      image: image ?? this.image,
      video: video ?? this.video,
      privacy: privacy ?? this.privacy,
      isActive: isActive ?? this.isActive,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      sharesCount: sharesCount ?? this.sharesCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      user: user ?? this.user,
      comments: comments ?? this.comments,
      isLiked: isLiked ?? this.isLiked,
    );
  }
}
