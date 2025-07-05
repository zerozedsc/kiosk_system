import '../../configs/configs.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../database/db.dart';
import '../database/model_sqlite.dart';

/// [300625] Analytics and reporting service for the kiosk system.
/// Provides sales, inventory, and attendance analytics using the main tables:
/// - kiosk_transaction
/// - inventory_transaction
/// - employee_attendance
///
/// All methods use the DatabaseQuery class for type-safe access.
class KioskAnalyticsService {
  final DatabaseQuery dbQuery;

  KioskAnalyticsService({required this.dbQuery});

  // [SALES ANALYTICS]
  /// Returns total sales amount for a given date (YYYY-MM-DD).
  Future<double> getTotalSalesForDate(String date) async {
    // Get all transactions for the date
    final List<Map<String, dynamic>> rows = await dbQuery.fetchAllData(
      'kiosk_transaction',
    );
    double total = 0.0;
    for (final row in rows) {
      final ts = row['timestamp'];
      final dt = DateTime.fromMillisecondsSinceEpoch(ts * 1000);
      final dateStr =
          "${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";
      if (dateStr == date) {
        total +=
            (row['total_amount'] is int)
                ? (row['total_amount'] as int).toDouble()
                : (row['total_amount'] as double);
      }
    }
    return total;
  }

  /// Returns total sales for a date range (inclusive).
  Future<double> getTotalSalesForRange(DateTime start, DateTime end) async {
    final List<Map<String, dynamic>> rows = await dbQuery.fetchAllData(
      'kiosk_transaction',
    );
    double total = 0.0;
    for (final row in rows) {
      final ts = row['timestamp'];
      final dt = DateTime.fromMillisecondsSinceEpoch(ts * 1000);
      if (!dt.isBefore(start) && !dt.isAfter(end)) {
        total +=
            (row['total_amount'] is int)
                ? (row['total_amount'] as int).toDouble()
                : (row['total_amount'] as double);
      }
    }
    return total;
  }

  /// Returns a map of product name to quantity sold for a given date.
  Future<Map<String, int>> getProductSalesCountForDate(String date) async {
    final List<Map<String, dynamic>> rows = await dbQuery.fetchAllData(
      'kiosk_transaction',
    );
    final Map<String, int> productCount = {};
    for (final row in rows) {
      final ts = row['timestamp'];
      final dt = DateTime.fromMillisecondsSinceEpoch(ts * 1000);
      final dateStr =
          "${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";
      if (dateStr == date) {
        final receiptList = row['receipt_list'];
        if (receiptList is String) {
          final List<dynamic> items = parseJsonList(receiptList);
          for (final item in items) {
            final name = item['name'] ?? '';
            final qty = item['quantity'] ?? 0;
            productCount[name] = ((productCount[name] ?? 0) + qty).toInt();
          }
        }
      }
    }
    return productCount;
  }

  // [INVENTORY ANALYTICS]
  /// Returns inventory changes for a given date as a map of productId to stock/pieces used.
  Future<Map<String, Map<String, dynamic>>> getInventoryChangeForDate(
    String date,
  ) async {
    final List<Map<String, dynamic>> rows = await dbQuery.fetchDataWhere(
      'inventory_transaction',
      'date = ?',
      [date],
    );
    if (rows.isEmpty) return {};
    // There could be multiple transactions per day, merge them
    final Map<String, Map<String, dynamic>> result = {};
    for (final row in rows) {
      final dataStr = row['data'];
      if (dataStr is String) {
        final Map<String, dynamic> data = parseJsonMap(dataStr);
        data.forEach((productId, change) {
          if (result.containsKey(productId)) {
            // Sum up stocks and pieces used
            result[productId]!['total_stocks'] += change['total_stocks'] ?? 0;
            result[productId]!['total_pieces_used'] +=
                change['total_pieces_used'] ?? 0;
          } else {
            result[productId] = {
              'total_stocks': change['total_stocks'] ?? 0,
              'total_pieces_used': change['total_pieces_used'] ?? 0,
            };
          }
        });
      }
    }
    return result;
  }

  /// [300625] Returns inventory changes for a date range (inclusive).
  Future<Map<String, Map<String, dynamic>>> getInventoryChangeForRange(
    DateTime start,
    DateTime end,
  ) async {
    final List<Map<String, dynamic>> rows = await dbQuery.fetchAllData(
      'inventory_transaction',
    );
    final Map<String, Map<String, dynamic>> result = {};
    final startDate = DateTime(start.year, start.month, start.day);
    final endDate = DateTime(end.year, end.month, end.day);
    for (final row in rows) {
      final dateStr = row['date'];
      final dt = DateTime.tryParse(dateStr);
      if (dt != null) {
        final dtDate = DateTime(dt.year, dt.month, dt.day);
        if (!dtDate.isBefore(startDate) && !dtDate.isAfter(endDate)) {
          final dataStr = row['data'];
          if (dataStr is String) {
            final Map<String, dynamic> data = parseJsonMap(dataStr);
            data.forEach((productId, change) {
              if (result.containsKey(productId)) {
                result[productId]!['total_stocks'] +=
                    change['total_stocks'] ?? 0;
                result[productId]!['total_pieces_used'] +=
                    change['total_pieces_used'] ?? 0;
              } else {
                result[productId] = {
                  'total_stocks': change['total_stocks'] ?? 0,
                  'total_pieces_used': change['total_pieces_used'] ?? 0,
                };
              }
            });
          }
        }
      }
    }
    return result;
  }

  // [ATTENDANCE ANALYTICS]
  /// Returns total hours worked by all employees for a given date.
  Future<double> getTotalAttendanceHoursForDate(String date) async {
    final List<Map<String, dynamic>> rows = await dbQuery.fetchDataWhere(
      'employee_attendance',
      'date = ?',
      [date],
    );
    double total = 0.0;
    for (final row in rows) {
      final hours = row['total_hour'];
      if (hours != null) {
        total += (hours is int) ? hours.toDouble() : hours;
      }
    }
    return total;
  }

  /// Returns a map of employeeId to total hours worked for a date range.
  Future<Map<String, double>> getAttendanceHoursForRange(
    DateTime start,
    DateTime end,
  ) async {
    final List<Map<String, dynamic>> rows = await dbQuery.fetchAllData(
      'employee_attendance',
    );
    final Map<String, double> result = {};
    for (final row in rows) {
      final dateStr = row['date'];
      final dt = DateTime.tryParse(dateStr);
      if (dt != null && !dt.isBefore(start) && !dt.isAfter(end)) {
        final empId = row['employee_id'].toString();
        final hours = row['total_hour'];
        final h = (hours is int) ? hours.toDouble() : (hours ?? 0.0);
        result[empId] = (result[empId] ?? 0.0) + h;
      }
    }
    return result;
  }

  // [COMBINED ANALYTICS]
  /// Returns a daily sales summary for a date range.
  Future<List<DailySalesSummary>> getDailySalesSummary(
    DateTime start,
    DateTime end,
  ) async {
    final List<Map<String, dynamic>> rows = await dbQuery.fetchAllData(
      'kiosk_transaction',
    );
    final Map<String, double> dailyTotals = {};
    for (final row in rows) {
      final ts = row['timestamp'];
      final dt = DateTime.fromMillisecondsSinceEpoch(ts * 1000);
      if (!dt.isBefore(start) && !dt.isAfter(end)) {
        final dateStr =
            "${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";
        final amt =
            (row['total_amount'] is int)
                ? (row['total_amount'] as int).toDouble()
                : (row['total_amount'] as double);
        dailyTotals[dateStr] = (dailyTotals[dateStr] ?? 0.0) + amt;
      }
    }
    return dailyTotals.entries
        .map((e) => DailySalesSummary(date: e.key, totalSales: e.value))
        .toList();
  }

  /// Returns a best-selling product list for a date range.
  Future<List<ProductSalesSummary>> getBestSellingProducts(
    DateTime start,
    DateTime end,
  ) async {
    final List<Map<String, dynamic>> rows = await dbQuery.fetchAllData(
      'kiosk_transaction',
    );
    final Map<String, int> productCount = {};
    for (final row in rows) {
      final ts = row['timestamp'];
      final dt = DateTime.fromMillisecondsSinceEpoch(ts * 1000);
      if (!dt.isBefore(start) && !dt.isAfter(end)) {
        final receiptList = row['receipt_list'];
        if (receiptList is String) {
          final List<dynamic> items = parseJsonList(receiptList);
          for (final item in items) {
            final name = item['name'] ?? '';
            final qty = item['quantity'] ?? 0;
            productCount[name] = ((productCount[name] ?? 0) + qty).toInt();
          }
        }
      }
    }
    return productCount.entries
        .map(
          (e) => ProductSalesSummary(productName: e.key, quantitySold: e.value),
        )
        .toList()
      ..sort((a, b) => b.quantitySold.compareTo(a.quantitySold));
  }

  // [300625] [COMBINED REPORTS]
  // --- Helper: Product ID to Name Map ---
  Future<Map<String, String>> _getProductIdNameMap() async {
    final List<Map<String, dynamic>> rows = await dbQuery.fetchAllData(
      'kiosk_product',
    );
    final Map<String, String> idNameMap = {};
    for (final row in rows) {
      idNameMap[row['id'].toString()] = row['name'];
    }
    return idNameMap;
  }

  // --- Helper: Get Low Stock Products ---
  Future<List<Map<String, dynamic>>> _getLowStockProducts({
    int threshold = 5,
  }) async {
    final List<Map<String, dynamic>> rows = await dbQuery.fetchAllData(
      'kiosk_product',
    );
    return rows.where((row) => (row['total_stocks'] ?? 0) < threshold).toList();
  }

  // --- Helper: Get Product Sales Total for Date Range ---
  Future<Map<String, double>> getProductSalesTotalForRange(
    DateTime start,
    DateTime end,
  ) async {
    final List<Map<String, dynamic>> rows = await dbQuery.fetchAllData(
      'kiosk_transaction',
    );

    // Build name->price maps for both tables
    final List<Map<String, dynamic>> kioskProducts = await dbQuery.fetchAllData(
      'kiosk_product',
    );
    final List<Map<String, dynamic>> setProducts = await dbQuery.fetchAllData(
      'set_product',
    );
    final Map<String, num> nameToPrice = {
      for (final row in kioskProducts) row['name']: row['price'],
      for (final row in setProducts) row['name']: row['price'],
    };

    final Map<String, double> productTotal = {};
    for (final row in rows) {
      final ts = row['timestamp'];
      final dt = DateTime.fromMillisecondsSinceEpoch(ts * 1000);
      if (!dt.isBefore(start) && !dt.isAfter(end)) {
        final receiptList = row['receipt_list'];
        if (receiptList is String) {
          final List<dynamic> items = parseJsonList(receiptList);
          for (final item in items) {
            final name = item['name'] ?? '';
            final qty = (item['quantity'] ?? 0) as num;
            // Use price from DB, fallback to item['price'] if not found
            final price = nameToPrice[name] ?? (item['price'] ?? 0.0) as num;
            productTotal[name] = (productTotal[name] ?? 0.0) + (qty * price);
          }
        }
      }
    }
    return productTotal;
  }

  // --- Combined TXT Report ---
  Future<File> generateCombinedReportTxt({
    required DateTime start,
    required DateTime end,
    required Map<String, int> productSales,
    required Map<String, int> categorySales,
    required Map<String, Map<String, dynamic>> paymentSummary,
    required Map<String, Map<String, dynamic>> inventoryChange,
  }) async {
    final idNameMap = await _getProductIdNameMap();
    final lowStockProducts = await _getLowStockProducts();
    final buffer = StringBuffer();
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');

    buffer.writeln("===============================================");
    Map<String, double> productSalesTotal = await getProductSalesTotalForRange(
      start,
      end,
    );
    buffer.writeln("   COMBINED SALES & INVENTORY REPORT");
    buffer.writeln("===============================================");
    buffer.writeln(
      "Kiosk ID: ${globalAppConfig['kiosk_info']['kiosk_id'] ?? 'N/A'}",
    );
    buffer.writeln(
      "Kiosk Name: ${globalAppConfig['kiosk_info']['kiosk_name'] ?? 'N/A'}",
    );
    buffer.writeln(
      "Period: ${dateFormat.format(start)} to ${dateFormat.format(end)}",
    );
    buffer.writeln("Generated on: ${dateFormat.format(DateTime.now())}");
    buffer.writeln();

    buffer.writeln("---------- Sales by Product ----------");
    if (productSales.isEmpty) {
      buffer.writeln("No product sales in this period.");
    } else {
      buffer.writeln("Product Name                 | Qty Sold | Total Price");
      buffer.writeln("-----------------------------------------------");
      productSales.forEach((k, v) {
        final total = productSalesTotal[k] ?? 0.0;
        buffer.writeln(
          "- ${k.padRight(28)} | ${v.toString().padLeft(8)} | ${total.toStringAsFixed(2).padLeft(11)}",
        );
      });
    }
    buffer.writeln();
    buffer.writeln("---------- Sales by Category ----------");
    if (categorySales.isEmpty) {
      buffer.writeln("No category sales in this period.");
    } else {
      categorySales.forEach(
        (k, v) => buffer.writeln("- ${k.padRight(30)}: $v items"),
      );
    }
    buffer.writeln();
    buffer.writeln("---------- Payment Methods Summary ----------");
    if (paymentSummary.isEmpty) {
      buffer.writeln("No payment data in this period.");
    } else {
      paymentSummary.forEach((k, v) {
        final count = v['count'];
        final total = (v['total'] as double).toStringAsFixed(2);
        buffer.writeln(
          "- ${k.padRight(20)} | Transactions: ${' ' * (5 - count.toString().length)}$count | Total: $total",
        );
      });
    }
    buffer.writeln();
    buffer.writeln("---------- Inventory Changes ----------");
    if (inventoryChange.isEmpty) {
      buffer.writeln("No inventory changes in this period.");
    } else {
      buffer.writeln("  Product Name               | Used Stock | Used Piece");
      buffer.writeln("  ----------------------------------------------------");
      inventoryChange.forEach((id, v) {
        final name = idNameMap[id] ?? 'Product $id';
        final usedStock = v['total_stocks'];
        final usedPiece = v['total_pieces_used'];
        buffer.writeln(
          "- ${name.padRight(25)} | ${usedStock.toString().padLeft(9)} | ${usedPiece.toString().padLeft(9)}",
        );
      });
    }
    buffer.writeln();

    // Low Stock Warning at the bottom
    buffer.writeln("---------- Low Stock Warning (< 5) ----------");
    if (lowStockProducts.isEmpty) {
      buffer.writeln("All products have sufficient stock.");
    } else {
      buffer.writeln("Product Name                 | Remaining Stock");
      buffer.writeln("---------------------------------------------");
      for (final row in lowStockProducts) {
        buffer.writeln(
          "- ${row['name'].toString().padRight(28)} | ${row['total_stocks'].toString().padLeft(15)}",
        );
      }
    }
    buffer.writeln();
    buffer.writeln("--- End of Report ---");

    final dir = await getTemporaryDirectory();
    String kioskId =
        globalAppConfig['kiosk_info']['kiosk_id'] ?? 'KIOSKNAMENOTFOUND';
    final file = File(
      '${dir.path}/${kioskId}_report_${DateTime.now().millisecondsSinceEpoch}.txt',
    );
    return file.writeAsString(buffer.toString());
  }

  // --- Combined PDF Report ---
  Future<File> generateCombinedReportPdf({
    required DateTime start,
    required DateTime end,
    required Map<String, int> productSales,

    required Map<String, int> categorySales,
    required Map<String, Map<String, dynamic>> paymentSummary,
    required Map<String, Map<String, dynamic>> inventoryChange,
  }) async {
    final idNameMap = await _getProductIdNameMap();
    final lowStockProducts = await _getLowStockProducts();
    final pdf = pw.Document();
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');

    final headerStyle = pw.TextStyle(
      fontSize: 11,
      fontWeight: pw.FontWeight.bold,
    );
    final bodyStyle = const pw.TextStyle(fontSize: 10);

    final kioskId = globalAppConfig['kiosk_info']['kiosk_id'] ?? 'N/A';
    final kioskName = globalAppConfig['kiosk_info']['kiosk_name'] ?? 'N/A';

    Map<String, double> productSalesTotal = await getProductSalesTotalForRange(
      start,
      end,
    );

    pdf.addPage(
      pw.MultiPage(
        header:
            (context) => pw.Container(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                'Page ${context.pageNumber} of ${context.pagesCount}',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey),
              ),
            ),
        build:
            (context) => [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Combined Sales & Inventory Report',
                    style: pw.TextStyle(
                      fontSize: 22,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Kiosk ID: $kioskId',
                    style: const pw.TextStyle(
                      fontSize: 12,
                      color: PdfColors.grey700,
                    ),
                  ),
                  pw.Text(
                    'Kiosk Name: $kioskName',
                    style: const pw.TextStyle(
                      fontSize: 12,
                      color: PdfColors.grey700,
                    ),
                  ),
                  pw.Text(
                    'Period: ${dateFormat.format(start)} to ${dateFormat.format(end)}',
                    style: const pw.TextStyle(
                      fontSize: 12,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
              ),
              pw.Divider(height: 30),

              // Sales by Product (with total price)
              pw.Text(
                'Sales by Product',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Table.fromTextArray(
                headers: ['Product', 'Quantity Sold', 'Total Price'],
                headerStyle: headerStyle,
                cellStyle: bodyStyle,
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.center,
                  2: pw.Alignment.centerRight,
                },
                data:
                    productSales.entries
                        .map(
                          (e) => [
                            e.key,
                            e.value.toString(),
                            (productSalesTotal[e.key] ?? 0.0).toStringAsFixed(
                              2,
                            ),
                          ],
                        )
                        .toList(),
              ),
              pw.SizedBox(height: 20),

              pw.Text(
                'Sales by Category',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Table.fromTextArray(
                headers: ['Category', 'Items Sold'],
                headerStyle: headerStyle,
                cellStyle: bodyStyle,
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.center,
                },
                data:
                    categorySales.entries
                        .map((e) => [e.key, e.value.toString()])
                        .toList(),
              ),
              pw.SizedBox(height: 20),

              pw.Text(
                'Payment Methods Summary',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Table.fromTextArray(
                headers: ['Method', 'Transactions', 'Total Amount'],
                headerStyle: headerStyle,
                cellStyle: bodyStyle,
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.center,
                  2: pw.Alignment.centerRight,
                },
                data:
                    paymentSummary.entries
                        .map(
                          (e) => [
                            e.key,
                            e.value['count'].toString(),
                            (e.value['total'] as double).toStringAsFixed(2),
                          ],
                        )
                        .toList(),
              ),
              pw.SizedBox(height: 20),

              pw.Text(
                'Inventory Changes',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Table.fromTextArray(
                headers: ['Product Name', 'Used Stock', 'Used Piece'],
                headerStyle: headerStyle,
                cellStyle: bodyStyle,
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.center,
                  2: pw.Alignment.center,
                },
                data:
                    inventoryChange.entries.map((e) {
                      final name = idNameMap[e.key] ?? 'Product ${e.key}';
                      return [
                        name,
                        e.value['total_stocks'].toString(),
                        e.value['total_pieces_used'].toString(),
                      ];
                    }).toList(),
              ),
              pw.SizedBox(height: 20),

              // Low Stock Warning at the bottom
              pw.Text(
                'Low Stock Warning (< 5)',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.red,
                ),
              ),
              pw.SizedBox(height: 8),
              if (lowStockProducts.isEmpty)
                pw.Text('All products have sufficient stock.', style: bodyStyle)
              else
                pw.Table.fromTextArray(
                  headers: ['Product Name', 'Remaining Stock'],
                  headerStyle: headerStyle,
                  cellStyle: bodyStyle,
                  cellAlignments: {
                    0: pw.Alignment.centerLeft,
                    1: pw.Alignment.center,
                  },
                  data:
                      lowStockProducts
                          .map(
                            (row) => [
                              row['name'],
                              row['total_stocks'].toString(),
                            ],
                          )
                          .toList(),
                ),
            ],
      ),
    );

    final dir = await getTemporaryDirectory();
    String fileKioskId = kioskId == 'N/A' ? 'KIOSKNAMENOTFOUND' : kioskId;
    final file = File(
      '${dir.path}/${fileKioskId}_report_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  // [--- JSON helpers ---]
  List<dynamic> parseJsonList(String jsonStr) {
    try {
      return jsonStr.isNotEmpty ? List<dynamic>.from(json.decode(jsonStr)) : [];
    } catch (_) {
      return [];
    }
  }

  Map<String, dynamic> parseJsonMap(String jsonStr) {
    try {
      return jsonStr.isNotEmpty
          ? Map<String, dynamic>.from(json.decode(jsonStr))
          : {};
    } catch (_) {
      return {};
    }
  }
}

/// [300625] Data class for daily sales summary.
class DailySalesSummary {
  final String date;
  final double totalSales;
  DailySalesSummary({required this.date, required this.totalSales});
}

/// [300625] Data class for product sales summary.
class ProductSalesSummary {
  final String productName;
  final int quantitySold;
  ProductSalesSummary({required this.productName, required this.quantitySold});
}

/// [02072025] Service for generating and sharing attendance reports.
class AttendanceReportingService {
  /// Generates a PDF document from attendance data and initiates sharing.
  Future<void> exportToPdf({
    required BuildContext context,
    required List<Map<String, dynamic>> attendanceRows,
    required String employeeName,
    required String employeeId,
    required int year,
    required int month,
    required double totalHours,
  }) async {
    try {
      final pdfBytes = await _generateAttendancePdf(
        attendanceRows: attendanceRows,
        employeeName: employeeName,
        year: year,
        month: month,
        totalHours: totalHours,
      );

      final tempDir = await getTemporaryDirectory();
      final fileName = 'attendance_${employeeId}_${year}_$month.pdf';
      final file = await File('${tempDir.path}/$fileName').create();
      await file.writeAsBytes(pdfBytes);

      await Share.shareXFiles([
        XFile(file.path),
      ], text: 'Attendance Report for $employeeName ($year-$month)');
    } catch (e) {
      // Handle potential errors, e.g., show a toast message
      print('Failed to export PDF: $e');
    }
  }

  /// Generates a CSV file from attendance data and initiates sharing.
  Future<void> exportToCsv({
    required BuildContext context,
    required List<Map<String, dynamic>> attendanceRows,
    required String employeeName,
    required String employeeId,
    required int year,
    required int month,
    required double totalHours,
  }) async {
    try {
      final csvData = await _generateAttendanceCsv(
        attendanceRows: attendanceRows,
        totalHours: totalHours,
      );

      final tempDir = await getTemporaryDirectory();
      final fileName = 'attendance_${employeeId}_${year}_$month.csv';
      final file = await File('${tempDir.path}/$fileName').create();
      await file.writeAsString(csvData);

      await Share.shareXFiles([
        XFile(file.path),
      ], text: 'Attendance Report for $employeeName ($year-$month)');
    } catch (e) {
      // Handle potential errors
      print('Failed to export CSV: $e');
    }
  }

  /// Creates a CSV string from attendance data.
  Future<String> _generateAttendanceCsv({
    required List<Map<String, dynamic>> attendanceRows,
    required double totalHours,
  }) async {
    final buffer = StringBuffer();
    // Add headers
    buffer.writeln('Date,Clock In,Clock Out,Total Hours');
    // Add data rows
    for (final row in attendanceRows) {
      final date = row['date'] ?? '';
      final clockIn = row['clock_in'] ?? '';
      final clockOut = row['clock_out'] ?? '';
      final hours =
          double.tryParse(
            row['total_hour']?.toString() ?? '0',
          )?.toStringAsFixed(2) ??
          '0.00';
      buffer.writeln('$date,$clockIn,$clockOut,$hours');
    }
    // Add summary
    buffer.writeln('');
    buffer.writeln(',,,Total Hours: ${totalHours.toStringAsFixed(2)}');
    return buffer.toString();
  }

  /// Creates a PDF document as a Uint8List from attendance data.
  Future<Uint8List> _generateAttendancePdf({
    required List<Map<String, dynamic>> attendanceRows,
    required String employeeName,
    required int year,
    required int month,
    required double totalHours,
  }) async {
    final pdf = pw.Document();
    final monthName = DateFormat.MMMM().format(DateTime(0, month));

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build:
            (context) => [
              pw.Header(
                level: 0,
                child: pw.Text(
                  'Attendance Report - $employeeName',
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.Paragraph(text: 'Report for: $monthName $year'),
              pw.SizedBox(height: 20),
              pw.Table.fromTextArray(
                headers: ['Date', 'Clock In', 'Clock Out', 'Total Hours'],
                data:
                    attendanceRows.map((row) {
                      final date = row['date']?.toString() ?? '';
                      final clockIn = row['clock_in']?.toString() ?? '--:--';
                      final clockOut = row['clock_out']?.toString() ?? '--:--';
                      final hours =
                          double.tryParse(
                            row['total_hour']?.toString() ?? '0',
                          )?.toStringAsFixed(2) ??
                          '0.00';
                      return [date, clockIn, clockOut, '$hours h'];
                    }).toList(),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                cellStyle: const pw.TextStyle(),
                cellAlignment: pw.Alignment.center,
                cellAlignments: {0: pw.Alignment.centerLeft},
              ),
              pw.Divider(height: 20),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  'Total Working Hours: ${totalHours.toStringAsFixed(2)} h',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            ],
      ),
    );

    return pdf.save();
  }
}
