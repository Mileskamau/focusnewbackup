import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:focus_swiftbill/theme/app_theme.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class CameraScannerScreen extends StatefulWidget {
  final String? title;

  const CameraScannerScreen({super.key, this.title});

  @override
  State<CameraScannerScreen> createState() => _CameraScannerScreenState();
}

class _CameraScannerScreenState extends State<CameraScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    torchEnabled: false,
    detectionSpeed: DetectionSpeed.noDuplicates,
    detectionTimeoutMs: 500,
  );
  bool _isTorchOn = false;
  String? _lastScannedBarcode;
  bool _hasDetectedBarcode = false;
  bool _isPreparingCamera = true;
  String? _cameraErrorMessage;

  @override
  void initState() {
    super.initState();
    _prepareCamera();
  }

  Future<void> _prepareCamera() async {
    setState(() {
      _isPreparingCamera = true;
      _cameraErrorMessage = null;
    });

    final status = await Permission.camera.request();
    if (!mounted) return;

    if (!status.isGranted) {
      setState(() {
        _isPreparingCamera = false;
        _cameraErrorMessage = status.isPermanentlyDenied
            ? 'Camera permission is blocked. Please enable it in Settings to scan barcodes.'
            : 'Camera permission is required to scan barcodes.';
      });
      return;
    }

    setState(() {
      _isPreparingCamera = false;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title ?? 'Scan Barcode'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_isTorchOn ? Icons.flash_on : Icons.flash_off),
            color: Colors.white,
            onPressed: () {
              setState(() {
                _isTorchOn = !_isTorchOn;
                _controller.toggleTorch();
              });
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: _buildScannerBody(),
          ),
          Align(
            alignment: Alignment.center,
            child: Container(
              width: 280,
              height: 180,
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.primaryOrange, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: -2,
                    left: -2,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(color: AppTheme.primaryOrange, width: 3),
                          left: BorderSide(color: AppTheme.primaryOrange, width: 3),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(color: AppTheme.primaryOrange, width: 3),
                          right: BorderSide(color: AppTheme.primaryOrange, width: 3),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -2,
                    left: -2,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: AppTheme.primaryOrange, width: 3),
                          left: BorderSide(color: AppTheme.primaryOrange, width: 3),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -2,
                    right: -2,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: AppTheme.primaryOrange, width: 3),
                          right: BorderSide(color: AppTheme.primaryOrange, width: 3),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: const Text(
              'Align barcode within the frame',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
                shadows: [
                  Shadow(
                    blurRadius: 4,
                    color: Colors.black54,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
          if (_lastScannedBarcode != null)
            Positioned(
              top: 20,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _lastScannedBarcode!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontFamily: 'monospace',
                        ),
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

  Widget _buildScannerBody() {
    if (_isPreparingCamera) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_cameraErrorMessage != null) {
      return Container(
        color: Colors.black,
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.camera_alt_outlined,
                color: Colors.white70,
                size: 52,
              ),
              const SizedBox(height: 16),
              Text(
                _cameraErrorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: _prepareCamera,
                    child: const Text('Try Again'),
                  ),
                  if (_cameraErrorMessage!.contains('Settings'))
                    OutlinedButton(
                      onPressed: openAppSettings,
                      child: const Text('Open Settings'),
                    ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return MobileScanner(
      controller: _controller,
      onDetect: (BarcodeCapture capture) {
        if (_hasDetectedBarcode) return;

        final List<Barcode> barcodes = capture.barcodes;
        for (final barcode in barcodes) {
          final String? code = barcode.rawValue?.trim();
          if (code != null && code.isNotEmpty) {
            if (_lastScannedBarcode == code) {
              return;
            }

            setState(() {
              _lastScannedBarcode = code;
              _hasDetectedBarcode = true;
            });

            HapticFeedback.lightImpact();

            Future.delayed(const Duration(milliseconds: 300), () {
              if (mounted) {
                Navigator.of(context).pop(code);
              }
            });
            break;
          }
        }
      },
      errorBuilder: (context, error) {
        if (mounted) {
          setState(() {
            _cameraErrorMessage = 'Could not start camera: ${error.toString()}';
          });
        }
        return Container(
          color: Colors.black,
          child: const Center(
            child: Text(
              'Camera error occurred',
              style: TextStyle(color: Colors.white),
            ),
          ),
        );
      },
      fit: BoxFit.cover,
    );
  }
}
