import "../../configs/configs.dart";
import "../../components/toastmsg.dart";

import 'package:smart_usb/smart_usb.dart';
import 'package:usb_serial/usb_serial.dart' as serial;

/// Request and check permissions for USB access, then initialize the USB manager
Future<void> checkPermissionsAndInitUsb(BuildContext context) async {
  // Read permission status from preferences
  final prefs = await SharedPreferences.getInstance();
  bool permissionsChecked = prefs.getBool('usb_permissions_checked') ?? false;
  bool mounted = context.mounted;

  if (!permissionsChecked) {
    // First show a dialog explaining why we need permissions
    if (mounted) {
      bool userWantsToProceed =
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder:
                (context) => AlertDialog(
                  title: Row(
                    children: [
                      Icon(Icons.usb, color: primaryColor),
                      const SizedBox(width: 10),
                      Text(LOCALIZATION.localize("usb_service.permission")),
                    ],
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        LOCALIZATION.localize("usb_service.permission_message"),
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        LOCALIZATION.localize(
                          "usb_service.grant_required_permissions",
                        ),
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: Text(LOCALIZATION.localize("main_word.skip")),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: Text(LOCALIZATION.localize("main_word.continue")),
                    ),
                  ],
                ),
          ) ??
          false;

      // Remember that we've checked permissions regardless of user choice
      await prefs.setBool('usb_permissions_checked', true);

      if (userWantsToProceed) {
        // Initialize USB manager with context to request permissions
        UsbManager.init(context: context).then((manager) {
          USB = manager;
          APP_LOGS.info('USB Manager initialized with permissions dialog');
        });
      } else {
        // User skipped permissions, initialize without context
        UsbManager.init().then((manager) {
          USB = manager;
          APP_LOGS.info('USB Manager initialized without permissions dialog');
        });
      }
    }
  } else {
    // Not first launch, just initialize USB manager as usual
    UsbManager.init().then((manager) {
      USB = manager;
      APP_LOGS.info('USB Manager initialized on subsequent launch');
    });
  }
}

/// UsbManager provides functionality for interacting with USB devices,
/// particularly for managing cash drawers in kiosk systems.
class UsbManager {
  // Singleton pattern implementation
  static UsbManager? _instance;

  // USB device information
  List<Map<String, dynamic>> _usbDevices = [];
  Map<String, dynamic>? _selectedDevice;
  bool _isInitialized = false;

  // Cash drawer related constants
  static const int VENDOR_ID_GENERIC_DRAWER =
      0x0123; // Example generic drawer vendor ID
  static const int PRODUCT_ID_GENERIC_DRAWER =
      0x3210; // Example generic drawer product ID
  // In your UsbManager class
  static const String USB_PERMISSION_ACTION =
      "com.example.smart_usb.USB_PERMISSION";

  // Cash drawer command bytes - with specific options for different drawer types
  Map<String, List<int>> CASH_DRAWER_COMMANDS = {
    // Standard ESC/POS command (generic)
    'standard': [0x1B, 0x70, 0x00, 0x19, 0xFA, 0x00], // ESC p 0 25 250 0
    // Longer pulse duration for Prolific
    'prolific': [
      0x1B,
      0x70,
      0x00,
      0x30,
      0x30,
      0x00,
    ], // ESC p 0 48 48 0 - longer pulse
    // Alternative approaches for Prolific
    'prolific_alt1': [0x1B, 0x07], // ESC BEL - simple bell command
    'prolific_alt2': [0x07], // BEL - direct bell character
    'prolific_alt3': [
      0x10,
      0x14,
      0x01,
      0x00,
      0x01,
    ], // DLE DC4 - alternative command
    'prolific_alt4': [
      0x1B,
      0x70,
      0x01,
      0x32,
      0x50,
      0x00,
    ], // ESC p 1 50 80 0 - pin 1, longer pulse
    // Raw serial control codes
    'serial_rts': [0xFF, 0x02, 0x01], // Special code to toggle RTS
    'serial_dtr': [0xFF, 0x01, 0x01], // Special code to toggle DTR
  };

  // Factory constructor that returns singleton instance
  factory UsbManager() {
    _instance ??= UsbManager._internal();
    return _instance!;
  }

  // Private constructor for singleton pattern
  UsbManager._internal();

  /// Gets the list of discovered USB devices
  List<Map<String, dynamic>> get usbDevices => _usbDevices;

  /// Gets the currently selected USB device
  Map<String, dynamic>? get selectedDevice => _selectedDevice;

  /// Returns if the USB manager is initialized
  bool get isInitialized => _isInitialized;

  /// Initialize the USB manager and request necessary permissions
  static Future<UsbManager> init({BuildContext? context}) async {
    if (_instance == null) {
      _instance = UsbManager._internal();

      try {
        // Initialize SmartUsb library
        await SmartUsb.init();
        APP_LOGS.info('SmartUsb initialized successfully');

        // Set automatic kernel driver detachment (Linux only, no-op on other platforms)
        await SmartUsb.setAutoDetachKernelDriver(true);

        // Check if we have USB permission
        if (context != null) {
          // Call the class method, not the standalone function
          await _instance!._checkAndRequestUsbPermission(context);
        }

        // Discover devices regardless of permission status
        await _instance!._discoverUsbDevices();

        _instance!._isInitialized = true;
        APP_LOGS.info('USB Manager initialized successfully');
      } catch (e) {
        APP_LOGS.error(
          'Failed to initialize USB Manager',
          e,
          StackTrace.current,
        );
      }
    }

    return _instance!;
  }

  /// Check for USB permission and request if needed
  Future<bool> _checkAndRequestUsbPermission(BuildContext context) async {
    try {
      // Get the device list first without requesting permission
      final devices = await SmartUsb.getDevicesWithDescription(
        requestPermission: false,
      );

      if (devices.isEmpty) {
        APP_LOGS.info('No USB devices found to request permissions for');
        return true; // No devices, no permissions needed
      }

      // Show a dialog explaining why we need USB permission
      bool shouldRequest =
          await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext dialogContext) {
              return AlertDialog(
                title: Row(
                  children: [
                    Icon(Icons.usb, color: primaryColor),
                    const SizedBox(width: 10),
                    Text(LOCALIZATION.localize("usb_service.permission")),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      LOCALIZATION.localize("usb_service.permission_message"),
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      LOCALIZATION.localize(
                        "usb_service.grant_required_permissions",
                      ),
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    child: Text(LOCALIZATION.localize("main_word.skip")),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                    child: Text(LOCALIZATION.localize("main_word.continue")),
                  ),
                ],
              );
            },
          ) ??
          false;

      if (shouldRequest) {
        // Request permissions for each device with robust error handling
        bool allPermissionsGranted = true;
        for (var deviceDesc in devices) {
          try {
            var device = deviceDesc.device;

            // Add a try-catch specifically around the permission request
            try {
              bool hasPermission = await SmartUsb.requestPermission(device);
              if (!hasPermission) {
                allPermissionsGranted = false;
                APP_LOGS.warning(
                  'Permission denied for device ${device.identifier}',
                );
              }
            } catch (e) {
              // This will now properly catch the exception from the broadcast receiver
              APP_LOGS.error(
                'Error requesting USB permission: $e',
                e,
                StackTrace.current,
              );
              allPermissionsGranted = false;
            }
          } catch (e) {
            APP_LOGS.error('Error accessing device: $e', e, StackTrace.current);
            allPermissionsGranted = false;
          }
        }

        return allPermissionsGranted;
      }

      return false;
    } catch (e) {
      APP_LOGS.error(
        'Error in USB permission request process',
        e,
        StackTrace.current,
      );
      return false;
    }
  }

  /// Discover all connected USB devices
  Future<List<Map<String, dynamic>>> _discoverUsbDevices() async {
    try {
      // Get the list of connected USB devices with descriptions
      final deviceDescriptions = await SmartUsb.getDevicesWithDescription();

      _usbDevices = []; // Clear existing devices

      for (var deviceDesc in deviceDescriptions) {
        var device = deviceDesc.device;

        // Extract device information into a structured Map
        Map<String, dynamic> deviceInfo = {
          'deviceName': "${deviceDesc.device}" ?? 'Unknown Device',
          'deviceId': device.identifier,
          'vendorId': device.vendorId,
          'productId': device.productId,
          'manufacturerName': deviceDesc.manufacturer ?? 'Unknown Manufacturer',
          'productName': deviceDesc.product ?? 'Unknown Product',
          'serialNumber': deviceDesc.serialNumber ?? 'N/A',
          'isConnected': false,
          'isCashDrawer': _isCashDrawer(device.vendorId, device.productId),
          'device': device, // Store the raw device object for direct API calls
        };

        _usbDevices.add(deviceInfo);
      }

      APP_LOGS.info('Discovered ${_usbDevices.length} USB devices');
      return _usbDevices;
    } catch (e) {
      APP_LOGS.error('Error discovering USB devices', e, StackTrace.current);
      return [];
    }
  }

  /// Check if the device is potentially a cash drawer based on vendor/product IDs
  bool _isCashDrawer(int vendorId, int productId) {
    // This is a simplified check - might need to be expanded for different drawer types
    if (vendorId == VENDOR_ID_GENERIC_DRAWER &&
        productId == PRODUCT_ID_GENERIC_DRAWER) {
      return true;
    }

    // Additional known cash drawer vendor/product ID combinations
    // Add more matches based on your hardware
    List<Map<String, int>> knownDrawers = [
      {'vendorId': 0x04b8, 'productId': 0x0202}, // Epson
      {
        'vendorId': 0x067b,
        'productId': 0x2303,
      }, // Prolific (often used for serial-USB drawers)
      {'vendorId': 0x0557, 'productId': 0x2008}, // ATEN
      // Add more as you discover them
    ];

    for (var drawer in knownDrawers) {
      if (vendorId == drawer['vendorId'] && productId == drawer['productId']) {
        return true;
      }
    }

    // Check for generic POS devices that might include cash drawer functionality
    List<int> posVendorIds = [0x04b8, 0x067b, 0x0557, 0x1504, 0x0519, 0x0dd4];
    if (posVendorIds.contains(vendorId)) {
      return true; // Potentially a POS device with cash drawer support
    }

    return false;
  }

  /// Refresh the list of connected USB devices
  Future<List<Map<String, dynamic>>> refreshDeviceList() async {
    return await _discoverUsbDevices();
  }

  /// Check if a specific USB device is connected by vendor and product ID
  Future<bool> isDeviceConnected(int vendorId, int productId) async {
    try {
      // First refresh the device list to ensure it's current
      await refreshDeviceList();

      // Check if any device matches the criteria
      return _usbDevices.any(
        (device) =>
            device['vendorId'] == vendorId && device['productId'] == productId,
      );
    } catch (e) {
      APP_LOGS.error(
        'Error checking if device is connected',
        e,
        StackTrace.current,
      );
      return false;
    }
  }

  /// Connect to a USB device by device ID
  Future<bool> connectToDevice(dynamic deviceId) async {
    try {
      // Find the device in our list
      int index = _usbDevices.indexWhere(
        (device) => device['deviceId'] == deviceId,
      );

      if (index == -1) {
        APP_LOGS.warning('Device with ID $deviceId not found');
        return false;
      }

      // Get the raw device object
      var device = _usbDevices[index]['device'];

      // Request connection to the device
      bool connected = await SmartUsb.connectDevice(device);

      if (connected) {
        bool opened = await SmartUsb.openDevice(device);
        if (!opened) {
          APP_LOGS.warning(
            'Connected to device but failed to open it: $deviceId',
          );
          return false;
        }

        // Update our internal state
        _usbDevices[index]['isConnected'] = true;
        _selectedDevice = _usbDevices[index];
        APP_LOGS.info(
          'Connected to USB device: ${_selectedDevice!['deviceName']}',
        );
      } else {
        APP_LOGS.warning('Failed to connect to USB device with ID $deviceId');
      }

      return connected;
    } catch (e) {
      APP_LOGS.error('Error connecting to USB device', e, StackTrace.current);
      return false;
    }
  }

  /// Disconnect from the current USB device
  Future<bool> disconnectDevice() async {
    if (_selectedDevice == null) {
      return true; // Already disconnected
    }

    try {
      // Close the USB connection
      await SmartUsb.closeDevice();

      // Update our device list
      int index = _usbDevices.indexWhere(
        (device) => device['deviceId'] == _selectedDevice!['deviceId'],
      );

      if (index != -1) {
        _usbDevices[index]['isConnected'] = false;
      }

      _selectedDevice = null;
      APP_LOGS.info('Disconnected from USB device');
      return true;
    } catch (e) {
      APP_LOGS.error(
        'Error disconnecting from USB device',
        e,
        StackTrace.current,
      );
      return false;
    }
  }

  /// Check if any cash drawer is connected
  Future<bool> isCashDrawerConnected() async {
    try {
      await refreshDeviceList();
      return _usbDevices.any((device) => device['isCashDrawer'] == true);
    } catch (e) {
      APP_LOGS.error('Error checking for cash drawer', e, StackTrace.current);
      return false;
    }
  }

  /// Open cash drawer using usb_serial directly (for Prolific adapters)
  Future<(bool, List<int>)> openCashDrawerWithUsbSerial() async {
    const String fn = 'openCashDrawerWithUsbSerial';
    final List<int> bellCommand = [0x07]; // Simple bell character (^G)

    try {
      // Get available devices from usb_serial package
      List<serial.UsbDevice> devices = await serial.UsbSerial.listDevices();
      APP_LOGS.info('[$fn] Available USB serial devices: ${devices.length}');

      if (devices.isEmpty) {
        APP_LOGS.warning('[$fn] No USB serial devices available');
        return (false, bellCommand);
      }

      // Find the Prolific device (VID:PID 067B:2303)
      serial.UsbDevice? prolificDevice;
      for (var device in devices) {
        APP_LOGS.info('[$fn] Found device: ${device.vid}:${device.pid}');
        if (device.vid == 0x067b && device.pid == 0x2303) {
          prolificDevice = device;
          APP_LOGS.info('[$fn] Found Prolific device');
          break;
        }
      }

      if (prolificDevice == null) {
        APP_LOGS.warning('[$fn] No Prolific adapter found');
        return (false, bellCommand);
      }

      // Open a connection to the device
      APP_LOGS.info('[$fn] Opening connection to Prolific device');
      serial.UsbPort? port = await prolificDevice.create();

      if (port == null) {
        APP_LOGS.error('[$fn] Failed to create port for Prolific device');
        return (false, bellCommand);
      }

      // Open the port
      bool opened = await port.open();
      if (!opened) {
        APP_LOGS.error('[$fn] Failed to open port');
        return (false, bellCommand);
      }

      try {
        // Configure serial port parameters (9600 baud, 8N1)
        await port.setPortParameters(
          9600, // baud rate
          serial.UsbPort.DATABITS_8, // data bits
          serial.UsbPort.STOPBITS_1, // stop bits
          serial.UsbPort.PARITY_NONE, // parity
        );

        APP_LOGS.info('[$fn] Port configured successfully');

        // Try multiple approaches with error handling

        // 1. Send the bell character (^G / 0x07) - simple approach like your Windows batch file
        APP_LOGS.info('[$fn] Sending bell character');
        try {
          await port.write(Uint8List.fromList(bellCommand));
          APP_LOGS.info('[$fn] Sent bell character successfully');
          await port.close();
          return (true, bellCommand);
        } catch (e) {
          APP_LOGS.warning('[$fn] Failed to send bell character: $e');
          // Continue to next approach
        }

        // 2. Try ESC/POS drawer kick command
        APP_LOGS.info('[$fn] Trying ESC/POS command');
        try {
          final escPosCommand = Uint8List.fromList([
            0x1B,
            0x70,
            0x00,
            0x19,
            0xFA,
            0x00,
          ]);
          await port.write(escPosCommand);
          APP_LOGS.info('[$fn] Sent ESC/POS command successfully');
          await port.close();
          return (true, [0x1B, 0x70, 0x00, 0x19, 0xFA, 0x00]);
        } catch (e) {
          APP_LOGS.warning('[$fn] Failed to send ESC/POS command: $e');
          // Continue to next approach
        }

        // 3. Try longer pulse ESC/POS drawer kick command
        APP_LOGS.info('[$fn] Trying longer pulse ESC/POS command');
        try {
          final longerPulseCommand = Uint8List.fromList([
            0x1B,
            0x70,
            0x00,
            0x30,
            0x30,
            0x00,
          ]);
          await port.write(longerPulseCommand);
          APP_LOGS.info('[$fn] Sent longer pulse ESC/POS command successfully');
          await port.close();
          return (true, [0x1B, 0x70, 0x00, 0x30, 0x30, 0x00]);
        } catch (e) {
          APP_LOGS.warning(
            '[$fn] Failed to send longer pulse ESC/POS command: $e',
          );
          // Continue to next approach
        }

        // 4. Try DTR/RTS control (usb_serial has special methods for this)
        APP_LOGS.info('[$fn] Trying DTR/RTS control');
        try {
          // Set DTR high
          await port.setDTR(true);
          APP_LOGS.info('[$fn] Set DTR high');
          await Future.delayed(const Duration(milliseconds: 200));

          // Set DTR low
          await port.setDTR(false);
          APP_LOGS.info('[$fn] Set DTR low');

          // Set RTS high
          await port.setRTS(true);
          APP_LOGS.info('[$fn] Set RTS high');
          await Future.delayed(const Duration(milliseconds: 200));

          // Set RTS low
          await port.setRTS(false);
          APP_LOGS.info('[$fn] Set RTS low');

          APP_LOGS.info('[$fn] DTR/RTS control completed');
          await port.close();
          return (true, [0xF1, 0xF2]); // Special code for DTR/RTS toggle
        } catch (e) {
          APP_LOGS.warning('[$fn] Failed to control DTR/RTS: $e');
        }

        // If we get here, all approaches failed
        await port.close();
        return (false, bellCommand);
      } catch (e) {
        APP_LOGS.error('[$fn] Error controlling serial port: $e');
        try {
          await port.close();
        } catch (closeError) {
          // Ignore errors on close
        }
        return (false, bellCommand);
      }
    } catch (e) {
      APP_LOGS.error('[$fn] USB Serial error: $e');
      return (false, bellCommand);
    }
  }

  /// Open the cash drawer (if connected)
  Future<(bool, List<int>)> openCashDrawer() async {
    const String fn = 'openCashDrawer';

    try {
      // First check if we have a cash drawer
      bool hasCashDrawer = await isCashDrawerConnected();

      if (!hasCashDrawer) {
        APP_LOGS.warning('[$fn] No cash drawer detected');
        return (false, [0]);
      }

      // Find the first cash drawer device
      Map<String, dynamic>? cashDrawer;
      try {
        cashDrawer = _usbDevices.firstWhere(
          (device) => device['isCashDrawer'] == true,
        );
      } catch (e) {
        APP_LOGS.warning('[$fn] No cash drawer found in device list');
        return (false, [0]);
      }

      // Check if it's a Prolific adapter
      bool isProlific =
          cashDrawer['vendorId'] == 0x067b && cashDrawer['productId'] == 0x2303;

      if (isProlific) {
        // For Prolific adapters, try both approaches (usb_serial first, then libserialport as fallback)
        APP_LOGS.info(
          '[$fn] Detected Prolific adapter, using USB Serial approach',
        );
        var result = await openCashDrawerWithUsbSerial();

        return result;
      }

      // For non-Prolific devices, use the standard USB approach
      // Connect to the cash drawer if not already connected
      bool isConnected = cashDrawer['isConnected'] ?? false;
      if (!isConnected) {
        isConnected = await connectToDevice(cashDrawer['deviceId']);
        if (!isConnected) {
          APP_LOGS.warning('[$fn] Failed to connect to cash drawer');
          return (false, [0]);
        }
      }

      // Try multiple commands for standard devices
      List<List<int>> standardCommands = [
        CASH_DRAWER_COMMANDS['standard']!,
        CASH_DRAWER_COMMANDS['prolific_alt1']!,
        CASH_DRAWER_COMMANDS['prolific_alt2']!,
      ];

      for (var command in standardCommands) {
        try {
          APP_LOGS.info('[$fn] Trying standard command: $command');
          bool success = await SmartUsb.send(command);

          if (success) {
            APP_LOGS.info('[$fn] Cash drawer command sent successfully');
            return (true, command);
          }

          // Wait a moment before trying the next command
          await Future.delayed(const Duration(milliseconds: 100));
        } catch (e) {
          APP_LOGS.warning('[$fn] Command failed: $e');
          // Continue to next command
        }
      }

      APP_LOGS.warning('[$fn] All standard commands failed');
      return (false, standardCommands.first);
    } catch (e) {
      APP_LOGS.error('[$fn] Error opening cash drawer', e, StackTrace.current);
      return (false, [0]);
    }
  }

  /// Send custom data to a USB device
  Future<bool> sendDataToDevice(List<int> data) async {
    if (_selectedDevice == null) {
      APP_LOGS.warning('No device selected for sending data');
      return false;
    }

    try {
      // Connect to the device if not already connected
      bool isConnected = _selectedDevice!['isConnected'] ?? false;
      if (!isConnected) {
        isConnected = await connectToDevice(_selectedDevice!['deviceId']);
        if (!isConnected) {
          APP_LOGS.warning('Failed to connect to device for sending data');
          return false;
        }
      }

      // Send data to device as List<int>
      bool success = await SmartUsb.send(data);

      if (success) {
        APP_LOGS.info('Data sent to USB device successfully');
      } else {
        APP_LOGS.warning('Failed to send data to USB device');
      }

      return success;
    } catch (e) {
      APP_LOGS.error('Error sending data to USB device', e, StackTrace.current);
      return false;
    }
  }

  /// Cleanup and release resources
  Future<void> dispose() async {
    try {
      // Close the device if one is connected
      if (_selectedDevice != null && _selectedDevice!['isConnected']) {
        await SmartUsb.closeDevice();
      }

      // Exit the SmartUsb library
      await SmartUsb.exit();

      _selectedDevice = null;
      _usbDevices = [];
      _isInitialized = false;

      APP_LOGS.info('USB Manager resources released');
    } catch (e) {
      APP_LOGS.error('Error disposing USB Manager', e, StackTrace.current);
    }
  }

  /// Show a dialog to manage USB devices
  Future<Map<String, dynamic>?> showUsbManagementDialog(
    BuildContext context,
  ) async {
    // Refresh the device list before showing dialog
    await refreshDeviceList();

    final completer = Completer<Map<String, dynamic>?>();
    Map<String, dynamic>? selectedDeviceInDialog = _selectedDevice;
    bool isTestingDrawer = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.usb, color: primaryColor),
                  const SizedBox(width: 8),
                  Text(
                    'USB ${LOCALIZATION.localize("main_word.devices")} (${_usbDevices.length})',
                  ),
                ],
              ),
              content: Container(
                width: double.maxFinite,
                height: 400,
                child: Column(
                  children: [
                    // Refresh button
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.refresh),
                            label: Text(
                              LOCALIZATION.localize(
                                "usb_service.refresh_devices",
                              ),
                            ),
                            onPressed: () async {
                              setState(() => isTestingDrawer = true);
                              await refreshDeviceList();
                              setState(() => isTestingDrawer = false);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Test cash drawer button
                        ElevatedButton.icon(
                          icon:
                              isTestingDrawer
                                  ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                  : const Icon(Icons.point_of_sale),
                          label: Text(
                            LOCALIZATION.localize(
                              "usb_service.test_cash_drawer",
                            ),
                          ),
                          onPressed:
                              isTestingDrawer
                                  ? null
                                  : () async {
                                    setState(() => isTestingDrawer = true);

                                    bool drawerExists =
                                        await isCashDrawerConnected();
                                    if (!drawerExists) {
                                      if (context.mounted) {
                                        showToastMessage(
                                          context,
                                          LOCALIZATION.localize(
                                            "usb_service.no_cash_drawer",
                                          ),
                                          ToastLevel.warning,
                                        );
                                      }
                                    } else {
                                      var result = await openCashDrawer();
                                      bool opened =
                                          result
                                              .$1; // Get the boolean from the tuple

                                      if (context.mounted) {
                                        showToastMessage(
                                          context,
                                          opened
                                              ? LOCALIZATION.localize(
                                                "usb_service.drawer_opened command:${result.$2}",
                                              )
                                              : LOCALIZATION.localize(
                                                "usb_service.drawer_failed command:${result.$2}",
                                              ),
                                          opened
                                              ? ToastLevel.success
                                              : ToastLevel.error,
                                        );
                                      }
                                    }

                                    setState(() => isTestingDrawer = false);
                                  },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Device list header
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Text(
                              LOCALIZATION.localize("usb_service.device_name"),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              "VID:PID",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              LOCALIZATION.localize("usb_service.type"),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 60),
                        ],
                      ),
                    ),

                    // Device list
                    Expanded(
                      child:
                          _usbDevices.isEmpty
                              ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.usb_off,
                                      size: 48,
                                      color: Colors.grey.shade400,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      LOCALIZATION.localize(
                                        "usb_service.no_devices",
                                      ),
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                              : ListView.builder(
                                itemCount: _usbDevices.length,
                                itemBuilder: (context, index) {
                                  final device = _usbDevices[index];
                                  final bool isSelected =
                                      selectedDeviceInDialog != null &&
                                      selectedDeviceInDialog!['deviceId'] ==
                                          device['deviceId'];

                                  return Card(
                                    margin: const EdgeInsets.symmetric(
                                      vertical: 4,
                                    ),
                                    color:
                                        isSelected
                                            ? primaryColor.withOpacity(0.1)
                                            : null,
                                    elevation: isSelected ? 2 : 1,
                                    child: InkWell(
                                      onTap: () {
                                        setState(() {
                                          selectedDeviceInDialog = device;
                                        });
                                      },
                                      borderRadius: BorderRadius.circular(4),
                                      child: Padding(
                                        padding: const EdgeInsets.all(12.0),
                                        child: Row(
                                          children: [
                                            // Device icon
                                            Icon(
                                              device['isCashDrawer']
                                                  ? Icons.point_of_sale
                                                  : Icons.usb,
                                              color:
                                                  isSelected
                                                      ? primaryColor
                                                      : device['isCashDrawer']
                                                      ? Colors.green
                                                      : Colors.blue,
                                            ),
                                            const SizedBox(width: 8),

                                            // Device name
                                            Expanded(
                                              flex: 2,
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    device['deviceName'] ??
                                                        'Unknown Device',
                                                    style: TextStyle(
                                                      fontWeight:
                                                          isSelected
                                                              ? FontWeight.bold
                                                              : FontWeight
                                                                  .normal,
                                                    ),
                                                  ),
                                                  Text(
                                                    device['manufacturerName'] ??
                                                        'Unknown Manufacturer',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color:
                                                          Colors.grey.shade600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),

                                            // VID:PID
                                            Expanded(
                                              child: Text(
                                                "${device['vendorId'].toRadixString(16).padLeft(4, '0')}:${device['productId'].toRadixString(16).padLeft(4, '0')}",
                                                style: TextStyle(
                                                  fontFamily: 'monospace',
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),

                                            // Device type
                                            Expanded(
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color:
                                                      device['isCashDrawer']
                                                          ? Colors.green
                                                              .withOpacity(0.1)
                                                          : Colors.blue
                                                              .withOpacity(0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  device['isCashDrawer']
                                                      ? LOCALIZATION.localize(
                                                        "usb_service.cash_drawer",
                                                      )
                                                      : LOCALIZATION.localize(
                                                        "usb_service.device",
                                                      ),
                                                  style: TextStyle(
                                                    color:
                                                        device['isCashDrawer']
                                                            ? Colors.green
                                                            : Colors.blue,
                                                    fontSize: 12,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                              ),
                                            ),

                                            // Connect button
                                            SizedBox(
                                              width: 60,
                                              child:
                                                  isSelected
                                                      ? Icon(
                                                        Icons.check_circle,
                                                        color: primaryColor,
                                                      )
                                                      : IconButton(
                                                        icon: const Icon(
                                                          Icons.link,
                                                        ),
                                                        color: Colors.grey,
                                                        onPressed: () {
                                                          setState(() {
                                                            selectedDeviceInDialog =
                                                                device;
                                                          });
                                                        },
                                                      ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                    ),

                    // Device details section
                    if (selectedDeviceInDialog != null)
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              LOCALIZATION.localize(
                                "usb_service.device_details",
                              ),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const Divider(),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "ID: ${selectedDeviceInDialog!['deviceId']}",
                                      ),
                                      if (selectedDeviceInDialog!['serialNumber'] !=
                                              null &&
                                          selectedDeviceInDialog!['serialNumber'] !=
                                              'N/A')
                                        Text(
                                          "S/N: ${selectedDeviceInDialog!['serialNumber']}",
                                        ),
                                      Text(
                                        "Product: ${selectedDeviceInDialog!['productName'] ?? 'N/A'}",
                                      ),
                                    ],
                                  ),
                                ),
                                if (selectedDeviceInDialog!['isCashDrawer']) ...[
                                  ElevatedButton.icon(
                                    icon: const Icon(
                                      Icons.point_of_sale,
                                      size: 18,
                                    ),
                                    label: Text(
                                      LOCALIZATION.localize(
                                        "usb_service.open_drawer",
                                      ),
                                    ),
                                    onPressed:
                                        isTestingDrawer
                                            ? null
                                            : () async {
                                              setState(
                                                () => isTestingDrawer = true,
                                              );
                                              await connectToDevice(
                                                selectedDeviceInDialog!['deviceId'],
                                              );
                                              var result =
                                                  await openCashDrawer();
                                              bool opened =
                                                  result
                                                      .$1; // Access the boolean from the tuple

                                              if (context.mounted) {
                                                showToastMessage(
                                                  context,
                                                  opened
                                                      ? LOCALIZATION.localize(
                                                        "usb_service.drawer_opened command:${result.$2}",
                                                      )
                                                      : LOCALIZATION.localize(
                                                        "usb_service.drawer_failed command:${result.$2}",
                                                      ),
                                                  opened
                                                      ? ToastLevel.success
                                                      : ToastLevel.error,
                                                );
                                              }
                                              setState(
                                                () => isTestingDrawer = false,
                                              );
                                            },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    completer.complete(null);
                  },
                  child: Text(LOCALIZATION.localize("main_word.cancel")),
                ),
                ElevatedButton(
                  onPressed:
                      selectedDeviceInDialog != null
                          ? () async {
                            bool connected = await connectToDevice(
                              selectedDeviceInDialog!['deviceId'],
                            );

                            if (connected) {
                              Navigator.pop(context);
                              completer.complete(selectedDeviceInDialog);
                            } else {
                              if (context.mounted) {
                                showToastMessage(
                                  context,
                                  LOCALIZATION.localize(
                                    "usb_service.connection_failed",
                                  ),
                                  ToastLevel.error,
                                );
                              }
                            }
                          }
                          : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                  ),
                  child: Text(LOCALIZATION.localize("main_word.select")),
                ),
              ],
            );
          },
        );
      },
    );

    return completer.future;
  }
}
