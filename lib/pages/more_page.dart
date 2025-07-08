import '../configs/configs.dart';

import '../pages/auth_page.dart';
import '../services/morepage/empaccount_section.dart';

import '../services/auth/auth_service.dart';
import '../services/database/db.dart';

import '../components/toastmsg.dart';
import '../components/buttonswithsound.dart';

// ignore: non_constant_identifier_names
late LoggingService MOREPAGE_LOGS;

// Sidebar menu items
enum MorePageSection {
  appSettings,
  employeeAccount,
  kioskInfo,
  connection,
  advanced,
}

class MorePage extends StatefulWidget {
  const MorePage({super.key});

  @override
  State<MorePage> createState() => _MorePageState();
}

class _MorePageState extends State<MorePage> {
  MorePageSection _selectedSection = MorePageSection.appSettings;

  bool _sidebarFolded = false;
  final bool _showDebugTools = false;

  // For settings
  String themeMode = globalAppConfig['userPreferences']['theme'];
  String language = globalAppConfig['userPreferences']['language'];
  String currency = globalAppConfig['userPreferences']['currency'];

  // variable for each section
  Map<String, Map<String, dynamic>> employees = {};

  Future<void> _initFunctions() async {
    // Initialize any required services or data here
    MOREPAGE_LOGS = await LoggingService(logName: "morepage_logs").initialize();

    setState(() {
      currency =
          (globalAppConfig['currency']['options'] as List).contains(currency)
              ? currency
              : (globalAppConfig['currency']['options'] as List).first
                  as String;
      employees = EMPQUERY.employees;
    });
  }

  @override
  void initState() {
    super.initState();
    // Initialize any required services or data here
    _initFunctions();
  }

  @override
  void dispose() {
    // Dispose of any resources if needed
    super.dispose();
  }

  Widget _buildSidebar(ThemeData theme, Color mainColor) {
    final items = [
      (
        MorePageSection.appSettings,
        Icons.settings,
        LOCALIZATION.localize('more_page.app_settings'),
      ),
      (
        MorePageSection.employeeAccount,
        Icons.person,
        LOCALIZATION.localize('more_page.employee_account'),
      ),
      (
        MorePageSection.kioskInfo,
        Icons.info,
        LOCALIZATION.localize('more_page.kiosk_info'),
      ),
      (
        MorePageSection.connection,
        Icons.usb,
        LOCALIZATION.localize('main_word.connection'),
      ),
      (
        MorePageSection.advanced,
        Icons.tune,
        LOCALIZATION.localize('main_word.advanced'),
      ),
      // Add more items here if needed
    ];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: _sidebarFolded ? 60 : 220,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 8,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              icon: Icon(
                _sidebarFolded ? Icons.chevron_right : Icons.chevron_left,
              ),
              tooltip: _sidebarFolded ? "Expand" : "Collapse",
              onPressed: () => setState(() => _sidebarFolded = !_sidebarFolded),
            ),
          ),
          Expanded(
            child: Scrollbar(
              thumbVisibility: true,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 12),
                itemCount: items.length,
                itemBuilder: (context, idx) {
                  final item = items[idx];
                  final selected = _selectedSection == item.$1;
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 2.0,
                      horizontal: 8,
                    ),
                    child: Material(
                      color:
                          selected
                              ? mainColor.withOpacity(0.12)
                              : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => setState(() => _selectedSection = item.$1),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: _sidebarFolded ? 0 : 10,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                item.$2,
                                color:
                                    selected
                                        ? mainColor
                                        : theme.iconTheme.color,
                              ),
                              if (!_sidebarFolded) ...[
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Text(
                                    item.$3,
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                          color:
                                              selected
                                                  ? mainColor
                                                  : theme
                                                      .textTheme
                                                      .bodyMedium
                                                      ?.color,
                                          fontWeight:
                                              selected
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                        ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 18.0),
            child:
                _sidebarFolded
                    ? null
                    : Text(
                      "v${globalAppConfig['version'] ?? '1.0.0'}",
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey,
                      ),
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionContent(ThemeData theme, Color mainColor) {
    switch (_selectedSection) {
      case MorePageSection.appSettings:
        return _buildAppSettings(theme, mainColor);
      case MorePageSection.employeeAccount:
        return EmployeeAccountSection(
          theme: theme,
          mainColor: mainColor,
          LOGS: MOREPAGE_LOGS,
        );
      case MorePageSection.kioskInfo:
        return _buildKioskInfo(theme, mainColor);
      case MorePageSection.connection:
        return _buildConnectionSettings(theme, mainColor);
      case MorePageSection.advanced:
        return _buildAdvanced(theme, mainColor);
    }
  }

  // 1. App Settings Section
  Widget _buildAppSettings(ThemeData theme, Color mainColor) {
    return Padding(
      key: const ValueKey('appSettings'),
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            LOCALIZATION.localize('more_page.app_settings') ?? "App Settings",
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
              padding: const EdgeInsets.all(28.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Theme Mode
                  Row(
                    children: [
                      Icon(Icons.brightness_6, color: mainColor),
                      const SizedBox(width: 12),
                      Text(
                        LOCALIZATION.localize('more_page.theme_mode') ??
                            "Theme",
                        style: theme.textTheme.titleMedium,
                      ),
                      const Spacer(),
                      DropdownButton<String>(
                        value: themeMode,
                        borderRadius: BorderRadius.circular(12),
                        style: theme.textTheme.titleMedium,
                        dropdownColor: theme.colorScheme.surface,
                        items:
                            (globalAppConfig['theme']['options'] as List)
                                .map(
                                  (e) => DropdownMenuItem<String>(
                                    value: e as String,
                                    child: Text(
                                      (e as String).replaceFirstMapped(
                                        RegExp(r'^\w'),
                                        (m) => m.group(0)!.toUpperCase(),
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                        onChanged: (val) async {
                          if (val != null) {
                            setState(() {
                              themeMode = val;
                              globalAppConfig['userPreferences']['theme'] = val;
                              themeNotifier.value = val;
                            });
                            if (await ConfigService.updateConfig()) {
                              showToastMessage(
                                context,
                                "${LOCALIZATION.localize('more_page.theme_changed')}: $val",
                                ToastLevel.success,
                              );
                            } else {
                              showToastMessage(
                                context,
                                LOCALIZATION.localize(
                                      'more_page.theme_change_failed',
                                    ) ??
                                    "Theme change failed",
                                ToastLevel.error,
                              );
                            }
                          }
                        },
                      ),
                    ],
                  ),
                  const Divider(height: 32),
                  // Language
                  Row(
                    children: [
                      Icon(Icons.language, color: mainColor),
                      const SizedBox(width: 12),
                      Text(
                        LOCALIZATION.localize('more_page.language') ??
                            "Language",
                        style: theme.textTheme.titleMedium,
                      ),
                      const Spacer(),
                      DropdownButton<String>(
                        value: language,
                        borderRadius: BorderRadius.circular(12),
                        style: theme.textTheme.titleMedium,
                        dropdownColor: theme.colorScheme.surface,
                        items:
                            (globalAppConfig['language']['options'] as List)
                                .map(
                                  (e) => DropdownMenuItem<String>(
                                    value: e as String,
                                    child: Text((e as String).toUpperCase()),
                                  ),
                                )
                                .toList(),

                        onChanged: (val) async {
                          if (val != null) {
                            setState(() {
                              language = val;
                              globalAppConfig['userPreferences']['language'] =
                                  val;
                            });
                            if (await ConfigService.updateConfig()) {
                              showToastMessage(
                                context,
                                "${LOCALIZATION.localize('more_page.language_changed')}: $val",
                                ToastLevel.success,
                              );
                              // Show confirmation dialog with timer before restart
                              int seconds = 3;
                              showDialog(
                                context: context,
                                barrierDismissible: false,
                                builder: (context) {
                                  late StateSetter setDialogState;
                                  Timer? timer;
                                  void startTimer() {
                                    timer = Timer.periodic(
                                      const Duration(seconds: 1),
                                      (t) {
                                        if (seconds > 1) {
                                          setDialogState(() => seconds--);
                                        } else {
                                          t.cancel();
                                          Navigator.of(context).pop();
                                          Restart.restartApp();
                                        }
                                      },
                                    );
                                  }

                                  return StatefulBuilder(
                                    builder: (context, setState) {
                                      setDialogState = setState;
                                      if (timer == null) startTimer();
                                      return AlertDialog(
                                        title: Text(
                                          LOCALIZATION.localize(
                                                'more_page.restart_required',
                                              ) ??
                                              "Restart Required",
                                        ),
                                        content: Text(
                                          "${LOCALIZATION.localize('more_page.restart_in') ?? "App will restart in"} $seconds ${LOCALIZATION.localize('main_word.seconds') ?? "seconds"}...",
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () {
                                              timer?.cancel();
                                              Navigator.of(context).pop();
                                            },
                                            child: Text(
                                              LOCALIZATION.localize(
                                                    'main_word.cancel',
                                                  ) ??
                                                  "Cancel",
                                            ),
                                          ),
                                          ElevatedButton(
                                            onPressed: () {
                                              timer?.cancel();
                                              Navigator.of(context).pop();
                                              Restart.restartApp();
                                            },
                                            child: Text(
                                              LOCALIZATION.localize(
                                                    'main_word.restart_now',
                                                  ) ??
                                                  "Restart Now",
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                },
                              );
                            } else {
                              showToastMessage(
                                context,
                                LOCALIZATION.localize(
                                      'more_page.language_change_failed',
                                    ) ??
                                    "Language change failed",
                                ToastLevel.error,
                              );
                            }
                          }
                        },
                      ),
                    ],
                  ),
                  const Divider(height: 32),
                  // Currency
                  Row(
                    children: [
                      Icon(Icons.attach_money, color: mainColor),
                      const SizedBox(width: 12),
                      Text(
                        LOCALIZATION.localize('more_page.currency') ??
                            "Currency",
                        style: theme.textTheme.titleMedium,
                      ),
                      const Spacer(),
                      DropdownButton<String>(
                        value: currency,
                        borderRadius: BorderRadius.circular(12),
                        style: theme.textTheme.titleMedium,
                        dropdownColor: theme.colorScheme.surface,
                        items:
                            (globalAppConfig['currency']['options'] as List)
                                .map(
                                  (e) => DropdownMenuItem<String>(
                                    value: e as String,
                                    child: Text(e as String),
                                  ),
                                )
                                .toList(),
                        onChanged: (val) async {
                          if (val != null) {
                            setState(() {
                              currency = val;
                              globalAppConfig['userPreferences']['currency'] =
                                  val;
                            });
                            if (await ConfigService.updateConfig()) {
                              showToastMessage(
                                context,
                                "${LOCALIZATION.localize('more_page.currency_changed')}: $val",
                                ToastLevel.success,
                              );
                            } else {
                              showToastMessage(
                                context,
                                LOCALIZATION.localize(
                                      'more_page.currency_change_failed',
                                    ) ??
                                    "Currency change failed",
                                ToastLevel.error,
                              );
                            }
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 3. Kiosk Information Section
  Widget _buildKioskInfo(ThemeData theme, Color mainColor) {
    final kioskInfo = {
      "name": globalAppConfig['kiosk_info']['kiosk_name'] ?? "NOT FOUND",
      "location": globalAppConfig['kiosk_info']['location'] ?? "N/A",
      "id": globalAppConfig['kiosk_info']['kiosk_id'] ?? "N/A",
      "version": globalAppConfig['version'] ?? "1.0.0",
      "lastSync": globalAppConfig['kiosk_info']['last_sync'] ?? "N/A",
      "registered": globalAppConfig['kiosk_info']['registered'] ?? false,
    };

    return Padding(
      key: const ValueKey('kioskInfo'),
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 36),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    LOCALIZATION.localize('more_page.kiosk_info') ??
                        "Kiosk Information",
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
                      padding: const EdgeInsets.all(28.0),
                      child: SingleChildScrollView(
                        // This makes the card content scrollable if needed
                        physics: const NeverScrollableScrollPhysics(),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.store, color: mainColor),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    kioskInfo["name"],
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Chip(
                                  label: Text(
                                    kioskInfo["registered"]
                                        ? LOCALIZATION.localize(
                                              'main_word.registered',
                                            ) ??
                                            "REGISTERED"
                                        : LOCALIZATION.localize(
                                              'main_word.not_registered',
                                            ) ??
                                            "NOT REGISTERED",
                                    style: TextStyle(
                                      color:
                                          kioskInfo["registered"]
                                              ? Colors.green
                                              : Colors.red,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  backgroundColor:
                                      kioskInfo["registered"]
                                          ? Colors.green.withOpacity(0.1)
                                          : Colors.red.withOpacity(0.1),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),

                            ListTile(
                              leading: Icon(
                                Icons.location_on,
                                color: mainColor,
                              ),
                              title: Text(
                                LOCALIZATION.localize(
                                      'more_page.kiosk_location',
                                    ) ??
                                    "Location",
                              ),
                              subtitle: Text(kioskInfo["location"]),
                            ),

                            ListTile(
                              leading: Icon(
                                Icons.confirmation_number,
                                color: mainColor,
                              ),
                              title: Text(
                                LOCALIZATION.localize('more_page.kiosk_id') ??
                                    "Kiosk ID",
                              ),
                              subtitle: Text(kioskInfo["id"]),
                            ),

                            ListTile(
                              leading: Icon(Icons.update, color: mainColor),
                              title: Text(
                                LOCALIZATION.localize('main_word.last_sync') ??
                                    "Last Sync",
                              ),
                              subtitle: Text(kioskInfo["lastSync"]),
                            ),

                            ListTile(
                              leading: Icon(
                                Icons.info_outline,
                                color: mainColor,
                              ),
                              title: Text(
                                LOCALIZATION.localize('main_page.version') ??
                                    "Version",
                              ),
                              subtitle: Text(kioskInfo["version"]),
                            ),
                            const SizedBox(height: 12),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                ElevatedButtonWithSound.icon(
                                  icon: const Icon(Icons.edit),
                                  label: Text(
                                    LOCALIZATION.localize(
                                          'more_page.adjust_kiosk_info',
                                        ) ??
                                        "Adjust Kiosk Info",
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: mainColor,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  onPressed: () async {
                                    final TextEditingController
                                    kioskNameController =
                                        TextEditingController();
                                    final TextEditingController
                                    locationController =
                                        TextEditingController();
                                    final TextEditingController
                                    currentPasswordController =
                                        TextEditingController();
                                    final TextEditingController
                                    newPasswordController =
                                        TextEditingController();
                                    final TextEditingController
                                    confirmPasswordController =
                                        TextEditingController();

                                    // Pre-fill with current values
                                    kioskNameController.text =
                                        globalAppConfig['kiosk_info']['kiosk_name'] ??
                                        '';
                                    locationController.text =
                                        globalAppConfig['kiosk_info']['location'] ??
                                        '';

                                    showDialog(
                                      context: context,
                                      barrierDismissible: false,
                                      builder:
                                          (context) => AlertDialog(
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            backgroundColor:
                                                theme.colorScheme.surface,
                                            elevation: 10,
                                            title: Container(
                                              padding: const EdgeInsets.only(
                                                bottom: 16,
                                              ),
                                              decoration: BoxDecoration(
                                                border: Border(
                                                  bottom: BorderSide(
                                                    color: mainColor
                                                        .withOpacity(0.3),
                                                    width: 2,
                                                  ),
                                                ),
                                              ),
                                              child: Row(
                                                children: [
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.all(8),
                                                    decoration: BoxDecoration(
                                                      color: mainColor
                                                          .withOpacity(0.1),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            10,
                                                          ),
                                                    ),
                                                    child: Icon(
                                                      Icons.edit,
                                                      color: mainColor,
                                                      size: 24,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),

                                                  Expanded(
                                                    child: Text(
                                                      LOCALIZATION.localize(
                                                            'more_page.adjust_kiosk_info',
                                                          ) ??
                                                          "Adjust Kiosk Info",
                                                      style: theme
                                                          .textTheme
                                                          .titleLarge
                                                          ?.copyWith(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color: mainColor,
                                                          ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            content: Container(
                                              width: double.maxFinite,
                                              constraints: const BoxConstraints(
                                                maxWidth: 500,
                                                maxHeight: 400,
                                              ),
                                              child: SingleChildScrollView(
                                                child: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    const SizedBox(height: 16),

                                                    // Kiosk Name Field
                                                    Container(
                                                      decoration: BoxDecoration(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              12,
                                                            ),
                                                        border: Border.all(
                                                          color: mainColor
                                                              .withOpacity(0.3),
                                                          width: 1,
                                                        ),
                                                      ),
                                                      child: TextField(
                                                        controller:
                                                            kioskNameController,
                                                        decoration: InputDecoration(
                                                          labelText:
                                                              LOCALIZATION.localize(
                                                                'auth_page.kiosk_name',
                                                              ) ??
                                                              "Kiosk Name",
                                                          labelStyle: TextStyle(
                                                            color: mainColor,
                                                          ),
                                                          border:
                                                              InputBorder.none,
                                                          contentPadding:
                                                              const EdgeInsets.all(
                                                                16,
                                                              ),
                                                          prefixIcon: Icon(
                                                            Icons.store,
                                                            color: mainColor,
                                                          ),
                                                          floatingLabelBehavior:
                                                              FloatingLabelBehavior
                                                                  .always,
                                                        ),
                                                        style:
                                                            theme
                                                                .textTheme
                                                                .bodyLarge,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 20),

                                                    // Location Field
                                                    Container(
                                                      decoration: BoxDecoration(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              12,
                                                            ),
                                                        border: Border.all(
                                                          color: mainColor
                                                              .withOpacity(0.3),
                                                          width: 1,
                                                        ),
                                                      ),
                                                      child: TextField(
                                                        controller:
                                                            locationController,
                                                        decoration: InputDecoration(
                                                          labelText:
                                                              LOCALIZATION.localize(
                                                                'auth_page.location',
                                                              ) ??
                                                              "Location",
                                                          labelStyle: TextStyle(
                                                            color: mainColor,
                                                          ),
                                                          border:
                                                              InputBorder.none,
                                                          contentPadding:
                                                              const EdgeInsets.all(
                                                                16,
                                                              ),
                                                          prefixIcon: Icon(
                                                            Icons.location_on,
                                                            color: mainColor,
                                                          ),
                                                          suffixIcon: IconButton(
                                                            icon: Icon(
                                                              Icons.my_location,
                                                              color: mainColor,
                                                            ),
                                                            tooltip:
                                                                LOCALIZATION
                                                                    .localize(
                                                                      'main_word.get_location',
                                                                    ) ??
                                                                "Get Current Location",
                                                            onPressed: () async {
                                                              // Show loading
                                                              showDialog(
                                                                context:
                                                                    context,
                                                                barrierDismissible:
                                                                    false,
                                                                builder:
                                                                    (
                                                                      context,
                                                                    ) => Center(
                                                                      child: Container(
                                                                        padding:
                                                                            const EdgeInsets.all(
                                                                              20,
                                                                            ),
                                                                        decoration: BoxDecoration(
                                                                          color:
                                                                              theme.colorScheme.surface,
                                                                          borderRadius: BorderRadius.circular(
                                                                            10,
                                                                          ),
                                                                        ),
                                                                        child: Column(
                                                                          mainAxisSize:
                                                                              MainAxisSize.min,
                                                                          children: [
                                                                            CircularProgressIndicator(
                                                                              color:
                                                                                  mainColor,
                                                                            ),
                                                                            const SizedBox(
                                                                              height:
                                                                                  16,
                                                                            ),
                                                                            Text(
                                                                              LOCALIZATION.localize(
                                                                                    'main_word.getting_location',
                                                                                  ) ??
                                                                                  "Getting location...",
                                                                              style:
                                                                                  theme.textTheme.bodyMedium,
                                                                            ),
                                                                          ],
                                                                        ),
                                                                      ),
                                                                    ),
                                                              );

                                                              try {
                                                                Map<
                                                                  String,
                                                                  dynamic
                                                                >
                                                                address =
                                                                    await getCurrentAddress();
                                                                Navigator.of(
                                                                  context,
                                                                ).pop(); // Close loading dialog

                                                                if (address["success"]) {
                                                                  locationController
                                                                          .text =
                                                                      address["address"];
                                                                } else {
                                                                  showToastMessage(
                                                                    context,
                                                                    "Failed to get location: ${address["message"]}",
                                                                    ToastLevel
                                                                        .error,
                                                                  );
                                                                }
                                                              } catch (e) {
                                                                Navigator.of(
                                                                  context,
                                                                ).pop(); // Close loading dialog
                                                                showToastMessage(
                                                                  context,
                                                                  LOCALIZATION.localize(
                                                                        'auth_page.failed_to_get_location',
                                                                      ) ??
                                                                      "Failed to get location",
                                                                  ToastLevel
                                                                      .error,
                                                                );
                                                              }
                                                            },
                                                          ),
                                                          floatingLabelBehavior:
                                                              FloatingLabelBehavior
                                                                  .always,
                                                        ),
                                                        style:
                                                            theme
                                                                .textTheme
                                                                .bodyLarge,
                                                        maxLines: 2,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 24),

                                                    // Info Card
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.all(
                                                            16,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: mainColor
                                                            .withOpacity(0.05),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              12,
                                                            ),
                                                        border: Border.all(
                                                          color: mainColor
                                                              .withOpacity(0.2),
                                                          width: 1,
                                                        ),
                                                      ),
                                                      child: Row(
                                                        children: [
                                                          Icon(
                                                            Icons.info_outline,
                                                            color: mainColor,
                                                          ),
                                                          const SizedBox(
                                                            width: 12,
                                                          ),
                                                          Expanded(
                                                            child: Text(
                                                              LOCALIZATION.localize(
                                                                    'more_page.kiosk_info_note',
                                                                  ) ??
                                                                  "These changes will be saved to your local configuration and can be synced later.",
                                                              style: theme
                                                                  .textTheme
                                                                  .bodySmall
                                                                  ?.copyWith(
                                                                    color:
                                                                        mainColor,
                                                                  ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    const SizedBox(height: 20),

                                                    // Change Kiosk Password Section
                                                    Container(
                                                      decoration: BoxDecoration(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              12,
                                                            ),
                                                        border: Border.all(
                                                          color: mainColor
                                                              .withOpacity(0.3),
                                                          width: 1,
                                                        ),
                                                      ),
                                                      child: ExpansionTile(
                                                        leading: Icon(
                                                          Icons.lock_reset,
                                                          color: mainColor,
                                                        ),
                                                        title: Text(
                                                          LOCALIZATION.localize(
                                                                'more_page.change_kiosk_password',
                                                              ) ??
                                                              "Change Kiosk Password",
                                                          style: theme
                                                              .textTheme
                                                              .bodyLarge
                                                              ?.copyWith(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w500,
                                                              ),
                                                        ),
                                                        children: [
                                                          Padding(
                                                            padding:
                                                                const EdgeInsets.all(
                                                                  16.0,
                                                                ),
                                                            child: Column(
                                                              children: [
                                                                // Current Password Field
                                                                Container(
                                                                  decoration: BoxDecoration(
                                                                    borderRadius:
                                                                        BorderRadius.circular(
                                                                          8,
                                                                        ),
                                                                    border: Border.all(
                                                                      color: mainColor
                                                                          .withOpacity(
                                                                            0.3,
                                                                          ),
                                                                      width: 1,
                                                                    ),
                                                                  ),
                                                                  child: TextField(
                                                                    controller:
                                                                        currentPasswordController,
                                                                    obscureText:
                                                                        true,
                                                                    decoration: InputDecoration(
                                                                      labelText:
                                                                          LOCALIZATION.localize(
                                                                            'auth_page.current_password',
                                                                          ) ??
                                                                          "Current Password",
                                                                      labelStyle:
                                                                          TextStyle(
                                                                            color:
                                                                                mainColor,
                                                                          ),
                                                                      border:
                                                                          InputBorder
                                                                              .none,
                                                                      contentPadding:
                                                                          const EdgeInsets.all(
                                                                            12,
                                                                          ),
                                                                      prefixIcon: Icon(
                                                                        Icons
                                                                            .lock_outline,
                                                                        color:
                                                                            mainColor,
                                                                      ),
                                                                    ),
                                                                    style:
                                                                        theme
                                                                            .textTheme
                                                                            .bodyLarge,
                                                                  ),
                                                                ),
                                                                const SizedBox(
                                                                  height: 12,
                                                                ),

                                                                // New Password Field
                                                                Container(
                                                                  decoration: BoxDecoration(
                                                                    borderRadius:
                                                                        BorderRadius.circular(
                                                                          8,
                                                                        ),
                                                                    border: Border.all(
                                                                      color: mainColor
                                                                          .withOpacity(
                                                                            0.3,
                                                                          ),
                                                                      width: 1,
                                                                    ),
                                                                  ),
                                                                  child: TextField(
                                                                    controller:
                                                                        newPasswordController,
                                                                    obscureText:
                                                                        true,
                                                                    decoration: InputDecoration(
                                                                      labelText:
                                                                          LOCALIZATION.localize(
                                                                            'auth_page.new_password',
                                                                          ) ??
                                                                          "New Password",
                                                                      labelStyle:
                                                                          TextStyle(
                                                                            color:
                                                                                mainColor,
                                                                          ),
                                                                      border:
                                                                          InputBorder
                                                                              .none,
                                                                      contentPadding:
                                                                          const EdgeInsets.all(
                                                                            12,
                                                                          ),
                                                                      prefixIcon: Icon(
                                                                        Icons
                                                                            .lock,
                                                                        color:
                                                                            mainColor,
                                                                      ),
                                                                      suffixIcon: IconButton(
                                                                        icon: Icon(
                                                                          Icons
                                                                              .auto_awesome,
                                                                          color:
                                                                              mainColor,
                                                                        ),
                                                                        tooltip:
                                                                            LOCALIZATION.localize(
                                                                              'main_word.generate',
                                                                            ) ??
                                                                            "Generate",
                                                                        onPressed: () {
                                                                          newPasswordController
                                                                              .text = EncryptService().generateStrongPassword(
                                                                            8,
                                                                          );
                                                                        },
                                                                      ),
                                                                    ),
                                                                    style:
                                                                        theme
                                                                            .textTheme
                                                                            .bodyLarge,
                                                                  ),
                                                                ),
                                                                const SizedBox(
                                                                  height: 12,
                                                                ),

                                                                // Confirm New Password Field
                                                                Container(
                                                                  decoration: BoxDecoration(
                                                                    borderRadius:
                                                                        BorderRadius.circular(
                                                                          8,
                                                                        ),
                                                                    border: Border.all(
                                                                      color: mainColor
                                                                          .withOpacity(
                                                                            0.3,
                                                                          ),
                                                                      width: 1,
                                                                    ),
                                                                  ),
                                                                  child: TextField(
                                                                    controller:
                                                                        confirmPasswordController,
                                                                    obscureText:
                                                                        true,
                                                                    decoration: InputDecoration(
                                                                      labelText:
                                                                          LOCALIZATION.localize(
                                                                            'auth_page.confirm_password',
                                                                          ) ??
                                                                          "Confirm New Password",
                                                                      labelStyle:
                                                                          TextStyle(
                                                                            color:
                                                                                mainColor,
                                                                          ),
                                                                      border:
                                                                          InputBorder
                                                                              .none,
                                                                      contentPadding:
                                                                          const EdgeInsets.all(
                                                                            12,
                                                                          ),
                                                                      prefixIcon: Icon(
                                                                        Icons
                                                                            .lock_outline,
                                                                        color:
                                                                            mainColor,
                                                                      ),
                                                                    ),
                                                                    style:
                                                                        theme
                                                                            .textTheme
                                                                            .bodyLarge,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            actions: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 8,
                                                    ),
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.end,
                                                  children: [
                                                    // Cancel Button
                                                    TextButton(
                                                      onPressed: () {
                                                        kioskNameController
                                                            .dispose();
                                                        locationController
                                                            .dispose();
                                                        Navigator.of(
                                                          context,
                                                        ).pop();
                                                      },
                                                      style: TextButton.styleFrom(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 24,
                                                              vertical: 12,
                                                            ),
                                                        shape: RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                10,
                                                              ),
                                                        ),
                                                      ),
                                                      child: Text(
                                                        LOCALIZATION.localize(
                                                              'main_word.cancel',
                                                            ) ??
                                                            "Cancel",
                                                        style: TextStyle(
                                                          color: theme
                                                              .colorScheme
                                                              .onSurface
                                                              .withOpacity(0.7),
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 12),

                                                    // Save Button
                                                    ElevatedButtonWithSound(
                                                      onPressed: () async {
                                                        final newKioskName =
                                                            kioskNameController
                                                                .text
                                                                .trim();
                                                        final newLocation =
                                                            locationController
                                                                .text
                                                                .trim();
                                                        final currentPassword =
                                                            currentPasswordController
                                                                .text
                                                                .trim();
                                                        final newPassword =
                                                            newPasswordController
                                                                .text
                                                                .trim();
                                                        final confirmPassword =
                                                            confirmPasswordController
                                                                .text
                                                                .trim();

                                                        if (newKioskName
                                                                .isEmpty ||
                                                            newLocation
                                                                .isEmpty) {
                                                          showToastMessage(
                                                            context,
                                                            LOCALIZATION.localize(
                                                                  'more_page.fill_all_fields',
                                                                ) ??
                                                                "Please fill all fields",
                                                            ToastLevel.warning,
                                                          );
                                                          return;
                                                        }

                                                        // Check if user wants to change password
                                                        bool changePassword =
                                                            currentPassword
                                                                .isNotEmpty ||
                                                            newPassword
                                                                .isNotEmpty ||
                                                            confirmPassword
                                                                .isNotEmpty;

                                                        if (changePassword) {
                                                          // Validate password fields
                                                          if (currentPassword
                                                                  .isEmpty ||
                                                              newPassword
                                                                  .isEmpty ||
                                                              confirmPassword
                                                                  .isEmpty) {
                                                            showToastMessage(
                                                              context,
                                                              LOCALIZATION.localize(
                                                                    'more_page.fill_all_password_fields',
                                                                  ) ??
                                                                  "Please fill all password fields",
                                                              ToastLevel
                                                                  .warning,
                                                            );
                                                            return;
                                                          }

                                                          if (newPassword !=
                                                              confirmPassword) {
                                                            showToastMessage(
                                                              context,
                                                              LOCALIZATION.localize(
                                                                    'auth_page.password_mismatch',
                                                                  ) ??
                                                                  "New passwords do not match",
                                                              ToastLevel.error,
                                                            );
                                                            return;
                                                          }

                                                          if (newPassword
                                                                  .length <
                                                              6) {
                                                            showToastMessage(
                                                              context,
                                                              LOCALIZATION.localize(
                                                                    'auth_page.password_too_short',
                                                                  ) ??
                                                                  "Password must be at least 6 characters",
                                                              ToastLevel.error,
                                                            );
                                                            return;
                                                          }

                                                          // Verify current password
                                                          bool
                                                          currentPasswordValid =
                                                              await EncryptService()
                                                                  .decryptPassword(
                                                                    globalAppConfig["kiosk_info"]["kiosk_password"],
                                                                    targetPassword:
                                                                        currentPassword,
                                                                  );

                                                          if (!currentPasswordValid) {
                                                            showToastMessage(
                                                              context,
                                                              LOCALIZATION.localize(
                                                                    'auth_page.current_password_incorrect',
                                                                  ) ??
                                                                  "Current password is incorrect",
                                                              ToastLevel.error,
                                                            );
                                                            return;
                                                          }

                                                          // Ask for admin authentication before changing password
                                                          final adminController =
                                                              TextEditingController();
                                                          bool?
                                                          adminConfirmed = await showDialog<
                                                            bool
                                                          >(
                                                            context: context,
                                                            barrierDismissible:
                                                                false,
                                                            builder:
                                                                (
                                                                  context,
                                                                ) => AlertDialog(
                                                                  shape: RoundedRectangleBorder(
                                                                    borderRadius:
                                                                        BorderRadius.circular(
                                                                          20,
                                                                        ),
                                                                  ),
                                                                  title: Row(
                                                                    children: [
                                                                      Icon(
                                                                        Icons
                                                                            .admin_panel_settings,
                                                                        color:
                                                                            Colors.red,
                                                                      ),
                                                                      const SizedBox(
                                                                        width:
                                                                            12,
                                                                      ),
                                                                      Text(
                                                                        LOCALIZATION.localize(
                                                                              'more_page.admin_authentication',
                                                                            ) ??
                                                                            "Admin Authentication",
                                                                        style: TextStyle(
                                                                          color:
                                                                              Colors.red,
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                  content: Column(
                                                                    mainAxisSize:
                                                                        MainAxisSize
                                                                            .min,
                                                                    children: [
                                                                      Text(
                                                                        LOCALIZATION.localize(
                                                                              'more_page.admin_password_required',
                                                                            ) ??
                                                                            "Admin password is required to change kiosk password.",
                                                                        style:
                                                                            theme.textTheme.bodyMedium,
                                                                      ),
                                                                      const SizedBox(
                                                                        height:
                                                                            16,
                                                                      ),

                                                                      TextField(
                                                                        controller:
                                                                            adminController,
                                                                        obscureText:
                                                                            true,
                                                                        decoration: InputDecoration(
                                                                          labelText:
                                                                              LOCALIZATION.localize(
                                                                                'auth_page.admin_password',
                                                                              ) ??
                                                                              "Admin Password",
                                                                          border: OutlineInputBorder(
                                                                            borderRadius: BorderRadius.circular(
                                                                              8.0,
                                                                            ),
                                                                          ),
                                                                          prefixIcon: const Icon(
                                                                            Icons.admin_panel_settings,
                                                                          ),
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                  actions: [
                                                                    TextButton(
                                                                      onPressed: () {
                                                                        adminController
                                                                            .dispose();
                                                                        Navigator.of(
                                                                          context,
                                                                        ).pop(
                                                                          false,
                                                                        );
                                                                      },
                                                                      child: Text(
                                                                        LOCALIZATION.localize(
                                                                              'main_word.cancel',
                                                                            ) ??
                                                                            "Cancel",
                                                                      ),
                                                                    ),

                                                                    ElevatedButtonWithSound(
                                                                      onPressed: () async {
                                                                        final adminPassword =
                                                                            adminController.text.trim();
                                                                        if (adminPassword
                                                                            .isEmpty) {
                                                                          showToastMessage(
                                                                            context,
                                                                            LOCALIZATION.localize(
                                                                                  'more_page.enter_admin_password',
                                                                                ) ??
                                                                                "Please enter admin password",
                                                                            ToastLevel.warning,
                                                                          );
                                                                          return;
                                                                        }

                                                                        // Verify admin password using EMPQUERY
                                                                        bool
                                                                        adminValid =
                                                                            false;
                                                                        try {
                                                                          final adminUser =
                                                                              EMPQUERY.employees["0"]; // Assuming admin is ID 0
                                                                          if (adminUser !=
                                                                                  null &&
                                                                              adminUser["username"] ==
                                                                                  "ADMIN") {
                                                                            adminValid = await EncryptService().decryptPassword(
                                                                              adminUser["password"],
                                                                              targetPassword:
                                                                                  adminPassword,
                                                                            );
                                                                          }
                                                                        } catch (
                                                                          e
                                                                        ) {
                                                                          adminValid =
                                                                              false;
                                                                        }

                                                                        if (adminValid) {
                                                                          adminController
                                                                              .dispose();
                                                                          Navigator.of(
                                                                            context,
                                                                          ).pop(
                                                                            true,
                                                                          );
                                                                        } else {
                                                                          showToastMessage(
                                                                            context,
                                                                            LOCALIZATION.localize(
                                                                                  'auth_page.admin_password_incorrect',
                                                                                ) ??
                                                                                "Invalid admin password",
                                                                            ToastLevel.error,
                                                                          );
                                                                        }
                                                                      },
                                                                      style: ElevatedButton.styleFrom(
                                                                        backgroundColor:
                                                                            Colors.red,
                                                                        foregroundColor:
                                                                            Colors.white,
                                                                      ),
                                                                      child: Text(
                                                                        LOCALIZATION.localize(
                                                                              'main_word.verify',
                                                                            ) ??
                                                                            "Verify",
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                          );

                                                          if (adminConfirmed !=
                                                              true) {
                                                            return; // Admin authentication failed or cancelled
                                                          }

                                                          // Encrypt and update new password
                                                          globalAppConfig['kiosk_info']['kiosk_password'] =
                                                              await EncryptService()
                                                                  .encryptPassword(
                                                                    newPassword,
                                                                  );
                                                        }

                                                        // Update other kiosk info
                                                        globalAppConfig['kiosk_info']['kiosk_name'] =
                                                            newKioskName;
                                                        globalAppConfig['kiosk_info']['location'] =
                                                            newLocation;

                                                        // Save to file
                                                        final success =
                                                            await ConfigService.updateConfig();

                                                        if (success) {
                                                          showToastMessage(
                                                            context,
                                                            changePassword
                                                                ? (LOCALIZATION
                                                                        .localize(
                                                                          'more_page.kiosk_info_and_password_updated',
                                                                        ) ??
                                                                    "Kiosk information and password updated successfully")
                                                                : (LOCALIZATION
                                                                        .localize(
                                                                          'more_page.kiosk_info_updated',
                                                                        ) ??
                                                                    "Kiosk information updated successfully"),
                                                            ToastLevel.success,
                                                          );

                                                          // Refresh the page
                                                          setState(() {});

                                                          // Dispose controllers
                                                          kioskNameController
                                                              .dispose();
                                                          locationController
                                                              .dispose();
                                                          currentPasswordController
                                                              .dispose();
                                                          newPasswordController
                                                              .dispose();
                                                          confirmPasswordController
                                                              .dispose();

                                                          Navigator.of(
                                                            context,
                                                          ).pop();
                                                        } else {
                                                          showToastMessage(
                                                            context,
                                                            LOCALIZATION.localize(
                                                                  'more_page.update_failed',
                                                                ) ??
                                                                "Failed to update kiosk information",
                                                            ToastLevel.error,
                                                          );
                                                        }
                                                      },
                                                      style: ElevatedButton.styleFrom(
                                                        backgroundColor:
                                                            mainColor,
                                                        foregroundColor:
                                                            Colors.white,
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 24,
                                                              vertical: 12,
                                                            ),
                                                        shape: RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                10,
                                                              ),
                                                        ),
                                                        elevation: 3,
                                                      ),
                                                      child: Row(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          const Icon(
                                                            Icons.save,
                                                            size: 18,
                                                          ),
                                                          const SizedBox(
                                                            width: 8,
                                                          ),
                                                          Text(
                                                            LOCALIZATION.localize(
                                                                  'main_word.save',
                                                                ) ??
                                                                "Save",
                                                            style:
                                                                const TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                    );
                                  },
                                ),
                                const SizedBox(width: 12),

                                // Sync Now Button
                                ElevatedButtonWithSound.icon(
                                  icon: const Icon(Icons.sync),
                                  label: Text(
                                    LOCALIZATION.localize(
                                          'main_word.sync_now',
                                        ) ??
                                        "Sync Now",
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: mainColor,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  onPressed: () {
                                    showToastMessage(
                                      context,
                                      LOCALIZATION.localize(
                                            'more_page.sync_triggered',
                                          ) ??
                                          "Sync triggered",
                                      ToastLevel.info,
                                    );
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // 4. Connection Settings Section
  Widget _buildConnectionSettings(ThemeData theme, Color mainColor) {
    // Example: Use globalAppConfig for device settings
    final bluetoothPrinter = globalAppConfig['cashier']['bluetooth_printer'];
    final cashDrawer = globalAppConfig['cashier']['cash_drawer'];

    return Padding(
      key: const ValueKey('connectionSettings'),
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            LOCALIZATION.localize('main_word.connection') ?? "Connection",
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
              padding: const EdgeInsets.all(28.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Bluetooth Printer
                  Row(
                    children: [
                      Icon(Icons.print, color: mainColor),
                      const SizedBox(width: 12),
                      Text(
                        LOCALIZATION.localize('main_word.bluetooth_printer') ??
                            "Bluetooth Printer",
                        style: theme.textTheme.titleMedium,
                      ),
                      const Spacer(),
                      Switch(
                        value: bluetoothPrinter['enabled'] ?? false,
                        activeColor: mainColor,
                        onChanged: (val) async {
                          setState(() {
                            bluetoothPrinter['enabled'] = val;
                            globalAppConfig['cashier']['bluetooth_printer']['enabled'] =
                                val;
                          });
                          if (await ConfigService.updateConfig()) {
                            showToastMessage(
                              context,
                              "${LOCALIZATION.localize('more_page.printer_enabled')}: $val",
                              ToastLevel.success,
                            );
                          } else {
                            showToastMessage(
                              context,
                              LOCALIZATION.localize(
                                    'more_page.printer_change_failed',
                                  ) ??
                                  "Printer change failed",
                              ToastLevel.error,
                            );
                          }
                        },
                      ),
                    ],
                  ),
                  if (bluetoothPrinter['enabled'] == true) ...[
                    const SizedBox(height: 10),
                    ListTile(
                      leading: Icon(Icons.devices, color: mainColor),
                      title: Text(
                        LOCALIZATION.localize('more_page.device_name') ??
                            "Device Name",
                      ),
                      subtitle: Text(bluetoothPrinter['device_name'] ?? "-"),
                      trailing: ElevatedButton.icon(
                        icon: const Icon(Icons.search),
                        label: Text(
                          LOCALIZATION.localize('more_page.scan') ?? "Scan",
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: mainColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () {
                          // TODO: Implement scan for Bluetooth printers
                          showToastMessage(
                            context,
                            LOCALIZATION.localize('more_page.scan_printer') ??
                                "Scanning for printers...",
                            ToastLevel.info,
                          );
                        },
                      ),
                    ),
                  ],
                  const Divider(height: 32),
                  // Cash Drawer
                  Row(
                    children: [
                      Icon(Icons.money, color: mainColor),
                      const SizedBox(width: 12),
                      Text(
                        LOCALIZATION.localize('main_word.cash_drawer') ??
                            "Cash Drawer",
                        style: theme.textTheme.titleMedium,
                      ),
                      const Spacer(),

                      Switch(
                        value: cashDrawer['enabled'] ?? false,
                        activeColor: mainColor,
                        onChanged: (val) async {
                          setState(() {
                            cashDrawer['enabled'] = val;
                            globalAppConfig['cashier']['cash_drawer']['enabled'] =
                                val;
                          });
                          if (await ConfigService.updateConfig()) {
                            showToastMessage(
                              context,
                              "${LOCALIZATION.localize('more_page.drawer_enabled')}: $val",
                              ToastLevel.success,
                            );
                          } else {
                            showToastMessage(
                              context,
                              LOCALIZATION.localize(
                                    'more_page.drawer_change_failed',
                                  ) ??
                                  "Drawer change failed",
                              ToastLevel.error,
                            );
                          }
                        },
                      ),
                    ],
                  ),
                  if (cashDrawer['enabled'] == true) ...[
                    const SizedBox(height: 10),
                    ListTile(
                      leading: Icon(Icons.devices_other, color: mainColor),
                      title: Text(
                        LOCALIZATION.localize('more_page.device_name') ??
                            "Device Name",
                      ),
                      subtitle: Text(cashDrawer['device_name'] ?? "-"),
                      trailing: ElevatedButton.icon(
                        icon: const Icon(Icons.search),
                        label: Text(
                          LOCALIZATION.localize('more_page.scan') ?? "Scan",
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: mainColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () {
                          // TODO: Implement scan for cash drawers
                          showToastMessage(
                            context,
                            LOCALIZATION.localize('more_page.scan_drawer') ??
                                "Scanning for cash drawers...",
                            ToastLevel.info,
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 5. Advanced Section
  Widget _buildAdvanced(ThemeData theme, Color mainColor) {
    return Padding(
      key: const ValueKey('advanced'),
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            LOCALIZATION.localize('main_word.advanced') ?? "Advanced",
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
              padding: const EdgeInsets.all(28.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- DEBUG TOOLS ---
                  if (_showDebugTools)
                    ListTile(
                      leading: Icon(Icons.bug_report, color: mainColor),
                      title: Text(
                        LOCALIZATION.localize('more_page.debug_tools') ??
                            "Debug Tools",
                        style: theme.textTheme.titleMedium,
                      ),
                      subtitle: Text(
                        LOCALIZATION.localize('more_page.debug_tools_desc') ??
                            "Access debug and developer tools.",
                      ),
                      trailing: ElevatedButton.icon(
                        icon: const Icon(Icons.open_in_new),
                        label: Text(
                          LOCALIZATION.localize('more_page.open_debug') ??
                              "Open",
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: mainColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () {
                          showToastMessage(
                            context,
                            LOCALIZATION.localize('more_page.debug_opened') ??
                                "Debug tools opened",
                            ToastLevel.info,
                          );
                        },
                      ),
                    ),
                  if (_showDebugTools) const Divider(height: 32),

                  // --- LOGOUT BUTTON ---
                  ListTile(
                    leading: Icon(Icons.logout, color: Colors.redAccent),
                    title: Text(
                      LOCALIZATION.localize('main_word.logout') ?? "Logout",
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      LOCALIZATION.localize('main_word.logout_desc') ??
                          "Sign out and return to login page.",
                    ),
                    trailing: ElevatedButton.icon(
                      icon: const Icon(Icons.logout),
                      label: Text(
                        LOCALIZATION.localize('main_word.logout') ?? "Logout",
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder:
                              (context) => AlertDialog(
                                title: Text(
                                  LOCALIZATION.localize('main_word.logout') ??
                                      "Logout",
                                ),
                                content: Text(
                                  LOCALIZATION.localize(
                                        'main_word.logout_confirm',
                                      ) ??
                                      "Are you sure you want to log out?",
                                ),
                                actions: [
                                  TextButton(
                                    onPressed:
                                        () => Navigator.of(context).pop(false),
                                    child: Text(
                                      LOCALIZATION.localize(
                                            'main_word.cancel',
                                          ) ??
                                          "Cancel",
                                    ),
                                  ),

                                  ElevatedButton(
                                    onPressed:
                                        () => Navigator.of(context).pop(true),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.redAccent,
                                    ),
                                    child: Text(
                                      LOCALIZATION.localize(
                                            'main_word.logout',
                                          ) ??
                                          "Logout",
                                    ),
                                  ),
                                ],
                              ),
                        );
                        if (confirmed == true) {
                          // Optional: Clear session or user data here
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                              builder: (context) => const LoginPage(),
                            ),
                            (route) => false,
                          );
                        }
                      },
                    ),
                  ),

                  // --- RESTART APP ---
                  ListTile(
                    leading: Icon(Icons.restart_alt, color: mainColor),
                    title: Text(
                      LOCALIZATION.localize('more_page.restart_app') ??
                          "Restart App",
                      style: theme.textTheme.titleMedium,
                    ),
                    subtitle: Text(
                      LOCALIZATION.localize('more_page.restart_app_desc') ??
                          "Restart the kiosk application safely.",
                    ),
                    trailing: ElevatedButton.icon(
                      icon: const Icon(Icons.restart_alt),
                      label: Text(
                        LOCALIZATION.localize('more_page.restart') ?? "Restart",
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orangeAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () {
                        showToastMessage(
                          context,
                          LOCALIZATION.localize(
                                'more_page.restart_triggered',
                              ) ??
                              "Restart triggered",
                          ToastLevel.warning,
                        );
                      },
                    ),
                  ),
                  const Divider(height: 32),

                  // --- ABOUT SECTION ---
                  ListTile(
                    leading: Icon(Icons.info_outline, color: mainColor),
                    title: Text(
                      LOCALIZATION.localize('more_page.about') ?? "About",
                      style: theme.textTheme.titleMedium,
                    ),
                    subtitle: Text(
                      LOCALIZATION.localize('more_page.about_desc') ??
                          "Kiosk System v${globalAppConfig['version'] ?? '1.0.0'}",
                    ),
                  ),
                  const Divider(height: 32),
                ],
              ),
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
      backgroundColor: theme.colorScheme.background,
      body: Row(
        children: [
          // Sidebar
          _buildSidebar(theme, mainColor),
          // Main content
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _buildSectionContent(theme, mainColor),
            ),
          ),
        ],
      ),
    );
  }
}
