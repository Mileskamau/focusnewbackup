import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ScannerService extends ChangeNotifier {
  static const String camera = 'camera';
  static const String bluetoothPrefix = 'bluetooth:';
  static const String usb = 'usb';
  static const String wifiPrefix = 'wifi:';

  String? _activeScanner;
  String? _lastScanner;
  Barcode? _lastBarcode;
  final StreamController<String> _barcodeController = StreamController<String>.broadcast();
  Stream<String> get barcodeStream => _barcodeController.stream;

  StreamSubscription<Barcode>? _cameraSubscription;
  StreamSubscription<List<ScanResult>>? _bluetoothSubscription;
  Socket? _wifiSocket;

  List<BluetoothDevice> _bluetoothDevices = [];
  bool _isScanningBluetooth = false;
  List<dynamic> _usbDevices = [];
  String _prefLastScanner = 'last_scanner';
  String _keyBuffer = '';
  Timer? _bufferTimer;
  final Duration _bufferTimeout = const Duration(milliseconds: 50);

  Future<void> _loadLastScanner() async {
    final prefs = await SharedPreferences.getInstance();
    _lastScanner = prefs.getString(_prefLastScanner);
    notifyListeners();
  }

  Future<void> _saveLastScanner(String scanner) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefLastScanner, scanner);
    _lastScanner = scanner;
    notifyListeners();
  }

  String? get lastScanner => _lastScanner;
  String? get activeScanner => _activeScanner;
  List<BluetoothDevice> get bluetoothDevices => _bluetoothDevices;
  bool get isScanningBluetooth => _isScanningBluetooth;
  List<dynamic> get usbDevices => _usbDevices;

  Future<void> startCameraScanner() async {
    await stopAllScanners();
    _activeScanner = camera;
    notifyListeners();
  }

  Future<void> startBluetoothScanner(BluetoothDevice device) async {
    await stopAllScanners();
    _activeScanner = '$bluetoothPrefix${device.remoteId}';
    notifyListeners();
  }

  Future<void> startUsbScanner() async {
    await stopAllScanners();
    _activeScanner = usb;
    notifyListeners();
  }

  Future<void> startWifiScanner(String ip, int port) async {
    await stopAllScanners();
    _activeScanner = '$wifiPrefix$ip:$port';
    notifyListeners();

    try {
      _wifiSocket = await Socket.connect(ip, port);
      _wifiSocket?.listen(
        (List<int> event) {
          final String data = String.fromCharCodes(event).trim();
          if (data.isNotEmpty) {
            _barcodeController.add(data);
          }
        },
        onError: (error) {
          debugPrint('Wi-Fi scanner error: $error');
          stopWifiScanner();
        },
        onDone: () {
          debugPrint('Wi-Fi scanner disconnected');
          stopWifiScanner();
        },
      );
    } catch (e) {
      debugPrint('Failed to connect to Wi-Fi scanner: $e');
      _wifiSocket = null;
      rethrow;
    }
  }

  Future<List<BluetoothDevice>> scanBluetoothDevices({Duration duration = const Duration(seconds: 4)}) async {
    _isScanningBluetooth = true;
    notifyListeners();
    _bluetoothDevices = [];

    FlutterBluePlus.startScan(timeout: duration);

    _bluetoothSubscription = FlutterBluePlus.scanResults.listen(
      (List<ScanResult> results) {
        for (ScanResult r in results) {
          if (!_bluetoothDevices.any((d) => d.remoteId == r.device.remoteId)) {
            _bluetoothDevices.add(r.device);
          }
        }
        notifyListeners();
      },
    );

    await Future.delayed(duration);
    FlutterBluePlus.stopScan();
    _isScanningBluetooth = false;
    notifyListeners();
    return _bluetoothDevices;
  }

  Future<void> stopAllScanners() async {
    await stopCameraScanner();
    await stopBluetoothScanner();
    await stopUsbScanner();
    await stopWifiScanner();
    _activeScanner = null;
    notifyListeners();
  }

  Future<void> stopCameraScanner() async {
    if (_cameraSubscription != null) {
      await _cameraSubscription?.cancel();
      _cameraSubscription = null;
    }
  }

  Future<void> stopBluetoothScanner() async {
    if (_isScanningBluetooth) {
      FlutterBluePlus.stopScan();
      _isScanningBluetooth = false;
    }
    if (_bluetoothSubscription != null) {
      await _bluetoothSubscription?.cancel();
      _bluetoothSubscription = null;
    }
  }

  Future<void> stopUsbScanner() async {
    _usbDevices = [];
    notifyListeners();
  }

  Future<void> stopWifiScanner() async {
    await _wifiSocket?.close();
    _wifiSocket = null;
  }

  void handleBarcode(Barcode barcode) {
    if (_activeScanner == camera && barcode.rawValue != null) {
      final String code = barcode.rawValue!;
      if (_lastBarcode?.rawValue == code) {
        return;
      }
      _lastBarcode = barcode;
      _barcodeController.add(code);
    }
  }

  // ------------------------------------------------------------
  // Existing KeyEvent handler (works with Focus widget)
  // ------------------------------------------------------------
  void handleKeyEvent(KeyEvent event) {
    if (_activeScanner == null) return;
    if (event is! KeyDownEvent) return;

    final LogicalKeyboardKey key = event.logicalKey;
    final String? keyLabel = event.logicalKey.keyLabel;

    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) {
      _processBuffer();
      return;
    }

    if (key == LogicalKeyboardKey.backspace) {
      if (_keyBuffer.isNotEmpty) {
        _keyBuffer = _keyBuffer.substring(0, _keyBuffer.length - 1);
      }
      return;
    }

    if (key == LogicalKeyboardKey.escape) {
      _clearBuffer();
      return;
    }

    if (keyLabel != null && keyLabel.isNotEmpty && keyLabel.length == 1) {
      if (RegExp(r'^[0-9A-Za-z\-\_\.\*\+\/\%\$\#\@\!\&\s]$').hasMatch(keyLabel)) {
        _keyBuffer += keyLabel;
        _bufferTimer?.cancel();
        _bufferTimer = Timer(_bufferTimeout, _processBuffer);
      }
    }

    if (_keyBuffer.isEmpty || _keyBuffer.length < 2) {
      final int? digit = _getNumpadDigit(key);
      if (digit != null) {
        _keyBuffer += digit.toString();
        _bufferTimer?.cancel();
        _bufferTimer = Timer(_bufferTimeout, _processBuffer);
      }
    }
  }

  // ------------------------------------------------------------
  // NEW: RawKeyEvent handler for RawKeyboardListener (hardware scanners)
  // ------------------------------------------------------------
  void handleRawKeyEvent(RawKeyEvent event) {
    if (_activeScanner == null) return;
    if (event is! RawKeyDownEvent) return;

    final LogicalKeyboardKey key = event.logicalKey;
    final String? keyLabel = event.character; // RawKeyDownEvent provides character

    // Enter key - finalize barcode
    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) {
      _processBuffer();
      return;
    }

    // Backspace
    if (key == LogicalKeyboardKey.backspace) {
      if (_keyBuffer.isNotEmpty) {
        _keyBuffer = _keyBuffer.substring(0, _keyBuffer.length - 1);
      }
      return;
    }

    // Escape - clear buffer
    if (key == LogicalKeyboardKey.escape) {
      _clearBuffer();
      return;
    }

    // Printable characters (via event.character)
    if (keyLabel != null && keyLabel.isNotEmpty && keyLabel.length == 1) {
      if (RegExp(r'^[0-9A-Za-z\-\_\.\*\+\/\%\$\#\@\!\&\s]$').hasMatch(keyLabel)) {
        _keyBuffer += keyLabel;
        _bufferTimer?.cancel();
        _bufferTimer = Timer(_bufferTimeout, _processBuffer);
      }
    }

    // Numpad digits (fallback if character not provided)
    final int? digit = _getNumpadDigit(key);
    if (digit != null && (keyLabel == null || keyLabel.isEmpty)) {
      _keyBuffer += digit.toString();
      _bufferTimer?.cancel();
      _bufferTimer = Timer(_bufferTimeout, _processBuffer);
    }
  }

  int? _getNumpadDigit(LogicalKeyboardKey key) {
    final Map<LogicalKeyboardKey, int> numpadMap = {
      LogicalKeyboardKey.numpad0: 0,
      LogicalKeyboardKey.numpad1: 1,
      LogicalKeyboardKey.numpad2: 2,
      LogicalKeyboardKey.numpad3: 3,
      LogicalKeyboardKey.numpad4: 4,
      LogicalKeyboardKey.numpad5: 5,
      LogicalKeyboardKey.numpad6: 6,
      LogicalKeyboardKey.numpad7: 7,
      LogicalKeyboardKey.numpad8: 8,
      LogicalKeyboardKey.numpad9: 9,
    };
    return numpadMap[key];
  }

  void _processBuffer() {
    _bufferTimer?.cancel();
    _bufferTimer = null;

    if (_keyBuffer.isNotEmpty && _keyBuffer.length >= 6) {
      final String barcode = _keyBuffer.trim();
      _barcodeController.add(barcode);
      debugPrint('Scanner [$_activeScanner]: $barcode');
    } else if (_keyBuffer.isNotEmpty) {
      _bufferTimer = Timer(const Duration(milliseconds: 100), _processBuffer);
      return;
    }
    _clearBuffer();
  }

  void _clearBuffer() {
    _bufferTimer?.cancel();
    _bufferTimer = null;
    _keyBuffer = '';
  }

  void sendBarcode(String barcode) {
    if (_activeScanner != null) {
      _barcodeController.add(barcode);
    }
  }

  @override
  void dispose() {
    _barcodeController.close();
    stopAllScanners();
    _bluetoothSubscription?.cancel();
    super.dispose();
  }
}