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
            ExpansionTile(
              title: const Text('External Scanner'),
              children: [
                if (_discoveredDevices.isNotEmpty ||
                    _usbDevices.isNotEmpty ||
                    _wifiIp.isNotEmpty) ...[
                  if (_discoveredDevices.isNotEmpty) ...[
                    const ListTile(
                      leading: Icon(Icons.bluetooth),
                      title: Text('Bluetooth Devices'),
                    ),
                    ..._discoveredDevices.map((device) => ListTile(
                          leading: const Icon(Icons.devices),
                          title: Text(device.platformName.isNotEmpty
                              ? device.platformName
                              : 'Unknown Device'),
                          subtitle: Text(device.remoteId.str),
                          trailing: _selectedScanner ==
                                  '${ScannerService.bluetoothPrefix}${device.remoteId}'
                              ? const Icon(Icons.check)
                              : null,
                          onTap: () => _selectScanner(
                            '${ScannerService.bluetoothPrefix}${device.remoteId}',
                          ),
                        )),
                  ],
                  if (_usbDevices.isNotEmpty) ...[
                    const ListTile(
                      leading: Icon(Icons.usb),
                      title: Text('USB Scanner (Wired)'),
                    ),
                    ..._usbDevices.map((device) => ListTile(
                          leading: const Icon(Icons.memory),
                          title: Text(device.name.isNotEmpty
                              ? device.name
                              : 'USB Device'),
                          subtitle: Text('VID: ${device.vendorId}, PID: ${device.productId}'),
                          trailing: _selectedScanner == ScannerService.usb
                              ? const Icon(Icons.check)
                              : null,
                          onTap: () => _selectScanner(ScannerService.usb),
                        )),
                  ],
                  const ListTile(
                    leading: Icon(Icons.wifi),
                    title: Text('Wi-Fi Scanner'),
                  ),
                  Column(
                    children: [
                      TextField(
                        decoration: const InputDecoration(
                          labelText: 'IP Address',
                          hintText: 'e.g., 192.168.1.100',
                        ),
                        keyboardType: TextInputType.numberWithOptions(signed: false, decimal: true),
                        onChanged: (value) => _wifiIp = value,
                      ),
                      TextField(
                        decoration: const InputDecoration(
                          labelText: 'Port',
                          hintText: 'e.g., 9100',
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (value) => _wifiPort = value,
                      ),
                    ],
                  ),
                  if (_wifiIp.isNotEmpty) ...[
                    ListTile(
                      leading: const Icon(Icons.wifi),
                      title: Text('Wi-Fi Scanner ($_wifiIp:$_wifiPort)'),
                      trailing: _selectedScanner ==
                              '${ScannerService.wifiPrefix}$_wifiIp:$_wifiPort'
                          ? const Icon(Icons.check)
                          : null,
                      onTap: () => _selectScanner(
                          '${ScannerService.wifiPrefix}$_wifiIp:$_wifiPort'),
                    ),
                  ],
                ] else ...[
                  const ListTile(
                    leading: Icon(Icons.warning_amber),
                    title: Text('No external scanners found.'),
                    subtitle: Text(
                        'Please connect a Bluetooth/USB scanner or enter Wi-Fi details.'),
                  ),
                  if (!_isScanningForDevices) ...[
                    ListTile(
                      leading: const Icon(Icons.refresh),
                      title: const Text('Scan for Bluetooth Devices'),
                      onTap: _scanForBluetoothDevices,
                    ),
                  ] else ...[
                    const ListTile(
                      leading: Icon(Icons.refresh),
                      title: Text('Scanning...'),
                      trailing: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ],
                ],
              ],
            ),
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
