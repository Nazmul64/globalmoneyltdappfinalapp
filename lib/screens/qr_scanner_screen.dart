import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../services/auth_service.dart';
import '../widgets/license_guard.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  final TextEditingController _qrInputController = TextEditingController();
  bool _isVerifying = false;
  String? _errorMessage;
  String? _authorizedUrl;
  WebViewController? _webViewController;

  @override
  void dispose() {
    _qrInputController.dispose();
    super.dispose();
  }

  Future<void> _processQrToken(String tokenStr) async {
    if (tokenStr.trim().isEmpty || _isVerifying) return;

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
      _authorizedUrl = null;
    });

    HapticFeedback.mediumImpact();

    final result = await AuthService().verifyQrToken(tokenStr.trim());

    if (!mounted) return;

    setState(() {
      _isVerifying = false;
    });

    if (result['success'] == true) {
      HapticFeedback.heavyImpact();
      final url = result['redirect_url'];

      if (url != null && url.toString().isNotEmpty) {
        final controller = WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..loadRequest(Uri.parse(url));

        setState(() {
          _authorizedUrl = url;
          _webViewController = controller;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('QR Code verified! Authorized content unlocked.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      HapticFeedback.vibrate();
      setState(() {
        _errorMessage = result['message'] ?? 'Invalid or unauthorized QR code.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF4361EE);

    return LicenseGuard(
      featureName: 'QR Scanner',
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Website QR Scanner'),
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
        ),
        body: _authorizedUrl != null && _webViewController != null
            ? WebViewWidget(controller: _webViewController!)
            : SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 20),
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(Icons.qr_code_scanner, size: 80, color: primaryColor),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Scan Website QR Code',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Scan or enter the random QR token generated on the website to verify authorization and access content.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 28),

                      if (_errorMessage != null)
                        Container(
                          padding: const EdgeInsets.all(14),
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.red.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: Colors.red, size: 22),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w600)),
                              ),
                            ],
                          ),
                        ),

                      TextField(
                        controller: _qrInputController,
                        enabled: !_isVerifying,
                        decoration: InputDecoration(
                          labelText: 'QR Code / Token Payload',
                          hintText: 'qrx_8f72a91c...',
                          prefixIcon: const Icon(Icons.qr_code),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: _isVerifying ? null : () => _processQrToken(_qrInputController.text),
                          icon: _isVerifying
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Icon(Icons.verified),
                          label: Text(_isVerifying ? 'Verifying Authorization...' : 'Verify QR Code'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
