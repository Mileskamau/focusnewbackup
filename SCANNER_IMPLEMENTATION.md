# Barcode Scanner Implementation

## Overview

The Focus Supermarket POS app now includes a complete barcode scanner system supporting:
- **Phone Camera** - using mobile_scanner for continuous scanning
- **Bluetooth Scanners** - HID-capable wireless scanners
- **USB/Wired Scanners** - Keyboard emulation via OTG
- **Network Scanners** - TCP/IP connected scanners

## Architecture

### Components

1. **ScannerService** (`lib/services/scanner_service.dart`)
   - Central service managing scanner state
   - Handles keyboard input buffering for HID scanners
   - Provides barcode stream for listening
   - Manages Bluetooth discovery and TCP connections

2. **ScannerSelectionDialog** (`lib/scanner_selection_dialog.dart`)
   - Modal bottom sheet for scanner selection
   - Auto-detects available scanners
   - Shows Bluetooth devices with refresh option
   - Manual Wi-Fi configuration
   - Persists user preference

3. **CameraScannerScreen** (`lib/screens/camera_scanner/camera_scanner_screen.dart`)
   - Full-screen camera view with MobileScanner
   - Bounding box overlay for guidance
   - Torch toggle
   - Haptic feedback on scan

4. **BillingScreen** (`lib/screens/billing/billing_screen.dart`)
   - Integrated scanner button in search bar
   - Persistent scanner status indicator
   - RawKeyboardListener for HID scanner input
   - Automatic barcode-to-product lookup

## Usage

### Basic Flow

1. **Tap Scanner Button** (🔍 icon in search bar)
2. **Choose Scanner Type** (dialog appears)
   - 📷 Camera - opens camera immediately
   - 🔌 External Scanner - shows detected devices
3. **Scan Barcode** - product is auto-added to cart
4. **Visual Feedback** - snackbar confirms addition

### Scanner Selection

- **Camera** (always available): Opens camera view with bounding box
- **Bluetooth**: Lists paired BLE devices  
  - Auto-refreshes device list
  - Shows device name and ID
- **USB**: Detected wired keyboards/scanners
  - No configuration needed
  - Plug-and-play HID
- **Wi-Fi**: Manual IP:Port entry
  - Default port 9100 (common for receipt printers)
  - Persistent socket connection

## Keyboard Buffer Implementation

For USB/Bluetooth HID scanners, the app buffers keystrokes:

```dart
- Each keystroke adds to buffer
- Timer resets on each keystroke (100ms timeout)
- Enter key triggers scan submission
- Buffer cleared after submission
- Minimum 8 characters required (valid barcode length)
```

This handles both:
- Fast scanning (all keys in <100ms)
- Manual entry (time between keys >100ms resets)

## Persistence

User's last scanner selection saved to `SharedPreferences`:
- Key: `last_scanner`
- Values: `camera`, `bluetooth:XX:XX`, `usb`, `wifi:IP:PORT`
- Auto-selected on next launch

## Error Handling

### No Camera Permission
- Shows error snackbar
- User can grant from Settings

### Bluetooth Unavailable  
- Hide Bluetooth option on iOS simulator
- Show "No scanners found" message

### Scanner Disconnected
- Auto-switch to last working scanner
- Show disconnection notice

### Barcode Not Found
- Red snackbar: "Product not found: BARCODE"
- Allows manual search entry

## Dependencies

```yaml
dependencies:
  mobile_scanner: ^7.0.0        # Camera scanning
  flutter_blue_plus: ^1.32.0    # Bluetooth discovery
  usb_device: ^0.3.0            # USB detection (optional)
  shared_preferences: ^2.5.0    # Settings persistence
  provider: ^6.0.5              # State management
```

## Integration Points

### Add to Existing Screen

```dart
// In your widget
@override
Widget build(BuildContext context) {
  final scannerService = context.watch<ScannerService>();
  
  return RawKeyboardListener(
    focusNode: FocusNode(),
    onKey: (event) {
      scannerService.handleKeyEvent(event);
    },
    child: Scaffold(...),
  );
}
```

### Listen for Scanned Barcodes

```dart
// Subscribe to barcode stream
scannerService.barcodeStream.listen((barcode) {
  // Handle scanned barcode
  addProductByBarcode(barcode);
});
```

### Open Scanner Selection

```dart
showModalBottomSheet(
  context: context,
  builder: (ctx) => ScannerSelectionDialog(
    onScannerSelected: () {
      // Scanner selected callback
    },
  ),
);
```

## Performance Optimizations

1. **Duplicate Prevention**: 500ms cooldown between same barcode
2. **Background Scanning**: Services use isolates where possible
3. **Lazy Loading**: Bluetooth scan only on request
4. **Connection Pooling**: Wi-Fi socket kept alive
5. **Memory**: StreamController uses broadcast for multiple listeners

## Testing

### Manual Testing Checklist

- [ ] Camera scanner opens and scans
- [ ] Torch toggle works
- [ ] Haptic feedback on scan
- [ ] USB keyboard emulator works
- [ ] Bluetooth scanner pairs and connects
- [ ] Wi-Fi scanner TCP connection
- [ ] Scanner preference persists
- [ ] No camera permission error handled
- [ ] Barcode not found message
- [ ] Duplicate scan prevention

### Automated Tests

```dart
test('ScannerService keyboard buffer', () {
  final service = ScannerService();
  // Simulate barcode: "12345678"
  // Verify buffer processes correctly
});

test('Barcode stream emits', () {
  final service = ScannerService();
  expectLater(
    service.barcodeStream,
    emits('123456789012'),
  );
});
```

## Future Enhancements

1. **Scan History**: Recent barcodes list in selection dialog
2. **Offline Mode**: Cache scanned products locally
3. **Multi-Scanner**: Support simultaneous device types
4. **QR Codes**: Parse loyalty/customer data
5. **Sound**: Custom scan beep tones
6. **Analytics**: Scan count per session
7. **Printer Integration**: Auto-print receipt after scan

## License

Proprietary - Focus Supermarket POS