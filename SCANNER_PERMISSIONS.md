# Barcode Scanner Permissions Setup

## Android

### 1. Camera Permission (`AndroidManifest.xml`)
Add to `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.BLUETOOTH" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />

<!-- For Android 12+ (API 31+) -->
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" android:usesPermissionFlags="neverForLocation" />
```

Inside `<application>` tag, add:
```xml
<meta-data
    android:name="flutterEmbedding"
    android:value="2" />
```

### 2. USB Host Mode (Optional)
For USB OTG scanner support:

```xml
<uses-feature android:name="android.hardware.usb.host" />
```

### 3. Minimum SDK Version
In `android/app/build.gradle`, ensure:

```gradle
minSdkVersion 21
targetSdkVersion 33
```

## iOS

### 1. Camera Usage Description (`Info.plist`)
Add to `ios/Runner/Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>We need camera access to scan product barcodes</string>
<key>NSBluetoothAlwaysUsageDescription</key>
<string>We need Bluetooth access to connect external scanners</string>
<key>NSBluetoothPeripheralUsageDescription</key>
<string>We need Bluetooth access to connect external scanners</string>
<key>UIBackgroundModes</key>
<array>
    <string>external-accessory</string>
    <string>bluetooth-central</string>
</array>
```

## Web (Optional)

For web deployment, camera access requires HTTPS in production.

## Testing Permissions

### Android:
```bash
adb shell pm grant com.your.package android.permission.CAMERA
adb shell pm grant com.your.package android.permission.BLUETOOTH_SCAN
```

### iOS Simulator:
- Camera: Use "Features > Camera" menu to simulate
- Bluetooth: External device required (simulator doesn't emulate BLE)

## Permission Request Flow

The app handles permission requests gracefully:

1. **First launch**: User is prompted for camera permission when opening scanner
2. **Denied permission**: Shows error message with option to open app settings
3. **Bluetooth**: Requested when user selects Bluetooth scanner option

## External Scanner Types

### USB (Wired)
- No special permissions needed (acts as HID keyboard)
- Just plug in via OTG cable
- Input appears as keyboard keystrokes

### Bluetooth (Wireless)
- Requires `BLUETOOTH_SCAN` and `BLUETOOTH_CONNECT` permissions
- Scanner must be paired in system settings first
- App discovers and connects to HID-capable scanners

### Network/WiFi
- No special permissions
- Scanner must be on same network
- Configure IP address in scanner selection dialog

## Troubleshooting

### Camera not working
- Check permission in Settings > Apps > Focus Supermarket > Permissions
- Ensure no other app is using camera
- Restart the app

### Bluetooth scanner not found
- Ensure scanner is in pairing mode
- Check system Bluetooth settings (must be paired)
- Verify scanner supports HID profile
- Check location permission (required for BLE on Android)

### USB scanner not recognized
- Use high-quality OTG cable
- Check USB device compatibility
- Ensure USB debugging is not conflicting
- Try different USB port