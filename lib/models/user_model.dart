import '../config/api_config.dart';

class User {
  final int id;
  final String name;
  final String? email;
  final String? avatar;
  final String? bio;
  final bool? isVerified;

  User({
    required this.id,
    required this.name,
    this.email,
    this.avatar,
    this.bio,
    this.isVerified,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: _parseId(json['id']),
      name: json['name']?.toString() ?? 'Unknown User',
      email: json['email']?.toString(),
      avatar: json['photo_url']?.toString() ??
          json['avatar']?.toString() ??
          json['photo']?.toString() ??
          json['profile_photo']?.toString() ??
          json['user_photo']?.toString() ??
          json['image']?.toString(),
      bio: json['bio']?.toString(),
      isVerified: json['is_verified'] == true || json['is_verified'] == 1,
    );
  }

  // Helper method to safely parse ID (handles both int and String)
  static int _parseId(dynamic id) {
    if (id == null) return 0;
    if (id is int) return id;
    if (id is String) {
      return int.tryParse(id) ?? 0;
    }
    return 0;
  }

  String get initials {
    final names = name.trim().split(' ');
    if (names.length >= 2 && names[0].isNotEmpty && names[1].isNotEmpty) {
      return '${names[0][0]}${names[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : 'U';
  }

  String? get fullAvatarUrl {
    if (avatar == null || avatar!.trim().isEmpty) return null;
    return ApiConfig.avatarUrl(avatar);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'avatar': avatar,
      'bio': bio,
      'is_verified': isVerified,
    };
  }

  User copyWith({
    int? id,
    String? name,
    String? email,
    String? avatar,
    String? bio,
    bool? isVerified,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      avatar: avatar ?? this.avatar,
      bio: bio ?? this.bio,
      isVerified: isVerified ?? this.isVerified,
    );
  }
}
