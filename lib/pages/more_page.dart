import '../configs/configs.dart';

import '../page_sections/morepage/index.dart';

import '../services/database/db.dart';

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

  // variable for each section
  Map<String, Map<String, dynamic>> employees = {};

  Future<void> _initFunctions() async {
    // Initialize any required services or data here
    MOREPAGE_LOGS = await LoggingService(logName: "morepage_logs").initialize();

    setState(() {
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
        return AppSettingsSection(theme: theme, mainColor: mainColor);
      case MorePageSection.employeeAccount:
        return EmployeeAccountSection(
          theme: theme,
          mainColor: mainColor,
          LOGS: MOREPAGE_LOGS,
        );
      case MorePageSection.kioskInfo:
        return KioskInfoSection(theme: theme, mainColor: mainColor);
      case MorePageSection.connection:
        return ConnectionSettingsSection(theme: theme, mainColor: mainColor);
      case MorePageSection.advanced:
        return AdvancedSection(theme: theme, mainColor: mainColor);
    }
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
