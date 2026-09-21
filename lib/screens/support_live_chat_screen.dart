import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../services/auth_service.dart';


class SupportLiveChatScreen extends StatefulWidget {
  const SupportLiveChatScreen({super.key});

  @override
  State<SupportLiveChatScreen> createState() => _SupportLiveChatScreenState();
}

class _SupportLiveChatScreenState extends State<SupportLiveChatScreen> {
  static const Color primaryColor = Color(0xFF4361EE);
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<dynamic> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  bool _isActivating = false;
  String? _assignedLicenseKey;
  String _licenseStatus = 'inactive';
  Timer? _pollingTimer;
  String? _userPhoto;
  String? _adminPhoto;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _loadConversation();
    _startPolling();
  }

  Future<void> _loadUserProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final photo = prefs.getString('profile_photo') ??
          prefs.getString('photo') ??
          prefs.getString('user_photo') ??
          prefs.getString('avatar') ??
          prefs.getString('image');
      if (mounted && photo != null && photo.isNotEmpty) {
        setState(() => _userPhoto = photo);
      }
    } catch (e) {
      debugPrint('Error loading user profile photo: $e');
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) _loadConversation(silent: true);
    });
  }

  Future<void> _loadConversation({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() => _isLoading = true);
    }

    try {
      final token = await AuthService().getToken();
      if (token == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      // Try admin chat fetch endpoint first
      final response = await http.get(
        Uri.parse(ApiConfig.adminChatFetch),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && mounted) {
          final msgs = data['data'] != null && data['data']['messages'] != null
              ? data['data']['messages'] as List
              : (data['messages'] ?? []);
          final status = data['license_status'] ?? 'active';

          String? assignedKey;
          if (data['assigned_license'] != null && data['assigned_license']['license_key'] != null) {
            assignedKey = data['assigned_license']['license_key'];
          }

          setState(() {
            _messages = msgs;
            _licenseStatus = status;
            _assignedLicenseKey = assignedKey;
            _isLoading = false;
          });

          if (!silent) _scrollToBottom();
          return;
        }
      }

      // Fallback to v1 support conversation if available
      final v1Response = await http.get(
        Uri.parse(ApiConfig.v1SupportConvo),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 5));

      if (v1Response.statusCode == 200) {
        final data = jsonDecode(v1Response.body);
        if (data['success'] == true && mounted) {
          setState(() {
            _messages = data['messages'] ?? [];
            _licenseStatus = data['license_status'] ?? 'active';
            _isLoading = false;
          });
          if (!silent) _scrollToBottom();
        }
      }
    } catch (e) {
      debugPrint('Error loading support conversation: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    _messageController.clear();

    try {
      final token = await AuthService().getToken();
      final response = await http.post(
        Uri.parse(ApiConfig.adminChatSend),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'message': text, 'message_type': 'text'}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        await _loadConversation(silent: true);
        _scrollToBottom();
      } else {
        // Fallback to v1 endpoint
        await http.post(
          Uri.parse(ApiConfig.v1SupportMessages),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'message': text}),
        );
        await _loadConversation(silent: true);
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send message. Check internet connection.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _pickAndSendImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (pickedFile == null) return;

      setState(() => _isSending = true);

      final token = await AuthService().getToken();
      final request = http.MultipartRequest('POST', Uri.parse(ApiConfig.adminChatSend));
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
        request.headers['Accept'] = 'application/json';
      }
      request.fields['message_type'] = 'image';
      request.fields['message'] = 'Image';
      request.files.add(await http.MultipartFile.fromPath('image', pickedFile.path));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        await _loadConversation(silent: true);
        _scrollToBottom();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to upload image.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading image: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _activateLicense(String key) async {
    if (_isActivating) return;

    setState(() => _isActivating = true);
    HapticFeedback.mediumImpact();

    final result = await AuthService().activateLicense(key);

    if (!mounted) return;
    setState(() => _isActivating = false);

    if (result['success'] == true) {
      HapticFeedback.heavyImpact();
      await _loadConversation();

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 28),
              SizedBox(width: 10),
              Text('License Activated!'),
            ],
          ),
          content: const Text(
            'License activated successfully! All features are now available.',
            style: TextStyle(fontSize: 15),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('Great!'),
            )
          ],
        ),
      );
    } else {
      HapticFeedback.vibrate();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Activation failed.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF4361EE);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text('Live Support Chat', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadConversation(),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Admin Assigned License Key Available Card Header
            if (_assignedLicenseKey != null && _licenseStatus.toLowerCase() != 'active')
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFFBEB), Color(0xFFFEF3C7)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFF59E0B), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.amber.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.vpn_key_rounded, color: Color(0xFFD97706), size: 24),
                        SizedBox(width: 8),
                        Text(
                          '🔑 License Key Available',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Your license is ready to activate.',
                      style: TextStyle(fontSize: 13, color: Color(0xFFB45309)),
                    ),
                    const SizedBox(height: 4),
                    SelectableText(
                      _assignedLicenseKey!,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFF78350F),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton.icon(
                        onPressed: _isActivating ? null : () => _activateLicense(_assignedLicenseKey!),
                        icon: _isActivating
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Icon(Icons.bolt),
                        label: Text(_isActivating ? 'Activating License...' : 'Activate License'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Messages ListView
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _messages.isEmpty
                      ? const Center(
                          child: Text(
                            'No messages yet. Send a message to start chatting with Support!',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final msg = _messages[index];
                            final isUser = msg['sender_type'] == 'user' || msg['sender'] == 'user';
                            final isLicenseCard = msg['is_license_card'] == true || msg['is_license_card'] == 1;

                            if (isLicenseCard) {
                              final key = msg['license_key'] ?? _assignedLicenseKey;
                              return _buildLicenseCardMessage(msg['message'] ?? '', key);
                            }

                            final senderName = msg['sender_name'] ?? (isUser ? 'You' : 'Admin');
                            final photo = isUser
                                ? (msg['user_photo'] ?? msg['user_avatar'] ?? msg['sender_photo'] ?? _userPhoto)
                                : (msg['admin_photo'] ?? msg['admin_avatar'] ?? _adminPhoto ?? ApiConfig.defaultAvatar);

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  if (!isUser) ...[
                                    _buildAvatar(
                                      imageUrl: photo?.toString(),
                                      isUser: false,
                                      name: senderName.toString(),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  Flexible(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
                                      decoration: BoxDecoration(
                                        color: isUser ? primaryColor : Colors.white,
                                        borderRadius: BorderRadius.only(
                                          topLeft: const Radius.circular(16),
                                          topRight: const Radius.circular(16),
                                          bottomLeft: Radius.circular(isUser ? 16 : 4),
                                          bottomRight: Radius.circular(isUser ? 4 : 16),
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.04),
                                            blurRadius: 6,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            senderName.toString(),
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: isUser ? Colors.white70 : Colors.grey[600],
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          if (_getMessageImageUrl(msg) != null) ...[
                                            Padding(
                                              padding: const EdgeInsets.only(bottom: 6),
                                              child: GestureDetector(
                                                onTap: () => _showFullImageDialog(context, _getMessageImageUrl(msg)!),
                                                child: ClipRRect(
                                                  borderRadius: BorderRadius.circular(10),
                                                  child: ConstrainedBox(
                                                    constraints: const BoxConstraints(
                                                      maxHeight: 220,
                                                      maxWidth: 260,
                                                    ),
                                                    child: Image.network(
                                                      _getMessageImageUrl(msg)!,
                                                      fit: BoxFit.cover,
                                                      loadingBuilder: (context, child, loadingProgress) {
                                                        if (loadingProgress == null) return child;
                                                        return Container(
                                                          height: 140,
                                                          width: 200,
                                                          color: Colors.black12,
                                                          child: const Center(
                                                            child: CircularProgressIndicator(strokeWidth: 2),
                                                          ),
                                                        );
                                                      },
                                                      errorBuilder: (context, error, stackTrace) => Container(
                                                        padding: const EdgeInsets.all(12),
                                                        decoration: BoxDecoration(
                                                          color: Colors.grey.shade200,
                                                          borderRadius: BorderRadius.circular(8),
                                                        ),
                                                        child: const Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            Icon(Icons.broken_image, color: Colors.grey),
                                                            SizedBox(width: 6),
                                                            Text('Image unavailable', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                          if (msg['message'] != null &&
                                              msg['message'].toString().isNotEmpty &&
                                              (_getMessageImageUrl(msg) == null || msg['message'] != 'Image'))
                                            Text(
                                              msg['message'] ?? '',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: isUser ? Colors.white : const Color(0xFF1E293B),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  if (isUser) ...[
                                    const SizedBox(width: 8),
                                    _buildAvatar(
                                      imageUrl: photo?.toString(),
                                      isUser: true,
                                      name: senderName.toString(),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
            ),

            // Input Bar
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, -2)),
                ],
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.attach_file, color: Color(0xFF64748B)),
                    onPressed: _isSending ? null : _pickAndSendImage,
                    tooltip: 'Send Image',
                  ),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'Type your message to Admin Support...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF1F5F9),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      ),

                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: primaryColor,
                    radius: 22,
                    child: IconButton(
                      icon: _isSending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.send, color: Colors.white, size: 20),
                      onPressed: _isSending ? null : _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLicenseCardMessage(String text, String? key) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF59E0B)),
      ),
      child: Column(
        children: [
          const Text('🔑 License Key Available', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF92400E), fontSize: 16)),
          const SizedBox(height: 6),
          Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: Color(0xFFB45309))),
          if (key != null) ...[
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _isActivating ? null : () => _activateLicense(key),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
              ),
              child: Text(_isActivating ? 'Activating License...' : 'Activate License'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAvatar({
    required String? imageUrl,
    required bool isUser,
    required String name,
  }) {
    String? resolvedUrl;
    if (imageUrl != null && imageUrl.trim().isNotEmpty) {
      if (imageUrl.startsWith('http')) {
        resolvedUrl = imageUrl;
      } else {
        resolvedUrl = ApiConfig.avatarUrl(imageUrl);
      }
    }

    final hasValidNetworkPhoto = resolvedUrl != null &&
        resolvedUrl.isNotEmpty &&
        !resolvedUrl.endsWith('/uploads/avator.jpg') &&
        !resolvedUrl.endsWith('/avator.jpg');

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isUser ? primaryColor.withOpacity(0.5) : const Color(0xFF2563EB).withOpacity(0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipOval(
        child: hasValidNetworkPhoto
            ? Image.network(
                resolvedUrl,
                width: 32,
                height: 32,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _fallbackAvatar(isUser, name),
                loadingBuilder: (_, child, progress) =>
                    progress == null ? child : _fallbackAvatar(isUser, name),
              )
            : _fallbackAvatar(isUser, name),
      ),
    );
  }

  Widget _fallbackAvatar(bool isUser, String name) {
    if (!isUser) {
      return Container(
        color: const Color(0xFF2563EB),
        alignment: Alignment.center,
        child: const Icon(Icons.support_agent_rounded, color: Colors.white, size: 18),
      );
    }
    return Container(
      color: primaryColor,
      alignment: Alignment.center,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : 'U',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }

  String? _getMessageImageUrl(dynamic msg) {
    if (msg == null || msg is! Map) return null;
    final candidates = [
      msg['image_url'],
      msg['image'],
      msg['attachment_path'],
      msg['file_path'],
      msg['attachment'],
      msg['photo'],
      msg['media_url'],
      msg['file_url'],
    ];
    for (final c in candidates) {
      if (c != null && c.toString().trim().isNotEmpty) {
        return ApiConfig.mediaUrl(c.toString().trim());
      }
    }
    return null;
  }

  void _showFullImageDialog(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(10),
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Center(
                  child: Icon(Icons.broken_image, color: Colors.white, size: 80),
                ),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Global Alias for Support Live Chat Page
class SupportLiveChatPage extends StatelessWidget {
  const SupportLiveChatPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const SupportLiveChatScreen();
  }
}
