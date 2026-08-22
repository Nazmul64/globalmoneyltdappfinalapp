import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../models/post_model.dart';
import '../services/api_service.dart' as api;

class EditPostSheet extends StatefulWidget {
  final Post post;
  final Function(Post) onPostUpdated;

  const EditPostSheet({
    Key? key,
    required this.post,
    required this.onPostUpdated,
  }) : super(key: key);

  @override
  State<EditPostSheet> createState() => _EditPostSheetState();
}

class _EditPostSheetState extends State<EditPostSheet> {
  final TextEditingController _contentController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  File? _newImage;
  String? _existingImageUrl;
  bool _removeImage = false;

  File? _newVideo;
  String? _existingVideoUrl;
  bool _removeVideo = false;

  String _privacy = 'public';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    _contentController.text = widget.post.content ?? '';
    _existingImageUrl = widget.post.fullImageUrl;
    _existingVideoUrl = widget.post.fullVideoUrl;
    _privacy = widget.post.privacy ?? 'public';

    print('═══════════════════════════════════════');
    print('🔧 EDIT POST INITIALIZED');
    print('═══════════════════════════════════════');
    print('Post ID: ${widget.post.id}');
    print('User ID: ${widget.post.userId}');
    print('Content: ${widget.post.content}');
    print('Privacy: $_privacy');
    print('Image URL: $_existingImageUrl');
    print('═══════════════════════════════════════\n');
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _newImage = File(image.path);
          _removeImage = false;
        });
        print('✅ New image selected');
      }
    } catch (e) {
      print('❌ Error picking image: $e');
      _showErrorSnackBar('Failed to pick image');
    }
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _newImage = File(image.path);
          _removeImage = false;
        });
        print('✅ Photo captured');
      }
    } catch (e) {
      print('❌ Error taking photo: $e');
      _showErrorSnackBar('Failed to take photo');
    }
  }

  Future<void> _pickVideo() async {
    try {
      final XFile? video = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 5),
      );

      if (video != null) {
        setState(() {
          _newVideo = File(video.path);
          _removeVideo = false;
        });
        print('✅ New video selected');
      }
    } catch (e) {
      print('❌ Error picking video: $e');
      _showErrorSnackBar('Failed to pick video');
    }
  }

  void _removeCurrentImage() {
    setState(() {
      _newImage = null;
      _existingImageUrl = null;
      _removeImage = true;
    });
    print('🗑️ Image marked for removal');
  }

  void _removeCurrentVideo() {
    setState(() {
      _newVideo = null;
      _existingVideoUrl = null;
      _removeVideo = true;
    });
    print('🗑️ Video marked for removal');
  }

  Future<void> _updatePost() async {
    print('\n╔═══════════════════════════════════════╗');
    print('║     STARTING POST UPDATE              ║');
    print('╚═══════════════════════════════════════╝');
    print('Post ID: ${widget.post.id}');
    print('Content: "${_contentController.text.trim()}"');
    print('Privacy: $_privacy');
    print('New Image: ${_newImage != null}');
    print('New Video: ${_newVideo != null}');
    print('Remove Image: $_removeImage');
    print('Remove Video: $_removeVideo');
    print('═══════════════════════════════════════\n');

    // Validation
    final String contentText = _contentController.text.trim();
    final bool hasContent = contentText.isNotEmpty;
    final bool hasNewImage = _newImage != null;
    final bool hasExistingImage = _existingImageUrl != null && !_removeImage;
    final bool hasNewVideo = _newVideo != null;
    final bool hasExistingVideo = _existingVideoUrl != null && !_removeVideo;

    final bool hasAnyMedia = hasNewImage || hasExistingImage || hasNewVideo || hasExistingVideo;

    if (!hasContent && !hasAnyMedia) {
      print('❌ VALIDATION FAILED: No content or media!');
      _showErrorSnackBar('Please add some content, image or video!');
      return;
    }

    print('✅ VALIDATION PASSED\n');

    setState(() {
      _isLoading = true;
    });

    try {
      print('🔄 CALLING API SERVICE...');

      final result = await api.ApiService.updatePost(
        postId: widget.post.id,
        content: contentText.isEmpty ? null : contentText,
        image: _newImage,
        video: _newVideo,
        privacy: _privacy,
        removeImage: _removeImage,
        removeVideo: _removeVideo,
      );

      print('\n╔═══════════════════════════════════════╗');
      print('║     API RESPONSE RECEIVED             ║');
      print('╚═══════════════════════════════════════╝');
      print('Success: ${result['success']}');
      print('Message: ${result['message']}');
      print('═══════════════════════════════════════\n');

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        if (result['success'] == true) {
          print('✅ POST UPDATE SUCCESSFUL!');

          final updatedPost = result['post'];

          if (updatedPost != null) {
            widget.onPostUpdated(updatedPost);
            Navigator.pop(context);

            _showSuccessSnackBar(
                result['message'] ?? 'Post updated successfully! ✅'
            );
          } else {
            print('⚠️ WARNING: No post data in response!');
            _showErrorSnackBar('Update successful but no data returned');
          }
        } else {
          print('❌ POST UPDATE FAILED!');

          String errorMsg = result['message'] ?? 'Failed to update post';

          if (errorMsg.toLowerCase().contains('not found') ||
              errorMsg.toLowerCase().contains('unauthorized') ||
              errorMsg.toLowerCase().contains('not authorized')) {
            errorMsg = 'You can only edit your own posts! 🚫';
          }

          _showErrorSnackBar(errorMsg);
        }
      }
    } catch (e) {
      print('╔═══════════════════════════════════════╗');
      print('║     EXCEPTION OCCURRED                ║');
      print('╚═══════════════════════════════════════╝');
      print('Exception: $e');
      print('═══════════════════════════════════════\n');

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showErrorSnackBar('Error: ${e.toString()}');
      }
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showImageSourceDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose Image Source'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.blue),
              title: const Text('Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage();
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.blue),
              title: const Text('Camera'),
              onTap: () {
                Navigator.pop(context);
                _takePhoto();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey[200]!),
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    print('❌ Edit cancelled by user');
                    Navigator.pop(context);
                  },
                ),
                const Expanded(
                  child: Text(
                    'Edit Post',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                TextButton(
                  onPressed: _isLoading ? null : _updatePost,
                  child: _isLoading
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Text(
                    'Update',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // User Info
                  Row(
                    children: [
                      ClipOval(
                        child: widget.post.user?.fullAvatarUrl != null &&
                                widget.post.user!.fullAvatarUrl!.isNotEmpty &&
                                !widget.post.user!.fullAvatarUrl!.endsWith('/uploads/avator.jpg') &&
                                !widget.post.user!.fullAvatarUrl!.endsWith('/avator.jpg')
                            ? Image.network(
                                widget.post.user!.fullAvatarUrl!,
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
                              widget.post.user?.name ?? 'Unknown User',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            // Privacy Dropdown
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: DropdownButton<String>(
                                value: _privacy,
                                underline: const SizedBox(),
                                isDense: true,
                                icon: const Icon(Icons.arrow_drop_down, size: 20),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[700],
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'public',
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.public, size: 14),
                                        SizedBox(width: 4),
                                        Text('Public'),
                                      ],
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: 'friends',
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.people, size: 14),
                                        SizedBox(width: 4),
                                        Text('Friends'),
                                      ],
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: 'only_me',
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.lock, size: 14),
                                        SizedBox(width: 4),
                                        Text('Only Me'),
                                      ],
                                    ),
                                  ),
                                ],
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() {
                                      _privacy = value;
                                    });
                                    print('🔒 Privacy changed to: $value');
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Content TextField
                  TextField(
                    controller: _contentController,
                    maxLines: null,
                    minLines: 3,
                    decoration: InputDecoration(
                      hintText: "What's on your mind?",
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      border: InputBorder.none,
                    ),
                    style: const TextStyle(fontSize: 16),
                  ),

                  const SizedBox(height: 16),

                  // Image Preview
                  if (_newImage != null)
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            _newImage!,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: IconButton(
                            icon: const Icon(Icons.close),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.black.withOpacity(0.6),
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () {
                              setState(() {
                                _newImage = null;
                              });
                            },
                          ),
                        ),
                      ],
                    )
                  else if (_existingImageUrl != null && !_removeImage)
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            _existingImageUrl!,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              print('❌ Error loading image: $error');
                              return Container(
                                height: 200,
                                color: Colors.grey[300],
                                child: const Center(
                                  child: Icon(Icons.broken_image, size: 50),
                                ),
                              );
                            },
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: IconButton(
                            icon: const Icon(Icons.close),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.black.withOpacity(0.6),
                              foregroundColor: Colors.white,
                            ),
                            onPressed: _removeCurrentImage,
                          ),
                        ),
                      ],
                    ),

                  const SizedBox(height: 16),

                  // Video Preview
                  if (_newVideo != null)
                    Stack(
                      children: [
                        Container(
                          height: 200,
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.play_circle_outline,
                                  size: 64,
                                  color: Colors.white,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Video Selected',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: IconButton(
                            icon: const Icon(Icons.close),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.black.withOpacity(0.6),
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () {
                              setState(() {
                                _newVideo = null;
                              });
                            },
                          ),
                        ),
                      ],
                    )
                  else if (_existingVideoUrl != null && !_removeVideo)
                    Stack(
                      children: [
                        Container(
                          height: 200,
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.play_circle_outline,
                              size: 64,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: IconButton(
                            icon: const Icon(Icons.close),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.black.withOpacity(0.6),
                              foregroundColor: Colors.white,
                            ),
                            onPressed: _removeCurrentVideo,
                          ),
                        ),
                      ],
                    ),

                  const SizedBox(height: 16),

                  // Media Options
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Text(
                          'Add to your post',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: Icon(Icons.image, color: Colors.green[600]),
                          onPressed: _showImageSourceDialog,
                          tooltip: 'Add Photo',
                        ),
                        IconButton(
                          icon: Icon(Icons.videocam, color: Colors.red[600]),
                          onPressed: _pickVideo,
                          tooltip: 'Add Video',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}