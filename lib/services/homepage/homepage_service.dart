import '../../configs/configs.dart';

import '../database/db.dart';
import '../analytics/analytics.dart';

import '../../components/toastmsg.dart';

// ignore: non_constant_identifier_names
late LoggingService HOMEPAGE_LOGS;
late HomepageService homepageService;

class HomepageService {
  static final HomepageService _instance = HomepageService._internal();
  Map<String, Map<String, dynamic>> employeeMap = {}; // id as key
  Map<String, Map<String, dynamic>> attendanceMaps = {};
  // Advanced sales summary data
  Map<String, dynamic> liveSalesSummary = {
    'orders': 0,
    'profit': 0.0,
    'bestSellingItem': '',
  };
  Map<String, int> productSales = {};
  Map<String, int> categorySales = {};
  Map<String, Map<String, dynamic>> paymentMethodSummary = {};

  factory HomepageService() {
    return _instance;
  }

  HomepageService._internal();

  // Initializes and preloads all employee data into memory as a Map.
  /// Call this during app startup.
  Future<HomepageService> initialize() async {
    try {
      HOMEPAGE_LOGS =
          await LoggingService(logName: "homepage_logs").initialize();

      employeeMap = EMPQUERY.employees;

      dynamic catchAttendanceData = await attendanceSetGetter();
      if (catchAttendanceData != null &&
          catchAttendanceData is Map<String, Map<String, dynamic>>) {
        // Store as a list of MapEntry<String, Map<String, dynamic>>
        attendanceMaps = catchAttendanceData;
      }

      HOMEPAGE_LOGS.info('Homepage service initialized.');
    } catch (e, stackTrace) {
      APP_LOGS.error('Error initialize homepage service', e, stackTrace);
    }
    return this;
  }

  // [300625] [EMPLOYEE ATTENDANCE]
  /// update employeeMap with new data
  Future<void> updateEmployeeMap() async {
    try {
      employeeMap = EMPQUERY.employees;

      dynamic catchAttendanceData = await attendanceSetGetter();
      if (catchAttendanceData != null &&
          catchAttendanceData is Map<String, Map<String, dynamic>>) {
        // Store as a list of MapEntry<String, Map<String, dynamic>>
        attendanceMaps = catchAttendanceData;
      }
    } catch (e, stackTrace) {
      HOMEPAGE_LOGS.error('Error updating employee map', e, stackTrace);
    }
  }

  /// [Retrieves and Saving employee attendance data]
  Future<dynamic> attendanceSetGetter({
    Map<String, dynamic>? attendanceData,
  }) async {
    try {
      final dbQuery = DatabaseQuery(db: DB, LOGS: HOMEPAGE_LOGS);
      final dateNow = getDateTimeNow();

      // Prepare allAttendanceData as a Map with id as key (for get, not for update/insert)
      Map<String, Map<String, dynamic>> allAttendanceData = {};
      if (employeeMap.isNotEmpty) {
        for (var entry in employeeMap.entries) {
          final id = entry.key;
          final employee = entry.value;
          final existing = await dbQuery.fetchDataWhere(
            'employee_attendance',
            'employee_id = ? AND date = ?',
            [id, dateNow],
            limit: 1,
          );
          allAttendanceData[id] = {
            "name": employee['name'],
            "username": employee['username'],
            "id": id,
            "clock_in":
                existing.isNotEmpty ? existing.first['clock_in'] ?? "" : "",
            "clock_out":
                existing.isNotEmpty ? existing.first['clock_out'] ?? "" : "",
            "total_hour":
                existing.isNotEmpty ? existing.first['total_hour'] ?? 0.0 : 0.0,
            "date": dateNow,
          };
        }
      }

      // If attendanceData is null, just return allAttendanceData (for get)
      if (attendanceData == null) {
        if (allAttendanceData.isEmpty) {
          HOMEPAGE_LOGS.warning('No attendance records found');
          return "no_attendance_records";
        }
        return allAttendanceData;
      }

      final String employeeId = attendanceData['id'].toString();
      final String date = attendanceData['date'].toString();

      // Always check for BOTH employee_id AND date!
      final existing = await dbQuery.fetchDataWhere(
        'employee_attendance',
        'employee_id = ? AND date = ?',
        [employeeId, date],
      );

      if (existing.isNotEmpty) {
        // Update only if the record for this employee and date exists
        final existingRecord = existing.first;
        final prevClockIn = existingRecord['clock_in'] ?? "";
        String newClockIn = attendanceData['clock_in'] ?? "";
        String newClockOut = attendanceData['clock_out'] ?? "";

        // Only update clock_in if it was empty before
        String clockInToSave = prevClockIn;
        if (prevClockIn == "" && newClockIn != "") {
          clockInToSave = newClockIn;
        }

        // Calculate total_hour if both clock_in and clock_out exist
        double totalHour =
            existingRecord['total_hour'] is num
                ? (existingRecord['total_hour'] as num).toDouble()
                : double.tryParse(
                      existingRecord['total_hour']?.toString() ?? '',
                    ) ??
                    0.0;

        if (clockInToSave != "" && newClockOut != "") {
          try {
            final inParts = clockInToSave.split(':');
            final outParts = newClockOut.split(':');
            if (inParts.length == 2 && outParts.length == 2) {
              final inTime = DateTime(
                0,
                1,
                1,
                int.parse(inParts[0]),
                int.parse(inParts[1]),
              );
              final outTime = DateTime(
                0,
                1,
                1,
                int.parse(outParts[0]),
                int.parse(outParts[1]),
              );
              final diff = outTime.difference(inTime);
              totalHour = diff.inMinutes / 60.0;
            }
          } catch (e) {
            HOMEPAGE_LOGS.warning('Failed to calculate total_hour: $e');
            return "total_hour_calculation_error";
          }
        }

        await dbQuery.updateData('employee_attendance', existingRecord['id'], {
          'clock_in': clockInToSave,
          if (newClockOut != "") 'clock_out': newClockOut,
          if (clockInToSave != "" && newClockOut != "")
            'total_hour': double.parse(totalHour.toStringAsFixed(3)),
        });

        HOMEPAGE_LOGS.info(
          'Attendance updated for employee_id: $employeeId, date: $date',
        );
        return "attendance_updated";
      } else {
        // No record for this date, so insert new
        await dbQuery.insertNewData('employee_attendance', {
          'employee_id': employeeId,
          'date': date,
          'clock_in': attendanceData['clock_in'] ?? "",
          'clock_out': attendanceData['clock_out'] ?? "",
          'total_hour': attendanceData['total_hour'] ?? 0.0,
        });
        HOMEPAGE_LOGS.info(
          'Attendance inserted for employee_id: $employeeId, date: $date',
        );
        return "attendance_inserted";
      }
    } catch (e, stackTrace) {
      HOMEPAGE_LOGS.error(
        'Failed to retrieve or save attendance data',
        e,
        stackTrace,
      );
      return "attendance_save_error";
    }
  }

  // [Update live sales summary (orders, profit, best selling item)]
  Future<void> updateLiveSalesSummary() async {
    final dbQuery = DatabaseQuery(db: DB, LOGS: HOMEPAGE_LOGS);
    final analytics = KioskAnalyticsService(dbQuery: dbQuery);

    final today = DateTime.now();
    final dateStr =
        "${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";

    // Orders = number of transactions today
    final transactions = await dbQuery.fetchAllData('kiosk_transaction');
    int orders =
        transactions.where((row) {
          final ts = row['timestamp'];
          final dt = DateTime.fromMillisecondsSinceEpoch(ts * 1000);
          final dStr =
              "${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";
          return dStr == dateStr;
        }).length;

    // Profit = total sales today * 0.2 (or your logic)
    double profit = await analytics.getTotalSalesForDate(dateStr) * 0.2;

    // Best selling item today
    final productSalesToday = await analytics.getProductSalesCountForDate(
      dateStr,
    );
    String bestSellingItem = '';
    int maxSold = 0;
    productSalesToday.forEach((name, qty) {
      if (qty > maxSold) {
        maxSold = qty;
        bestSellingItem = name;
      }
    });

    liveSalesSummary = {
      'orders': orders,
      'profit': profit,
      'bestSellingItem': bestSellingItem,
    };
  }

  // [Fetch and cache advanced sales summary (by product and by category) for today]
  Future<void> updateAdvancedSalesSummary() async {
    final dbQuery = DatabaseQuery(db: DB, LOGS: HOMEPAGE_LOGS);
    final analytics = KioskAnalyticsService(dbQuery: dbQuery);

    final today = DateTime.now();
    final dateStr =
        "${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";

    // Product sales
    final productSalesToday = await analytics.getProductSalesCountForDate(
      dateStr,
    );

    // Category sales: group by category (requires fetching product info)
    final products = await dbQuery.fetchAllData('kiosk_product');
    final Map<String, String> productToCategory = {
      for (var p in products) p['name']: p['categories'],
    };
    final Map<String, int> categorySalesToday = {};
    productSalesToday.forEach((product, qty) {
      final category = productToCategory[product] ?? 'SET';
      categorySalesToday[category] = (categorySalesToday[category] ?? 0) + qty;
    });

    productSales = productSalesToday;
    categorySales = categorySalesToday;
  }

  // [Fetch and cache advanced sales summary (by product and by category) for a given range]
  Future<void> updateAdvancedSalesSummaryWithRange({
    required DateTime start,
    required DateTime end,
  }) async {
    final dbQuery = DatabaseQuery(db: DB, LOGS: HOMEPAGE_LOGS);
    final analytics = KioskAnalyticsService(dbQuery: dbQuery);

    // Product sales for range
    final List<Map<String, dynamic>> transactions = await dbQuery.fetchAllData(
      'kiosk_transaction',
    );
    final Map<String, int> productSalesRange = {};
    final Map<String, int> categorySalesRange = {};

    // Get product info for category mapping
    final products = await dbQuery.fetchAllData('kiosk_product');
    final Map<String, String> productToCategory = {
      for (var p in products) p['name']: p['categories'],
    };

    for (final row in transactions) {
      final ts = row['timestamp'];
      final dt = DateTime.fromMillisecondsSinceEpoch(ts * 1000);
      if (!dt.isBefore(start) && !dt.isAfter(end)) {
        final receiptList = row['receipt_list'];
        if (receiptList is String) {
          final List<dynamic> items = analytics.parseJsonList(receiptList);
          for (final item in items) {
            final name = item['name'] ?? '';
            final qty = item['quantity'] ?? 0;
            productSalesRange[name] =
                ((productSalesRange[name] ?? 0) + qty).toInt();
            final category = productToCategory[name] ?? 'SET';
            categorySalesRange[category] =
                ((categorySalesRange[category] ?? 0) + qty).toInt();
          }
        }
      }
    }

    productSales = productSalesRange;
    categorySales = categorySalesRange;
  }

  // [300625] [Payment method summary for a given range]
  Future<void> updatePaymentMethodSummaryWithRange({
    required DateTime start,
    required DateTime end,
  }) async {
    final dbQuery = DatabaseQuery(db: DB, LOGS: HOMEPAGE_LOGS);
    final List<Map<String, dynamic>> transactions = await dbQuery.fetchAllData(
      'kiosk_transaction',
    );
    final Map<String, Map<String, dynamic>> summary = {};

    for (final row in transactions) {
      final ts = row['timestamp'];
      final dt = DateTime.fromMillisecondsSinceEpoch(ts * 1000);
      if (!dt.isBefore(start) && !dt.isAfter(end)) {
        final method = row['payment_method'] ?? 'Unknown';
        final amount =
            (row['total_amount'] is num)
                ? (row['total_amount'] as num).toDouble()
                : double.tryParse(row['total_amount']?.toString() ?? '') ?? 0.0;
        summary[method] ??= {'count': 0, 'total': 0.0};
        summary[method]!['count'] += 1;
        summary[method]!['total'] += amount;
      }
    }
    paymentMethodSummary = summary;
  }

  // [300625] [Export combined report for a given range in specified format]
  Future<File> exportCombinedReport({
    required DateTime start,
    required DateTime end,
    required String format, // 'txt' or 'pdf'
  }) async {
    final analytics = KioskAnalyticsService(
      dbQuery: DatabaseQuery(db: DB, LOGS: HOMEPAGE_LOGS),
    );
    // Fetch inventory changes for the range
    final inventoryChange = await analytics.getInventoryChangeForRange(
      start,
      end,
    );

    if (format == 'txt') {
      return analytics.generateCombinedReportTxt(
        start: start,
        end: end,
        productSales: productSales,
        categorySales: categorySales,
        paymentSummary: paymentMethodSummary,
        inventoryChange: inventoryChange,
      );
    } else {
      return analytics.generateCombinedReportPdf(
        start: start,
        end: end,
        productSales: productSales,
        categorySales: categorySales,
        paymentSummary: paymentMethodSummary,
        inventoryChange: inventoryChange,
      );
    }
  }
}
