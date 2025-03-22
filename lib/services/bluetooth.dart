import '../configs/configs.dart';

import '../services/permission_handler.dart';

import '../components/toastmsg.dart';
import '../components/image.dart';

import 'package:bluetooth_print_plus/bluetooth_print_plus.dart' as bpp;
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;
import 'package:synchronized/synchronized.dart';

// Add these properties to the BtPrinter class
final Queue<_BluetoothOperation> _operationQueue = Queue<_BluetoothOperation>();
final Lock _operationLock = Lock();
bool _processingQueue = false;
bool _permissionsRequested =
    false; // Track if we already requested permissions in this session

// Add this class inside or outside the BtPrinter class
class _BluetoothOperation {
  final Future<dynamic> Function() operation;
  final Completer<dynamic> completer;

  _BluetoothOperation(this.operation, this.completer);
}

// Add this method to queue operations
Future<T> queueOperation<T>(Future<T> Function() operation) {
  final completer = Completer<T>();
  _operationQueue.add(_BluetoothOperation(operation, completer));
  _processOperationQueue();
  return completer.future;
}

// Process the operation queue
void _processOperationQueue() async {
  // Use lock to ensure only one thread processes the queue
  await _operationLock.synchronized(() async {
    if (_processingQueue || _operationQueue.isEmpty) return;

    _processingQueue = true;

    while (_operationQueue.isNotEmpty) {
      final operation = _operationQueue.removeFirst();
      try {
        final result = await operation.operation();
        if (!operation.completer.isCompleted) {
          operation.completer.complete(result);
        }
      } catch (e) {
        if (!operation.completer.isCompleted) {
          operation.completer.completeError(e);
        }
      }

      // Small delay between operations
      await Future.delayed(const Duration(milliseconds: 500));
    }

    _processingQueue = false;
  });
}

Future<void> checkPermissionsAndInitBluetooth(BuildContext context) async {
  if (_permissionsRequested) return; // Already requested in this session
  _permissionsRequested = true;

  // Read permission status from preferences
  final prefs = await SharedPreferences.getInstance();
  bool permissionsChecked = prefs.getBool('permissions_checked') ?? false;

  // If we need to request permissions
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
                      Icon(Icons.bluetooth, color: primaryColor),
                      const SizedBox(width: 10),
                      const Text('Bluetooth Permissions'),
                    ],
                  ),
                  content: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'This app needs Bluetooth permissions to connect to receipt printers.',
                        style: TextStyle(fontSize: 16),
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Please grant all requested permissions on the next screens to ensure proper functionality.',
                        style: TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Skip'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Continue'),
                    ),
                  ],
                ),
          ) ??
          false;

      if (userWantsToProceed) {
        // Request permissions with timeout
        bool granted =
            await PermissionManager.requestBluetoothPermissionsWithTimeout(
              context,
              timeout: const Duration(seconds: 60),
            );

        // Remember that we've checked permissions
        await prefs.setBool('permissions_checked', true);

        // Initialize Bluetooth regardless of permission result
        BtPrinter.init(continueWithoutBluetooth: true).then((printer) {
          btPrinter = printer;

          // If permission was denied, show settings dialog
          if (!granted && mounted) {
            // Wait a bit before showing another dialog
            Future.delayed(const Duration(seconds: 1), () {
              showDialog(
                context: context,
                builder:
                    (context) => AlertDialog(
                      title: const Text('Permissions Required'),
                      content: const Text(
                        'Bluetooth permissions are required for printing receipts. '
                        'You can enable them in app settings.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Later'),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            openAppSettings();
                          },
                          child: const Text('Open Settings'),
                        ),
                      ],
                    ),
              );
            });
          }
        });
      } else {
        // User skipped permissions, initialize without expectation of Bluetooth
        BtPrinter.init(
          continueWithoutBluetooth: true,
        ).then((printer) => btPrinter = printer);

        // Mark that we showed the dialog
        await prefs.setBool('permissions_checked', true);
      }
    }
  } else {
    // Not first launch, just initialize Bluetooth as usual
    BtPrinter.init().then((printer) => btPrinter = printer);
  }
}

class BtPrinter {
  late StreamSubscription<bool> _isScanningSubscription;
  late StreamSubscription<bpp.BlueState> _blueStateSubscription;
  late StreamSubscription<bpp.ConnectState> _connectStateSubscription;
  late StreamSubscription<Uint8List> _receivedDataSubscription;
  late StreamSubscription<List<bpp.BluetoothDevice>> _scanResultsSubscription;
  bpp.BluetoothDevice? selectedPrinter;
  bool btIsOn = false; // Initialize with a default value

  List<bpp.BluetoothDevice> printerList = [];

  // Private static instance
  static BtPrinter? _instance;

  // Factory constructor that returns the singleton instance
  factory BtPrinter() {
    _instance ??= BtPrinter._();
    return _instance!;
  }

  // Static async initializer with better error handling
  // Static async initializer with better error handling
  static Future<BtPrinter> init({
    bool continueWithoutBluetooth = true,
    BuildContext? context,
  }) async {
    if (_instance == null) {
      _instance = BtPrinter._();

      try {
        // Check Bluetooth state with timeout
        await _instance!._checkBluetoothState().timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            APP_LOGS.warning(
              'Bluetooth state check timed out during initialization',
            );
            _instance!.btIsOn = false;
          },
        );

        if (_instance!.btIsOn) {
          try {
            // Use a timeout for scanning
            final devices = await _instance!.scanForThermalPrinters().timeout(
              const Duration(seconds: 10),
              onTimeout: () {
                APP_LOGS.warning(
                  'Printer scan timed out during initialization',
                );
                return <bpp.BluetoothDevice>[];
              },
            );

            if (devices.isNotEmpty) {
              _instance!.printerList = devices;
              _instance!.selectedPrinter = devices.first;
              APP_LOGS.info(
                'Automatically selected printer: ${_instance!.selectedPrinter!.name}',
              );
            } else {
              APP_LOGS.info('No printers found during initialization');
            }
          } catch (e) {
            APP_LOGS.error(
              'Error scanning for printers during initialization: $e',
            );
          }
        } else if (context != null) {
          // Prompt to enable Bluetooth but don't block initialization
          _instance!._showEnableBluetoothLater(context);
        }
      } catch (e) {
        APP_LOGS.error('Error during BtPrinter initialization: $e');
        _instance!.btIsOn = false;
      }
    }
    return _instance!;
  }

  // Helper method to show enable bluetooth message
  void _showEnableBluetoothLater(BuildContext context) {
    // Show message without blocking initialization
    Future.delayed(Duration.zero, () {
      if (context.mounted) {
        showToastMessage(
          context,
          'Bluetooth is disabled. Enable Bluetooth to use printer features.',
          ToastLevel.warning,
          position: ToastPosition.bottom,
        );
      }
    });
  }

  static BtPrinter get instance {
    if (_instance == null) {
      throw StateError(
        'BtPrinter not initialized. Call BtPrinter.init() first.',
      );
    }
    return _instance!;
  }

  // Private constructor
  BtPrinter._() {
    _initStreams();
  }

  void _initStreams() {
    _isScanningSubscription = Stream<bool>.empty().listen((_) {});
    _blueStateSubscription = Stream<bpp.BlueState>.empty().listen((_) {});
    _connectStateSubscription = Stream<bpp.ConnectState>.empty().listen((_) {});
    _receivedDataSubscription = Stream<Uint8List>.empty().listen((_) {});
    _scanResultsSubscription = Stream<List<bpp.BluetoothDevice>>.empty().listen(
      (_) {},
    );
  }

  void dispose() {
    _isScanningSubscription.cancel();
    _blueStateSubscription.cancel();
    _connectStateSubscription.cancel();
    _receivedDataSubscription.cancel();
    _scanResultsSubscription.cancel();
  }

  /// Check if Bluetooth is currently enabled on the device on initialization
  Future<void> _checkBluetoothState() async {
    try {
      btIsOn =
          await fbp.FlutterBluePlus.adapterState.first ==
          fbp.BluetoothAdapterState.on;
      APP_LOGS.info(
        'Bluetooth is ${btIsOn ? 'enabled' : 'disabled'} on initialization',
      );
    } catch (e) {
      btIsOn = false;
      APP_LOGS.error('Failed to check Bluetooth status on initialization: $e');
    }
  }

  /// Check if Bluetooth is currently enabled on the device stream
  Stream<bool> checkBluetoothStateStream() {
    return fbp.FlutterBluePlus.adapterState
        .map((state) {
          btIsOn = state == fbp.BluetoothAdapterState.on;
          APP_LOGS.info(
            'Bluetooth state changed: ${btIsOn ? 'enabled' : 'disabled'}',
          );
          return btIsOn;
        })
        .handleError((error) {
          APP_LOGS.error('Error monitoring Bluetooth state: $error');
          btIsOn = false;
          return false;
        });
  }

  /// Check if Bluetooth is currently enabled on the device
  Future<bool> isBluetoothEnabled() async {
    try {
      // Check if Bluetooth is on
      bool isOn =
          await fbp.FlutterBluePlus.adapterState.first ==
          fbp.BluetoothAdapterState.on;
      return isOn;
    } catch (e) {
      // Handle any errors that might occur
      APP_LOGS.error('Error checking Bluetooth status: $e');
      return false;
    }
  }

  /// Add this method to your BtPrinter class
  Future<bool> safeBluetoothOperation(
    Future<bool> Function() operation, {
    Duration timeout = const Duration(seconds: 30),
    String timeoutMessage = "Operation timed out",
  }) async {
    try {
      return await operation().timeout(
        timeout,
        onTimeout: () {
          APP_LOGS.warning('Bluetooth operation timed out: $timeoutMessage');
          return false;
        },
      );
    } catch (e) {
      APP_LOGS.error('Bluetooth operation failed: $e');
      return false;
    }
  }

  /// Prompt the user to enable Bluetooth if it's not already enabled
  Future<bool> checkAndEnableBluetooth(BuildContext context) async {
    bool isEnabled = await isBluetoothEnabled();

    if (!isEnabled) {
      // Show a dialog to prompt the user to enable Bluetooth
      bool? shouldEnable = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.bluetooth_disabled),
                SizedBox(width: 8),
                Text('Bluetooth is Off'),
              ],
            ),
            content: const Text('Please turn on Bluetooth to proceed.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Enable Bluetooth'),
              ),
            ],
          );
        },
      );

      if (shouldEnable == true) {
        try {
          // Request to enable Bluetooth
          await fbp.FlutterBluePlus.turnOn();
          return await isBluetoothEnabled(); // Check again after enabling
        } catch (e) {
          print('Failed to enable Bluetooth: $e');
          return false;
        }
      }
      return false; // User canceled
    }
    return true; // Bluetooth is already enabled
  }

  /// Scan for thermal printers with robust error handling
  Future<List<bpp.BluetoothDevice>> scanForThermalPrinters() async {
    if (!btIsOn) {
      APP_LOGS.debug('Cannot scan for printers: Bluetooth is disabled');
      return [];
    }

    try {
      List<bpp.BluetoothDevice> devices = [];
      bool scanComplete = false;

      // Set up a more robust subscription with retry
      try {
        await bpp.BluetoothPrintPlus.startScan(
          timeout: const Duration(seconds: 8),
        );

        _scanResultsSubscription = bpp.BluetoothPrintPlus.scanResults.listen(
          (results) {
            devices =
                results.where((device) {
                  final name = device.name.toLowerCase();
                  return name.contains('richtech') ||
                      name.contains('printer') ||
                      name.contains('pos') ||
                      name.contains('thermal');
                }).toList();

            for (var device in devices) {
              APP_LOGS.info(
                'Found printer: ${device.name} (${device.address})',
              );
            }
          },
          onDone: () {
            scanComplete = true;
          },
          onError: (e) {
            APP_LOGS.error('Error in scan results stream: $e');
            scanComplete = true;
          },
        );

        // Wait for scan to complete or timeout
        await Future.delayed(const Duration(seconds: 5));
      } catch (e) {
        APP_LOGS.error('Error starting bluetooth scan: $e');
      } finally {
        // Always try to stop scan, even if it failed to start properly
        try {
          await bpp.BluetoothPrintPlus.stopScan();
        } catch (e) {
          APP_LOGS.debug('Error stopping scan (may already be stopped): $e');
        }
      }

      printerList = devices;
      return devices;
    } catch (e) {
      APP_LOGS.error('Error scanning for printers: $e');
      return [];
    }
  }

  /// Connect to the specified printer
  /// Returns true if connection is successful, false otherwise
  Future<bool> connectToPrinter(bpp.BluetoothDevice device) async {
    try {
      selectedPrinter = device;

      if (selectedPrinter != null) {
        await bpp.BluetoothPrintPlus.connect(selectedPrinter!);
        APP_LOGS.info('Connected to printer: ${selectedPrinter!.name}');
        return true;
      } else {
        APP_LOGS.error('Printer not found');
        return false;
      }
    } catch (e) {
      APP_LOGS.error('Failed to connect to printer: ${device.name}', e);
      return false;
    }
  }

  /// Send test print to connected printer
  Future<bool> printTestPage(BuildContext context) async {
    bool connectionCreated = false; // Track if we created a new connection
    int retryCount = 0;
    const maxRetries = 2;

    try {
      // Check if printer is connected
      if (selectedPrinter == null) {
        APP_LOGS.debug(
          '[printTestPage] No printer connected. Attempting to find one...',
        );
        showToastMessage(
          context,
          'No printer connected. Attempting to find one...',
          ToastLevel.warning,
          position: ToastPosition.topRight,
        );

        // Try to find printers
        List<bpp.BluetoothDevice> availablePrinters =
            await scanForThermalPrinters();

        if (availablePrinters.isEmpty) {
          showToastMessage(
            context,
            'No thermal printers found. Please turn on your printer and try again.',
            ToastLevel.warning,
          );
          return false;
        }

        // Try to connect to the first printer in the list
        connectionCreated = await connectToPrinter(availablePrinters[0]);
        if (!connectionCreated) {
          showToastMessage(
            context,
            'Failed to connect to printer: ${availablePrinters[0].name}',
            ToastLevel.error,
            position: ToastPosition.topRight,
          );
          return false;
        }

        showToastMessage(
          context,
          'Connected to printer: ${selectedPrinter!.name}',
          ToastLevel.success,
          position: ToastPosition.topRight,
        );
      } else {
        // Ensure the connection is still active by checking status or reconnecting
        try {
          // Try to disconnect and reconnect to ensure fresh connection
          await bpp.BluetoothPrintPlus.disconnect();
          await Future.delayed(const Duration(milliseconds: 500));
          connectionCreated = await connectToPrinter(selectedPrinter!);
          if (!connectionCreated) {
            throw Exception("Failed to refresh printer connection");
          }
          await Future.delayed(
            const Duration(milliseconds: 500),
          ); // Give connection time to stabilize
        } catch (e) {
          APP_LOGS.debug(
            '[printTestPage] Error refreshing printer connection: $e',
          );
          // Continue anyway, we'll catch any further errors in the main try/catch
        }
      }

      while (retryCount <= maxRetries) {
        try {
          // Create an ESC command instance
          final escCommand = bpp.EscCommand();
          await escCommand.cleanCommand();

          // Create a list to hold all command preparation Futures
          List<Future<void>> commandFutures = [];

          // Prepare the image
          Uint8List image = await convertForThermalPrinter(
            'assets/images/main-logo.png',
          );

          // Build test print commands
          commandFutures.add(
            escCommand.image(image: image, alignment: bpp.Alignment.center),
          );
          commandFutures.add(
            escCommand.text(
              content: "TEST PRINT\n",
              alignment: bpp.Alignment.center,
              fontSize: bpp.EscFontSize.size2,
            ),
          );
          commandFutures.add(
            escCommand.text(content: "--------------------------------\n"),
          );
          commandFutures.add(
            escCommand.text(content: "Printer is working correctly!\n"),
          );
          commandFutures.add(escCommand.text(content: "${DateTime.now()}\n\n"));
          commandFutures.add(
            escCommand.text(content: "--------------------------------\n"),
          );
          commandFutures.add(escCommand.cutPaper());

          // Wait for all commands to be prepared
          await Future.wait(commandFutures);

          // Get the final command
          final cmd = await escCommand.getCommand();
          if (cmd == null) {
            APP_LOGS.debug('Failed to generate ESC command for test print');
            throw Exception('Failed to generate print command');
          }

          // Send the command to the printer with timeout
          await bpp.BluetoothPrintPlus.write(cmd);

          // Wait for printing to complete
          await Future.delayed(const Duration(seconds: 2));

          APP_LOGS.debug('Test page printed successfully');
          return true;
        } catch (e) {
          APP_LOGS.warning(
            'Test printing attempt ${retryCount + 1} failed: $e',
          );

          if (e.toString().contains('socket closed') ||
              e.toString().contains('IOException')) {
            // This is likely a connection issue - try reconnecting if there are retries left
            retryCount++;

            if (retryCount <= maxRetries) {
              APP_LOGS.debug(
                'Retrying test print operation (attempt $retryCount of $maxRetries)...',
              );

              // Try to reconnect before next attempt
              try {
                await bpp.BluetoothPrintPlus.disconnect();
                await Future.delayed(const Duration(seconds: 1));
                await connectToPrinter(selectedPrinter!);
                await Future.delayed(
                  const Duration(seconds: 1),
                ); // Give connection time to stabilize
              } catch (reconnectError) {
                APP_LOGS.error(
                  'Failed to reconnect to printer for retry',
                  reconnectError,
                );
              }
            } else {
              throw Exception(
                "Maximum retry attempts reached. Test print failed.",
              );
            }
          } else {
            // Not a connection issue, rethrow
            rethrow;
          }
        }
      }

      // If we get here, all retries failed
      return false;
    } catch (e) {
      APP_LOGS.error('Failed to print test page', e, StackTrace.current);
      showToastMessage(
        context,
        'Failed to print test page: ${e.toString().split('\n')[0]}', // Only show first line of error
        ToastLevel.error,
      );
      return false;
    } finally {
      // Wait a moment before attempting to disconnect to ensure commands are sent
      await Future.delayed(const Duration(seconds: 1));

      // Only disconnect if we created a new connection for this print job
      if (connectionCreated) {
        try {
          APP_LOGS.debug('Disconnecting from printer after test printing');
          await bpp.BluetoothPrintPlus.disconnect();
        } catch (e) {
          APP_LOGS.error('Error disconnecting from printer', e);
        }
      }
    }
  }

  /// Print a receipt using the connected Bluetooth thermal printer
  Future<bool> printReceiptBluetooth({
    required BuildContext context,
    required bpp.BluetoothDevice? currentPrinter,
    required Map<String, dynamic> receiptData,
  }) async {
    bool connectionCreated = false; // Track if we created a new connection
    int retryCount = 0;
    const maxRetries = 2;

    try {
      // Check if printer is connected
      if (currentPrinter == null) {
        APP_LOGS.debug(
          '[printReceiptBluetooth] No printer connected. Attempting to find one...',
        );
        showToastMessage(
          context,
          'No printer connected. Attempting to find one...',
          ToastLevel.warning,
          position: ToastPosition.topRight,
        );

        // Try to find printers
        List<bpp.BluetoothDevice> availablePrinters =
            await scanForThermalPrinters();

        if (availablePrinters.isEmpty) {
          // No printers found, show toast message
          showToastMessage(
            context,
            'No thermal printers found. Please turn on your printer and try again.',
            ToastLevel.warning,
          );
          return false;
        }

        // Try to connect to the first printer in the list
        connectionCreated = await connectToPrinter(availablePrinters[0]);
        if (!connectionCreated) {
          showToastMessage(
            context,
            'Failed to connect to printer: ${availablePrinters[0].name}',
            ToastLevel.error,
            position: ToastPosition.topRight,
          );
          return false;
        }

        showToastMessage(
          context,
          'Connected to printer: ${selectedPrinter!.name}',
          ToastLevel.success,
          position: ToastPosition.topRight,
        );
      } else if (selectedPrinter?.address != currentPrinter.address) {
        // Use the currentPrinter passed as parameter if it's different from the current one
        connectionCreated = await connectToPrinter(currentPrinter);
        if (!connectionCreated) {
          showToastMessage(
            context,
            'Failed to connect to printer: ${currentPrinter.name}',
            ToastLevel.error,
            position: ToastPosition.topRight,
          );
          return false;
        }
      } else {
        // Ensure the connection is still active by checking status or reconnecting
        try {
          // Try to disconnect and reconnect to ensure fresh connection
          await bpp.BluetoothPrintPlus.disconnect();
          await Future.delayed(const Duration(milliseconds: 500));
          connectionCreated = await connectToPrinter(currentPrinter);
          if (!connectionCreated) {
            throw Exception("Failed to refresh printer connection");
          }
          await Future.delayed(
            const Duration(milliseconds: 500),
          ); // Give connection time to stabilize
        } catch (e) {
          APP_LOGS.debug(
            '[printReceiptBluetooth] Error refreshing printer connection: $e',
          );
          // Continue anyway, we'll catch any further errors in the main try/catch
        }
      }

      while (retryCount <= maxRetries) {
        try {
          // Create an ESC command instance
          final escCommand = bpp.EscCommand();
          await escCommand.cleanCommand();

          // Create a list to hold all command preparation Futures
          List<Future<void>> commandFutures = [];

          // Prepare the image
          Uint8List image = await convertForThermalPrinter(
            'assets/images/main-logo.png',
          );

          // Add logo
          commandFutures.add(
            escCommand.image(image: image, alignment: bpp.Alignment.center),
          );

          // Print header
          commandFutures.add(escCommand.text(content: "\n"));

          // Invoice details
          commandFutures.add(
            escCommand.text(content: "INVOICE NO: ${receiptData['id']}\n"),
          );
          commandFutures.add(
            escCommand.text(content: "DATE: ${receiptData['datetime']}\n"),
          );
          commandFutures.add(
            escCommand.text(content: "--------------------------------\n"),
          );

          // Items list
          for (var item in receiptData['itemList']) {
            String itemText = "${item['name']} ${item['quantity']}x";
            String priceText = "RM${item['total_price']}";

            // Calculate padding to align price to the right
            int lineLength = 32; // Typical chars per line on thermal paper
            int paddingLength = lineLength - itemText.length - priceText.length;
            String padding = paddingLength > 0 ? ' ' * paddingLength : ' ';

            commandFutures.add(
              escCommand.text(content: "$itemText$padding$priceText\n"),
            );
          }

          commandFutures.add(
            escCommand.text(content: "--------------------------------\n"),
          );

          // Totals
          // For each row, align the value to the right
          String totalText = "TOTAL";
          String totalAmount = "RM${receiptData['totalAmount']}";
          commandFutures.add(
            escCommand.text(
              content:
                  "$totalText${' ' * (32 - totalText.length - totalAmount.length)}$totalAmount\n",
            ),
          );

          String discountText = "DISCOUNT";
          String discountAmount = "RM${receiptData['discountAmount']}";
          commandFutures.add(
            escCommand.text(
              content:
                  "$discountText${' ' * (32 - discountText.length - discountAmount.length)}$discountAmount\n",
            ),
          );

          String taxText = "SERVICE TAX";
          String taxAmount = "RM${receiptData['tax']}";
          commandFutures.add(
            escCommand.text(
              content:
                  "$taxText${' ' * (32 - taxText.length - taxAmount.length)}$taxAmount\n",
            ),
          );

          String grandText = "GRAND TOTAL";
          String grandAmount = "RM${receiptData['totalAmount']}";
          commandFutures.add(
            escCommand.text(
              content:
                  "$grandText${' ' * (32 - grandText.length - grandAmount.length)}$grandAmount\n",
            ),
          );

          commandFutures.add(
            escCommand.text(content: "--------------------------------\n"),
          );

          // Payment details
          String cashText = receiptData['paymentMethod'].toUpperCase();
          String cashAmount = "RM${receiptData['enteredAmount']}";
          commandFutures.add(
            escCommand.text(
              content:
                  "$cashText${' ' * (32 - cashText.length - cashAmount.length)}$cashAmount\n",
            ),
          );

          String changeText = "PAY CHANGE";
          String changeAmount = "RM${receiptData['changeAmount']}";
          commandFutures.add(
            escCommand.text(
              content:
                  "$changeText${' ' * (32 - changeText.length - changeAmount.length)}$changeAmount\n",
            ),
          );

          commandFutures.add(
            escCommand.text(content: "--------------------------------\n"),
          );

          // Footer
          commandFutures.add(
            escCommand.text(
              content: "Thank You & Please Come Again\n\n",
              alignment: bpp.Alignment.center,
            ),
          );
          commandFutures.add(
            escCommand.text(content: "--------------------------------\n"),
          );
          commandFutures.add(escCommand.cutPaper()); // Add paper cut command

          // Wait for all commands to be prepared
          await Future.wait(commandFutures);

          // Get the final command
          final cmd = await escCommand.getCommand();
          if (cmd == null) {
            APP_LOGS.debug('Failed to generate ESC command for receipt');
            throw Exception('Failed to generate print command');
          }

          // Send the command to the printer with timeout
          await bpp.BluetoothPrintPlus.write(cmd);

          // Wait for printing to complete
          await Future.delayed(const Duration(seconds: 2));

          APP_LOGS.debug('Receipt printed successfully');
          return true;
        } catch (e) {
          APP_LOGS.warning('Printing attempt ${retryCount + 1} failed: $e');

          if (e.toString().contains('socket closed') ||
              e.toString().contains('IOException')) {
            // This is likely a connection issue - try reconnecting if there are retries left
            retryCount++;

            if (retryCount <= maxRetries) {
              APP_LOGS.debug(
                'Retrying print operation (attempt $retryCount of $maxRetries)...',
              );

              // Try to reconnect before next attempt
              try {
                await bpp.BluetoothPrintPlus.disconnect();
                await Future.delayed(const Duration(seconds: 1));
                await connectToPrinter(currentPrinter!);
                await Future.delayed(
                  const Duration(seconds: 1),
                ); // Give connection time to stabilize
              } catch (reconnectError) {
                APP_LOGS.error(
                  'Failed to reconnect to printer for retry',
                  reconnectError,
                );
              }
            } else {
              throw Exception("Maximum retry attempts reached. Print failed.");
            }
          } else {
            // Not a connection issue, rethrow
            rethrow;
          }
        }
      }

      // If we get here, all retries failed
      return false;
    } catch (e) {
      APP_LOGS.error('Failed to print receipt', e, StackTrace.current);
      showToastMessage(
        context,
        'Failed to print receipt: ${e.toString().split('\n')[0]}', // Only show first line of error
        ToastLevel.error,
      );
      return false;
    } finally {
      // Wait a moment before attempting to disconnect to ensure commands are sent
      await Future.delayed(const Duration(seconds: 1));

      // Only disconnect if we created a new connection for this print job
      // Don't disconnect if the printer was already selected/connected before
      if (connectionCreated) {
        try {
          APP_LOGS.debug('Disconnecting from printer after printing');
          await bpp.BluetoothPrintPlus.disconnect();
        } catch (e) {
          APP_LOGS.error('Error disconnecting from printer', e);
        }
      }
    }
  }

  /// Show a dialog with detailed printer information
  Future<bool> bluetoothTestingDialog(BuildContext context) async {
    final completer = Completer<bool>();
    // Initialize printers list with existing printerList
    List<bpp.BluetoothDevice> printers = List.from(printerList);
    bool isScanning = false;
    bpp.BluetoothDevice? connectedPrinter;
    // Track Bluetooth status
    bool isBluetoothOn = btIsOn;
    bool isTogglingBluetooth = false;

    // Set up a subscription to track Bluetooth state changes
    late StreamSubscription<bool> bluetoothStateSubscription;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        // Start monitoring Bluetooth state changes
        bluetoothStateSubscription = checkBluetoothStateStream().listen((isOn) {
          if (dialogContext.mounted) {
            // Find the closest StatefulBuilder and use its setState
            (context as StatefulElement).markNeedsBuild();
            isBluetoothOn = isOn;
            isTogglingBluetooth = false;

            // If Bluetooth was just turned on, auto-scan for printers
            if (isOn && !isScanning && printers.isEmpty) {
              scanForThermalPrinters();
            }
          }
        });

        return StatefulBuilder(
          builder: (context, setState) {
            Widget buildPrinterInfo(bpp.BluetoothDevice printer) {
              final bool isConnected =
                  connectedPrinter?.address == printer.address;

              return Card(
                color: isConnected ? Colors.blue.withOpacity(0.1) : null,
                elevation: isConnected ? 4 : 1,
                child: InkWell(
                  onTap: () async {
                    // Show connecting indicator
                    setState(() {
                      isScanning = true;
                    });

                    bool success = await connectToPrinter(printer);

                    setState(() {
                      isScanning = false;
                      if (success) {
                        connectedPrinter = printer;
                      }
                    });

                    if (success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Connected to ${printer.name}')),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to connect to ${printer.name}'),
                        ),
                      );
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              isConnected ? Icons.check_circle : Icons.print,
                              color: isConnected ? Colors.green : Colors.blue,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                printer.name,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color:
                                      isConnected ? Colors.blue.shade700 : null,
                                ),
                              ),
                            ),
                            if (isConnected)
                              ElevatedButton.icon(
                                icon: const Icon(Icons.print, size: 18),
                                label: const Text('Test Print'),
                                onPressed: () async {
                                  bool success = await printTestPage(context);
                                  if (success) {
                                    showToastMessage(
                                      context,
                                      'Test page printed successfully',
                                      ToastLevel.success,
                                      position: ToastPosition.bottom,
                                    );
                                  } else {
                                    showToastMessage(
                                      context,
                                      'Failed to print test page',
                                      ToastLevel.error,
                                      position: ToastPosition.bottom,
                                    );
                                  }
                                },
                              ),
                          ],
                        ),
                        const Divider(),
                        Text('MAC Address: ${printer.address}'),
                        Text('Type: ${printer.type}'),
                        if (isConnected)
                          const Text(
                            'Status: Connected',
                            style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        if (!isConnected)
                          const Text(
                            'Click to connect',
                            style: TextStyle(
                              fontStyle: FontStyle.italic,
                              color: Colors.grey,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }

            Future<void> startScan() async {
              if (!isBluetoothOn) {
                showToastMessage(
                  context,
                  'Bluetooth is disabled. Please enable Bluetooth to scan for printers',
                  ToastLevel.warning,
                  position: ToastPosition.bottom,
                );
                return;
              }

              setState(() {
                isScanning = true;
                printers = [];
              });

              final devices = await scanForThermalPrinters();
              setState(() {
                printers = devices;
                isScanning = false;
              });

              if (printers.isEmpty) {
                showToastMessage(
                  context,
                  'No printers found. Please make sure the printer is turned on and discoverable',
                  ToastLevel.warning,
                  position: ToastPosition.bottom,
                );
              }
            }

            Future<void> toggleBluetooth() async {
              setState(() {
                isTogglingBluetooth = true;
              });

              try {
                if (isBluetoothOn) {
                  await fbp.FlutterBluePlus.turnOff();
                } else {
                  await fbp.FlutterBluePlus.turnOn();
                }
              } catch (e) {
                showToastMessage(
                  context,
                  'Failed to toggle Bluetooth: $e',
                  ToastLevel.error,
                  position: ToastPosition.bottom,
                );
                setState(() {
                  isTogglingBluetooth = false;
                });
              }
            }

            // Check if current selectedPrinter exists
            if (selectedPrinter != null) {
              connectedPrinter = selectedPrinter;
            }

            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.print, color: Colors.blue),
                  const SizedBox(width: 8),
                  Text('Thermal Printers (${printers.length})'),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: Column(
                  children: [
                    Row(
                      children: [
                        // Bluetooth toggle button
                        ElevatedButton.icon(
                          icon: Icon(
                            isBluetoothOn
                                ? Icons.bluetooth_connected
                                : Icons.bluetooth_disabled,
                            color: isBluetoothOn ? Colors.blue : Colors.red,
                          ),
                          label: Text(
                            isTogglingBluetooth
                                ? 'Toggling...'
                                : isBluetoothOn
                                ? 'Bluetooth On'
                                : 'Enable Bluetooth',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                isBluetoothOn
                                    ? Colors.blue.withOpacity(0.1)
                                    : null,
                          ),
                          onPressed:
                              isTogglingBluetooth ? null : toggleBluetooth,
                        ),
                        const SizedBox(width: 8),
                        // Scan button
                        Expanded(
                          child: ElevatedButton.icon(
                            icon:
                                isScanning
                                    ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                    : const Icon(Icons.search),
                            label: Text(
                              isScanning ? 'Scanning...' : 'Scan for Printers',
                            ),
                            onPressed:
                                (isScanning || !isBluetoothOn)
                                    ? null
                                    : startScan,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (!isBluetoothOn)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          "Please enable Bluetooth to scan for printers",
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    if (isBluetoothOn && printers.isNotEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          "Click on a printer to connect",
                          style: TextStyle(fontStyle: FontStyle.italic),
                        ),
                      ),
                    Expanded(
                      child:
                          !isBluetoothOn
                              ? const Center(
                                child: Text(
                                  'Bluetooth is disabled',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              )
                              : printers.isEmpty
                              ? Center(
                                child: Text(
                                  isScanning
                                      ? 'Scanning for printers...'
                                      : 'No printers found',
                                ),
                              )
                              : ListView.builder(
                                itemCount: printers.length,
                                itemBuilder:
                                    (context, index) =>
                                        buildPrinterInfo(printers[index]),
                              ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    bluetoothStateSubscription.cancel();
                    Navigator.pop(context);
                    completer.complete(false);
                  },
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed:
                      connectedPrinter != null
                          ? () {
                            bluetoothStateSubscription.cancel();
                            selectedPrinter = connectedPrinter;
                            Navigator.pop(context);
                            completer.complete(true);
                          }
                          : null,
                  child: const Text('Continue'),
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
