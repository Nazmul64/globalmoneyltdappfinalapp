import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../config/api_config.dart';
import '../services/auth_service.dart';


class SupportLiveChatScreen extends StatefulWidget {
  const SupportLiveChatScreen({super.key});

  @override
  State<SupportLiveChatScreen> createState() => _SupportLiveChatScreenState();
}

class _SupportLiveChatScreenState extends State<SupportLiveChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<dynamic> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  bool _isActivating = false;
  String? _assignedLicenseKey;
  String _licenseStatus = 'inactive';
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _loadConversation();
    _startPolling();
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
    if (!silent) {
      setState(() => _isLoading = true);
    }

    try {
      final token = await AuthService().getToken();
      if (token == null) return;

      final response = await http.get(
        Uri.parse(ApiConfig.v1SupportConvo),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && mounted) {
          final msgs = data['messages'] ?? [];
          final status = data['license_status'] ?? 'inactive';

          String? assignedKey;
          if (data['assigned_license'] != null && data['assigned_license']['license_key'] != null) {
            assignedKey = data['assigned_license']['license_key'];
          }

          // Also check messages for license keys or preset cards
          for (var m in msgs) {
            final msgText = m['message']?.toString() ?? '';
            if (m['license_key'] != null && m['license_key'].toString().isNotEmpty) {
              assignedKey = m['license_key'].toString();
            } else if (msgText.contains('[LICENSE_CARD:')) {
              final match = RegExp(r'key=([a-zA-Z0-9_\-]+)').firstMatch(msgText);
              if (match != null && match.group(1) != null) {
                assignedKey = match.group(1);
              }
            }
          }

          setState(() {
            _messages = msgs;
            _licenseStatus = status;
            _assignedLicenseKey = assignedKey;
            _isLoading = false;
          });

          if (!silent) _scrollToBottom();
        }
      }
    } catch (e) {
      if (!silent && mounted) {
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
        Uri.parse(ApiConfig.v1SupportMessages),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'message': text}),
      );

      if (response.statusCode == 200) {
        await _loadConversation(silent: true);
        _scrollToBottom();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to send message. Check internet connection.')),
      );
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
      final request = http.MultipartRequest('POST', Uri.parse(ApiConfig.v1SupportMessages));
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      request.files.add(await http.MultipartFile.fromPath('file', pickedFile.path));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        await _loadConversation(silent: true);
        _scrollToBottom();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to upload image.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading image: $e')),
      );
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Live Support Chat', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(
              'License Status: ${_licenseStatus.toUpperCase()}',
              style: TextStyle(
                fontSize: 12,
                color: _licenseStatus.toLowerCase() == 'active' ? Colors.greenAccent : Colors.amberAccent,
              ),
            ),
          ],
        ),
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

                            return Align(
                              alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
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
                                  crossAxisAlignment: isUser ? CrossAlignment.end : CrossAlignment.start,
                                  children: [
                                    Text(
                                      msg['sender_name'] ?? (isUser ? 'You' : 'Admin'),
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: isUser ? Colors.white70 : Colors.grey[600],
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    if (msg['attachment_path'] != null && msg['attachment_path'].toString().isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 6),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(10),
                                          child: Image.network(
                                            ApiConfig.mediaUrl(msg['attachment_path'].toString()),
                                            fit: BoxFit.cover,
                                            maxHeight: 200,
                                            errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, color: Colors.grey),
                                          ),
                                        ),
                                      ),
                                    if (msg['message'] != null && msg['message'].toString().isNotEmpty)
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
}

// Global Alias for Support Live Chat Page
class SupportLiveChatPage extends StatelessWidget {
  const SupportLiveChatPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const SupportLiveChatScreen();
  }
}
