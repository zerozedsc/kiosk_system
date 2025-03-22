import '../configs/configs.dart';

import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

export 'package:permission_handler/permission_handler.dart';

class PermissionManager {
  /// Improved permission request with timeout handling
  static Future<bool> requestBluetoothPermissionsWithTimeout(
    BuildContext context, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    // Create a completer to handle the permission result
    final completer = Completer<bool>();

    // Start a timer for timeout
    Timer? timeoutTimer;
    timeoutTimer = Timer(timeout, () {
      if (!completer.isCompleted) {
        completer.complete(false);
        APP_LOGS.warning('Bluetooth permission request timed out');

        // Show timeout message if context is still valid
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Permission request timed out. Please try again.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    });

    // Request permissions in the background
    _requestPermissionsInternal(context).then((result) {
      if (!completer.isCompleted) {
        completer.complete(result);
        timeoutTimer?.cancel();
      }
    });

    return completer.future;
  }

  /// Internal method to request permissions
  static Future<bool> _requestPermissionsInternal(BuildContext context) async {
    try {
      Map<Permission, PermissionStatus> statuses;

      if (Platform.isAndroid) {
        if (await DeviceInfoPlugin().androidInfo.then(
              (info) => info.version.sdkInt,
            ) >=
            31) {
          // Android 12+ (API 31+)
          statuses =
              await [
                Permission.bluetooth,
                Permission.bluetoothScan,
                Permission.bluetoothConnect,
                Permission
                    .location, // Still needed on many devices for BLE scanning
              ].request();
        } else {
          // Below Android 12
          statuses =
              await [Permission.bluetooth, Permission.location].request();
        }
      } else if (Platform.isIOS) {
        statuses = await [Permission.bluetooth].request();
      } else {
        // Other platforms
        return false;
      }

      // Check if all permissions are granted
      bool allGranted = true;
      for (var entry in statuses.entries) {
        if (entry.value != PermissionStatus.granted) {
          allGranted = false;
          APP_LOGS.warning('Permission not granted: ${entry.key}');
          break;
        }
      }

      if (!allGranted && context.mounted) {
        // Show dialog explaining why permissions are needed
        showPermissionExplanationDialog(context);
      }

      return allGranted;
    } catch (e) {
      APP_LOGS.error('Error requesting permissions: $e');
      return false;
    }
  }

  /// Show dialog explaining permissions
  static void showPermissionExplanationDialog(BuildContext context) {
    if (context.mounted) {
      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.security, color: Colors.amber),
                  SizedBox(width: 10),
                  Text('Permissions Required'),
                ],
              ),
              content: const Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('The following permissions are required:'),
                  SizedBox(height: 8),
                  Text('• Bluetooth - to connect to thermal printers'),
                  Text(
                    '• Location - required by Android for Bluetooth scanning',
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Later'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    openAppSettings();
                  },
                  child: const Text('Open Settings'),
                ),
              ],
            ),
      );
    }
  }

  /// Check if we should request permissions again
  static Future<bool> shouldRequestBluetoothPermissions() async {
    try {
      // Get current permission statuses
      Map<Permission, PermissionStatus> statuses = {};

      if (Platform.isAndroid) {
        if (await DeviceInfoPlugin().androidInfo.then(
              (info) => info.version.sdkInt,
            ) >=
            31) {
          // Android 12+ (API 31+)
          statuses = {
            Permission.bluetooth: await Permission.bluetooth.status,
            Permission.bluetoothScan: await Permission.bluetoothScan.status,
            Permission.bluetoothConnect:
                await Permission.bluetoothConnect.status,
            Permission.location: await Permission.location.status,
          };
        } else {
          // Below Android 12
          statuses = {
            Permission.bluetooth: await Permission.bluetooth.status,
            Permission.location: await Permission.location.status,
          };
        }
      } else if (Platform.isIOS) {
        statuses = {Permission.bluetooth: await Permission.bluetooth.status};
      }

      // Check if any permission is permanently denied
      bool anyPermanentlyDenied = false;

      // Check if any permission is just denied (can be requested again)
      bool anyDenied = false;

      for (var status in statuses.values) {
        if (status == PermissionStatus.permanentlyDenied) {
          anyPermanentlyDenied = true;
        } else if (status == PermissionStatus.denied) {
          anyDenied = true;
        }
      }

      // If any permission is permanently denied, we need settings
      if (anyPermanentlyDenied) {
        return false; // Need to go to settings instead
      }

      // If any permission is just denied, we should request again
      return anyDenied;
    } catch (e) {
      APP_LOGS.error('Error checking permission status: $e');
      return false;
    }
  }

  /// Check if we need to direct user to settings
  static Future<bool> needOpenSettings() async {
    try {
      // Get current permission statuses
      Map<Permission, PermissionStatus> statuses = {};

      if (Platform.isAndroid) {
        if (await DeviceInfoPlugin().androidInfo.then(
              (info) => info.version.sdkInt,
            ) >=
            31) {
          statuses = {
            Permission.bluetooth: await Permission.bluetooth.status,
            Permission.bluetoothScan: await Permission.bluetoothScan.status,
            Permission.bluetoothConnect:
                await Permission.bluetoothConnect.status,
            Permission.location: await Permission.location.status,
          };
        } else {
          statuses = {
            Permission.bluetooth: await Permission.bluetooth.status,
            Permission.location: await Permission.location.status,
          };
        }
      } else if (Platform.isIOS) {
        statuses = {Permission.bluetooth: await Permission.bluetooth.status};
      }

      // Check if any permission is permanently denied
      for (var status in statuses.values) {
        if (status == PermissionStatus.permanentlyDenied) {
          return true; // Need to go to settings
        }
      }

      return false;
    } catch (e) {
      APP_LOGS.error('Error checking permission status: $e');
      return false;
    }
  }
}
