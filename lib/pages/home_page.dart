import '../configs/configs.dart';

import 'package:intl/intl.dart'; // <-- Add this line
import 'package:share_plus/share_plus.dart';
import 'package:open_file/open_file.dart';

import '../services/homepage/homepage_service.dart';
import '../services/auth/auth_service.dart';
import '../services/notification/enhanced_notification_service.dart';
import '../services/database/db.dart';

import '../components/toastmsg.dart';

class HomePage extends StatefulWidget {
  final ValueNotifier<int> reloadNotifier;
  const HomePage({super.key, required this.reloadNotifier});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const double _sectionHeight = 320;

  Map<String, Map<String, dynamic>> attendanceMaps = {};
  List<Widget> notificationTiles = [];
  Map<String, dynamic> liveSalesSummary = {
    'orders': 0,
    'revenue': 0.0,
    'profit': 0.0,
    'bestSellingItem': '',
  };

  // init function
  @override
  void initState() {
    super.initState();
    _initHomePage();
    widget.reloadNotifier.addListener(() async {
      await homepageService.updateEmployeeMap();
      await _updateLiveSalesSummary();
      setState(() {
        attendanceMaps = homepageService.attendanceMaps;
        liveSalesSummary = homepageService.liveSalesSummary;
      });
    });
  }

  @override
  void dispose() {
    super.dispose();
    widget.reloadNotifier.removeListener(() async {
      await homepageService.updateEmployeeMap();
    });
  }

  // Add this method to reload product data
  Future<void> _initHomePage() async {
    try {
      await _updateLiveSalesSummary();
      setState(() {
        attendanceMaps = homepageService.attendanceMaps;
        liveSalesSummary = homepageService.liveSalesSummary;
      });
    } catch (e) {
      HOMEPAGE_LOGS.error('Error with homepage init', e, StackTrace.current);
      showToastMessage(
        context,
        '${LOCALIZATION.localize("home_page.error_loading_products")}\n\n$e',
        ToastLevel.error,
        position: ToastPosition.topRight,
      );
    }
  }

  // Update live sales summary
  Future<void> _updateLiveSalesSummary() async {
    await homepageService.updateLiveSalesSummary();
  }

  // Modern Card Section Wrapper with sticky title
  // Modern Card Section Wrapper with sticky title
  Widget _buildCardSection({
    required Widget title,
    required Widget child,
    required double height,
    bool fillEmptySpace = false,
    bool hasOwnScrolling =
        false, // Add this parameter for widgets that handle their own scrolling
  }) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Theme.of(context).colorScheme.surface,
      child: SizedBox(
        height: height,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
              child: title,
            ),
            const SizedBox(height: 10),
            Expanded(
              child:
                  hasOwnScrolling
                      ? Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18.0),
                        child: child,
                      )
                      : LayoutBuilder(
                        builder: (context, constraints) {
                          return Scrollbar(
                            thumbVisibility: true,
                            child: SingleChildScrollView(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18.0,
                                ),
                                constraints:
                                    fillEmptySpace
                                        ? BoxConstraints(
                                          minHeight: constraints.maxHeight,
                                        )
                                        : null,
                                child: child,
                              ),
                            ),
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }

  // [140725] [ATTENDANCE SECTION]
  Widget _attendanceSectionTitle(Color mainColor) => Row(
    children: [
      Icon(Icons.people_alt_rounded, color: mainColor),
      const SizedBox(width: 8),
      Text(
        LOCALIZATION.localize('home_page.attendance'),
        style: _headerStyle.copyWith(color: mainColor),
      ),
      const Spacer(),
    ],
  );

  Widget _buildAttendanceSection(Color mainColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Debug information
        if (attendanceMaps.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              "No attendance data available",
              style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
            ),
          ),

        // Use the map and its entries correctly
        ...attendanceMaps.entries
            .where((entry) {
              // Skip key '0' which might be a placeholder
              if (entry.key == '0') return false;

              final value = entry.value;
              final String? attendanceUsername = value['username'] as String?;

              // If username is not in the attendance record, filter it out.
              if (attendanceUsername == null) {
                return false;
              }

              // Find the corresponding employee in the main employee list (EMPQUERY.employees)
              // by matching the username.
              final targetEmployee = EMPQUERY.employees.values.firstWhere(
                (emp) => emp['username'] == attendanceUsername,
                orElse:
                    () =>
                        <
                          String,
                          dynamic
                        >{}, // Return an empty map if not found to avoid errors.
              );

              // If the employee is not found in the main list, don't show them in attendance.
              if (targetEmployee.isEmpty) {
                return false;
              }

              // Get the 'exist' status from the found employee data.
              final existValue = targetEmployee['exist'];

              // Check if the employee is active. Handles different possible data types for 'exist'.
              final bool isActive =
                  existValue == 1 || existValue == '1' || existValue == true;

              return isActive;
            })
            .map((entry) {
              final id = entry.key;
              final empData = entry.value;

              // Ensure we have all required fields
              final emp = {
                ...empData,
                'id': id, // Add employee ID to the map
                'name': empData['name'] ?? 'Unknown Employee',
                'username': empData['username'] ?? 'unknown',
                'clock_in': empData['clock_in'] ?? '',
                'clock_out': empData['clock_out'] ?? '',
              };

              return _buildattendanceMapsTile(emp, mainColor);
            }),
      ],
    );
  }

  Widget _buildattendanceMapsTile(Map<String, dynamic> emp, Color mainColor) {
    final bool checkedIn = emp['clock_in'] != "";
    final bool checkedOut = emp['clock_out'] != "";

    void handleTap() {
      try {
        if (!checkedIn) {
          _showAttendanceDialog(emp, isClockIn: true, mainColor: mainColor);
        } else if (!checkedOut) {
          _showAttendanceDialog(emp, isClockIn: false, mainColor: mainColor);
        }
      } catch (e, stackTrace) {
        HOMEPAGE_LOGS.error('Error handling tap', e, stackTrace);
        showToastMessage(
          context,
          "${LOCALIZATION.localize('main_word.error')} ${LOCALIZATION.localize('main_word.attendance')}",
          ToastLevel.error,
          position: ToastPosition.topRight,
        );
      }
    }

    // Determine icon and color for status
    IconData statusIcon;
    Color statusColor;
    String statusText;

    if (!checkedIn) {
      statusIcon = Icons.tab_unselected_outlined;
      statusColor = Colors.blueGrey;
      statusText =
          LOCALIZATION.localize('home_page.not_clocked_in').toUpperCase();
    } else if (checkedIn && !checkedOut) {
      statusIcon = Icons.login;
      statusColor = mainColor;
      statusText = LOCALIZATION.localize('home_page.clocked_in').toUpperCase();
    } else {
      statusIcon = Icons.logout;
      statusColor = Colors.grey;
      statusText = LOCALIZATION.localize('home_page.clocked_out').toUpperCase();
    }

    // Get employee image if exists - try both id and username as keys
    final imageBytes =
        homepageService.employeeMap[emp['id']]?['image'] ??
        homepageService.employeeMap[emp['username']]?['image'];

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        onTap: handleTap,
        leading:
            (imageBytes != null &&
                    imageBytes is List<int> &&
                    imageBytes.isNotEmpty)
                ? CircleAvatar(
                  radius: 26,
                  backgroundImage: MemoryImage(Uint8List.fromList(imageBytes)),
                )
                : CircleAvatar(
                  radius: 26,
                  backgroundColor: mainColor.withOpacity(0.15),
                  child: Icon(Icons.person, color: mainColor, size: 28),
                ),
        title: Text(
          emp['name'],
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          "${LOCALIZATION.localize('main_word.time')}: ${emp['clock_out'] == '' ? emp['clock_in'] : emp['clock_out']}",
          style: TextStyle(color: statusColor, fontWeight: FontWeight.w500),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(statusIcon, color: statusColor, size: 28),
            const SizedBox(height: 4),
            Text(
              statusText,
              style: TextStyle(
                color: statusColor,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        minVerticalPadding: 0,
      ),
    );
  }

  void _showAttendanceDialog(
    Map<String, dynamic> emp, {
    required bool isClockIn,
    required Color mainColor,
  }) {
    final TextEditingController _passwordController = TextEditingController();
    final ValueNotifier<bool> _obscurePassword = ValueNotifier<bool>(true);
    String? errorText;
    // Current time for display
    final formattedTime = getDateTimeNow(format: 'HH:mm');
    final formattedDate = getDateTimeNow(format: 'dd/MM/yyyy');

    void _onConfirm() async {
      final inputPassword = _passwordController.text;
      bool isValid = false;
      if (inputPassword.isEmpty) {
        setState(() {
          errorText = LOCALIZATION.localize('main_word.password_required');
          showToastMessage(context, errorText!, ToastLevel.error);
        });
        return;
      }

      if (!DEBUG_AUTH_IN_TESTING) {
        // Get password from employee data - try both id and username as keys
        final storedHash =
            homepageService.employeeMap[emp['id']]?['password'] ??
            homepageService.employeeMap[emp['username']]?['password'];
        if (storedHash == null) {
          HOMEPAGE_LOGS.error(
            'Password hash not found for employee: ${emp['id']} (${emp['username']})',
          );
          Navigator.of(context).pop();
          showToastMessage(
            context,
            LOCALIZATION.localize('main_word.password_data_error'),
            ToastLevel.error,
          );
          return;
        }

        // Validate password
        isValid = await EncryptService().decryptPassword(
          storedHash,
          targetPassword: inputPassword,
        );
      } else {
        // Bypass password check in DEBUG mode
        isValid = inputPassword == 'test';
      }

      if (!isValid) {
        setState(() {
          errorText = LOCALIZATION.localize('main_word.password_incorrect');
        });
        showToastMessage(
          context,
          LOCALIZATION.localize('main_word.password_incorrect'),
          ToastLevel.error,
        );
        return;
      }

      // Handle clock in/out logic here
      // Update attendance data
      try {
        if (isClockIn) {
          // Clock in logic
          emp['clock_in'] = formattedTime;
          showToastMessage(
            context,
            LOCALIZATION.localize('home_page.clock_in_success'),
            ToastLevel.success,
          );
        } else {
          // Clock out logic
          emp['clock_out'] = formattedTime;
          showToastMessage(
            context,
            LOCALIZATION.localize('home_page.clock_out_success'),
            ToastLevel.success,
          );
        }

        final String checkSetAttendance = await homepageService
            .attendanceSetGetter(attendanceData: emp);
        if (checkSetAttendance == "attendance_save_error" ||
            checkSetAttendance == "total_hour_calculation_error") {
          showToastMessage(
            context,
            LOCALIZATION.localize('home_page.$checkSetAttendance'),
            ToastLevel.error,
          );
        } else if (checkSetAttendance == "clock_in_already_exists" ||
            checkSetAttendance == "no_attendance_records") {
          showToastMessage(
            context,
            LOCALIZATION.localize('home_page.$checkSetAttendance'),
            ToastLevel.warning,
          );
        } else {
          showToastMessage(
            context,
            LOCALIZATION.localize('home_page.$checkSetAttendance'),
            ToastLevel.success,
          );
        }
      } catch (e, stackTrace) {
        HOMEPAGE_LOGS.error(
          'Failed to update attendance for ${emp['name']}',
          e,
          stackTrace,
        );
        showToastMessage(
          context,
          "[${emp['name']}] ${LOCALIZATION.localize('main_word.attendance_error')}",
          ToastLevel.error,
        );
      }

      setState(() {
        attendanceMaps[emp['id']] = emp;
      });

      Navigator.of(context).pop();
    }

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return StatefulBuilder(
          builder:
              (context, setState) => Dialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 5,
                // Set max width for narrower dialog
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 350),
                  // ✨ WRAP the Column with SingleChildScrollView
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header with Employee Info
                        Container(
                          decoration: BoxDecoration(
                            color: mainColor.withOpacity(0.1),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(20),
                              topRight: Radius.circular(20),
                            ),
                          ),
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                          child: Column(
                            children: [
                              // Employee image and basic info
                              Row(
                                children: [
                                  // Employee image or icon
                                  Builder(
                                    builder: (context) {
                                      final imageBytes =
                                          homepageService
                                              .employeeMap[emp['id']]?['image'];
                                      if (imageBytes != null &&
                                          imageBytes is List<int> &&
                                          imageBytes.isNotEmpty) {
                                        return CircleAvatar(
                                          radius: 28,
                                          backgroundImage: MemoryImage(
                                            Uint8List.fromList(imageBytes),
                                          ),
                                        );
                                      } else {
                                        return CircleAvatar(
                                          radius: 28,
                                          backgroundColor: mainColor
                                              .withOpacity(0.2),
                                          child: Icon(
                                            Icons.person,
                                            color: mainColor,
                                            size: 28,
                                          ),
                                        );
                                      }
                                    },
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          emp['name'],
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                          ),
                                        ),
                                        if (emp['username'] != null &&
                                            emp['username']
                                                .toString()
                                                .isNotEmpty)
                                          Text(
                                            '@${emp['username']}',
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 13,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),

                              // Time and date info
                              Container(
                                margin: const EdgeInsets.only(top: 14),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                  horizontal: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: Colors.grey.withOpacity(0.3),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          isClockIn
                                              ? Icons.login
                                              : Icons.logout,
                                          color:
                                              isClockIn
                                                  ? mainColor
                                                  : Colors.grey[700],
                                          size: 18,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          isClockIn
                                              ? LOCALIZATION.localize(
                                                'home_page.clocking_in',
                                              )
                                              : LOCALIZATION.localize(
                                                'home_page.clocking_out',
                                              ),
                                          style: TextStyle(
                                            color:
                                                isClockIn
                                                    ? mainColor
                                                    : Colors.grey[700],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.access_time,
                                              size: 14,
                                              color: Colors.grey[600],
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              formattedTime,
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                color: Colors.grey[800],
                                              ),
                                            ),
                                          ],
                                        ),
                                        Text(
                                          formattedDate,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Content
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Password field label
                              Text(
                                LOCALIZATION.localize(
                                  'main_word.enter_password',
                                ),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 8),

                              // Password field
                              ValueListenableBuilder<bool>(
                                valueListenable: _obscurePassword,
                                builder:
                                    (context, obscure, _) => TextField(
                                      controller: _passwordController,
                                      obscureText: obscure,
                                      decoration: InputDecoration(
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          borderSide: BorderSide(
                                            color: Colors.grey.shade300,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          borderSide: BorderSide(
                                            color: mainColor,
                                            width: 2,
                                          ),
                                        ),
                                        isDense: true,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 12,
                                            ),
                                        errorText: errorText,
                                        hintText: LOCALIZATION.localize(
                                          'main_word.password_hint',
                                        ),
                                        prefixIcon: const Icon(
                                          Icons.lock_outline,
                                          size: 20,
                                        ),
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            obscure
                                                ? Icons.visibility_off
                                                : Icons.visibility,
                                            color: Colors.grey,
                                            size: 20,
                                          ),
                                          onPressed: () {
                                            _obscurePassword.value = !obscure;
                                          },
                                        ),
                                        errorBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          borderSide: BorderSide(
                                            color: Colors.red.shade300,
                                          ),
                                        ),
                                      ),
                                      style: const TextStyle(fontSize: 14),
                                      onSubmitted: (_) => _onConfirm(),
                                      textInputAction: TextInputAction.done,
                                    ),
                              ),
                            ],
                          ),
                        ),

                        // Action buttons
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: Text(
                                  LOCALIZATION.localize('main_word.cancel'),
                                  style: TextStyle(color: Colors.grey[700]),
                                ),
                              ),
                              const SizedBox(width: 8),

                              ElevatedButton(
                                onPressed: _onConfirm,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: mainColor,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                                  elevation: 0,
                                ),
                                child: Text(
                                  LOCALIZATION.localize('main_word.confirm'),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
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
        );
      },
    );
  }

  /// Title for the live sales summary section
  Widget _salesSummaryTitle(Color mainColor) => Row(
    children: [
      Icon(Icons.bar_chart_rounded, color: mainColor),
      const SizedBox(width: 8),

      Text(
        LOCALIZATION.localize('home_page.live_sales_summary'),
        style: _headerStyle.copyWith(color: mainColor),
      ),
    ],
  );

  // [NOTIFICATION PANEL SECTION]
  Widget _notificationPanelTitle(Color mainColor) =>
      SizedBox.shrink(); // Removed, handled by NotificationPanel

  Widget _buildNotificationPanel(Color mainColor) {
    return NotificationPanel(
      mainColor: mainColor,
      onNotificationTap: () {
        // Optional: Handle notification tap events
        print('Notification tapped');
      },
    );
  }

  // [FUTURE FEATURE SECTION]
  Widget _futureFeatureTitle(Color mainColor) => Row(
    children: [
      Icon(Icons.upcoming, color: mainColor.withOpacity(0.3), size: 28),
      const SizedBox(width: 8),
      Text(
        LOCALIZATION.localize('home_page.coming_soon'),
        style: _headerStyle.copyWith(
          color: mainColor.withOpacity(0.5),
          fontWeight: FontWeight.bold,
        ),
      ),
    ],
  );

  Widget _buildFutureFeatureSection(Color mainColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.upcoming, color: mainColor.withOpacity(0.3), size: 48),
          const SizedBox(height: 12),
          Text(
            LOCALIZATION.localize('home_page.coming_soon'),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: mainColor.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mainColor = theme.colorScheme.primary;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: theme.colorScheme.background,
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              // First Row: Attendance & Live Sales Summary
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Attendance Section
                  Expanded(
                    child: _buildCardSection(
                      title: _attendanceSectionTitle(mainColor),
                      child: _buildAttendanceSection(mainColor),
                      height: _sectionHeight,
                    ),
                  ),
                  const SizedBox(width: 20),

                  // Live Sales Summary Section
                  Expanded(
                    child: _buildCardSection(
                      title: _salesSummaryTitle(mainColor),
                      child: LiveSalesSummarySection(
                        liveSalesSummary: liveSalesSummary,
                        mainColor: mainColor,
                        currency:
                            globalAppConfig["userPreferences"]["currency"],
                      ),
                      height: _sectionHeight,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Second Row: Notification Panel & Future Feature Section
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildCardSection(
                      title: _notificationPanelTitle(mainColor),
                      child: _buildNotificationPanel(mainColor),
                      height: _sectionHeight,
                      hasOwnScrolling:
                          true, // NotificationPanel handles its own scrolling
                    ),
                  ),
                  const SizedBox(width: 20),

                  Expanded(
                    child: _buildCardSection(
                      title: _futureFeatureTitle(mainColor),
                      child: _buildFutureFeatureSection(mainColor),
                      height: _sectionHeight,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Header Text Style
const TextStyle _headerStyle = TextStyle(
  fontSize: 20,
  fontWeight: FontWeight.bold,
);

// [300625] Live Sales Summary Section + State
class LiveSalesSummarySection extends StatefulWidget {
  final Map<String, dynamic> liveSalesSummary;
  final Color mainColor;
  final String currency;

  const LiveSalesSummarySection({
    super.key,
    required this.liveSalesSummary,
    required this.mainColor,
    required this.currency,
  });

  @override
  State<LiveSalesSummarySection> createState() =>
      _LiveSalesSummarySectionState();
}

class _LiveSalesSummarySectionState extends State<LiveSalesSummarySection> {
  bool _loadingAdvancedSales = false;
  DateTimeRange? _selectedRange;
  String _selectedFilter = 'today';

  /// Builds a single, styled tile for the summary grid.
  Widget _buildSummaryTile({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, color: iconColor, size: 30),
        const SizedBox(height: 8),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 4),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade900,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Shows the advanced sales summary dialog with a new responsive layout.
  Future<void> _showAdvancedSalesSummaryDialog() async {
    await _updateAdvancedData();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => StatefulBuilder(
            builder: (context, setDialogState) {
              return Dialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                child: ConstrainedBox(
                  // Increased maxWidth to accommodate the side-by-side layout on kiosks.
                  constraints: const BoxConstraints(
                    maxWidth: 900,
                    maxHeight: 650,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        Text(
                          LOCALIZATION.localize(
                            'home_page.advanced_sales_summary',
                          ),
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 24),

                        _buildFilterControls(setDialogState),

                        if (_selectedFilter == 'custom' &&
                            _selectedRange != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 12.0),
                            child: Text(
                              "${DateFormat.yMMMd().format(_selectedRange!.start)} - ${DateFormat.yMMMd().format(_selectedRange!.end)}",
                              style: TextStyle(
                                fontSize: 14,
                                fontStyle: FontStyle.italic,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ),
                        const SizedBox(height: 16),

                        Expanded(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child:
                                _loadingAdvancedSales
                                    ? Center(
                                      key: const ValueKey('loader'),
                                      child: CircularProgressIndicator(
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Theme.of(context).primaryColor,
                                            ),
                                      ),
                                    )
                                    // THIS IS THE NEW RESPONSIVE BODY
                                    : LayoutBuilder(
                                      key: const ValueKey('content'),
                                      builder: (context, constraints) {
                                        // Define a breakpoint for switching between layouts.
                                        const double wideLayoutThreshold = 600;
                                        if (constraints.maxWidth >
                                            wideLayoutThreshold) {
                                          // WIDE LAYOUT (Kiosk)
                                          return Row(
                                            children: [
                                              Expanded(
                                                child: _buildSalesTabs(),
                                              ),
                                              const VerticalDivider(
                                                width: 32,
                                                thickness: 1,
                                              ),
                                              SizedBox(
                                                width: 280,
                                                child:
                                                    _buildPaymentMethodSummary(),
                                              ),
                                            ],
                                          );
                                        } else {
                                          // NARROW LAYOUT (Phone)
                                          return Column(
                                            children: [
                                              Expanded(
                                                child: _buildSalesTabs(),
                                              ),
                                              const Divider(
                                                height: 32,
                                                thickness: 1,
                                              ),
                                              _buildPaymentMethodSummary(),
                                            ],
                                          );
                                        }
                                      },
                                    ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: Text(
                                LOCALIZATION.localize('main_word.close'),
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Theme.of(context).primaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Export TXT buttons
                            ElevatedButton.icon(
                              icon: const Icon(Icons.file_download, size: 18),
                              label: const Text('Export TXT'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).primaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                textStyle: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                                elevation: 1,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: () async {
                                DateTime now = DateTime.now();
                                DateTime start;
                                DateTime end;

                                if (_selectedFilter == 'custom' &&
                                    _selectedRange != null) {
                                  start = _selectedRange!.start;
                                  end = DateTime(
                                    _selectedRange!.end.year,
                                    _selectedRange!.end.month,
                                    _selectedRange!.end.day,
                                    23,
                                    59,
                                    59,
                                    999,
                                  );
                                } else if (_selectedFilter == 'today') {
                                  start = DateTime(
                                    now.year,
                                    now.month,
                                    now.day,
                                    0,
                                    0,
                                    0,
                                    0,
                                  );
                                  end = DateTime(
                                    now.year,
                                    now.month,
                                    now.day,
                                    23,
                                    59,
                                    59,
                                    999,
                                  );
                                } else if (_selectedFilter == 'hour') {
                                  start = DateTime(
                                    now.year,
                                    now.month,
                                    now.day,
                                    now.hour,
                                  );
                                  end = start
                                      .add(const Duration(hours: 1))
                                      .subtract(
                                        const Duration(milliseconds: 1),
                                      );
                                } else {
                                  // fallback to today
                                  start = DateTime(
                                    now.year,
                                    now.month,
                                    now.day,
                                    0,
                                    0,
                                    0,
                                    0,
                                  );
                                  end = DateTime(
                                    now.year,
                                    now.month,
                                    now.day,
                                    23,
                                    59,
                                    59,
                                    999,
                                  );
                                }

                                // Then use:
                                final file = await homepageService
                                    .exportCombinedReport(
                                      start: start,
                                      end: end,
                                      format: 'txt', // or 'pdf'
                                    );
                                showToastMessage(
                                  context,
                                  'TXT exported: ${file.path}',
                                  ToastLevel.success,
                                );
                                await OpenFile.open(file.path);
                                final shouldShare = await showDialog<bool>(
                                  context: context,
                                  builder:
                                      (context) => AlertDialog(
                                        title: const Text('Share File?'),
                                        content: const Text(
                                          'Do you want to share this TXT file?',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed:
                                                () => Navigator.pop(
                                                  context,
                                                  false,
                                                ),
                                            child: const Text('No'),
                                          ),
                                          TextButton(
                                            onPressed:
                                                () => Navigator.pop(
                                                  context,
                                                  true,
                                                ),
                                            child: const Text('Yes'),
                                          ),
                                        ],
                                      ),
                                );
                                if (shouldShare == true) {
                                  await Share.shareXFiles([
                                    XFile(file.path),
                                  ], text: 'Sales Report (TXT)');
                                }
                              },
                            ),
                            const SizedBox(width: 8),

                            // Export PDF button
                            ElevatedButton.icon(
                              icon: const Icon(Icons.picture_as_pdf, size: 18),
                              label: const Text('Export PDF'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red.shade700,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                textStyle: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                                elevation: 1,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: () async {
                                DateTime now = DateTime.now();
                                DateTime start;
                                DateTime end;

                                if (_selectedFilter == 'custom' &&
                                    _selectedRange != null) {
                                  start = _selectedRange!.start;
                                  end = DateTime(
                                    _selectedRange!.end.year,
                                    _selectedRange!.end.month,
                                    _selectedRange!.end.day,
                                    23,
                                    59,
                                    59,
                                    999,
                                  );
                                } else if (_selectedFilter == 'today') {
                                  start = DateTime(
                                    now.year,
                                    now.month,
                                    now.day,
                                    0,
                                    0,
                                    0,
                                    0,
                                  );
                                  end = DateTime(
                                    now.year,
                                    now.month,
                                    now.day,
                                    23,
                                    59,
                                    59,
                                    999,
                                  );
                                } else if (_selectedFilter == 'hour') {
                                  start = DateTime(
                                    now.year,
                                    now.month,
                                    now.day,
                                    now.hour,
                                  );
                                  end = start
                                      .add(const Duration(hours: 1))
                                      .subtract(
                                        const Duration(milliseconds: 1),
                                      );
                                } else {
                                  // fallback to today
                                  start = DateTime(
                                    now.year,
                                    now.month,
                                    now.day,
                                    0,
                                    0,
                                    0,
                                    0,
                                  );
                                  end = DateTime(
                                    now.year,
                                    now.month,
                                    now.day,
                                    23,
                                    59,
                                    59,
                                    999,
                                  );
                                }

                                // Then use:
                                final file = await homepageService
                                    .exportCombinedReport(
                                      start: start,
                                      end: end,
                                      format: 'pdf', // or 'pdf'
                                    );
                                showToastMessage(
                                  context,
                                  'PDF exported: ${file.path}',
                                  ToastLevel.success,
                                );
                                await OpenFile.open(file.path);
                                final shouldShare = await showDialog<bool>(
                                  context: context,
                                  builder:
                                      (context) => AlertDialog(
                                        title: const Text('Share File?'),
                                        content: const Text(
                                          'Do you want to share this PDF file?',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed:
                                                () => Navigator.pop(
                                                  context,
                                                  false,
                                                ),
                                            child: const Text('No'),
                                          ),
                                          TextButton(
                                            onPressed:
                                                () => Navigator.pop(
                                                  context,
                                                  true,
                                                ),
                                            child: const Text('Yes'),
                                          ),
                                        ],
                                      ),
                                );
                                if (shouldShare == true) {
                                  await Share.shareXFiles([
                                    XFile(file.path),
                                  ], text: 'Sales Report (PDF)');
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
    );
  }

  /// Updates all data needed for the advanced summary dialog.
  Future<void> _updateAdvancedData([StateSetter? setDialogState]) async {
    final updateState = setDialogState ?? setState;
    updateState(() => _loadingAdvancedSales = true);

    DateTime now = DateTime.now();
    DateTime start = DateTime(now.year, now.month, now.day);
    DateTime end = DateTime(now.year, now.month, now.day, 23, 59, 59);

    if (_selectedFilter == 'hour') {
      start = DateTime(now.year, now.month, now.day, now.hour);
      end = start
          .add(const Duration(hours: 1))
          .subtract(const Duration(seconds: 1));
    } else if (_selectedFilter == 'custom' && _selectedRange != null) {
      start = _selectedRange!.start;
      end = DateTime(
        _selectedRange!.end.year,
        _selectedRange!.end.month,
        _selectedRange!.end.day,
        23,
        59,
        59,
      );
    }

    // Fetch both sales and payment data concurrently.
    await Future.wait([
      homepageService.updateAdvancedSalesSummaryWithRange(
        start: start,
        end: end,
      ),
      homepageService.updatePaymentMethodSummaryWithRange(
        start: start,
        end: end,
      ),
    ]);

    updateState(() => _loadingAdvancedSales = false);
  }

  // [Filter Controls Section] - No changes needed
  Widget _buildFilterControls(StateSetter setDialogState) {
    return SegmentedButton<String>(
      segments: [
        ButtonSegment(
          value: 'today',
          label: Text(LOCALIZATION.localize('main_word.today')),
          icon: const Icon(Icons.today),
        ),
        ButtonSegment(
          value: 'hour',
          label: Text(LOCALIZATION.localize('main_word.this_hour')),
          icon: const Icon(Icons.hourglass_bottom),
        ),
        ButtonSegment(
          value: 'custom',
          label: Text(LOCALIZATION.localize('main_word.custom_range')),
          icon: const Icon(Icons.date_range),
        ),
      ],
      selected: {_selectedFilter},
      onSelectionChanged: (newSelection) async {
        setDialogState(() => _selectedFilter = newSelection.first);
        if (newSelection.first == 'custom') {
          final picked = await showDateRangePicker(
            context: context,
            firstDate: DateTime(2020),
            lastDate: DateTime.now(),
            initialDateRange:
                _selectedRange ??
                DateTimeRange(
                  start: DateTime.now().subtract(const Duration(days: 7)),
                  end: DateTime.now(),
                ),
          );
          if (picked != null) {
            setDialogState(() => _selectedRange = picked);
          } else {
            setDialogState(() => _selectedFilter = 'today');
          }
        }
        _updateAdvancedData(setDialogState);
      },
      style: SegmentedButton.styleFrom(
        backgroundColor: Colors.grey.shade200,
        foregroundColor: Theme.of(context).primaryColor,
        selectedForegroundColor: Colors.white,
        selectedBackgroundColor: Theme.of(context).primaryColor,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }

  // [Sales Tabs Section] - No changes needed
  Widget _buildSalesTabs() {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            labelColor: Theme.of(context).primaryColor,
            unselectedLabelColor: Colors.grey.shade600,
            indicatorColor: Theme.of(context).primaryColor,
            indicatorWeight: 3.0,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
            tabs: [
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.coffee),
                    const SizedBox(width: 8),
                    Text(LOCALIZATION.localize('home_page.by_product')),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.category),
                    const SizedBox(width: 8),
                    Text(LOCALIZATION.localize('home_page.by_category')),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: TabBarView(
              children: [
                _buildSalesChart(homepageService.productSales),
                _buildSalesChart(homepageService.categorySales),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // [Sales Chart Section] - No changes needed
  Widget _buildSalesChart(Map<String, int> data) {
    if (data.isEmpty) {
      return Center(
        child: Text(
          LOCALIZATION.localize('main_word.no_data'),
          style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
        ),
      );
    }
    final sortedEntries =
        data.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final maxValue = sortedEntries.isNotEmpty ? sortedEntries.first.value : 1;
    return ListView.builder(
      itemCount: sortedEntries.length,
      itemBuilder: (context, index) {
        final entry = sortedEntries[index];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            children: [
              SizedBox(
                width: 150,
                child: Text(
                  entry.key,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final barWidth =
                        (entry.value / maxValue) * constraints.maxWidth;
                    return Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        Container(
                          height: 35,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeOutCubic,
                          height: 35,
                          width: barWidth,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Theme.of(context).primaryColor.withOpacity(0.7),
                                Theme.of(context).primaryColor,
                              ],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12.0),
                          child: Text(
                            entry.value.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Returns a specific icon based on the payment method name.
  IconData _getPaymentMethodIcon(String methodName) {
    final lowerCaseMethod = methodName.toLowerCase();
    if (lowerCaseMethod.contains('card')) {
      return Icons.credit_card;
    } else if (lowerCaseMethod.contains('cash')) {
      return Icons.money;
    } else if (lowerCaseMethod.contains('qr')) {
      return Icons.qr_code_scanner;
    }
    return Icons.payment; // Default icon
  }

  /// Builds the styled payment method summary component.
  Widget _buildPaymentMethodSummary() {
    final data = homepageService.paymentMethodSummary;
    if (data.isEmpty) {
      return Center(
        child: Text(
          LOCALIZATION.localize('main_word.no_payment_data'),
          style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
        ),
      );
    }
    final sorted =
        data.entries.toList()..sort(
          (a, b) =>
              (b.value['count'] as int).compareTo(a.value['count'] as int),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min, // Ensure column takes minimum space
      children: [
        Text(
          LOCALIZATION.localize('home_page.payment_method_summary'),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        const SizedBox(height: 12),
        // Use Wrap for a responsive, grid-like layout that avoids horizontal scrolling.
        Wrap(
          spacing: 14.0, // Horizontal space between cards
          runSpacing: 14.0, // Vertical space between rows
          children:
              sorted.map((e) {
                final count = e.value['count'] ?? 0;
                final total = e.value['total'] ?? 0.0;

                // Each item is a consistently sized container.
                // Wrap will handle placing them in the available space.
                return Container(
                  width: 200, // A consistent width for each card looks clean.
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                    border: Border.all(
                      color: Theme.of(context).primaryColor.withOpacity(0.12),
                      width: 1.0,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: Theme.of(
                          context,
                        ).primaryColor.withOpacity(0.13),
                        child: Icon(
                          _getPaymentMethodIcon(e.key),
                          color: Theme.of(context).primaryColor,
                          size: 28,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        e.key,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "${LOCALIZATION.localize('main_word.transactions')}: $count",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "${widget.currency} ${total.toStringAsFixed(2)}",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // No changes needed in this final build method.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.insights, size: 18),
                label: Text(
                  LOCALIZATION.localize('home_page.advanced_summary'),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.mainColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _showAdvancedSalesSummaryDialog,
              ),
            ],
          ),
          const SizedBox(height: 24),
          GridView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.0,
            ),
            children: [
              _buildSummaryTile(
                icon: Icons.shopping_cart_checkout,
                iconColor: widget.mainColor,
                label: LOCALIZATION.localize('home_page.orders'),
                value: widget.liveSalesSummary['orders'].toString(),
              ),
              _buildSummaryTile(
                icon: Icons.monetization_on,
                iconColor: Colors.green.shade600,
                label: LOCALIZATION.localize('home_page.profit'),
                value:
                    "${widget.currency} ${widget.liveSalesSummary['profit']?.toStringAsFixed(2) ?? '0.00'}",
              ),
              _buildSummaryTile(
                icon: Icons.star,
                iconColor: Colors.amber.shade700,
                label: LOCALIZATION.localize('home_page.best_selling_item'),
                value:
                    widget.liveSalesSummary['bestSellingItem'] ??
                    LOCALIZATION.localize('main_word.no_data'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// [060725] Widget for displaying notifications in the home page panel
class NotificationPanel extends StatefulWidget {
  final Color mainColor;
  final VoidCallback? onNotificationTap;

  const NotificationPanel({
    Key? key,
    required this.mainColor,
    this.onNotificationTap,
  }) : super(key: key);

  @override
  State<NotificationPanel> createState() => _NotificationPanelState();
}

class _NotificationPanelState extends State<NotificationPanel> {
  final EnhancedNotificationService _notificationService =
      EnhancedNotificationService();

  @override
  void initState() {
    super.initState();
    // Initialize notification service if not already done
    _notificationService.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<AppNotification>>(
      valueListenable: _notificationService.notifications,
      builder: (context, notifications, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with unread count
            _buildHeader(notifications),
            const SizedBox(height: 12),

            // Notification list
            Expanded(
              child:
                  notifications.isEmpty
                      ? _buildEmptyState()
                      : _buildNotificationList(notifications),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeader(List<AppNotification> notifications) {
    final unreadCount = notifications.where((n) => !n.isRead).length;

    return Row(
      children: [
        Icon(Icons.notifications_active_rounded, color: widget.mainColor),
        const SizedBox(width: 8),

        Text(
          LOCALIZATION.localize('home_page.notifications'),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: widget.mainColor,
          ),
        ),
        const Spacer(),

        // Unread count badge
        if (unreadCount > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$unreadCount',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

        const SizedBox(width: 8),

        // Mark all as read button
        if (unreadCount > 0)
          IconButton(
            onPressed: () => _notificationService.markAllAsRead(),
            icon: const Icon(Icons.mark_email_read),
            tooltip: 'Mark all as read',
            iconSize: 20,
          ),

        // Clear all button
        if (notifications.isNotEmpty)
          IconButton(
            onPressed: _showClearAllDialog,
            icon: const Icon(Icons.clear_all),
            tooltip: 'Clear all notifications',
            iconSize: 20,
          ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.notifications_none, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),

            Text(
              LOCALIZATION.localize('home_page.no_notifications'),
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),

            Text(
              LOCALIZATION.localize('home_page.no_notifications_details'),
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationList(List<AppNotification> notifications) {
    return ListView.separated(
      itemCount:
          notifications.length > 10 ? 10 : notifications.length, // Show max 10
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final notification = notifications[index];
        return _buildNotificationTile(notification);
      },
    );
  }

  Widget _buildNotificationTile(AppNotification notification) {
    final isExpired = notification.isExpired;

    return Container(
      decoration: BoxDecoration(
        color:
            notification.isRead
                ? Colors.transparent
                : notification.color.withOpacity(0.05),
        border:
            notification.isRead
                ? null
                : Border(left: BorderSide(width: 4, color: notification.color)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        onTap: () => _handleNotificationTap(notification),

        // Leading icon with priority indicator
        leading: Stack(
          children: [
            CircleAvatar(
              backgroundColor: notification.color.withOpacity(0.1),
              child: Icon(
                notification.icon,
                color: notification.color,
                size: 20,
              ),
            ),

            // Priority indicator
            if (notification.priority == NotificationPriority.high ||
                notification.priority == NotificationPriority.critical)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: notification.priorityColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1),
                  ),
                  child: Icon(
                    notification.priorityIcon,
                    size: 8,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),

        // Title and details
        title: Row(
          children: [
            Expanded(
              child: Text(
                notification.title,
                style: TextStyle(
                  fontWeight:
                      notification.isRead ? FontWeight.w500 : FontWeight.w700,
                  fontSize: 14,
                  color: isExpired ? Colors.grey : null,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // Timestamp
            Text(
              _formatTimestamp(notification.dateTime),
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),

        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              notification.details,
              style: TextStyle(
                fontSize: 13,
                color: isExpired ? Colors.grey : Colors.grey[700],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            // Action button if available
            if (notification.actionButtonText != null && !isExpired) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: ElevatedButton(
                  onPressed: () => _handleActionTap(notification),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: notification.color,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    notification.actionButtonText!,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ],

            // Expiry warning
            if (isExpired) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(
                    'Expired',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),

        // Trailing delete button
        trailing:
            notification.isDismissible
                ? IconButton(
                  onPressed: () => _deleteNotification(notification),
                  icon: Icon(Icons.close, size: 18, color: Colors.grey[600]),
                  tooltip: 'Dismiss',
                )
                : null,
      ),
    );
  }

  String _formatTimestamp(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM d').format(dateTime);
    }
  }

  void _handleNotificationTap(AppNotification notification) {
    // Mark as read when tapped
    if (!notification.isRead) {
      _notificationService.markAsRead(notification.id);
    }

    // Call optional callback
    widget.onNotificationTap?.call();
  }

  void _handleActionTap(AppNotification notification) {
    // Handle action button tap
    // You can implement specific actions based on actionData
    if (notification.actionData != null) {
      final action = notification.actionData!['action'] as String?;

      switch (action) {
        case 'retry_queue':
          // Trigger queue retry
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Retrying queued operations...')),
          );
          break;
        case 'view_details':
          // Show more details
          _showNotificationDetails(notification);
          break;
        default:
          // Generic action
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Action: ${notification.actionButtonText}')),
          );
      }
    }

    // Mark as read
    _notificationService.markAsRead(notification.id);
  }

  void _deleteNotification(AppNotification notification) {
    _notificationService.deleteNotification(notification.id);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Notification dismissed'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            // Re-add the notification
            _notificationService.addNotification(notification);
          },
        ),
      ),
    );
  }

  void _showClearAllDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Clear All Notifications'),
            content: const Text(
              'Are you sure you want to clear all notifications? This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  _notificationService.clearAll();
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Clear All'),
              ),
            ],
          ),
    );
  }

  void _showNotificationDetails(AppNotification notification) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                Icon(notification.icon, color: notification.color),
                const SizedBox(width: 8),
                Expanded(child: Text(notification.title)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Details:', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Text(notification.details),
                const SizedBox(height: 16),
                Text('Type:', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(notification.type.name.toUpperCase()),
                const SizedBox(height: 12),
                Text(
                  'Priority:',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      notification.priorityIcon,
                      size: 16,
                      color: notification.priorityColor,
                    ),
                    const SizedBox(width: 4),
                    Text(notification.priority.name.toUpperCase()),
                  ],
                ),
                const SizedBox(height: 12),
                Text('Time:', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(
                  DateFormat('MMM d, y - h:mm a').format(notification.dateTime),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
              if (notification.isDismissible)
                ElevatedButton(
                  onPressed: () {
                    _notificationService.deleteNotification(notification.id);
                    Navigator.of(context).pop();
                  },
                  child: const Text('Dismiss'),
                ),
            ],
          ),
    );
  }
}
