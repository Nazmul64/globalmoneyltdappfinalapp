// lib/services/api_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/post_model.dart';
import '../models/comment_model.dart';
import '../models/user_model.dart';
import '../config/api_config.dart';

String get baseUrl => ApiConfig.baseUrl;

class ApiService {
  // ✅ Persistent HTTP Client with Keep-Alive Connection Pooling
  static final http.Client _client = http.Client();
  static http.Client get client => _client;

  static const Duration timeout = Duration(seconds: 30);
  static String? _cachedToken;

  // ===================== AUTH TOKEN MANAGEMENT =====================

  static Future<String?> _getAuthToken() async {
    if (_cachedToken != null) return _cachedToken;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token != null && token.isNotEmpty) {
        _cachedToken = token;
        return token;
      }
      return null;
    } catch (e) {
      print('❌ Token retrieval error: $e');
      return null;
    }
  }

  static Future<void> setAuthToken(String token) async {
    _cachedToken = token;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', token);
      print('✅ Token saved');
    } catch (e) {
      print('❌ Save token error: $e');
    }
  }

  static Future<void> clearAuthToken() async {
    _cachedToken = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
      print('✅ Token cleared');
    } catch (e) {
      print('❌ Clear token error: $e');
    }
  }

  static Future<Map<String, String>> _getHeaders({
    bool isMultipart = false,
  }) async {
    final headers = <String, String>{'Accept': 'application/json'};

    if (!isMultipart) {
      headers['Content-Type'] = 'application/json';
    }

    final token = await _getAuthToken();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    return headers;
  }

  // ===================== ERROR HANDLING =====================

  static Map<String, dynamic> _handleError(
    dynamic error, [
    String defaultMessage = 'An error occurred',
  ]) {
    print('❌ API Error: $error');

    if (error is SocketException) {
      return {'success': false, 'message': 'No internet connection'};
    } else if (error is http.ClientException) {
      return {'success': false, 'message': 'Connection failed'};
    } else if (error is FormatException) {
      return {'success': false, 'message': 'Invalid response format'};
    }

    return {
      'success': false,
      'message': defaultMessage,
      'error': error.toString(),
    };
  }

  static Map<String, dynamic> _parseResponse(http.Response response) {
    try {
      final data = json.decode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return data is Map<String, dynamic>
            ? data
            : {'success': false, 'message': 'Invalid response'};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Request failed',
          'status_code': response.statusCode,
        };
      }
    } catch (e) {
      print('❌ Parse response error: $e');
      return {
        'success': false,
        'message': 'Failed to parse response',
        'error': e.toString(),
      };
    }
  }

  // ===================== THEME API =====================

  static Future<Map<String, dynamic>> getTheme() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/themechange'), headers: await _getHeaders())
          .timeout(timeout);

      print('🎨 Get Theme - Status: ${response.statusCode}');

      final data = _parseResponse(response);

      if (data['status'] == true && data['data'] != null) {
        return {'status': true, 'data': data['data']};
      }

      return {
        'status': false,
        'data': {'color_code': '#4361EE'},
      };
    } catch (e) {
      return _handleError(e, 'Failed to load theme');
    }
  }

  // ===================== USER API =====================

  static Future<Map<String, dynamic>> getCurrentUser() async {
    try {
      final token = await _getAuthToken();
      if (token == null) {
        return {'success': false, 'message': 'Authentication required'};
      }

      final response = await http
          .get(Uri.parse('$baseUrl/user'), headers: await _getHeaders())
          .timeout(timeout);

      print('👤 Get User - Status: ${response.statusCode}');

      final data = _parseResponse(response);

      if (data['status'] == true && data['data'] != null) {
        return {'success': true, 'user': User.fromJson(data['data'])};
      }

      return {
        'success': false,
        'message': data['message'] ?? 'Failed to get user',
      };
    } catch (e) {
      return _handleError(e, 'Failed to load user');
    }
  }

  // ===================== POSTS API =====================

  static Future<Map<String, dynamic>> getPosts({
    int page = 1,
    int perPage = 10,
  }) async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/posts?page=$page&per_page=$perPage'),
            headers: await _getHeaders(),
          )
          .timeout(timeout);

      print('📡 GET Posts - Status: ${response.statusCode} | Page: $page');

      final data = _parseResponse(response);

      if (data['success'] == true && data['data'] != null) {
        final postsData = data['data']['posts'] as List;
        final posts = postsData.map((json) => Post.fromJson(json)).toList();

        final pagination = data['data']['pagination'] ?? {};

        return {'success': true, 'posts': posts, 'pagination': pagination};
      }

      return {
        'success': false,
        'message': data['message'] ?? 'Failed to load posts',
        'posts': <Post>[],
      };
    } catch (e) {
      return _handleError(e, 'Failed to load posts');
    }
  }

  static Future<Map<String, dynamic>> createPost({
    String? content,
    File? image,
    File? video,
    String privacy = 'public',
  }) async {
    try {
      final token = await _getAuthToken();
      if (token == null) {
        return {'success': false, 'message': 'Authentication required'};
      }

      var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/posts'));
      request.headers['Accept'] = 'application/json';
      request.headers['Authorization'] = 'Bearer $token';

      if (content != null && content.isNotEmpty) {
        request.fields['content'] = content;
      }
      request.fields['privacy'] = privacy;

      if (image != null) {
        final filename = image.path.split('/').last;
        request.files.add(
          await http.MultipartFile.fromPath(
            'image',
            image.path,
            filename: filename,
          ),
        );
      }

      if (video != null) {
        final filename = video.path.split('/').last;
        request.files.add(
          await http.MultipartFile.fromPath(
            'video',
            video.path,
            filename: filename,
          ),
        );
      }

      print('✍️ Creating Post...');
      final streamedResponse = await request.send().timeout(timeout);
      final response = await http.Response.fromStream(streamedResponse);

      print('✍️ Create Post - Status: ${response.statusCode}');

      final data = _parseResponse(response);

      if (data['success'] == true && data['data'] != null) {
        return {
          'success': true,
          'post': Post.fromJson(data['data']['post']),
          'message': data['message'] ?? 'Post created successfully',
        };
      }

      return {
        'success': false,
        'message': data['message'] ?? 'Failed to create post',
      };
    } catch (e) {
      return _handleError(e, 'Failed to create post');
    }
  }

  // ✅✅✅ COMPLETELY FIXED UPDATE METHOD ✅✅✅
  static Future<Map<String, dynamic>> updatePost({
    required int postId,
    String? content,
    File? image,
    File? video,
    String? privacy,
    bool removeImage = false,
    bool removeVideo = false,
  }) async {
    try {
      final token = await _getAuthToken();
      if (token == null) {
        return {'success': false, 'message': 'Authentication required'};
      }

      print('\n╔═══════════════════════════════════════╗');
      print('║   🔧 POST UPDATE REQUEST STARTING     ║');
      print('╚═══════════════════════════════════════╝');
      print('🆔 Post ID: $postId');
      print('📝 Content: ${content ?? "null"}');
      print('🔒 Privacy: ${privacy ?? "null"}');
      print('🖼️ New Image: ${image != null}');
      print('🎥 New Video: ${video != null}');
      print('🗑️ Remove Image: $removeImage');
      print('🗑️ Remove Video: $removeVideo');

      // ✅ CRITICAL FIX: Use MultipartRequest with proper _method field
      var request = http.MultipartRequest(
        'POST', // ← Always POST for file uploads
        Uri.parse('$baseUrl/posts/$postId'),
      );

      // ✅ Set headers
      request.headers['Accept'] = 'application/json';
      request.headers['Authorization'] = 'Bearer $token';

      // ✅ CRITICAL: Add _method=PUT as a FIELD, NOT in URL
      request.fields['_method'] = 'PUT';
      print('✅ _method field set to: PUT');

      // ✅ Add content if provided
      if (content != null) {
        request.fields['content'] = content;
        print('✅ Content field added: ${content.length} chars');
      }

      // ✅ Add privacy if provided
      if (privacy != null) {
        request.fields['privacy'] = privacy;
        print('✅ Privacy field added: $privacy');
      }

      // ✅ Handle image removal
      if (removeImage) {
        request.fields['remove_image'] = '1';
        print('✅ Remove image flag set');
      }

      // ✅ Handle video removal
      if (removeVideo) {
        request.fields['remove_video'] = '1';
        print('✅ Remove video flag set');
      }

      // ✅ Add new image if provided
      if (image != null) {
        final filename = image.path.split('/').last;
        request.files.add(
          await http.MultipartFile.fromPath(
            'image',
            image.path,
            filename: filename,
          ),
        );
        print('✅ New image added: $filename');
      }

      // ✅ Add new video if provided
      if (video != null) {
        final filename = video.path.split('/').last;
        request.files.add(
          await http.MultipartFile.fromPath(
            'video',
            video.path,
            filename: filename,
          ),
        );
        print('✅ New video added: $filename');
      }

      print('\n📤 Sending request to: ${request.url}');
      print('📤 Headers: ${request.headers}');
      print('📤 Fields: ${request.fields}');
      print('📤 Files count: ${request.files.length}\n');

      // ✅ Send request
      final streamedResponse = await request.send().timeout(timeout);
      final response = await http.Response.fromStream(streamedResponse);

      print('📥 Response Status: ${response.statusCode}');
      print(
        '📥 Response Body: ${response.body.length > 500 ? response.body.substring(0, 500) + "..." : response.body}',
      );

      final data = _parseResponse(response);

      if (data['success'] == true &&
          data['data'] != null &&
          data['data']['post'] != null) {
        print('\n✅✅✅ POST UPDATE SUCCESSFUL ✅✅✅\n');
        return {
          'success': true,
          'post': Post.fromJson(data['data']['post']),
          'message': data['message'] ?? 'Post updated successfully',
        };
      }

      print('\n❌❌❌ POST UPDATE FAILED ❌❌❌');
      print('Server Response: ${data['message']}\n');

      return {
        'success': false,
        'message': data['message'] ?? 'Failed to update post',
      };
    } catch (e) {
      print('\n❌❌❌ EXCEPTION IN UPDATE POST ❌❌❌');
      print('Exception: $e\n');
      return _handleError(e, 'Failed to update post');
    }
  }

  static Future<Map<String, dynamic>> deletePost(int postId) async {
    try {
      final token = await _getAuthToken();
      if (token == null) {
        return {'success': false, 'message': 'Authentication required'};
      }

      final response = await http
          .delete(
            Uri.parse('$baseUrl/posts/$postId'),
            headers: await _getHeaders(),
          )
          .timeout(timeout);

      print('🗑️ Delete Post - Status: ${response.statusCode}');

      final data = _parseResponse(response);

      return {
        'success': data['success'] == true,
        'message':
            data['message'] ??
            (data['success'] == true ? 'Post deleted' : 'Failed to delete'),
      };
    } catch (e) {
      return _handleError(e, 'Failed to delete post');
    }
  }

  // ===================== INTERACTIONS API =====================

  static Future<Map<String, dynamic>> toggleLike(int postId) async {
    try {
      final token = await _getAuthToken();
      if (token == null) {
        return {'success': false, 'message': 'Authentication required'};
      }

      final response = await http
          .post(
            Uri.parse('$baseUrl/posts/$postId/like'),
            headers: await _getHeaders(),
          )
          .timeout(timeout);

      print('👍 Toggle Like - Status: ${response.statusCode}');

      final data = _parseResponse(response);

      if (data['success'] == true && data['data'] != null) {
        return {
          'success': true,
          'liked': data['data']['liked'] ?? false,
          'likes_count': data['data']['likes_count'] ?? 0,
          'message': data['message'] ?? 'Success',
        };
      }

      return {
        'success': false,
        'message': data['message'] ?? 'Failed to toggle like',
      };
    } catch (e) {
      return _handleError(e, 'Failed to toggle like');
    }
  }

  static Future<Map<String, dynamic>> sharePost(int postId) async {
    try {
      final token = await _getAuthToken();
      if (token == null) {
        return {'success': false, 'message': 'Authentication required'};
      }

      final response = await http
          .post(
            Uri.parse('$baseUrl/posts/$postId/share'),
            headers: await _getHeaders(),
          )
          .timeout(timeout);

      print('🔄 Share Post - Status: ${response.statusCode}');

      final data = _parseResponse(response);

      if (data['success'] == true && data['data'] != null) {
        return {
          'success': true,
          'shares_count': data['data']['shares_count'] ?? 0,
          'message': data['message'] ?? 'Post shared',
        };
      }

      return {
        'success': false,
        'message': data['message'] ?? 'Failed to share',
      };
    } catch (e) {
      return _handleError(e, 'Failed to share post');
    }
  }

  // ===================== COMMENTS API =====================

  static Future<Map<String, dynamic>> getComments(
    int postId, {
    int page = 1,
    int perPage = 20,
  }) async {
    try {
      final response = await http
          .get(
            Uri.parse(
              '$baseUrl/posts/$postId/comments?page=$page&per_page=$perPage',
            ),
            headers: await _getHeaders(),
          )
          .timeout(timeout);

      print('💬 Get Comments - Status: ${response.statusCode}');

      final data = _parseResponse(response);

      if (data['success'] == true && data['data'] != null) {
        final commentsData = data['data']['comments'] as List;
        final comments = commentsData
            .map((json) => Comment.fromJson(json))
            .toList();

        return {
          'success': true,
          'comments': comments,
          'pagination': data['data']['pagination'] ?? {},
        };
      }

      return {
        'success': false,
        'message': data['message'] ?? 'Failed to load comments',
        'comments': <Comment>[],
      };
    } catch (e) {
      return _handleError(e, 'Failed to load comments');
    }
  }

  static Future<Map<String, dynamic>> addComment(
    int postId,
    String comment,
  ) async {
    try {
      final token = await _getAuthToken();
      if (token == null) {
        return {'success': false, 'message': 'Authentication required'};
      }

      final response = await http
          .post(
            Uri.parse('$baseUrl/posts/$postId/comments'),
            headers: await _getHeaders(),
            body: json.encode({'comment': comment}),
          )
          .timeout(timeout);

      print('💬 Add Comment - Status: ${response.statusCode}');

      final data = _parseResponse(response);

      if (data['success'] == true && data['data'] != null) {
        return {
          'success': true,
          'comment': Comment.fromJson(data['data']['comment']),
          'comments_count': data['data']['comments_count'] ?? 0,
          'message': data['message'] ?? 'Comment added',
        };
      }

      return {
        'success': false,
        'message': data['message'] ?? 'Failed to add comment',
      };
    } catch (e) {
      return _handleError(e, 'Failed to add comment');
    }
  }

  static Future<Map<String, dynamic>> deleteComment(
    int postId,
    int commentId,
  ) async {
    try {
      final token = await _getAuthToken();
      if (token == null) {
        return {'success': false, 'message': 'Authentication required'};
      }

      final response = await http
          .delete(
            Uri.parse('$baseUrl/posts/$postId/comments/$commentId'),
            headers: await _getHeaders(),
          )
          .timeout(timeout);

      print('🗑️ Delete Comment - Status: ${response.statusCode}');

      final data = _parseResponse(response);

      if (data['success'] == true) {
        return {
          'success': true,
          'comments_count': data['data']?['comments_count'] ?? 0,
          'message': data['message'] ?? 'Comment deleted',
        };
      }

      return {
        'success': false,
        'message': data['message'] ?? 'Failed to delete comment',
      };
    } catch (e) {
      return _handleError(e, 'Failed to delete comment');
    }
  }

  // ===================== LOGOUT =====================

  static Future<void> logout() async {
    print('🚪 Logging out...');
    await clearAuthToken();
    print('✅ Logout complete');
  }
}
