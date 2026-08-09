import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'config/api_config.dart';

String get apiBaseUrl => ApiConfig.baseUrl;

class KycSubmitPage extends StatefulWidget {
  const KycSubmitPage({super.key});

  @override
  State<KycSubmitPage> createState() => _KycSubmitPageState();
}

class _KycSubmitPageState extends State<KycSubmitPage> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();

  String? _selectedDocumentType;
  File? _firstPhoto;
  File? _secondPhoto;
  bool _isUploading = false;
  bool _isLoadingStatus = true;
  String? _authToken;

  // KYC Status
  String? _kycStatus;
  Map<String, dynamic>? _kycData;

  // Theme Color
  Color _themeColor = const Color(0xFFE53935);
  bool _isLoadingTheme = true;

  // API Base URL
  // URL: use ApiConfig.baseUrl

  final List<String> _documentTypes = [
    'Passport',
    'NID',
    'Driving License',
    'Date of Birth Certificate',
  ];

  @override
  void initState() {
    super.initState();
    _initializePage();
  }

  Future<void> _initializePage() async {
    await Future.wait([_loadThemeColor(), _loadTokenAndCheckStatus()]);
  }

  /// Load Theme Color from API
  Future<void> _loadThemeColor() async {
    try {
      debugPrint('🎨 Loading theme color...');

      final response = await http
          .get(
            Uri.parse('$apiBaseUrl/themechange'),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == true && data['data'] != null) {
          String colorCode = data['data']['color_code'] ?? '#E53935';
          colorCode = colorCode.replaceAll('#', '');
          final color = Color(int.parse('FF$colorCode', radix: 16));
          if (mounted) {
            setState(() {
              _themeColor = color;
              _isLoadingTheme = false;
            });
          }
          debugPrint('✅ Theme color loaded: #$colorCode');
        } else {
          if (mounted) setState(() => _isLoadingTheme = false);
        }
      } else {
        if (mounted) setState(() => _isLoadingTheme = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingTheme = false);
      debugPrint('❌ Theme load error: $e');
    }
  }

  /// Load Auth Token from SharedPreferences
  Future<void> _loadTokenAndCheckStatus() async {
    try {
      debugPrint('🔐 Loading authentication token...');

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      debugPrint('Token exists: ${token != null}');

      if (token != null && token.isNotEmpty) {
        debugPrint('✅ Token found');

        if (mounted) {
          setState(() {
            _authToken = token.trim();
          });
        }

        await _checkKycStatus();
      } else {
        debugPrint('❌ No token found');

        if (mounted) {
          setState(() {
            _authToken = null;
            _isLoadingStatus = false;
            _kycStatus = 'not_submitted';
          });

          _showSnackBar('Please login to submit KYC', Colors.orange);
        }
      }
    } catch (e) {
      debugPrint('❌ Token load error: $e');

      if (mounted) {
        setState(() {
          _authToken = null;
          _isLoadingStatus = false;
          _kycStatus = 'not_submitted';
        });
      }
    }
  }

  /// Check KYC Status from API
  Future<void> _checkKycStatus() async {
    if (_authToken == null || _authToken!.isEmpty) {
      if (mounted) {
        setState(() {
          _isLoadingStatus = false;
          _kycStatus = 'not_submitted';
        });
      }
      return;
    }

    if (mounted) setState(() => _isLoadingStatus = true);

    try {
      final url = '$apiBaseUrl/kycsubmit/kyc-status';

      debugPrint('📋 Checking KYC status...');

      final response = await http
          .get(
            Uri.parse(url),
            headers: {
              'Authorization': 'Bearer $_authToken',
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 15));

      debugPrint('Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (mounted) {
          setState(() {
            _kycData = data['data'];
            _kycStatus = _kycData?['status'] ?? 'not_submitted';
            _isLoadingStatus = false;
          });
        }

        debugPrint('✅ KYC Status: $_kycStatus');
      } else if (response.statusCode == 401) {
        debugPrint('❌ 401 Unauthorized');

        if (mounted) {
          setState(() {
            _kycStatus = 'not_submitted';
            _isLoadingStatus = false;
          });

          _showSnackBar('Session expired. Please login again.', Colors.red);
        }
      } else if (response.statusCode == 404) {
        debugPrint('ℹ️ No KYC found (first submission)');

        if (mounted) {
          setState(() {
            _kycStatus = 'not_submitted';
            _kycData = null;
            _isLoadingStatus = false;
          });
        }
      } else {
        debugPrint('⚠️ Unexpected status: ${response.statusCode}');

        if (mounted) {
          setState(() {
            _kycStatus = 'not_submitted';
            _isLoadingStatus = false;
          });
        }
      }
    } on SocketException {
      debugPrint('❌ Network error');

      if (mounted) {
        setState(() {
          _kycStatus = 'not_submitted';
          _isLoadingStatus = false;
        });
        _showSnackBar('No internet connection', Colors.red);
      }
    } catch (e) {
      debugPrint('❌ Error: $e');

      if (mounted) {
        setState(() {
          _kycStatus = 'not_submitted';
          _isLoadingStatus = false;
        });
      }
    }
  }

  /// Pick Image from Camera or Gallery
  Future<void> _pickImage(ImageSource source, bool isFirst) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1080,
      );

      if (picked != null) {
        final fileSize = await File(picked.path).length();
        if (fileSize > 2 * 1024 * 1024) {
          if (mounted) {
            _showSnackBar(
              '⚠️ Image size too large. Please select an image under 2MB',
              Colors.orange,
            );
          }
          return;
        }

        setState(() {
          if (isFirst) {
            _firstPhoto = File(picked.path);
          } else {
            _secondPhoto = File(picked.path);
          }
        });

        if (mounted) {
          _showSnackBar(
            isFirst ? '✓ Front photo selected' : '✓ Back photo selected',
            Colors.green,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error: ${e.toString()}', Colors.red);
      }
      debugPrint('Error picking image: $e');
    }
  }

  /// Show SnackBar
  void _showSnackBar(String message, Color backgroundColor) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  /// Show Image Source Bottom Sheet
  Future<void> _showImageSourceSheet(bool isFirst) async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text(
                'Select Photo',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              _buildImageOption(
                icon: Icons.camera_alt,
                color: _themeColor,
                title: 'Camera',
                subtitle: 'Take a new photo',
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera, isFirst);
                },
              ),
              const Divider(height: 20),
              _buildImageOption(
                icon: Icons.photo_library,
                color: _themeColor,
                title: 'Gallery',
                subtitle: 'Choose from gallery',
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery, isFirst);
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  /// Build Image Option Widget
  Widget _buildImageOption({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }

  /// Image Upload Section Widget
  Widget _imageUploadSection(String label, File? imageFile, bool isFirst) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isFirst ? Icons.credit_card : Icons.credit_card_outlined,
                size: 20,
                color: _themeColor,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () => _showImageSourceSheet(isFirst),
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                color: Colors.grey.shade100,
                border: Border.all(
                  color: imageFile != null ? _themeColor : Colors.grey.shade300,
                  width: 2,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: imageFile != null
                    ? Stack(
                        children: [
                          Image.file(
                            imageFile,
                            fit: BoxFit.cover,
                            width: 160,
                            height: 160,
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: _themeColor,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_photo_alternate_outlined,
                            size: 50,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tap to upload',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _showImageSourceSheet(isFirst),
            icon: const Icon(Icons.camera_alt, size: 18),
            label: Text(imageFile != null ? 'Change Photo' : 'Select Photo'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _themeColor,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
          ),
          if (imageFile != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _themeColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, color: _themeColor, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'Photo selected',
                    style: TextStyle(
                      color: _themeColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Submit KYC
  Future<void> _submitKyc() async {
    if (_authToken == null || _authToken!.isEmpty) {
      debugPrint('❌ No token available');
      _showSnackBar('Please login first', Colors.red);
      return;
    }

    if (!_formKey.currentState!.validate()) {
      _showSnackBar('⚠️ Please fill all fields', Colors.orange);
      return;
    }

    if (_firstPhoto == null || _secondPhoto == null) {
      _showSnackBar('⚠️ Please upload both photos', Colors.red);
      return;
    }

    setState(() => _isUploading = true);

    try {
      String endpoint = _kycStatus == 'rejected'
          ? '$apiBaseUrl/kycsubmit/kyc-resubmit'
          : '$apiBaseUrl/kycsubmit';

      debugPrint('📤 Submitting KYC...');
      debugPrint('Endpoint: $endpoint');

      final request = http.MultipartRequest('POST', Uri.parse(endpoint))
        ..headers['Authorization'] = 'Bearer $_authToken'
        ..headers['Accept'] = 'application/json'
        ..fields['document_type'] = _selectedDocumentType!
        ..files.add(
          await http.MultipartFile.fromPath(
            'document_first_part_photo',
            _firstPhoto!.path,
            filename: path.basename(_firstPhoto!.path),
          ),
        )
        ..files.add(
          await http.MultipartFile.fromPath(
            'document_secound_part_photo',
            _secondPhoto!.path,
            filename: path.basename(_secondPhoto!.path),
          ),
        );

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 60),
      );

      final response = await http.Response.fromStream(streamedResponse);

      setState(() => _isUploading = false);

      debugPrint('Response Status: ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);

        if (mounted) {
          _showSuccessSubmissionDialog(
            data['message'] ?? 'KYC submitted successfully!',
          );

          setState(() {
            _firstPhoto = null;
            _secondPhoto = null;
            _selectedDocumentType = null;
            _kycStatus = 'pending';
          });

          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) _checkKycStatus();
          });
        }
      } else if (response.statusCode == 401) {
        debugPrint('❌ 401 Unauthorized');
        if (mounted) {
          _showSnackBar(
            'Session expired. Please logout and login again.',
            Colors.red,
          );
        }
      } else if (response.statusCode == 403) {
        final data = json.decode(response.body);
        String errorMessage = data['message'] ?? 'KYC already submitted';

        if (mounted) {
          _showDialog('Cannot Submit', errorMessage, false);
          _checkKycStatus();
        }
      } else {
        final data = json.decode(response.body);
        String errorMessage = data['message'] ?? 'Failed to submit KYC';

        if (data['data'] != null && data['data']['errors'] != null) {
          final errors = data['data']['errors'] as Map<String, dynamic>;
          errorMessage = errors.values.first[0];
        }

        if (mounted) {
          _showDialog('Submission Failed', errorMessage, false);
        }
      }
    } on SocketException {
      setState(() => _isUploading = false);
      if (mounted) {
        _showDialog(
          'Network Error',
          'Please check your internet connection and try again.',
          false,
        );
      }
    } catch (e) {
      setState(() => _isUploading = false);
      debugPrint('Error: $e');
      if (mounted) {
        _showDialog(
          'Error Occurred',
          e.toString().replaceAll('Exception: ', ''),
          false,
        );
      }
    }
  }

  /// Show Success Submission Dialog
  void _showSuccessSubmissionDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: _themeColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check_circle, size: 50, color: _themeColor),
              ),
              const SizedBox(height: 24),
              const Text(
                'Successfully Submitted!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                message,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.hourglass_empty,
                      color: Colors.amber.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Your status will now show as Pending',
                        style: TextStyle(
                          color: Colors.amber.shade900,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _themeColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'OK',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Show Dialog
  void _showDialog(String title, String message, bool isSuccess) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Row(
          children: [
            Icon(
              isSuccess ? Icons.check_circle : Icons.error_outline,
              color: isSuccess ? _themeColor : Colors.red,
              size: 30,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(title, style: const TextStyle(fontSize: 18))),
          ],
        ),
        content: Text(message, style: const TextStyle(fontSize: 15)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'OK',
              style: TextStyle(
                color: isSuccess ? _themeColor : Colors.red,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build Pending View
  Widget _buildPendingView() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Container(
                margin: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.hourglass_empty_rounded,
                  size: 70,
                  color: Colors.orange.shade600,
                ),
              ),
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    'Your KYC Status:',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.orange.shade400,
                          Colors.orange.shade600,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.orange.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Text(
                      'Pending',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Divider(color: Colors.grey.shade200, thickness: 1),
                  const SizedBox(height: 24),
                  Text(
                    'Your KYC is under review. Please wait.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey.shade700,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            if (_kycData != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      'Submission Details',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildDetailRow(
                      Icons.description,
                      'Document Type',
                      _kycData!['document_type'] ?? 'N/A',
                    ),
                    const Divider(height: 24),
                    _buildDetailRow(
                      Icons.calendar_today,
                      'Submitted Date',
                      _kycData!['submitted_at'] ?? 'N/A',
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: _themeColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: _themeColor.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _themeColor,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.info_outline,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Your document will be verified within 24-48 hours.',
                      style: TextStyle(
                        color: _themeColor.computeLuminance() > 0.5
                            ? Colors.black87
                            : _themeColor,
                        fontSize: 13,
                        height: 1.5,
                        fontWeight: FontWeight.w500,
                      ),
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

  /// Build Verified View
  Widget _buildVerifiedView() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _themeColor.withOpacity(0.3),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Container(
                margin: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_themeColor.withOpacity(0.8), _themeColor],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, size: 80, color: Colors.white),
              ),
            ),
            const SizedBox(height: 40),
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    'Your KYC Status:',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_themeColor.withOpacity(0.8), _themeColor],
                      ),
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: _themeColor.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.verified, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Verified',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Divider(color: Colors.grey.shade200, thickness: 1),
                  const SizedBox(height: 24),
                  Text(
                    'Congratulations! Your KYC has been successfully verified.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey.shade700,
                      height: 1.6,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            if (_kycData != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      'Verification Details',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildDetailRow(
                      Icons.description,
                      'Document Type',
                      _kycData!['document_type'] ?? 'N/A',
                    ),
                    const Divider(height: 24),
                    _buildDetailRow(
                      Icons.check_circle,
                      'Verified On',
                      _kycData!['verified_at'] ??
                          _kycData!['submitted_at'] ??
                          'N/A',
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: _themeColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: _themeColor.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _themeColor,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.thumb_up,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'You can now use all features.',
                      style: TextStyle(
                        color: _themeColor.computeLuminance() > 0.5
                            ? Colors.black87
                            : _themeColor,
                        fontSize: 13,
                        height: 1.5,
                        fontWeight: FontWeight.w600,
                      ),
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

  /// Build Detail Row
  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _themeColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: _themeColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Submit KYC',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        backgroundColor: _themeColor,
        elevation: 0,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _checkKycStatus,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoadingStatus
          ? Center(child: CircularProgressIndicator(color: _themeColor))
          : _kycStatus == 'pending'
          ? _buildPendingView()
          : _kycStatus == 'approved'
          ? _buildVerifiedView()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  if (_kycStatus == 'rejected') ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 24),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: Colors.red.shade300,
                          width: 2,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.cancel,
                            color: Colors.red.shade600,
                            size: 60,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'KYC Rejected',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.red.shade700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _kycData?['rejection_reason'] ??
                                'Your KYC has been rejected. Please submit again with correct documents.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.red.shade900,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.amber.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: Colors.amber.shade700,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Please upload correct documents below and resubmit.',
                                    style: TextStyle(
                                      color: Colors.amber.shade900,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    _infoCard(),
                    const SizedBox(height: 24),
                  ],
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        _documentDropdown(),
                        const SizedBox(height: 24),
                        _imageUploadSection(
                          "Front Side Photo",
                          _firstPhoto,
                          true,
                        ),
                        const SizedBox(height: 24),
                        _imageUploadSection(
                          "Back Side Photo",
                          _secondPhoto,
                          false,
                        ),
                        const SizedBox(height: 32),
                        _isUploading ? _uploadingWidget() : _submitButton(),
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _themeColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _themeColor.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.access_time,
                                color: _themeColor,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Your document will be verified within 24-48 hours',
                                  style: TextStyle(
                                    color: _themeColor.computeLuminance() > 0.5
                                        ? Colors.black87
                                        : _themeColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
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

  /// Info Card Widget
  Widget _infoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _themeColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _themeColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _themeColor,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.info_outline,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Important',
                  style: TextStyle(
                    color: _themeColor.computeLuminance() > 0.5
                        ? Colors.black87
                        : _themeColor,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Please upload clear photos of your document. Keep all details clearly visible.',
                  style: TextStyle(
                    color: _themeColor.computeLuminance() > 0.5
                        ? Colors.black87
                        : _themeColor.withOpacity(0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Document Dropdown Widget
  Widget _documentDropdown() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonFormField<String>(
        decoration: InputDecoration(
          labelText: "Select Document Type",
          labelStyle: TextStyle(color: Colors.grey.shade700),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: _themeColor, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red),
          ),
          prefixIcon: Icon(Icons.description, color: _themeColor),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
        value: _selectedDocumentType,
        items: _documentTypes
            .map(
              (type) => DropdownMenuItem(
                value: type,
                child: Text(type, style: const TextStyle(fontSize: 15)),
              ),
            )
            .toList(),
        onChanged: (value) => setState(() => _selectedDocumentType = value),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return "Please select a document type";
          }
          return null;
        },
      ),
    );
  }

  /// Uploading Widget
  Widget _uploadingWidget() {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _themeColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: CircularProgressIndicator(color: _themeColor, strokeWidth: 4),
        ),
        const SizedBox(height: 20),
        const Text(
          "Uploading KYC documents...",
          style: TextStyle(
            color: Colors.black87,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "Please wait...",
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        ),
      ],
    );
  }

  /// Submit Button Widget
  Widget _submitButton() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: _themeColor.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _submitKyc,
        style: ElevatedButton.styleFrom(
          backgroundColor: _themeColor,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _kycStatus == 'rejected' ? Icons.refresh : Icons.upload_file,
              size: 24,
            ),
            const SizedBox(width: 12),
            Text(
              _kycStatus == 'rejected' ? "Resubmit KYC" : "Submit KYC",
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
