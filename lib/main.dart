import 'package:device_preview/device_preview.dart';
import 'package:kiosk_system/services/homepage/homepage_service.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'configs/configs.dart';
import 'pages/auth_page.dart';
import 'services/database/db.dart';
import 'services/inventory/inventory_services.dart';
import 'services/connection/bluetooth.dart';
import 'services/connection/usb.dart';
import 'services/connection/internet.dart';
import 'services/auth/auth_service.dart';
import 'services/server/kiosk_server.dart';

import 'components/toastmsg.dart';
import 'components/notification_island.dart';
import 'components/global_toast_notification.dart';

// ignore: unused_element
// 035368 pin tab

Future<void> runAppInitializations() async {
  // Set up logging
  APP_LOGS = await LoggingService(logName: "app_logs").initialize();
  SERVER_LOGS = await LoggingService(logName: "server_logs").initialize();

  // Initialize configuration
  globalAppConfig =
      await ConfigService.initializeConfig(); // Initialize app_config.json first
  themeNotifier.value = globalAppConfig["userPreferences"]["theme"] ?? "light";

  await EncryptService().getEncryptionKey(); // Ensures key is generated/stored
  // Initialize Database
  DBNAME = 'app.db';
  DB = await DatabaseConnection.getDatabase(dbName: DBNAME);
  EMPQUERY = EmployeeQuery(db: DB, logs: APP_LOGS);
  await EMPQUERY.initialize();
  inventory = await InventoryServices().initialize();
  homepageService = await HomepageService().initialize();
  kioskApiService = KioskApiService(); // Initialize KioskApiService
  await kioskApiService.initialize();

  // Initialize localization
  LOCALIZATION = LocalizationManager(
    globalAppConfig["userPreferences"]["language"] ?? "ma",
  );

  // Initialize Internet Connection Service
  internetConnectionService = InternetConnectionService();

  // Perform initial internet connectivity check
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    await internetConnectionService.checkAndUpdateStatus();
  });

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
    return ValueListenableBuilder<String>(
      valueListenable: themeNotifier,
      builder: (context, themeValue, _) {
        return MaterialApp(
          locale: DevicePreview.locale(context),
          builder: DevicePreview.appBuilder,
          title: 'Kiosk System',
          theme: mainThemeData,
          darkTheme: ThemeData(
            colorScheme: darkThemeColorScheme,
            useMaterial3: true,
            buttonTheme: ButtonThemeData(
              buttonColor: primaryColor,
              textTheme: ButtonTextTheme.primary,
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
              ),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: primaryColor),
            ),
            outlinedButtonTheme: OutlinedButtonThemeData(
              style: OutlinedButton.styleFrom(
                foregroundColor: primaryColor,
                side: BorderSide(color: primaryColor),
              ),
            ),
            iconTheme: IconThemeData(color: primaryColor),
            appBarTheme: AppBarTheme(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
            ),
            navigationRailTheme: NavigationRailThemeData(
              backgroundColor: Colors.grey.shade900,
              selectedIconTheme: IconThemeData(color: primaryColor),
              selectedLabelTextStyle: TextStyle(
                color: primaryColor,
                fontWeight: FontWeight.bold,
              ),
              unselectedIconTheme: IconThemeData(color: Colors.grey),
              unselectedLabelTextStyle: TextStyle(color: Colors.grey),
              indicatorColor: primaryColor.withOpacity(0.2),
              useIndicator: true,
            ),
          ),
          themeMode: themeValue == "dark" ? ThemeMode.dark : ThemeMode.light,
          home: StreamBuilder<bool>(
            stream: internetConnectionService.onInternetChanged,
            initialData: false, // Start assuming no internet
            builder: (context, snapshot) {
              final isConnected = snapshot.data ?? false;

              return Stack(
                children: [
                  // Your main app content
                  Builder(
                    builder: (context) {
                      // Now we have a context with MaterialLocalizations
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        // Set the context for global toast notifications
                        GlobalToastNotification.instance.setContext(context);

                        // Initialize Bluetooth in the background
                        checkPermissionsAndInitBluetooth(context);

                        // Initialize USB Manager in parallel
                        checkPermissionsAndInitUsb(context);
                      });
                      if (globalAppConfig["kiosk_info"]?["registered"]) {
                        // If the app is not registered, show the registration page
                        return const LoginPage();
                      } else {
                        return const SignupPage();
                      }
                    },
                  ),
                  // Modern notification island for connectivity status
                  if (!isConnected)
                    PositionedNotificationIsland.top(
                      notification: NotificationTypes.offline,
                      topPadding: MediaQuery.of(context).padding.top + 10,
                    ),
                ],
              );
            },
          ),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}
