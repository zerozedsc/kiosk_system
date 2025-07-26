import '../../configs/configs.dart';
import '../../components/toastmsg.dart';
import '../../components/buttonswithsound.dart';

/// Kiosk Information Section for More Page
/// Displays kiosk details and allows editing kiosk information
class KioskInfoSection extends StatefulWidget {
  final ThemeData theme;
  final Color mainColor;

  const KioskInfoSection({
    super.key,
    required this.theme,
    required this.mainColor,
  });

  @override
  State<KioskInfoSection> createState() => _KioskInfoSectionState();
}

class _KioskInfoSectionState extends State<KioskInfoSection> {
  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final mainColor = widget.mainColor;

    final kioskInfo = {
      "name": globalAppConfig['kiosk_info']['kiosk_name'] ?? "NOT FOUND",
      "location": globalAppConfig['kiosk_info']['location'] ?? "N/A",
      "id": globalAppConfig['kiosk_info']['kiosk_id'] ?? "N/A",
      "version": globalAppConfig['version'] ?? "1.0.0",
      "lastSync": globalAppConfig['kiosk_info']['last_sync'] ?? "N/A",
      "registered": globalAppConfig['kiosk_info']['registered'] ?? false,
    };

    return SingleChildScrollView(
      key: const ValueKey('kioskInfo'),
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 36),
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
                              ? LOCALIZATION.localize('main_word.registered') ??
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
                    leading: Icon(Icons.location_on, color: mainColor),
                    title: Text(
                      LOCALIZATION.localize('more_page.kiosk_location') ??
                          "Location",
                    ),
                    subtitle: Text(kioskInfo["location"]),
                  ),

                  ListTile(
                    leading: Icon(Icons.confirmation_number, color: mainColor),
                    title: Text(
                      LOCALIZATION.localize('more_page.kiosk_id') ?? "Kiosk ID",
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
                    leading: Icon(Icons.info_outline, color: mainColor),
                    title: Text(
                      LOCALIZATION.localize('main_page.version') ?? "Version",
                    ),
                    subtitle: Text(kioskInfo["version"]),
                  ),
                  const SizedBox(height: 12),

                  // Fixed: Use Wrap instead of Row to prevent horizontal overflow
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    alignment: WrapAlignment.end,
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
                        onPressed:
                            () => _showAdjustKioskInfoDialog(
                              context,
                              theme,
                              mainColor,
                            ),
                      ),
                      ElevatedButtonWithSound.icon(
                        icon: const Icon(Icons.sync),
                        label: Text(
                          LOCALIZATION.localize('main_word.sync_now') ??
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
                            LOCALIZATION.localize('more_page.sync_triggered') ??
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
        ],
      ),
    );
  }

  Future<void> _showAdjustKioskInfoDialog(
    BuildContext context,
    ThemeData theme,
    Color mainColor,
  ) async {
    final TextEditingController kioskNameController = TextEditingController();
    final TextEditingController locationController = TextEditingController();
    final TextEditingController currentPasswordController =
        TextEditingController();
    final TextEditingController newPasswordController = TextEditingController();
    final TextEditingController confirmPasswordController =
        TextEditingController();

    // Pre-fill with current values
    kioskNameController.text =
        globalAppConfig['kiosk_info']['kiosk_name'] ?? '';
    locationController.text = globalAppConfig['kiosk_info']['location'] ?? '';

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            backgroundColor: theme.colorScheme.surface,
            elevation: 10,
            title: Container(
              padding: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: mainColor.withOpacity(0.3),
                    width: 2,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: mainColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.edit, color: mainColor, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      LOCALIZATION.localize('more_page.adjust_kiosk_info') ??
                          "Adjust Kiosk Info",
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: mainColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            content: Container(
              width: double.maxFinite,
              constraints: const BoxConstraints(maxWidth: 500, maxHeight: 400),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 16),

                    // Kiosk Name Field
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: mainColor.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: TextField(
                        controller: kioskNameController,
                        decoration: InputDecoration(
                          labelText:
                              LOCALIZATION.localize('auth_page.kiosk_name') ??
                              "Kiosk Name",
                          labelStyle: TextStyle(color: mainColor),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.all(16),
                          prefixIcon: Icon(Icons.store, color: mainColor),
                          floatingLabelBehavior: FloatingLabelBehavior.always,
                        ),
                        style: theme.textTheme.bodyLarge,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Location Field
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: mainColor.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: TextField(
                        controller: locationController,
                        decoration: InputDecoration(
                          labelText:
                              LOCALIZATION.localize(
                                'more_page.kiosk_location',
                              ) ??
                              "Location",
                          labelStyle: TextStyle(color: mainColor),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.all(16),
                          prefixIcon: Icon(Icons.location_on, color: mainColor),
                          floatingLabelBehavior: FloatingLabelBehavior.always,
                        ),
                        style: theme.textTheme.bodyLarge,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  LOCALIZATION.localize('main_word.cancel') ?? "Cancel",
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  // Update kiosk info
                  globalAppConfig['kiosk_info']['kiosk_name'] =
                      kioskNameController.text;
                  globalAppConfig['kiosk_info']['location'] =
                      locationController.text;

                  if (await ConfigService.updateConfig()) {
                    Navigator.of(context).pop();
                    setState(() {}); // Refresh the UI
                    showToastMessage(
                      context,
                      LOCALIZATION.localize('more_page.kiosk_info_updated') ??
                          "Kiosk information updated",
                      ToastLevel.success,
                    );
                  } else {
                    showToastMessage(
                      context,
                      LOCALIZATION.localize(
                            'more_page.kiosk_info_update_failed',
                          ) ??
                          "Failed to update kiosk information",
                      ToastLevel.error,
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: mainColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.save, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      LOCALIZATION.localize('main_word.save') ?? "Save",
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
    );
  }
}
