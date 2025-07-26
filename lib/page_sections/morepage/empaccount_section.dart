import '../../../../configs/configs.dart';
import 'package:intl/intl.dart';

import '../../services/auth/auth_service.dart';
import '../../services/database/db.dart';
import '../../services/analytics/analytics.dart';
import '../../services/server/kiosk_server.dart';

import '../../components/toastmsg.dart';
import '../../components/image.dart';

// [010725] Employee Account Section
class EmployeeAccountSection extends StatefulWidget {
  final ThemeData theme;
  final Color mainColor;
  final LoggingService LOGS;

  const EmployeeAccountSection({
    super.key,
    required this.theme,
    required this.mainColor,
    required this.LOGS,
  });

  @override
  State<EmployeeAccountSection> createState() => _EmployeeAccountSectionState();
}

class _EmployeeAccountSectionState extends State<EmployeeAccountSection> {
  Map<String, Map<String, dynamic>> employees = {};
  late LoggingService LOGS;

  @override
  void initState() {
    super.initState();
    LOGS = widget.LOGS;
    _loadEmployees();
  }

  Future<void> _loadEmployees() async {
    // Ensure EMPQUERY is properly initialized and force refresh from database
    await EMPQUERY.initialize(forceRefresh: true);
    setState(() {
      // Get only active employees for display (exist == 1 or "1")
      employees = Map.from(EMPQUERY.employees)..removeWhere(
        (key, value) => value['exist'] != 1 && value['exist'] != "1",
      );
    });

    LOGS.debug(
      'Loading employees - current cache size: ${EMPQUERY.employees.length}',
    );
  }

  // [02072025] [Employee Attendance Detail Dialog]
  Future<void> showAttendanceDetailDialog(
    BuildContext context,
    Map<String, dynamic> emp,
    String empId,
  ) async {
    DateTime now = DateTime.now();
    int selectedYear = now.year;
    int selectedMonth = now.month;
    List<Map<String, dynamic>> attendanceRows = [];
    double totalHours = 0.0;
    final theme = Theme.of(context);
    final mainColor = theme.colorScheme.primary;

    Future<void> fetchAttendance() async {
      final firstDay = DateTime(selectedYear, selectedMonth, 1);
      final lastDay = DateTime(selectedYear, selectedMonth + 1, 0);
      attendanceRows = await DB.rawQuery(
        '''
      SELECT date, clock_in, clock_out, total_hour
      FROM employee_attendance
      WHERE employee_id = ? AND date >= ? AND date <= ?
      ORDER BY date ASC
      ''',
        [
          empId,
          "${firstDay.toIso8601String().substring(0, 10)}",
          "${lastDay.toIso8601String().substring(0, 10)}",
        ],
      );
      totalHours = 0.0;
      for (var row in attendanceRows) {
        final th = row['total_hour'];
        if (th != null) {
          totalHours += double.tryParse(th.toString()) ?? 0.0;
        }
      }
    }

    await fetchAttendance();

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            String getMonthName(int month) {
              // Uses intl package for accurate month names
              return DateFormat.MMMM().format(DateTime(0, month));
            }

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 8,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 500,
                  maxHeight: MediaQuery.of(context).size.height * 0.8,
                ),
                child: Column(
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
                      child: Row(
                        children: [
                          Icon(
                            Icons.person_pin_circle_outlined,
                            color: mainColor,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              "${emp["name"] ?? "Employee"} - ${LOCALIZATION.localize('main_word.attendance') ?? "Attendance"}",
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.of(context).pop(),
                            tooltip:
                                LOCALIZATION.localize('main_word.close') ??
                                "Close",
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, thickness: 1),

                    // Month/Year Picker
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          DropdownButton<int>(
                            value: selectedMonth,
                            underline: Container(),
                            items:
                                List.generate(12, (i) => i + 1)
                                    .map(
                                      (m) => DropdownMenuItem(
                                        value: m,
                                        child: Text(
                                          getMonthName(m),
                                          style: theme.textTheme.titleMedium,
                                        ),
                                      ),
                                    )
                                    .toList(),
                            onChanged: (m) async {
                              if (m != null) {
                                setDialogState(() => selectedMonth = m);
                                await fetchAttendance();
                                setDialogState(() {});
                              }
                            },
                          ),
                          const SizedBox(width: 16),
                          DropdownButton<int>(
                            value: selectedYear,
                            underline: Container(),
                            items:
                                List.generate(5, (i) => now.year - i)
                                    .map(
                                      (y) => DropdownMenuItem(
                                        value: y,
                                        child: Text(
                                          y.toString(),
                                          style: theme.textTheme.titleMedium,
                                        ),
                                      ),
                                    )
                                    .toList(),
                            onChanged: (y) async {
                              if (y != null) {
                                setDialogState(() => selectedYear = y);
                                await fetchAttendance();
                                setDialogState(() {});
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, thickness: 1),

                    // Content: Attendance List or Empty State
                    Expanded(
                      child:
                          attendanceRows.isEmpty
                              ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.calendar_month_outlined,
                                      size: 60,
                                      color: Colors.grey.shade400,
                                    ),
                                    const SizedBox(height: 16),

                                    Text(
                                      LOCALIZATION.localize(
                                            'main_word.no_data',
                                          ) ??
                                          "No attendance data for this month.",
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            color: Colors.grey.shade600,
                                          ),
                                    ),
                                  ],
                                ),
                              )
                              : ListView.separated(
                                padding: const EdgeInsets.all(16),
                                itemCount: attendanceRows.length,
                                separatorBuilder:
                                    (context, index) =>
                                        const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  final row = attendanceRows[index];
                                  final date = DateTime.tryParse(
                                    row['date']?.toString() ?? '',
                                  );
                                  final day =
                                      date?.day.toString().padLeft(2, '0') ??
                                      '??';
                                  final dayOfWeek =
                                      date != null
                                          ? DateFormat('EEE').format(date)
                                          : '---';

                                  return Container(
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.surfaceVariant
                                          .withOpacity(0.3),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: ListTile(
                                      leading: Container(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 8,
                                          horizontal: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          color: mainColor.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              day,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: mainColor,
                                                fontSize: 16,
                                              ),
                                            ),
                                            Text(
                                              dayOfWeek.toUpperCase(),
                                              style: TextStyle(
                                                color: mainColor,
                                                fontSize: 10,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      title: Row(
                                        children: [
                                          const Icon(
                                            Icons.login,
                                            size: 16,
                                            color: Colors.green,
                                          ),
                                          const SizedBox(width: 4),

                                          Text(
                                            row['clock_in']?.toString() ??
                                                '--:--',
                                          ),
                                          const SizedBox(width: 12),

                                          const Icon(
                                            Icons.logout,
                                            size: 16,
                                            color: Colors.redAccent,
                                          ),
                                          const SizedBox(width: 4),

                                          Text(
                                            row['clock_out']?.toString() ??
                                                '--:--',
                                          ),
                                        ],
                                      ),
                                      trailing: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            "${double.tryParse(row['total_hour']?.toString() ?? '0')?.toStringAsFixed(2) ?? '0.00'}h",
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),

                                          Text(
                                            LOCALIZATION.localize(
                                                  'main_word.total',
                                                ) ??
                                                "Total",
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                    ),

                    // Footer: Total Hours & Export
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        border: Border(
                          top: BorderSide(color: theme.dividerColor, width: 1),
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(
                            LOCALIZATION.localize('main_word.total_hours') ??
                                "Total Hours",
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            totalHours.toStringAsFixed(2),
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: mainColor,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.picture_as_pdf),
                            color: Colors.red.shade700,
                            tooltip: 'Export PDF',
                            onPressed: () async {
                              final reportingService =
                                  AttendanceReportingService();
                              await reportingService.exportToPdf(
                                context: context,
                                attendanceRows: attendanceRows,
                                employeeName: emp['name'] ?? 'Employee',
                                employeeId: empId,
                                year: selectedYear,
                                month: selectedMonth,
                                totalHours: totalHours,
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.table_rows_sharp),
                            color: Colors.green.shade700,
                            tooltip: 'Export CSV',
                            onPressed: () async {
                              final reportingService =
                                  AttendanceReportingService();
                              await reportingService.exportToCsv(
                                context: context,
                                attendanceRows: attendanceRows,
                                employeeName: emp['name'] ?? 'Employee',
                                employeeId: empId,
                                year: selectedYear,
                                month: selectedMonth,
                                totalHours: totalHours,
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // [080725] [Employee Account Section]
  // Enhanced employee dialog is now in ../../components/enhanced_employee_dialog.dart
  Future<void> showAddAdjustEmployeeDialog(
    BuildContext context,
    Color mainColor, {
    Map<String, dynamic>? employee,
    int empID = 0,
    required Function()
    setState, // Modified to be Function() instead of Function
  }) async {
    final _formKey = GlobalKey<FormState>();
    final TextEditingController usernameController = TextEditingController(
      text: employee?['username'] ?? '', // Username will be generated by server
    );
    final TextEditingController nameController = TextEditingController(
      text: employee?['name'] ?? '',
    );
    final TextEditingController ageController = TextEditingController(
      text: employee?['age']?.toString() ?? '',
    );
    final TextEditingController addressController = TextEditingController(
      text: employee?['address'] ?? '',
    );
    final TextEditingController phoneController = TextEditingController(
      text: employee?['phone_number'] ?? '',
    );
    final TextEditingController emailController = TextEditingController(
      text: employee?['email'] ?? '',
    );
    final TextEditingController descriptionController = TextEditingController(
      text: employee?['description'] ?? '',
    );
    final TextEditingController passwordController = TextEditingController(
      text: empID > 0 ? '' : EncryptService().generateStrongPassword(6),
    );

    Uint8List? imageBytes;

    if (employee != null && employee['image'] != null) {
      if (employee['image'] is Uint8List) {
        imageBytes = employee['image'] as Uint8List;
      } else if (employee['image'] is List<int>) {
        imageBytes = Uint8List.fromList(employee['image'] as List<int>);
      }
    } else {
      imageBytes = null;
    }

    // Add variables to track synchronization state
    bool isSyncing = false;
    bool isOnline = await kioskApiService.testConnection();

    Future<void> pickImage() async {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery);
      if (picked != null) {
        imageBytes = await picked.readAsBytes();
        imageBytes = await resizeImage(source: imageBytes);
      }
    }

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: LayoutBuilder(
                builder:
                    (context, constraints) => ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: 420,
                        minWidth: 320,
                        maxHeight: MediaQuery.of(context).size.height * 0.95,
                      ),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Title with sync indicator
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: Text(
                                      employee == null
                                          ? (LOCALIZATION.localize(
                                                'more_page.add_employee',
                                              ) ??
                                              "Add Employee")
                                          : (LOCALIZATION.localize(
                                                'more_page.adjust_employee',
                                              ) ??
                                              "Adjust Employee"),
                                      style: Theme.of(
                                        context,
                                      ).textTheme.headlineSmall?.copyWith(
                                        color: mainColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  if (isOnline)
                                    Tooltip(
                                      message: "Data will sync with server",
                                      child: Icon(
                                        Icons.sync,
                                        color: Colors.green,
                                        size: 20,
                                      ),
                                    )
                                  else
                                    Tooltip(
                                      message:
                                          "Offline mode - Changes saved locally",
                                      child: Icon(
                                        Icons.sync_disabled,
                                        color: Colors.grey,
                                        size: 20,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 18),

                              // Image Picker (employee)
                              GestureDetector(
                                onTap: () async {
                                  await pickImage();
                                  setDialogState(() {});
                                },
                                child: CircleAvatar(
                                  radius: 40,
                                  backgroundColor: mainColor.withOpacity(0.12),
                                  backgroundImage:
                                      imageBytes != null
                                          ? MemoryImage(imageBytes!)
                                          : null,
                                  child:
                                      imageBytes == null
                                          ? Icon(
                                            Icons.camera_alt,
                                            color: mainColor,
                                            size: 32,
                                          )
                                          : null,
                                ),
                              ),
                              const SizedBox(height: 18),

                              // username (employee) - only show for existing employees
                              if (empID > 0)
                                TextFormField(
                                  controller: usernameController,
                                  enabled: false,
                                  decoration: InputDecoration(
                                    labelText:
                                        LOCALIZATION.localize(
                                          'auth_page.username',
                                        ) ??
                                        "Username",
                                    prefixIcon: const Icon(
                                      Icons.person_outline,
                                    ),
                                    border: const OutlineInputBorder(),
                                  ),
                                ),
                              if (empID > 0) const SizedBox(height: 12),

                              // name (employee)
                              TextFormField(
                                controller: nameController,
                                decoration: InputDecoration(
                                  labelText:
                                      LOCALIZATION.localize('main_word.name') ??
                                      "Name",
                                  prefixIcon: const Icon(Icons.badge_outlined),
                                  border: const OutlineInputBorder(),
                                ),
                                validator:
                                    (v) =>
                                        (v == null || v.isEmpty)
                                            ? LOCALIZATION.localize(
                                                  'main_word.required',
                                                ) ??
                                                "Required"
                                            : null,
                              ),
                              const SizedBox(height: 12),

                              // age (employee)
                              TextFormField(
                                controller: ageController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText:
                                      LOCALIZATION.localize('main_word.age') ??
                                      "Age",
                                  prefixIcon: const Icon(Icons.cake_outlined),
                                  border: const OutlineInputBorder(),
                                ),
                                validator: (v) {
                                  if (v == null || v.isEmpty) {
                                    return LOCALIZATION.localize(
                                          'main_word.required',
                                        ) ??
                                        "Required";
                                  }
                                  final age = int.tryParse(v);
                                  if (age == null || age < 16 || age > 100) {
                                    return LOCALIZATION.localize(
                                          'main_word.invalid',
                                        ) ??
                                        "Invalid";
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),

                              // address (employee)
                              TextFormField(
                                controller: addressController,
                                decoration: InputDecoration(
                                  labelText:
                                      LOCALIZATION.localize(
                                        'main_word.address',
                                      ) ??
                                      "Address",
                                  prefixIcon: const Icon(Icons.home_outlined),
                                  border: const OutlineInputBorder(),
                                ),
                                validator:
                                    (v) =>
                                        (v == null || v.isEmpty)
                                            ? LOCALIZATION.localize(
                                                  'main_word.required',
                                                ) ??
                                                "Required"
                                            : null,
                              ),
                              const SizedBox(height: 12),

                              // phone number (employee)
                              TextFormField(
                                controller: phoneController,
                                keyboardType: TextInputType.phone,
                                decoration: InputDecoration(
                                  labelText:
                                      LOCALIZATION.localize(
                                        'main_word.phone_number',
                                      ) ??
                                      "Phone Number",
                                  prefixIcon: const Icon(Icons.phone_outlined),
                                  border: const OutlineInputBorder(),
                                ),
                                validator:
                                    (v) =>
                                        (v == null || v.isEmpty)
                                            ? LOCALIZATION.localize(
                                                  'main_word.required',
                                                ) ??
                                                "Required"
                                            : null,
                              ),
                              const SizedBox(height: 12),

                              // email (employee)
                              TextFormField(
                                controller: emailController,
                                keyboardType: TextInputType.emailAddress,
                                decoration: InputDecoration(
                                  labelText:
                                      LOCALIZATION.localize(
                                        'auth_page.email',
                                      ) ??
                                      "Email",
                                  prefixIcon: const Icon(Icons.email_outlined),
                                  border: const OutlineInputBorder(),
                                ),
                                validator: (v) {
                                  if (v == null || v.isEmpty) {
                                    return LOCALIZATION.localize(
                                          'main_word.required',
                                        ) ??
                                        "Required";
                                  }
                                  final emailRegex = RegExp(
                                    r'^[^@]+@[^@]+\.[^@]+',
                                  );
                                  if (!emailRegex.hasMatch(v)) {
                                    return LOCALIZATION.localize(
                                          'main_word.invalid',
                                        ) ??
                                        "Invalid";
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),

                              // password (employee) - only show for new employees
                              if (empID <= 0)
                                TextFormField(
                                  controller: passwordController,
                                  obscureText: true,
                                  decoration: InputDecoration(
                                    labelText:
                                        LOCALIZATION.localize(
                                          'auth_page.password',
                                        ) ??
                                        "Password",
                                    prefixIcon: const Icon(Icons.lock_outline),
                                    border: const OutlineInputBorder(),
                                  ),
                                  validator: (v) {
                                    // If adding new employee, password is required
                                    // If adjusting, password is optional (only required if not empty)
                                    if (employee == null) {
                                      return (v == null || v.isEmpty)
                                          ? LOCALIZATION.localize(
                                                'main_word.required',
                                              ) ??
                                              "Required"
                                          : null;
                                    } else {
                                      // If not empty, you can add more validation if needed (e.g. min length)
                                      return null;
                                    }
                                  },
                                  enabled: false,
                                ),
                              const SizedBox(height: 12),

                              // description (employee)
                              TextFormField(
                                controller: descriptionController,
                                maxLines: 2,
                                decoration: InputDecoration(
                                  labelText:
                                      LOCALIZATION.localize(
                                        'main_word.description',
                                      ) ??
                                      "Description",
                                  prefixIcon: const Icon(
                                    Icons.description_outlined,
                                  ),
                                  border: const OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Save and Cancel buttons with sync indicator
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton(
                                    onPressed:
                                        () => Navigator.of(context).pop(),
                                    child: Text(
                                      LOCALIZATION.localize(
                                            'main_word.cancel',
                                          ) ??
                                          "Cancel",
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  ElevatedButton.icon(
                                    icon:
                                        isSyncing
                                            ? SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                      Color
                                                    >(Colors.white),
                                              ),
                                            )
                                            : const Icon(Icons.save),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: mainColor,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    onPressed:
                                        isSyncing
                                            ? null
                                            : () async {
                                              if (_formKey.currentState
                                                      ?.validate() ??
                                                  false) {
                                                // Set syncing state
                                                setDialogState(() {
                                                  isSyncing = true;
                                                });

                                                try {
                                                  // Prepare employee data
                                                  final newEmployee = {
                                                    'name': nameController.text,
                                                    'age': int.tryParse(
                                                      ageController.text,
                                                    ),
                                                    'address':
                                                        addressController.text,
                                                    'phone_number':
                                                        phoneController.text,
                                                    'email':
                                                        emailController.text,
                                                    'description':
                                                        descriptionController
                                                            .text,
                                                    'password':
                                                        passwordController.text,
                                                    'exist': 1,
                                                    'image': imageBytes,
                                                  };

                                                  // Only add ID and username for updates (empID > 0 means editing existing employee)
                                                  bool isUpdate = empID > 0;
                                                  String?
                                                  serverAssignedUsername;

                                                  if (isUpdate) {
                                                    newEmployee['id'] = empID;
                                                    newEmployee['username'] =
                                                        usernameController.text;
                                                  }

                                                  LOGS.info(
                                                    '${isUpdate ? "Updating" : "Adding"} employee: ${newEmployee['name']}, empID: $empID',
                                                  );

                                                  // For new employees, try server sync first to get username
                                                  if (!isUpdate && isOnline) {
                                                    try {
                                                      // Create EmployeeData object for API
                                                      String kioskId =
                                                          globalAppConfig["kiosk_info"]["kiosk_id"] ??
                                                          "";
                                                      if (kioskId.isEmpty) {
                                                        throw Exception(
                                                          "Kiosk ID is not set in globalAppConfig",
                                                        );
                                                      }

                                                      final employeeData = EmployeeData(
                                                        kioskId: kioskId,
                                                        id: null, // New employee
                                                        username:
                                                            "", // Server will generate
                                                        name:
                                                            nameController.text,
                                                        age:
                                                            int.tryParse(
                                                              ageController
                                                                  .text,
                                                            ) ??
                                                            0,
                                                        address:
                                                            addressController
                                                                .text,
                                                        phoneNumber:
                                                            phoneController
                                                                .text,
                                                        email:
                                                            emailController
                                                                .text,
                                                        description:
                                                            descriptionController
                                                                .text,
                                                        password: EncryptService()
                                                            .encryptPasswordForServer(
                                                              passwordController
                                                                  .text,
                                                            ), // Hash password with SHA before sending to server
                                                        exist: true,
                                                        image: imageBytes,
                                                        isAdmin: false,
                                                      );

                                                      // Add employee to server first
                                                      final serverResponse =
                                                          await kioskApiService
                                                              .addEmployee(
                                                                employeeData,
                                                              );

                                                      // Extract username from server response
                                                      serverAssignedUsername =
                                                          serverResponse['username']
                                                              as String?;

                                                      if (serverAssignedUsername !=
                                                          null) {
                                                        newEmployee['username'] =
                                                            serverAssignedUsername;
                                                        LOGS.info(
                                                          'Server assigned username: $serverAssignedUsername',
                                                        );
                                                      } else {
                                                        throw Exception(
                                                          "Server did not return username",
                                                        );
                                                      }
                                                    } catch (e) {
                                                      LOGS.warning(
                                                        'Failed to sync with server first: $e. Saving locally with temp username.',
                                                      ); // Generate temporary username for local storage based on employee count
                                                      int empCount =
                                                          EMPQUERY
                                                              .employees
                                                              .length +
                                                          1;
                                                      newEmployee['username'] =
                                                          'TEMP$empCount';
                                                      serverAssignedUsername =
                                                          null;
                                                    }
                                                  } else if (!isUpdate) {
                                                    // Offline mode - generate temporary username based on employee count
                                                    int empCount =
                                                        EMPQUERY
                                                            .employees
                                                            .length +
                                                        1;
                                                    newEmployee['username'] =
                                                        'TEMP$empCount';
                                                  }

                                                  // Save to local database
                                                  final checkTransfer =
                                                      await EMPQUERY
                                                          .upsertEmployee(
                                                            newEmployee,
                                                          );

                                                  if (!checkTransfer) {
                                                    throw Exception(
                                                      "Failed to save employee locally",
                                                    );
                                                  }

                                                  LOGS.info(
                                                    'Local DB save result: $checkTransfer',
                                                  );

                                                  // For updates, sync with server after local save
                                                  if (isUpdate && isOnline) {
                                                    try {
                                                      String kioskId =
                                                          globalAppConfig["kiosk_info"]["kiosk_id"] ??
                                                          "";
                                                      if (kioskId.isEmpty) {
                                                        throw Exception(
                                                          "Kiosk ID is not set in globalAppConfig",
                                                        );
                                                      }

                                                      final employeeData = EmployeeData(
                                                        kioskId: kioskId,
                                                        id: empID,
                                                        username:
                                                            usernameController
                                                                .text,
                                                        name:
                                                            nameController.text,
                                                        age:
                                                            int.tryParse(
                                                              ageController
                                                                  .text,
                                                            ) ??
                                                            0,
                                                        address:
                                                            addressController
                                                                .text,
                                                        phoneNumber:
                                                            phoneController
                                                                .text,
                                                        email:
                                                            emailController
                                                                .text,
                                                        description:
                                                            descriptionController
                                                                .text,
                                                        password:
                                                            passwordController
                                                                    .text
                                                                    .isNotEmpty
                                                                ? EncryptService()
                                                                    .encryptPasswordForServer(
                                                                      passwordController
                                                                          .text,
                                                                    )
                                                                : employee?['password'] ??
                                                                    '', // Use existing password if not changing
                                                        exist: true,
                                                        image: imageBytes,
                                                        isAdmin: false,
                                                      );

                                                      // Use appropriate API method based on whether it's an update or new employee
                                                      if (isUpdate &&
                                                          usernameController
                                                              .text
                                                              .isNotEmpty) {
                                                        await kioskApiService
                                                            .updateEmployee(
                                                              usernameController
                                                                  .text,
                                                              employeeData,
                                                            );
                                                        LOGS.info(
                                                          'Server sync successful for employee update (Username: ${usernameController.text})',
                                                        );
                                                      } else {
                                                        await kioskApiService
                                                            .addEmployee(
                                                              employeeData,
                                                            );
                                                        LOGS.info(
                                                          'Server sync successful for new employee',
                                                        );
                                                      }
                                                    } catch (e) {
                                                      LOGS.warning(
                                                        'Failed to sync employee update with server: $e. Changes saved locally only.',
                                                      );
                                                      showToastMessage(
                                                        context,
                                                        LOCALIZATION.localize(
                                                              'more_page.sync_warning',
                                                            ) ??
                                                            "Employee updated locally but failed to sync with server",
                                                        ToastLevel.warning,
                                                      );
                                                    }
                                                  }

                                                  if (checkTransfer) {
                                                    // Refresh local employee data to reflect changes
                                                    await _loadEmployees();

                                                    // Show success message and employee details dialog for new employees
                                                    if (!isUpdate) {
                                                      if (serverAssignedUsername !=
                                                          null) {
                                                        // Successfully created on server
                                                        await showEmployeeCreatedDialog(
                                                          context,
                                                          serverAssignedUsername,
                                                          passwordController
                                                              .text,
                                                          nameController.text,
                                                          mainColor,
                                                        );
                                                      } else {
                                                        // Saved locally only
                                                        showSyncRetryNotification(
                                                          context,
                                                        );
                                                        showToastMessage(
                                                          context,
                                                          "Employee saved locally. Username will be assigned when server is available.",
                                                          ToastLevel.warning,
                                                        );
                                                      }
                                                    } else {
                                                      // Updated existing employee
                                                      showToastMessage(
                                                        context,
                                                        LOCALIZATION.localize(
                                                              'main_word.save_success',
                                                            ) ??
                                                            "Employee updated successfully!",
                                                        ToastLevel.success,
                                                      );
                                                    }
                                                    setState();
                                                  } else {
                                                    showToastMessage(
                                                      context,
                                                      LOCALIZATION.localize(
                                                            'main_word.save_failed',
                                                          ) ??
                                                          "Failed to save employee!",
                                                      ToastLevel.error,
                                                    );
                                                  }

                                                  Navigator.of(context).pop();
                                                } catch (e) {
                                                  // Handle errors
                                                  LOGS.error(
                                                    'Error saving employee: $e',
                                                  );
                                                  showToastMessage(
                                                    context,
                                                    "${LOCALIZATION.localize('main_word.error_occurred')}: ${e.toString()}" ??
                                                        "An error occurred: ${e.toString()}",
                                                    ToastLevel.error,
                                                  );

                                                  // Reset syncing state
                                                  setDialogState(() {
                                                    isSyncing = false;
                                                  });
                                                }
                                              }
                                            },
                                    label: Text(
                                      LOCALIZATION.localize('main_word.save') ??
                                          "Save",
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              // Connection status indicator
                              if (!isOnline)
                                Padding(
                                  padding: const EdgeInsets.only(top: 16.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.cloud_off,
                                        size: 16,
                                        color: Colors.grey,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        LOCALIZATION.localize(
                                              'main_word.offline_mode',
                                            ) ??
                                            "Offline Mode - Data will be synced when online",
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
              ),
            );
          },
        );
      },
    );
  }

  // Helper function to show employee creation success dialog
  Future<void> showEmployeeCreatedDialog(
    BuildContext context,
    String username,
    String password,
    String name,
    Color mainColor,
  ) async {
    bool isPasswordVisible = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 28),
                  const SizedBox(width: 12),
                  Text(
                    LOCALIZATION.localize(
                          'more_page.employee_created_success',
                        ) ??
                        "Employee Created Successfully",
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Employee '$name'${LOCALIZATION.localize('more_page.employee_created_success')}",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 20),

                  // Employee ID section
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: mainColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.person, color: mainColor),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Employee ID:",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            SelectableText(
                              username,
                              style: TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                        const Spacer(),
                        IconButton(
                          icon: Icon(Icons.copy),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: username));
                            showToastMessage(
                              context,
                              "Employee ID copied!",
                              ToastLevel.success,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Password section
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.lock, color: Colors.orange),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Password:",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            SelectableText(
                              isPasswordVisible
                                  ? password
                                  : "•" * password.length,
                              style: TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                        const Spacer(),
                        IconButton(
                          icon: Icon(
                            isPasswordVisible
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () {
                            setDialogState(() {
                              isPasswordVisible = !isPasswordVisible;
                            });
                          },
                        ),
                        IconButton(
                          icon: Icon(Icons.copy),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: password));
                            showToastMessage(
                              context,
                              "Password copied!",
                              ToastLevel.success,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Sync status important note
                  Text(
                    LOCALIZATION.localize(
                          'more_page.sync_status_important_note',
                        ) ??
                        "⚠️ Please save these credentials securely. The employee will need them to login.",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.orange.shade700,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(backgroundColor: mainColor),
                  child: Text("OK", style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Helper function to show sync retry notification
  Future<void> showSyncRetryNotification(BuildContext context) async {
    // This could be enhanced with a proper notification system
    showToastMessage(
      context,
      "Employee saved locally. Will retry server sync when connection is available.",
      ToastLevel.warning,
    );
  }

  // Retry sync for employees with temporary usernames
  Future<void> _retrySyncEmployee(
    String empId,
    Map<String, dynamic> emp,
    BuildContext context,
    Color mainColor,
  ) async {
    try {
      // Check if online
      bool isOnline = await kioskApiService.testConnection();
      if (!isOnline) {
        showToastMessage(
          context,
          "No internet connection available",
          ToastLevel.error,
        );
        return;
      }

      // Create EmployeeData for server sync
      String kioskId = globalAppConfig["kiosk_info"]["kiosk_id"] ?? "";
      if (kioskId.isEmpty) {
        throw Exception("Kiosk ID is not set in globalAppConfig");
      }

      final employeeData = EmployeeData(
        kioskId: kioskId,
        id: null, // New employee
        username: "", // Server will generate
        name: emp['name'] ?? '',
        age: emp['age'] ?? 0,
        address: emp['address'] ?? '',
        phoneNumber: emp['phone_number'] ?? '',
        email: emp['email'] ?? '',
        description: emp['description'] ?? '',
        password: EncryptService().encryptPasswordForServer(
          emp['password'] ?? '',
        ), // Hash password with SHA before sending to server
        exist: true,
        image:
            emp['image'] != null
                ? Uint8List.fromList(emp['image'] as List<int>)
                : null,
        isAdmin: false,
      );

      // Sync with server

      final serverResponse = await kioskApiService.addEmployee(employeeData);

      // Extract username from server response
      final serverAssignedUsername = serverResponse['username'] as String?;

      if (serverAssignedUsername != null) {
        // Update local database with server-assigned username
        final updatedEmployee = Map<String, dynamic>.from(emp);
        updatedEmployee['username'] = serverAssignedUsername;
        updatedEmployee['id'] = int.parse(empId);

        await EMPQUERY.upsertEmployee(updatedEmployee);
        await _loadEmployees();

        String empPassword = await EncryptService().decryptPassword(
          emp['password'],
        );
        // Show success dialog with new credentials
        await showEmployeeCreatedDialog(
          context,
          serverAssignedUsername,
          empPassword ?? '',
          emp['name'] ?? '',
          mainColor,
        );

        LOGS.info(
          'Successfully synced employee with server, new username: $serverAssignedUsername',
        );
      } else {
        throw Exception("Server did not return username");
      }
    } catch (e) {
      LOGS.error('Failed to retry sync employee: $e');
      showToastMessage(
        context,
        "Failed to sync with server: $e",
        ToastLevel.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final mainColor = widget.mainColor;

    return SingleChildScrollView(
      key: const ValueKey('employeeAccount'),
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            LOCALIZATION.localize('more_page.employee_account') ??
                "Employee Account",
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: mainColor,
            ),
          ),
          const SizedBox(height: 18),

          Card(
            elevation: 6,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            color: theme.colorScheme.surface,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Employee List Icon
                      Icon(Icons.group, color: mainColor),
                      const SizedBox(width: 12),

                      // Employee List Title
                      Text(
                        LOCALIZATION.localize('more_page.employee_list') ??
                            "Employee List",
                        style: theme.textTheme.titleMedium,
                      ),
                      const Spacer(),

                      // ADD EMPLOYEE
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: mainColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(Icons.person_add_alt_1),
                        label: Text(
                          LOCALIZATION.localize('more_page.add_employee') ??
                              "Add",
                        ),
                        onPressed: () async {
                          await showAddAdjustEmployeeDialog(
                            context,
                            mainColor,
                            setState: () async {
                              // The database layer already updates the employees map internally
                              // Just trigger UI refresh
                              await _loadEmployees();
                            },
                          );
                        },
                      ),
                    ],
                  ),
                  const Divider(height: 28),

                  // Employee List
                  if (employees.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20.0),
                      child: Center(
                        child: Text(
                          LOCALIZATION.localize(
                                'more_page.no_employees_found',
                              ) ??
                              "No employees found.",
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    )
                  else
                    ...employees.entries.map((entry) {
                      final String empId = entry.key;
                      final Map<String, dynamic> emp = entry.value;

                      // Iterate over the values of the map
                      final bool isActive =
                          emp["exist"] == 1 || emp["exist"] == "1";
                      final Color itemStatusColor =
                          isActive ? Colors.green : Colors.grey;
                      // Assuming emp["image"] is List<int> (from database) or null
                      final List<int>? imageBytes = emp["image"] as List<int>?;

                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 4.0),
                        decoration: BoxDecoration(
                          color: itemStatusColor.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          minVerticalPadding: 0,
                          leading:
                              (imageBytes != null && imageBytes.isNotEmpty)
                                  ? CircleAvatar(
                                    radius: 26,
                                    backgroundImage: MemoryImage(
                                      Uint8List.fromList(imageBytes),
                                    ),
                                  )
                                  : CircleAvatar(
                                    radius: 26,
                                    backgroundColor: mainColor.withOpacity(
                                      0.15,
                                    ),
                                    child: Icon(
                                      Icons.person,
                                      color: mainColor,
                                      size: 28,
                                    ),
                                  ),
                          title: Text(
                            emp["name"] ?? "N/A",
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("EMPLOYEE"),
                              if (emp["username"]?.toString().startsWith(
                                    "TEMP",
                                  ) ==
                                  true)
                                Row(
                                  children: [
                                    Icon(
                                      Icons.sync_problem,
                                      size: 14,
                                      color: Colors.orange,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      "Pending server sync",
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.orange.shade700,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Sync retry button for temporary employees
                              if (emp["username"]?.toString().startsWith(
                                    "TEMP",
                                  ) ==
                                  true)
                                IconButton(
                                  icon: Icon(Icons.sync, color: Colors.orange),
                                  tooltip: "Retry server sync",
                                  onPressed: () async {
                                    // Attempt to sync this employee with server
                                    await _retrySyncEmployee(
                                      empId,
                                      emp,
                                      context,
                                      mainColor,
                                    );
                                  },
                                ),

                              Builder(
                                builder: (context) {
                                  IconData statusIcon;
                                  String statusText;

                                  if (isActive) {
                                    statusIcon = Icons.check_circle_outline;
                                    statusText =
                                        LOCALIZATION
                                            .localize('main_word.active')
                                            ?.toUpperCase() ??
                                        "ACTIVE";
                                  } else {
                                    statusIcon = Icons.highlight_off_outlined;
                                    statusText =
                                        LOCALIZATION
                                            .localize('main_word.inactive')
                                            ?.toUpperCase() ??
                                        "INACTIVE";
                                  }

                                  return Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Icon(
                                        statusIcon,
                                        color: itemStatusColor,
                                        size: 20,
                                      ),
                                      const SizedBox(height: 2),

                                      Text(
                                        statusText,
                                        style: TextStyle(
                                          color: itemStatusColor,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                              const SizedBox(width: 16),

                              // edit employee button
                              IconButton(
                                icon: Icon(Icons.edit, color: mainColor),
                                tooltip:
                                    LOCALIZATION.localize(
                                      'more_page.edit_employee',
                                    ) ??
                                    "Edit",
                                onPressed: () async {
                                  // Prompt for admin password
                                  bool? confirmed = await AdminAuthDialog.show(
                                    context,
                                  );

                                  if (confirmed == true) {
                                    await showAddAdjustEmployeeDialog(
                                      context,
                                      mainColor,
                                      employee: emp,
                                      empID: int.parse(empId),
                                      setState: () async {
                                        await _loadEmployees();
                                      },
                                    );
                                  }
                                },
                              ),

                              // delete button
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.redAccent,
                                ),
                                tooltip:
                                    LOCALIZATION.localize(
                                      'more_page.delete_employee',
                                    ) ??
                                    "Delete",
                                onPressed: () async {
                                  // Prompt for admin password
                                  bool? confirmed = await AdminAuthDialog.show(
                                    context,
                                  );

                                  if (confirmed == true) {
                                    await kioskApiService.updateEmployee(
                                      emp["username"],
                                      EmployeeData(
                                        kioskId: emp["kiosk_id"] ?? "",
                                        id: int.parse(empId),
                                        username: emp["username"],
                                        name: emp["name"] ?? "",
                                        age: emp["age"] ?? 0,
                                        address: emp["address"] ?? "",
                                        phoneNumber: emp["phone_number"] ?? "",
                                        email: emp["email"] ?? "",
                                        description: emp["description"] ?? "",
                                        password: emp['password'] ?? '',
                                        exist: false, // Mark as deleted
                                        image: emp['image'],
                                        isAdmin: false,
                                      ),
                                    );

                                    final checkDelete = await EMPQUERY
                                        .deleteEmployee(empId);

                                    if (checkDelete) {
                                      await _loadEmployees();
                                      showToastMessage(
                                        context,
                                        "${LOCALIZATION.localize('more_page.delete_employee_msg')} for ${emp["username"]}",
                                        ToastLevel.warning,
                                      );
                                    } else {
                                      showToastMessage(
                                        context,
                                        LOCALIZATION.localize(
                                              'main_word.delete_failed',
                                            ) ??
                                            "Failed to delete employee",
                                        ToastLevel.error,
                                      );
                                    }
                                  }
                                },
                              ),

                              // show password button
                              IconButton(
                                icon: const Icon(
                                  Icons.visibility,
                                  color: Colors.blueAccent,
                                ),
                                tooltip:
                                    LOCALIZATION.localize(
                                      'main_word.show_password',
                                    ) ??
                                    "Show Password",
                                onPressed: () async {
                                  // Prompt for admin password
                                  bool? confirmed = await AdminAuthDialog.show(
                                    context,
                                  );

                                  if (confirmed == true) {
                                    // Decrypt and show the employee password
                                    String decrypted = "";
                                    try {
                                      decrypted = await EncryptService()
                                          .decryptPassword(emp['password']);
                                    } catch (e) {
                                      decrypted =
                                          LOCALIZATION.localize(
                                            'main_word.decrypt_failed',
                                          ) ??
                                          "Failed to decrypt password";
                                    }
                                    showDialog(
                                      context: context,
                                      builder:
                                          (context) => AlertDialog(
                                            title: Text(
                                              LOCALIZATION.localize(
                                                    'main_word.employee_password',
                                                  ) ??
                                                  "Employee Password",
                                            ),
                                            content: SelectableText(decrypted),
                                            actions: [
                                              TextButton(
                                                onPressed: () {
                                                  Clipboard.setData(
                                                    ClipboardData(
                                                      text: decrypted,
                                                    ),
                                                  );
                                                  showToastMessage(
                                                    context,
                                                    LOCALIZATION.localize(
                                                          'main_word.copied',
                                                        ) ??
                                                        "Copied to clipboard",
                                                    ToastLevel.success,
                                                  );
                                                },
                                                child: Text(
                                                  LOCALIZATION.localize(
                                                        'main_word.copy',
                                                      ) ??
                                                      "Copy",
                                                ),
                                              ),

                                              TextButton(
                                                onPressed:
                                                    () =>
                                                        Navigator.of(
                                                          context,
                                                        ).pop(),
                                                child: Text(
                                                  LOCALIZATION.localize(
                                                        'main_word.close',
                                                      ) ??
                                                      "Close",
                                                ),
                                              ),
                                            ],
                                          ),
                                    );
                                  }
                                },
                              ),

                              // Attendance button
                              IconButton(
                                icon: const Icon(
                                  Icons.calendar_month,
                                  color: Colors.deepPurple,
                                ),
                                tooltip:
                                    LOCALIZATION.localize(
                                      'main_word.attendance',
                                    ) ??
                                    "Attendance",
                                onPressed: () async {
                                  // Prompt for admin password
                                  bool? confirmed = await AdminAuthDialog.show(
                                    context,
                                  );

                                  if (confirmed == true) {
                                    await showAttendanceDetailDialog(
                                      context,
                                      emp,
                                      empId,
                                    );
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
