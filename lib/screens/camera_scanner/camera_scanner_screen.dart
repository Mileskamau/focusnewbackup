import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:focus_swiftbill/theme/app_theme.dart';
import 'package:focus_swiftbill/utils/constants.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class CameraScannerScreen extends StatefulWidget {
  final String? title;

  const CameraScannerScreen({super.key, this.title});

  @override
  State<CameraScannerScreen> createState() => _CameraScannerScreenState();
}

class _CameraScannerScreenState extends State<CameraScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    torchEnabled: true,
    detectionSpeed: DetectionSpeed.noDuplicates,
    detectionTimeoutMs: 500,
  );
  bool _isTorchOn = false;
  String? _lastScannedBarcode;
  bool _hasDetectedBarcode = false;

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
          MobileScanner(
            controller: _controller,
            onDetect: (BarcodeCapture capture) {
              if (_hasDetectedBarcode) return;
              
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                final String? code = barcode.rawValue;
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
            fit: BoxFit.cover,
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
}
