import '../../configs/configs.dart';
import '../../components/toastmsg.dart';

/// Connection Settings Section for More Page
/// Manages bluetooth printer and cash drawer settings
class ConnectionSettingsSection extends StatefulWidget {
  final ThemeData theme;
  final Color mainColor;

  const ConnectionSettingsSection({
    super.key,
    required this.theme,
    required this.mainColor,
  });

  @override
  State<ConnectionSettingsSection> createState() =>
      _ConnectionSettingsSectionState();
}

class _ConnectionSettingsSectionState extends State<ConnectionSettingsSection> {
  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final mainColor = widget.mainColor;

    // Example: Use globalAppConfig for device settings
    final bluetoothPrinter = globalAppConfig['cashier']['bluetooth_printer'];
    final cashDrawer = globalAppConfig['cashier']['cash_drawer'];

    return SingleChildScrollView(
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
                              "${LOCALIZATION.localize('main_word.bluetooth_printer')} ${val ? LOCALIZATION.localize('main_word.enabled') ?? 'enabled' : LOCALIZATION.localize('main_word.disabled') ?? 'disabled'}",
                              ToastLevel.success,
                            );
                          } else {
                            showToastMessage(
                              context,
                              LOCALIZATION.localize(
                                    'more_page.setting_change_failed',
                                  ) ??
                                  "Setting change failed",
                              ToastLevel.error,
                            );
                          }
                        },
                      ),
                    ],
                  ),
                  const Divider(height: 32),

                  // Cash Drawer
                  Row(
                    children: [
                      Icon(Icons.inventory, color: mainColor),
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
                              "${LOCALIZATION.localize('main_word.cash_drawer')} ${val ? LOCALIZATION.localize('main_word.enabled') ?? 'enabled' : LOCALIZATION.localize('main_word.disabled') ?? 'disabled'}",
                              ToastLevel.success,
                            );
                          } else {
                            showToastMessage(
                              context,
                              LOCALIZATION.localize(
                                    'more_page.setting_change_failed',
                                  ) ??
                                  "Setting change failed",
                              ToastLevel.error,
                            );
                          }
                        },
                      ),
                    ],
                  ),
                  const Divider(height: 32),

                  // Additional connection settings can be added here
                  Text(
                    LOCALIZATION.localize('more_page.connection_status') ??
                        "Connection Status",
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  ListTile(
                    leading: Icon(
                      Icons.wifi,
                      color: Colors.green, // Assume connected for demo
                    ),
                    title: Text(
                      LOCALIZATION.localize('main_word.network') ?? "Network",
                    ),
                    subtitle: Text(
                      LOCALIZATION.localize('main_word.connected') ??
                          "Connected",
                    ),
                    trailing: Icon(Icons.check_circle, color: Colors.green),
                  ),

                  ListTile(
                    leading: Icon(
                      Icons.bluetooth,
                      color:
                          bluetoothPrinter['enabled']
                              ? Colors.blue
                              : Colors.grey,
                    ),
                    title: Text(
                      LOCALIZATION.localize('main_word.bluetooth') ??
                          "Bluetooth",
                    ),
                    subtitle: Text(
                      bluetoothPrinter['enabled']
                          ? LOCALIZATION.localize('main_word.enabled') ??
                              "Enabled"
                          : LOCALIZATION.localize('main_word.disabled') ??
                              "Disabled",
                    ),
                    trailing: Icon(
                      bluetoothPrinter['enabled']
                          ? Icons.bluetooth_connected
                          : Icons.bluetooth_disabled,
                      color:
                          bluetoothPrinter['enabled']
                              ? Colors.blue
                              : Colors.grey,
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
}
