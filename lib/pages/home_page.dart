import '../services/homepage/homepage_service.dart';

import '../configs/configs.dart';

import '../components/toastmsg.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const double _sectionHeight = 320;

  Map<String, Map<String, dynamic>> attendanceMaps = {};
  List<Widget> notificationTiles = [];

  // init function
  @override
  void initState() {
    super.initState();
    _initHomePage();
  }

  @override
  void dispose() {
    super.dispose();
  }

  // Add this method to reload product data
  Future<void> _initHomePage() async {
    try {
      setState(() {
        attendanceMaps = homepageService.attendanceMaps;
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

  // Modern Card Section Wrapper with sticky title
  Widget _buildCardSection({
    required Widget title,
    required Widget child,
    required double height,
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
              child: Scrollbar(
                thumbVisibility: true,
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18.0),
                    child: child,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Attendance Section
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
        // Use the map and its entries correctly
        ...attendanceMaps.entries.map((entry) {
          final id = entry.key;
          final empData = entry.value;
          final emp = {...empData, 'id': id}; // Add employee ID to the map

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

    // Get employee image if exists
    final imageBytes = homepageService.employeeMap[emp['id']]?['image'];

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

      // Check if password is empty
      if (inputPassword.isEmpty) {
        setState(() {
          errorText = LOCALIZATION.localize('main_word.password_required');
          showToastMessage(context, errorText!, ToastLevel.error);
        });
        return;
      }

      // Get password from employee data
      final storedHash = homepageService.employeeMap[emp['id']]?['password'];
      if (storedHash == null) {
        HOMEPAGE_LOGS.error(
          'Password hash not found for employee: ${emp['id']}',
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
      final isValid = BCrypt.checkpw(inputPassword, storedHash);
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

        // HOMEPAGE_LOGS.debug(
        //   'Attendance updated for ${emp['name']}: ${HOMEPAGE_LOGS.map2str(emp)}\n\n${HOMEPAGE_LOGS.map2str(attendanceMaps[emp['id']]!)}',
        // );
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
                                        backgroundColor: mainColor.withOpacity(
                                          0.2,
                                        ),
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
                                          emp['username'].toString().isNotEmpty)
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
                                        isClockIn ? Icons.login : Icons.logout,
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
                                    crossAxisAlignment: CrossAxisAlignment.end,
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
                              LOCALIZATION.localize('main_word.enter_password'),
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
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: BorderSide(
                                          color: Colors.grey.shade300,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
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
                                        borderRadius: BorderRadius.circular(10),
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
        );
      },
    );
  }

  // Live Sales Summary
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

  Widget _buildSalesSummary(Color mainColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSummaryTile(
          icon: Icons.shopping_cart,
          iconColor: mainColor,
          label: LOCALIZATION.localize('home_page.orders'),
          value: "120",
        ),
        _buildSummaryTile(
          icon: Icons.attach_money,
          iconColor: Colors.green,
          label: LOCALIZATION.localize('home_page.revenue'),
          value: "${globalAppConfig["userPreferences"]["currency"]} 5,000",
        ),
        _buildSummaryTile(
          icon: Icons.bar_chart,
          iconColor: Colors.orange,
          label: LOCALIZATION.localize('home_page.profit'),
          value: "${globalAppConfig["userPreferences"]["currency"]} 1,000",
        ),
        _buildSummaryTile(
          icon: Icons.trending_up,
          iconColor: Colors.purple,
          label: LOCALIZATION.localize('home_page.best_selling_item'),
          value: "Cheeseburger",
        ),
      ],
    );
  }

  Widget _buildSummaryTile({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: iconColor.withOpacity(0.1),
            child: Icon(icon, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: iconColor,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  // Notification Panel
  Widget _notificationPanelTitle(Color mainColor) => Row(
    children: [
      Icon(Icons.notifications_active_rounded, color: mainColor),
      const SizedBox(width: 8),
      Text(
        LOCALIZATION.localize('home_page.notifications'),
        style: _headerStyle.copyWith(color: mainColor),
      ),
    ],
  );

  Widget _buildNotificationPanel(Color mainColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children:
          notificationTiles.isNotEmpty
              ? notificationTiles
              : [
                _buildNotificationTile(
                  icon: Icons.info_outline,
                  iconColor: mainColor,
                  title: LOCALIZATION.localize('home_page.no_notifications'),
                  subtitle: LOCALIZATION.localize('home_page.check_back_later'),
                ),
              ],
    );
  }

  Widget _buildNotificationTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: iconColor.withOpacity(0.1),
          child: Icon(icon, color: iconColor),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
      ),
    );
  }

  // Future Feature Placeholder
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
                  Expanded(
                    child: _buildCardSection(
                      title: _attendanceSectionTitle(mainColor),
                      child: _buildAttendanceSection(mainColor),
                      height: _sectionHeight,
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: _buildCardSection(
                      title: _salesSummaryTitle(mainColor),
                      child: _buildSalesSummary(mainColor),
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
