import '../../configs/configs.dart';
import '../../components/toastmsg.dart';

/// Advanced Settings Section for More Page
/// Contains debug tools and advanced configuration options
class AdvancedSection extends StatefulWidget {
  final ThemeData theme;
  final Color mainColor;

  const AdvancedSection({
    super.key,
    required this.theme,
    required this.mainColor,
  });

  @override
  State<AdvancedSection> createState() => _AdvancedSectionState();
}

class _AdvancedSectionState extends State<AdvancedSection> {
  final bool _showDebugTools = false; // Can be controlled via config

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final mainColor = widget.mainColor;

    return SingleChildScrollView(
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
                            "Debug tools would open here",
                            ToastLevel.info,
                          );
                        },
                      ),
                    ),

                  // --- DATA MANAGEMENT ---
                  ListTile(
                    leading: Icon(Icons.storage, color: mainColor),
                    title: Text(
                      LOCALIZATION.localize('more_page.data_management') ??
                          "Data Management",
                      style: theme.textTheme.titleMedium,
                    ),
                    subtitle: Text(
                      LOCALIZATION.localize('more_page.data_management_desc') ??
                          "Backup, restore, and manage app data.",
                    ),
                    trailing: ElevatedButton.icon(
                      icon: const Icon(Icons.backup),
                      label: Text(
                        LOCALIZATION.localize('more_page.backup') ?? "Backup",
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: mainColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () {
                        _showDataManagementDialog(context, theme, mainColor);
                      },
                    ),
                  ),

                  const Divider(height: 32),

                  // --- FACTORY RESET ---
                  ListTile(
                    leading: Icon(Icons.restore, color: Colors.red),
                    title: Text(
                      LOCALIZATION.localize('more_page.factory_reset') ??
                          "Factory Reset",
                      style: theme.textTheme.titleMedium,
                    ),
                    subtitle: Text(
                      LOCALIZATION.localize('more_page.factory_reset_desc') ??
                          "Reset app to default settings. This action cannot be undone.",
                    ),
                    trailing: ElevatedButton.icon(
                      icon: const Icon(Icons.warning),
                      label: Text(
                        LOCALIZATION.localize('more_page.reset') ?? "Reset",
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () {
                        _showFactoryResetDialog(context, theme, mainColor);
                      },
                    ),
                  ),

                  const Divider(height: 32),

                  // --- SYSTEM INFO ---
                  ListTile(
                    leading: Icon(Icons.info, color: mainColor),
                    title: Text(
                      LOCALIZATION.localize('more_page.system_info') ??
                          "System Information",
                      style: theme.textTheme.titleMedium,
                    ),
                    subtitle: Text(
                      LOCALIZATION.localize('more_page.system_info_desc') ??
                          "View detailed system and app information.",
                    ),
                    trailing: ElevatedButton.icon(
                      icon: const Icon(Icons.info_outline),
                      label: Text(
                        LOCALIZATION.localize('more_page.view') ?? "View",
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: mainColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () {
                        _showSystemInfoDialog(context, theme, mainColor);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showDataManagementDialog(
    BuildContext context,
    ThemeData theme,
    Color mainColor,
  ) async {
    return showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              LOCALIZATION.localize('more_page.data_management') ??
                  "Data Management",
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(Icons.backup, color: mainColor),
                  title: Text(
                    LOCALIZATION.localize('more_page.create_backup') ??
                        "Create Backup",
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    showToastMessage(
                      context,
                      "Backup feature would be implemented here",
                      ToastLevel.info,
                    );
                  },
                ),
                ListTile(
                  leading: Icon(Icons.restore, color: mainColor),
                  title: Text(
                    LOCALIZATION.localize('more_page.restore_backup') ??
                        "Restore Backup",
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    showToastMessage(
                      context,
                      "Restore feature would be implemented here",
                      ToastLevel.info,
                    );
                  },
                ),
                ListTile(
                  leading: Icon(Icons.file_download, color: mainColor),
                  title: Text(
                    LOCALIZATION.localize('more_page.export_data') ??
                        "Export Data",
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    showToastMessage(
                      context,
                      "Export feature would be implemented here",
                      ToastLevel.info,
                    );
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  LOCALIZATION.localize('main_word.close') ?? "Close",
                ),
              ),
            ],
          ),
    );
  }

  Future<void> _showFactoryResetDialog(
    BuildContext context,
    ThemeData theme,
    Color mainColor,
  ) async {
    return showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.warning, color: Colors.red),
                const SizedBox(width: 8),
                Text(
                  LOCALIZATION.localize('more_page.factory_reset') ??
                      "Factory Reset",
                ),
              ],
            ),
            content: Text(
              LOCALIZATION.localize('more_page.factory_reset_warning') ??
                  "This will permanently delete all data and reset the app to its default state. This action cannot be undone.\n\nAre you sure you want to proceed?",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  LOCALIZATION.localize('main_word.cancel') ?? "Cancel",
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  showToastMessage(
                    context,
                    "Factory reset would be implemented here",
                    ToastLevel.warning,
                  );
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: Text(
                  LOCALIZATION.localize('more_page.reset_confirm') ?? "Reset",
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
  }

  Future<void> _showSystemInfoDialog(
    BuildContext context,
    ThemeData theme,
    Color mainColor,
  ) async {
    return showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              LOCALIZATION.localize('more_page.system_info') ??
                  "System Information",
            ),
            content: Container(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoRow(
                    "App Version",
                    globalAppConfig['version'] ?? "1.0.0",
                  ),
                  _buildInfoRow("Platform", "Flutter"),
                  _buildInfoRow(
                    "Kiosk ID",
                    globalAppConfig['kiosk_info']['kiosk_id'] ?? "N/A",
                  ),
                  _buildInfoRow(
                    "Theme",
                    globalAppConfig['userPreferences']['theme'] ?? "system",
                  ),
                  _buildInfoRow(
                    "Language",
                    globalAppConfig['userPreferences']['language'] ?? "en",
                  ),
                  _buildInfoRow(
                    "Currency",
                    globalAppConfig['userPreferences']['currency'] ?? "USD",
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  LOCALIZATION.localize('main_word.close') ?? "Close",
                ),
              ),
            ],
          ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(flex: 3, child: Text(value)),
        ],
      ),
    );
  }
}
