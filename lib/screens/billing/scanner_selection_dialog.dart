import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:focus_swiftbill/services/scanner_service.dart';

class ScannerSelectionDialog extends StatefulWidget {
  final VoidCallback? onScannerSelected;
  final String? currentScanner;

  const ScannerSelectionDialog({
    Key? key,
    this.onScannerSelected,
    this.currentScanner,
  }) : super(key: key);

  @override
  State<ScannerSelectionDialog> createState() => _ScannerSelectionDialogState();
}

class _ScannerSelectionDialogState extends State<ScannerSelectionDialog> {
  late final ScannerService _scannerService;
  bool _isLoading = false;
  String? _selectedScanner;
  bool _showExternalDetails = false;
  List<BluetoothDevice> _discoveredDevices = [];
  bool _isScanningForDevices = false;
  String _wifiIp = '';
  String _wifiPort = '9100';

  @override
  void initState() {
    super.initState();
    _scannerService = context.read<ScannerService>();
    _selectedScanner = widget.currentScanner;
    _loadLastSelection();
  }

  Future<void> _loadLastSelection() async {
    if (_selectedScanner == null) {
      final prefs = await SharedPreferences.getInstance();
      final String? last = prefs.getString('last_scanner');
      if (last != null && last.isNotEmpty) {
        setState(() {
          _selectedScanner = last;
        });
      }
    }
  }
  

  Future<void> _saveSelection(String scanner) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_scanner', scanner);
  }

  Future<void> _scanForBluetoothDevices() async {
    setState(() {
      _isScanningForDevices = true;
      _discoveredDevices = [];
    });

    try {
      final devices = await _scannerService.scanBluetoothDevices();
      if (mounted) {
        setState(() {
          _discoveredDevices = devices;
          _isScanningForDevices = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isScanningForDevices = false;
        });
      }
      debugPrint('Error scanning for Bluetooth devices: $e');
    }
  }

  List<dynamic> get _usbDevices => _scannerService.usbDevices;

  bool get _hasExternalScanners {
    return _discoveredDevices.isNotEmpty ||
        _usbDevices.isNotEmpty ||
        _wifiIp.isNotEmpty;
  }

  void _selectScanner(String scannerType) {
    setState(() {
      _selectedScanner = scannerType;
    });
  }

  void _confirmSelection() {
    if (_selectedScanner == null) return;
    _saveSelection(_selectedScanner!);
    widget.onScannerSelected?.call();
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Scanner'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Phone Camera'),
              trailing: _selectedScanner == ScannerService.camera
                  ? const Icon(Icons.check)
                  : null,
              onTap: () => _selectScanner(ScannerService.camera),
            ),
            const Divider(),
            
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _hasExternalScanners || _selectedScanner == ScannerService.camera
              ? _confirmSelection
              : null,
          child: const Text('Select'),
        ),
      ],
    );
  }
}
