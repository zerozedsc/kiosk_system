import '../../configs/configs.dart';
import '../../services/database/db.dart';
import '../../components/toastmsg.dart';

// ignore: non_constant_identifier_names
late LoggingService HOMEPAGE_LOGS;
late HomepageService homepageService;

class HomepageService {
  static final HomepageService _instance = HomepageService._internal();
  Map<String, Map<String, dynamic>> employeeMap = {}; // id as key
  Map<String, Map<String, dynamic>> attendanceMaps = {};

  factory HomepageService() {
    return _instance;
  }

  HomepageService._internal();

  /// Initializes and preloads all employee data into memory as a Map.
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

  /// Retrieves and Saving employee attendance data
  Future<dynamic> attendanceSetGetter({
    Map<String, dynamic>? attendanceData,
  }) async {
    try {
      // Check if a record exists for this employee_id and date
      final dbQuery = DatabaseQuery(db: DB, LOGS: HOMEPAGE_LOGS);
      List<Map<String, dynamic>> existing = [];
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

      // If attendanceData is provided, update or insert into employee_attendance
      final String employeeId = attendanceData['id'].toString();
      final String date = attendanceData['date'].toString();
      existing = await dbQuery.fetchDataWhere(
        'employee_attendance',
        'employee_id = ? AND date = ?',
        [employeeId, date],
      );

      if (existing.isNotEmpty) {
        final existingRecord = existing.first;
        final prevClockIn = existingRecord['clock_in'] ?? "";

        // If clock_in is already set, do not update clock_in again
        if (prevClockIn != "" &&
            attendanceData['clock_in'] != "" &&
            prevClockIn != attendanceData['clock_in']) {
          HOMEPAGE_LOGS.info(
            'Clock-in already exists for employee_id: $employeeId, date: $date. Not updating clock_in.',
          );
          return "clock_in_already_exists";
        }

        // If updating clock_out and clock_in exists, calculate total_hour
        double totalHour =
            (existingRecord['total_hour'] is num)
                ? (existingRecord['total_hour'] as num).toDouble()
                : double.tryParse(
                      existingRecord['total_hour']?.toString() ?? '',
                    ) ??
                    0.0;
        String newClockOut = attendanceData['clock_out'] ?? "";

        if (prevClockIn != "" && newClockOut != "") {
          // Calculate total_hour (assume format 'HH:mm')
          try {
            final inParts = prevClockIn.split(':');
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

        HOMEPAGE_LOGS.debug(
          'Updating attendance: ${HOMEPAGE_LOGS.map2str(existingRecord)}',
        );

        await dbQuery.updateData('employee_attendance', existingRecord['id'], {
          // Only update clock_in if it was empty before
          if (prevClockIn == "" && attendanceData['clock_in'] != "")
            'clock_in': attendanceData['clock_in'],
          // Only update clock_out if provided
          if (attendanceData['clock_out'] != "")
            'clock_out': attendanceData['clock_out'],
          // Always update total_hour if clock_out is set
          if (prevClockIn != "" && attendanceData['clock_out'] != "")
            'total_hour': double.parse(totalHour.toStringAsFixed(3)),
        });

        HOMEPAGE_LOGS.info(
          'Attendance updated for employee_id: $employeeId, date: $date',
        );

        return "attendance_updated";
      } else {
        // Insert new record
        await dbQuery.insertNewData('employee_attendance', {
          'employee_id': employeeId,
          'date': date,
          'clock_in': attendanceData['clock_in'],
          'clock_out': attendanceData['clock_out'],
          'total_hour': attendanceData['total_hour'],
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
}
