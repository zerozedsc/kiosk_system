import '../../configs/configs.dart';
import '../../components/toastmsg.dart';
import '../../components/buttonswithsound.dart';

/// App Settings Section for More Page
/// Handles theme, language, and currency preferences
class AppSettingsSection extends StatefulWidget {
  final ThemeData theme;
  final Color mainColor;

  const AppSettingsSection({
    super.key,
    required this.theme,
    required this.mainColor,
  });

  @override
  State<AppSettingsSection> createState() => _AppSettingsSectionState();
}

class _AppSettingsSectionState extends State<AppSettingsSection> {
  String themeMode = globalAppConfig['userPreferences']['theme'];
  String language = globalAppConfig['userPreferences']['language'];
  String currency = globalAppConfig['userPreferences']['currency'];

  @override
  void initState() {
    super.initState();
    // Ensure currency is valid
    currency =
        (globalAppConfig['currency']['options'] as List).contains(currency)
            ? currency
            : (globalAppConfig['currency']['options'] as List).first as String;
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final mainColor = widget.mainColor;

    return SingleChildScrollView(
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
                                                    'more_page.restart_now',
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
}
