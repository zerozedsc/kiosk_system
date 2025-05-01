import '../../configs/configs.dart';
import '../../services/database/db.dart';
import '../../components/toastmsg.dart';

export '../../services/permission_handler.dart';
export '../../services/connection/bluetooth.dart';
export '../../services/connection/usb.dart';

// ignore: non_constant_identifier_names
late LoggingService CASHIER_LOGS;

/// use to process item for transaction
Map<String, dynamic> processItem(Map<String, dynamic> item) {
  if (item.containsKey('piece') &&
      item.containsKey('details') &&
      item['details'].length == 1) {
    item['id'] = item['details'][0]['ids'][0];
    item.remove('details');
    item['type'] = item['set'];
    item.remove('set');
    item.remove('total_max_qty');
  }

  if (!item.containsKey('type')) {
    item['type'] = "total_stocks";
  }

  CASHIER_LOGS.console(item);

  return item;
}

/// Retrieves the latest transaction ID from the inventory_transaction table.
///
/// This method queries the inventory_transaction table and returns the highest ID value,
/// which corresponds to the most recent transaction. If no transactions exist,
/// it returns 0 as a starting point.
///
/// Returns:
///   A [Future<int>] representing the latest transaction ID or 0 if no transactions exist.
///
/// Example:
///   ```dart
///   final latestId = await inventory.getLatestTransactionId();
///   final nextId = latestId + 1; // Use for the next transaction
///   ```
Future<int> getLatestTransactionId() async {
  try {
    final dbQuery = DatabaseQuery(db: DB, LOGS: CASHIER_LOGS);
    final result = await dbQuery.query(
      'SELECT MAX(id) as max_id FROM kiosk_transaction',
    );

    // Extract the maximum ID value from the result
    if (result.isNotEmpty && result[0]['max_id'] != null) {
      return result[0]['max_id'] as int;
    }

    // If no records exist or max_id is null, return 0
    return 0;
  } catch (e) {
    CASHIER_LOGS.error('Error retrieving latest transaction ID: $e');
    return 0;
  }
}

/// Records a new inventory transaction in the database.
///
/// This method creates a new entry in the inventory_transaction table with the provided
/// transaction details. It automatically generates a transaction ID by incrementing
/// the latest ID retrieved from the database.
///
/// Parameters:
///   - [timestamp]: Unix timestamp when the transaction occurred.
///   - [receiptList]: JSON or text representation of items in the receipt.
///   - [paymentMethod]: The method used for payment (e.g., "CASH", "CARD").
///   - [totalAmount]: The total monetary value of the transaction.
///
/// Returns:
///   bool
///
///
/// Example:
///   ```dart
///   final transactionId = await inventory.recordTransaction(
///     timestamp: DateTime.now().millisecondsSinceEpoch ~/ 1000,
///     receiptList: jsonEncode(itemsList),
///     paymentMethod: 'CREDIT_CARD',
///     totalAmount: 45.99,
///   );
///   ```
Future<bool> recordTransaction({
  required String employeeId,
  required Map<String, dynamic> processTransactionData,
}) async {
  try {
    final dbQuery = DatabaseQuery(db: DB, LOGS: CASHIER_LOGS);

    Map<String, dynamic> kiosktransaction = {
      'employee_id': employeeId,
      'date': getDateTimeNow(format: "yyyy-MM-dd"),
      'data': processTransactionData['inventoryTransaction'],
    };

    try {
      final List<Map<String, dynamic>> fetchInventoryData = await dbQuery
          .fetchDataWhere(
            'inventory_transaction',
            'date = ? AND employee_id = ?',
            [kiosktransaction['date'], employeeId],
          );

      if (fetchInventoryData.isEmpty) {
        kiosktransaction["data"] = json.encode(kiosktransaction["data"]);
        await dbQuery.insertNewData('inventory_transaction', kiosktransaction);
      } else {
        Map<String, dynamic> inventoryData = fetchInventoryData.first;
        CASHIER_LOGS.debug(
          "check kioskTransaction[data]: ${CASHIER_LOGS.map2str(kiosktransaction['data'])}",
        );
        Map<String, dynamic> data =
            json.decode(inventoryData['data']) as Map<String, dynamic>;
        kiosktransaction['data'].forEach((key, value) {
          if (data.containsKey(key)) {
            data[key]["total_stocks"] += value["total_stocks"];
            data[key]["total_pieces_used"] += value["total_pieces_used"];
          } else {
            data[key] = {
              "total_stocks": value["total_stocks"],
              "total_pieces_used": value["total_pieces_used"],
            };
          }
        });

        kiosktransaction["data"] = json.encode(data);
        await dbQuery.updateData(
          'inventory_transaction',
          inventoryData['id'],
          kiosktransaction,
        );
      }
    } catch (e) {
      CASHIER_LOGS.error(
        'Error processing inventory transaction:',
        e,
        StackTrace.current,
      );
    }

    // Insert the transaction and get the ID
    await dbQuery.insertNewData('kiosk_transaction', {
      'employee_id': employeeId,
      'timestamp': processTransactionData['timestamp_int'],
      'receipt_list': json.encode(processTransactionData['receiptList']),
      'payment_method': processTransactionData['paymentMethod'],
      'total_amount': processTransactionData['totalAmount'],
    });

    // Get the latest transaction ID (which should be the one we just created)
    final newId = await getLatestTransactionId();

    CASHIER_LOGS.info('Transaction recorded with ID: $newId');
    return true;
  } catch (e, stackTrace) {
    CASHIER_LOGS.error('Failed to record transaction', e, stackTrace);
    return false;
  }
}

/// Retrieves discount information for a given coupon code.
///
/// This function checks if the coupon code exists in the database and if it's valid.
/// If the coupon exists and is valid, it returns the discount information including
/// the type of discount (percentage or fixed amount) and which products it applies to.
///
/// Parameters:
///   - [couponCode]: The coupon code to validate and retrieve information for.
///
/// Returns:
///   A [Future<Map<String, dynamic>>] containing the following keys:
///   - 'valid': boolean indicating if the coupon is valid
///   - 'message': string explaining the status (especially if invalid)
///   - 'discount_type': either 'percent' or 'amount' if valid
///   - 'discount_value': the discount percentage or fixed amount
///   - 'target_type': either 'product' or 'set' if the discount targets specific items
///   - 'target_ids': list of integer IDs the discount applies to (if applicable)
///
/// Example:
///   ```dart
///   final discountInfo = await getDiscountItems('SUMMER20');
///   if (discountInfo['valid']) {
///     // Apply the discount based on returned info
///   } else {
///     print(discountInfo['message']);
///   }
///   ```
Future<Map<String, dynamic>> getDiscountItems(String couponCode) async {
  try {
    final dbQuery = DatabaseQuery(db: DB, LOGS: CASHIER_LOGS);

    // Check if coupon exists and is valid
    final List<Map<String, dynamic>> results = await dbQuery.fetchDataWhere(
      'discount_info',
      'code = ?',
      [couponCode],
    );

    // Coupon not found
    if (results.isEmpty) {
      return {'valid': false, 'message': 'Coupon code not found'};
    }

    final couponData = results.first;

    // Check if coupon is active (exist field)
    if (couponData['exist'] != 1) {
      return {'valid': false, 'message': 'Coupon code is inactive or expired'};
    }

    // Determine discount type and value
    String discountType;
    double discountValue;

    if (couponData['cut_percent'] != null) {
      discountType = 'percent';
      discountValue = (couponData['cut_percent'] as num).toDouble();
    } else if (couponData['cut_price'] != null) {
      discountType = 'amount';
      discountValue = (couponData['cut_price'] as num).toDouble();
    } else {
      // Both are null which shouldn't happen with proper DB constraints
      return {'valid': false, 'message': 'Invalid coupon configuration'};
    }

    // Determine target type and parse target IDs if available
    String? targetType;
    List<int>? targetIds;

    // Check for product-specific discount
    if (couponData['product_id'] != null &&
        couponData['product_id'].toString().isNotEmpty) {
      targetType = 'product';

      try {
        final String productIdStr = couponData['product_id'].toString();
        // Split by comma directly, no need to remove brackets
        final List<String> idStrings =
            productIdStr
                .split(',')
                .map((s) => s.trim())
                .where((s) => s.isNotEmpty)
                .toList();

        targetIds = idStrings.map((s) => int.parse(s)).toList();
      } catch (e) {
        CASHIER_LOGS.warning(
          'Failed to parse product_id: ${couponData['product_id']}',
        );
      }
    }
    // Check for set-specific discount
    else if (couponData['set_id'] != null &&
        couponData['set_id'].toString().isNotEmpty) {
      targetType = 'set';

      try {
        final String setIdStr = couponData['set_id'].toString();
        // Split by comma directly, no need to remove brackets
        final List<String> idStrings =
            setIdStr
                .split(',')
                .map((s) => s.trim())
                .where((s) => s.isNotEmpty)
                .toList();

        targetIds = idStrings.map((s) => int.parse(s)).toList();
      } catch (e) {
        CASHIER_LOGS.warning('Failed to parse set_id: ${couponData['set_id']}');
      }
    }

    // Return the complete discount information
    return {
      'valid': true,
      'discount_type': discountType,
      'discount_value': discountValue,
      'target_type': targetType,
      'target_ids': targetIds,
      'raw_data': couponData, // Include original data for debugging if needed
    };
  } catch (e) {
    CASHIER_LOGS.error('Error retrieving discount information: $e');
    return {'valid': false, 'message': 'Error processing coupon: $e'};
  }
}

/// Processes a receipt and prints it using the Bluetooth printer.
Future<bool> processReceipt({
  required BuildContext context,
  required dynamic currentPrinter,
  required Map<String, dynamic> receiptData,
}) async {
  try {
    Map<String, dynamic> processReceipt = {
      'id': receiptData['id'],
      'itemList': receiptData['receiptList'],
      'datetime': receiptData['datetime'],
      'paymentMethod': receiptData['paymentMethod'],
      'totalAmount': receiptData['totalAmount'],
      'employeeId': receiptData['employeeId'],
      'employeeName': receiptData['employeeName'],
    };

    for (final entry in receiptData['receiptData'].entries) {
      processReceipt[entry.key] = entry.value;
    }

    await btPrinter?.printReceiptBluetooth(
      context: context,
      currentPrinter: currentPrinter,
      receiptData: processReceipt,
    );

    return true;
  } catch (e) {
    CASHIER_LOGS.error('Error processing receipt: $e');
    return false;
  }
}

/// Checks if a cash drawer is connected and attempts to open it.
///
/// Returns a tuple with:
/// - A boolean indicating success or failure
/// - A string message describing the result
///
/// Example:
///   ```dart
///   final (success, message) = await checkAndOpenCashDrawer();
///   if (success) {
///     // Cash drawer opened successfully
///   } else {
///     // Show error message
///   }
///   ```
Future<(bool, String)> checkAndOpenCashDrawer(BuildContext context) async {
  try {
    // Check if USB manager is initialized
    if (USB == null || !USB!.isInitialized) {
      CASHIER_LOGS.warning('USB Manager not initialized');
      showToastMessage(
        context,
        LOCALIZATION.localize("usb_service.permission_message"),
        ToastLevel.error,
        position: ToastPosition.topRight,
      );
      return (false, 'USB Manager not initialized');
    }

    // Check if cash drawer is connected
    bool isConnected = await USB!.isCashDrawerConnected();
    if (!isConnected) {
      CASHIER_LOGS.warning('No cash drawer detected');
      showToastMessage(
        context,
        LOCALIZATION.localize("usb_service.no_cash_drawer"),
        ToastLevel.warning,
        position: ToastPosition.topRight,
      );
      return (false, 'No cash drawer detected');
    }

    // Attempt to open the cash drawer
    CASHIER_LOGS.info('Cash drawer detected, attempting to open');
    final (success, commandUsed) = await USB!.openCashDrawer();

    if (success) {
      CASHIER_LOGS.info(
        'Cash drawer opened successfully using command: $commandUsed',
      );
      showToastMessage(
        context,
        LOCALIZATION.localize("usb_service.drawer_opened"),
        ToastLevel.success,
        position: ToastPosition.topRight,
      );
      return (true, 'Cash drawer opened successfully');
    } else {
      CASHIER_LOGS.warning('Failed to open cash drawer');
      showToastMessage(
        context,
        LOCALIZATION.localize('usb_service.drawer_failed'),
        ToastLevel.error,
        position: ToastPosition.topRight,
      );
      return (false, 'Failed to open cash drawer');
    }
  } catch (e, stackTrace) {
    CASHIER_LOGS.error('Error opening cash drawer', e, stackTrace);
    showToastMessage(
      context,
      '${LOCALIZATION.localize("usb_service.connection_failed")}: ${e.toString()}',
      ToastLevel.error,
      position: ToastPosition.topRight,
    );
    return (false, 'Error: ${e.toString()}');
  }
}
