import 'package:device_preview/device_preview.dart';
import 'package:kiosk_system/services/homepage/homepage_service.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'configs/configs.dart';
import 'pages/auth_page.dart';
import 'services/database/db.dart';
import 'services/inventory/inventory_services.dart';
import 'services/connection/bluetooth.dart';
import 'services/connection/usb.dart';

import 'components/toastmsg.dart';

// ignore: unused_element
// 035368 pin tab

Future<void> runAppInitializations() async {
  // Set up logging
  APP_LOGS = await LoggingService(logName: "app_logs").initialize();

  // Initialize configuration
  globalAppConfig =
      await ConfigService.initializeConfig(); // Initialize app_config.json first

  // Initialize Database
  DBNAME = 'app.db';
  DB = await DatabaseConnection.getDatabase(dbName: DBNAME);
  inventory = await InventoryServices().initialize();
  homepageService = await HomepageService().initialize();

  // Initialize localization
  LOCALIZATION = LocalizationManager(
    globalAppConfig["userPreferences"]["language"] ?? "ma",
  );

  // Initialize Vibration
  canVibrate = await Vibration.hasVibrator();

  // Force landscape orientation
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Fetch and print package info
  PackageInfo packageInfo = await PackageInfo.fromPlatform();
  APP_LOGS.info(
    "Package Info: ${packageInfo.appName} ${packageInfo.version}+${packageInfo.buildNumber}",
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await runAppInitializations();

  runApp(const AppRoot());
}

class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      locale: DevicePreview.locale(context),
      builder: DevicePreview.appBuilder,
      title: 'Kiosk System',
      theme: mainThemeData,
      darkTheme:
          globalAppConfig["userPreferences"]["theme"] == "light"
              ? mainThemeData
              : ThemeData.dark().copyWith(
                colorScheme: themeColorScheme.copyWith(
                  brightness: Brightness.dark,
                  background: Colors.grey.shade900,
                  surface: Colors.grey.shade800,
                  onBackground: Colors.white,
                  onSurface: Colors.white,
                ),
                navigationRailTheme: NavigationRailThemeData(
                  selectedIconTheme: IconThemeData(color: primaryColor),
                  selectedLabelTextStyle: TextStyle(
                    color: primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                  indicatorColor: primaryColor.withOpacity(0.2),
                ),
              ),
      home: Builder(
        builder: (context) {
          // Now we have a context with MaterialLocalizations
          WidgetsBinding.instance.addPostFrameCallback((_) {
            // Initialize Bluetooth in the background
            checkPermissionsAndInitBluetooth(context);

            // Initialize USB Manager in parallel
            checkPermissionsAndInitUsb(context);
          });
          return const LoginPage();
        },
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}
