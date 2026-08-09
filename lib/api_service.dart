// ====================================================================
// 🌐 API SERVICE - SOCIAL POSTS
// 📁 lib/api_service.dart
//
// Handles all Social Feed (Post) API calls.
// Uses ApiConfig for correct endpoint URLs.
// Uses SharedPreferences for auth token.
// ====================================================================

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'config/api_config.dart';

class ApiService {
  static const String baseUrl = ApiConfig.baseUrl;

  /// 🚀 Persistent HTTP Client for TCP Connection Reuse (Keep-Alive)
  static final http.Client _client = http.Client();

  // ── Auth Token ────────────────────────────────────────────────────

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<Map<String, String>> _getHeaders({bool includeToken = true}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Connection': 'keep-alive',
    };

    if (includeToken) {
      final token = await _getToken();
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }

    return headers;
  }

  Future<Map<String, String>> _getMultipartHeaders() async {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Connection': 'keep-alive',
    };

    final token = await _getToken();
    if (token != null) headers['Authorization'] = 'Bearer $token';

    return headers;
  }

  // ====================================================================
  // 📄 POSTS  (API Section 11)
  // ====================================================================

  /// 11.1 Get paginated post feed.
  Future<Map<String, dynamic>> getPosts({int page = 1, int perPage = 15}) async {
    try {
      final headers = await _getHeaders();
      final response = await _client.get(
        Uri.parse('${ApiConfig.posts}?page=$page&per_page=$perPage'),
        headers: headers,
      );

      if (response.statusCode == 200) return json.decode(response.body);
      throw Exception('Failed to load posts: ${response.statusCode}');
    } catch (e) {
      throw Exception('Error loading posts: $e');
    }
  }

  /// 11.2 Create a new post (supports image + video).
  Future<Map<String, dynamic>> createPost({
    String? content,
    File? image,
    File? video,
    required String privacy,
  }) async {
    try {
      final headers = await _getMultipartHeaders();
      final request = http.MultipartRequest('POST', Uri.parse(ApiConfig.posts));
      request.headers.addAll(headers);

      if (content != null && content.isNotEmpty) {
        request.fields['content'] = content;
      }
      request.fields['privacy'] = privacy.toLowerCase().replaceAll(' ', '_');

      if (image != null) {
        request.files
            .add(await http.MultipartFile.fromPath('image', image.path));
      }
      if (video != null) {
        request.files
            .add(await http.MultipartFile.fromPath('video', video.path));
      }

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body);
      }
      throw Exception('Failed to create post: ${response.body}');
    } catch (e) {
      throw Exception('Error creating post: $e');
    }
  }

  /// 11.3 Get a single post by ID.
  Future<Map<String, dynamic>> getPost(int id) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse(ApiConfig.postById(id)),
        headers: headers,
      );

      if (response.statusCode == 200) return json.decode(response.body);
      throw Exception('Failed to load post: ${response.statusCode}');
    } catch (e) {
      throw Exception('Error loading post: $e');
    }
  }

  /// 11.3 Update an existing post.
  Future<Map<String, dynamic>> updatePost({
    required int id,
    String? content,
    File? image,
    File? video,
    String? privacy,
    bool removeImage = false,
    bool removeVideo = false,
  }) async {
    try {
      final headers = await _getMultipartHeaders();
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(ApiConfig.postById(id)),
      );
      request.headers.addAll(headers);
      request.fields['_method'] = 'PUT';

      if (content != null) request.fields['content'] = content;
      if (privacy != null) {
        request.fields['privacy'] =
            privacy.toLowerCase().replaceAll(' ', '_');
      }
      if (removeImage) request.fields['remove_image'] = '1';
      if (removeVideo) request.fields['remove_video'] = '1';

      if (image != null) {
        request.files
            .add(await http.MultipartFile.fromPath('image', image.path));
      }
      if (video != null) {
        request.files
            .add(await http.MultipartFile.fromPath('video', video.path));
      }

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode == 200) return json.decode(response.body);
      throw Exception('Failed to update post: ${response.body}');
    } catch (e) {
      throw Exception('Error updating post: $e');
    }
  }

  /// Delete a post by ID.
  Future<bool> deletePost(int id) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse(ApiConfig.postById(id)),
        headers: headers,
      );
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      throw Exception('Error deleting post: $e');
    }
  }

  /// 11.4 Toggle like / unlike a post.
  Future<Map<String, dynamic>> toggleLike(int postId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse(ApiConfig.toggleLike(postId)),
        headers: headers,
      );

      if (response.statusCode == 200) return json.decode(response.body);
      throw Exception('Failed to toggle like: ${response.statusCode}');
    } catch (e) {
      throw Exception('Error toggling like: $e');
    }
  }

  // ── Comment helpers (if backend supports comment sub-routes) ──────

  Future<Map<String, dynamic>> addComment(int postId, String comment) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('${ApiConfig.postById(postId)}/comments'),
        headers: headers,
        body: json.encode({'comment': comment}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body);
      }
      throw Exception('Failed to add comment: ${response.body}');
    } catch (e) {
      throw Exception('Error adding comment: $e');
    }
  }

  Future<List<dynamic>> getComments(int postId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('${ApiConfig.postById(postId)}/comments'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['comments'] ?? [];
      }
      throw Exception('Failed to load comments: ${response.statusCode}');
    } catch (e) {
      throw Exception('Error loading comments: $e');
    }
  }

  Future<bool> deleteComment(int postId, int commentId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('${ApiConfig.postById(postId)}/comments/$commentId'),
        headers: headers,
      );
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      throw Exception('Error deleting comment: $e');
    }
  }

  Future<Map<String, dynamic>> sharePost(int postId,
      {String? shareContent}) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('${ApiConfig.postById(postId)}/share'),
        headers: headers,
        body: json.encode({'share_content': shareContent}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body);
      }
      throw Exception('Failed to share post: ${response.body}');
    } catch (e) {
      throw Exception('Error sharing post: $e');
    }
  }

  Future<List<dynamic>> getLikes(int postId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('${ApiConfig.postById(postId)}/likes'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['likes'] ?? [];
      }
      throw Exception('Failed to load likes: ${response.statusCode}');
    } catch (e) {
      throw Exception('Error loading likes: $e');
    }
  }

  // ── My posts & search ─────────────────────────────────────────────

  Future<Map<String, dynamic>> getMyPosts({int page = 1}) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/posts/my-posts?page=$page'),
        headers: headers,
      );

      if (response.statusCode == 200) return json.decode(response.body);
      throw Exception('Failed to load my posts: ${response.statusCode}');
    } catch (e) {
      throw Exception('Error loading my posts: $e');
    }
  }

  Future<Map<String, dynamic>> searchPosts(String query,
      {int page = 1}) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse(
            '$baseUrl/posts/search?q=${Uri.encodeComponent(query)}&page=$page'),
        headers: headers,
      );

      if (response.statusCode == 200) return json.decode(response.body);
      throw Exception('Failed to search posts: ${response.statusCode}');
    } catch (e) {
      throw Exception('Error searching posts: $e');
    }
  }
}
