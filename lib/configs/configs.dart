//export from configs
// ignore_for_file: constant_identifier_names

export 'package:flutter/material.dart';
export 'package:shared_preferences/shared_preferences.dart';
// export 'package:autocomplete_textfield/autocomplete_textfield.dart';
export 'package:flutter/services.dart';
// export 'package:flutter_typeahead/flutter_typeahead.dart';
export 'package:path_provider/path_provider.dart';
export 'package:fluttertoast/fluttertoast.dart';
export 'package:bcrypt/bcrypt.dart';
export 'package:restart_app/restart_app.dart';
export 'package:image_picker/image_picker.dart';
export 'package:flutter_image_compress/flutter_image_compress.dart';
export 'package:flutter_typeahead/flutter_typeahead.dart'; // Add this import at the top

export 'dart:convert';
export 'dart:math';
export 'dart:io';
export 'dart:async';
// export 'dart:ui';
export 'dart:collection';

//import to configs
import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart'; // Add this import statement
import 'dart:io';
import 'dart:math';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

import '../services/connection/bluetooth.dart';
import '../services/connection/usb.dart';

// global var
late Map<String, dynamic> globalAppConfig;
// ignore: non_constant_identifier_names
late LocalizationManager LOCALIZATION;
// ignore: non_constant_identifier_names
late LoggingService APP_LOGS, SERVER_LOGS;
BtPrinter? btPrinter;
UsbManager? USB;
bool canVibrate = false;

const double kTopSpacing = 12.0;
const double kHorizontalSpacing = 10.0;
const double kInternalSpacing = 5.5;
const double kInternalLargeSpacing = 12.0;
const double kFABSpacing = 76.0;
const double kDialogBottomSpacing = 24.0;

final Color primaryColor = Colors.orange.shade700;
final Color secondaryColor = Colors.orange.shade400;
final ColorScheme themeColorScheme = ColorScheme(
  brightness: Brightness.light,
  primary: primaryColor,
  onPrimary: Colors.white,
  secondary: secondaryColor,
  onSecondary: Colors.black,
  error: Colors.red,
  onError: Colors.white,
  background: Colors.white,
  onBackground: Colors.black,
  surface: Colors.white,
  onSurface: Colors.black,
  // Adjusted colors to work better with orange theme
  primaryContainer: primaryColor.withOpacity(0.2),
  onPrimaryContainer: primaryColor,
  secondaryContainer: secondaryColor.withOpacity(0.2),
  onSecondaryContainer: secondaryColor,
  tertiary: primaryColor.withOpacity(0.7),
  onTertiary: Colors.white,
  tertiaryContainer: primaryColor.withOpacity(0.1),
  onTertiaryContainer: primaryColor,
  surfaceVariant: Colors.white, // Changed from grey.shade100 to white
  onSurfaceVariant: primaryColor.withOpacity(
    0.7,
  ), // Changed to use primaryColor with opacity instead of grey
);
final ColorScheme darkThemeColorScheme = ColorScheme(
  brightness: Brightness.dark,
  primary: primaryColor,
  onPrimary: Colors.black,
  secondary: secondaryColor,
  onSecondary: Colors.black,
  error: Colors.red.shade400,
  onError: Colors.black,
  background: Colors.grey.shade900,
  onBackground: Colors.white,
  surface: Colors.grey.shade800,
  onSurface: Colors.white,
  primaryContainer: primaryColor.withOpacity(0.25),
  onPrimaryContainer: Colors.white,
  secondaryContainer: secondaryColor.withOpacity(0.25),
  onSecondaryContainer: Colors.white,
  tertiary: primaryColor.withOpacity(0.7),
  onTertiary: Colors.white,
  tertiaryContainer: primaryColor.withOpacity(0.2),
  onTertiaryContainer: Colors.white,
  surfaceVariant: Colors.grey.shade700,
  onSurfaceVariant: Colors.white70,
);
final ThemeData mainThemeData = ThemeData(
  // Use a completely custom ColorScheme instead of generating from seed
  colorScheme: themeColorScheme,
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
    ).copyWith(
      overlayColor: MaterialStateProperty.resolveWith<Color?>((
        Set<MaterialState> states,
      ) {
        if (states.contains(MaterialState.pressed)) {
          // Play sound when button is pressed
          AudioManager().playSound(soundPath: 'assets/sounds/click.mp3');
          return Colors.white.withOpacity(0.1);
        }
        return null;
      }),
    ),
  ),
  iconTheme: IconThemeData(color: primaryColor),
  appBarTheme: AppBarTheme(
    backgroundColor: primaryColor,
    foregroundColor: Colors.white,
  ),
  navigationRailTheme: NavigationRailThemeData(
    backgroundColor: Colors.white,
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
);

// [DEBUG VARIABLES]
const bool DEBUG = false;
const bool DEBUG_AUTH_IN_TESTING =
    false; // Changed to false to enable authentication
const bool UPDATE_DB_AS_DEBUG = false; // Update DB when in DEBUG mode
const bool UPDATE_CONFIG_AS_DEBUG = false;

/// notifier for app state changes
ValueNotifier<String> themeNotifier = ValueNotifier<String>("light");

/// Class to play a sound effect
class AudioManager {
  static final AudioManager _instance = AudioManager._internal();
  final AudioPlayer _player = AudioPlayer();

  factory AudioManager() {
    return _instance;
  }

  AudioManager._internal();

  Future<void> playSound({String? soundPath}) async {
    try {
      final String audioPath = soundPath ?? 'assets/sounds/click.mp3';

      // Check if asset exists
      try {
        await rootBundle.load(audioPath);
      } catch (e) {
        APP_LOGS.error('Sound file not found: $audioPath');
        return;
      }

      // Reset the player if it's playing
      await _player.setAsset(audioPath);
      await _player.play();
      // ignore: empty_catches
    } catch (e) {}
  }
}

/// Class to handle the app configuration
class ConfigService {
  static const String _configFileName = 'app_config.json';
  static const String _assetConfigPath = 'assets/configs/$_configFileName';

  // Initialize and load the configuration
  static Future<Map<String, dynamic>> initializeConfig() async {
    await _copyConfigFileToWritableDirectory();
    return await _loadConfig();
  }

  // Copy the config file from assets to a writable directory if it doesn't already exist
  static Future<void> _copyConfigFileToWritableDirectory() async {
    final Directory appDocDir = await getApplicationDocumentsDirectory();
    final String configPath = '${appDocDir.path}/$_configFileName';
    final String assetConfigPath = _assetConfigPath;

    // If the writable config does not exist, copy from asset (first run or after uninstall)
    if (FileSystemEntity.typeSync(configPath) ==
        FileSystemEntityType.notFound) {
      APP_LOGS.debug("$configPath not found. Copying from assets.");
      final ByteData data = await rootBundle.load(assetConfigPath);
      final List<int> bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      await File(configPath).writeAsBytes(bytes);
      APP_LOGS.info("Config file copied to writable directory.");
    } else {
      // If in DEBUG mode and asset config has changed, overwrite writable config
      final ByteData assetData = await rootBundle.load(assetConfigPath);
      final List<int> assetBytes = assetData.buffer.asUint8List(
        assetData.offsetInBytes,
        assetData.lengthInBytes,
      );
      final List<int> writableBytes = await File(configPath).readAsBytes();

      if (!compareBytes(assetBytes, writableBytes) && UPDATE_CONFIG_AS_DEBUG) {
        APP_LOGS.warning(
          "Config in assets has been updated. Replacing the writable config file...",
        );
        await File(configPath).writeAsBytes(assetBytes);
        APP_LOGS.info("Config file updated successfully.");
      } else {
        APP_LOGS.info("Config file in writable directory is up to date.");
      }
    }
  }

  // Load the config file from the writable directory
  static Future<Map<String, dynamic>> _loadConfig() async {
    final Directory appDocDir = await getApplicationDocumentsDirectory();
    final String configPath = '${appDocDir.path}/$_configFileName';

    final String data = await File(configPath).readAsString();
    return json.decode(data);
  }

  // Update the app configuration file json based on globalAppConfig in the writable directory
  static Future<bool> updateConfig() async {
    try {
      final Directory appDocDir = await getApplicationDocumentsDirectory();
      final String configPath = '${appDocDir.path}/$_configFileName';

      await File(configPath).writeAsString(json.encode(globalAppConfig));
      APP_LOGS.info("Config file updated successfully with updateConfig()");
      // APP_LOGS.info(
      //   "Config file updated successfully: ${APP_LOGS.map2str(globalAppConfig)}",
      // );
      return true;
    } catch (e, s) {
      APP_LOGS.error("Error updating config", e, s);
      return false;
    }
  }
}

/// Class to handle localization
class LocalizationManager {
  static final LocalizationManager _instance = LocalizationManager._internal();

  // Singleton instance
  factory LocalizationManager(String languageCode) {
    _instance.loadLanguage(languageCode);
    return _instance;
  }

  LocalizationManager._internal();

  Map<String, dynamic> _localizedStrings = {};

  // Load the JSON file for the given locale
  Future<void> loadLanguage(String languageCode) async {
    final String jsonString = await rootBundle.loadString(
      'assets/locales/$languageCode.json',
    );
    final Map<String, dynamic> jsonMap = json.decode(jsonString);

    // Flattening the map to ensure all values are Strings
    _localizedStrings = _flattenMap(jsonMap);
  }

  // Retrieve a translated string by key
  String localize(String key) {
    return _localizedStrings[key] ?? key; // Return key if translation not found
  }

  // Helper method to flatten nested maps
  Map<String, dynamic> _flattenMap(
    Map<String, dynamic> map, [
    String prefix = '',
  ]) {
    final Map<String, dynamic> result = {};
    map.forEach((key, value) {
      if (value is Map) {
        result.addAll(
          _flattenMap(value as Map<String, dynamic>, '$prefix$key.'),
        );
      } else {
        result['$prefix$key'] = value;
      }
    });
    return result;
  }

  // Retrieve a <String, dynamic> map by key
  Map<String, dynamic> localizeMap(String key) {
    return _localizedStrings[key] ?? {}; // Return empty map if key not found
  }
}

/// Logger configuration for app-wide logging
class LoggingService {
  late Logger _logger;
  File? _logFile;
  String _logName;
  late StreamSubscription<LogRecord> _subscription;

  // Constructor takes a log name
  LoggingService({required String logName})
    : _logName = logName.replaceAll(' ', '_');

  // Initialize the logging system
  Future<LoggingService> initialize() async {
    _logger = Logger(_logName);
    Logger.root.level = Level.ALL;

    // Setup log file
    final Directory appDocDir = await getApplicationDocumentsDirectory();
    final String logDirPath = '${appDocDir.path}/logs';

    // Create logs directory if it doesn't exist
    final Directory logDir = Directory(logDirPath);
    if (!await logDir.exists()) {
      await logDir.create(recursive: true);
    }

    final String logPath = '$logDirPath/${_logName}.log';
    _logFile = File(logPath);

    // Add this helper method to handle all filtering logic
    bool _shouldFilterLog(String message) {
      // List of patterns to filter out
      final List<String> filterPatterns = [
        // System components
        'BufferPoolAccessor',
        'BufferPoolAccessor2.0',
        'pHwBinder',
        'onLastStrongRef',
        'AudioTrack',
        'CCodec',
        'MediaCodec',
        'DMCodec',
        'AudioTrackShared',
        'ReflectedParamUpdater',
        'Codec2Client',
        'CCodecConfig',
        'CCodecBufferChannel',

        // Common Android log tags to filter
        'D/', 'I/', 'W/', 'E/',

        // Path-like patterns
        '/hw-',

        // Any message containing these keywords
        'bufferpool2',
        'evictor expired',
        'linkling death',
        'INSP:',
        'FUTEX_WAKE',
      ];

      // Check if the log message contains any of the filter patterns
      for (final pattern in filterPatterns) {
        if (message.contains(pattern)) {
          return true; // Should filter this log
        }
      }

      return false; // Don't filter this log
    }

    // Attach a listener ONLY for this logger instance
    _subscription = _logger.onRecord.listen((record) {
      // Skip any system or just_audio logs based on comprehensive patterns
      if (_shouldFilterLog(record.message)) {
        return; // Skip these logs
      }

      if (record.loggerName == _logName) {
        // ✅ Ensure only this logger writes to its file
        String message =
            '${record.time}: ${record.level.name}: ${record.message}';
        if (record.error != null) {
          message += '\nerror:\n${record.error}';
        }
        if (record.stackTrace != null) {
          message += '\nstackTrace:\n${record.stackTrace}';
        }

        // Print to console in debug mode
        if (DEBUG) {
          console('[$_logName] $message');
        }

        // Write to log file
        _logFile?.writeAsStringSync('$message\n', mode: FileMode.append);
      }
    });

    debug('Logging service initialized with log name: $_logName');
    return this;
  }

  // Dispose of logger listener
  void dispose() {
    _subscription.cancel();
  }

  // Convert a map to a formatted JSON string. Useful for logging complex objects.
  String map2str(Map<dynamic, dynamic> map) {
    // Convert all keys to strings first
    final Map<String, dynamic> stringMap = {};
    map.forEach((key, value) {
      stringMap[key.toString()] = value;
    });
    return JsonEncoder.withIndent('  ').convert(stringMap);
  }

  // Convert a list to a formatted string with indentation
  String list2str(List<dynamic> list, {int indentLevel = 0}) {
    if (list.isEmpty) return '[]';

    // Calculate indentation
    final String indent = '  ' * indentLevel;
    final String nestedIndent = '  ' * (indentLevel + 1);

    StringBuffer buffer = StringBuffer('[\n');

    for (int i = 0; i < list.length; i++) {
      var item = list[i];

      // Format based on item type
      if (item is Map) {
        buffer.write('$nestedIndent${map2str(item)}');
      } else if (item is List) {
        buffer.write(
          '$nestedIndent${list2str(item, indentLevel: indentLevel + 1)}',
        );
      } else if (item is String) {
        buffer.write('$nestedIndent"$item"');
      } else {
        buffer.write('$nestedIndent$item');
      }

      // Add comma for all but the last item
      if (i < list.length - 1) {
        buffer.write(',');
      }
      buffer.write('\n');
    }

    buffer.write('$indent]');
    return buffer.toString();
  }

  // Helper to handle various message types
  String _formatMessage(dynamic message) {
    if (message == null) return 'null';
    if (message is Map<String, dynamic>) return map2str(message);
    return message.toString();
  }

  // Log methods with dynamic parameters converted to strings
  /// Log a message at the [Level.info] log level. Used for general information.
  void info(dynamic message) => _logger.info(_formatMessage(message));

  /// Log a message at the [Level.warning] log level. Used for warnings.
  void warning(dynamic message) => _logger.warning(_formatMessage(message));

  /// Log a message at the [Level.severe] log level. Used for errors.
  void error(dynamic message, [Object? error, StackTrace? stackTrace]) =>
      _logger.severe(_formatMessage(message), error, stackTrace);

  /// Log a message at the [Level.fine] log level. More detailed than INFO, useful for debugging.
  void debug(dynamic message) {
    if (DEBUG) {
      _logger.fine(_formatMessage(message));
    }
  }

  /// Log a message at the [Level.shout] log level.
  void critical(dynamic message) => _logger.shout(_formatMessage(message));

  /// Log a message at the [Level.config] log level. Used for configuration messages.
  void config(dynamic message) => _logger.config(_formatMessage(message));

  /// Log a message at the [Level.finer] log level. More detailed than FINE, useful for tracing logic.
  void finer(dynamic message) => _logger.finer(_formatMessage(message));

  /// Log a message at the [Level.finest] log level. Extremely detailed logs, often used for profiling.
  void finest(dynamic message) => _logger.finest(_formatMessage(message));

  /// Print a message to the console.
  void console(dynamic message) =>
      print('[$_logName] ${_formatMessage(message)}');
}

// MISC FUNCTION
String getCurrentFunctionName(StackTrace currentStack) {
  String stackTraceString = currentStack.toString();
  // Extract the function name from stack trace
  RegExp regExp = RegExp(r'#0\s+([^(]+)');
  Match? match = regExp.firstMatch(stackTraceString);
  if (match != null) {
    String fullName = match.group(1)?.trim() ?? 'unknown';
    // Remove the trailing parenthesis if present
    fullName = fullName.replaceAll(RegExp(r'\($'), '');
    return fullName;
  }
  return 'unknown_function';
}

/// Compares two lists of integers byte by byte.
///
/// Returns `true` if the two lists contain exactly the same elements in the same order.
/// Returns `false` if the lists have different lengths or if any corresponding elements differ.
///
/// Parameters:
/// - [list1]: First list of integers to compare
/// - [list2]: Second list of integers to compare
///
/// Returns: `bool` indicating whether the lists are identical
bool compareBytes(List<int> list1, List<int> list2) {
  if (list1.length != list2.length) return false;

  // Use Uint8List views for faster comparison if possible
  final bytes1 = list1 is Uint8List ? list1 : Uint8List.fromList(list1);
  final bytes2 = list2 is Uint8List ? list2 : Uint8List.fromList(list2);

  // Compare byte length first (quick exit)
  final len = bytes1.length;

  // Process multiple bytes at once with 8-byte chunks where possible
  const chunkSize = 8;
  int i = 0;
  for (; i <= len - chunkSize; i += chunkSize) {
    // Compare chunks of 8 bytes at a time
    if (bytes1[i] != bytes2[i] ||
        bytes1[i + 1] != bytes2[i + 1] ||
        bytes1[i + 2] != bytes2[i + 2] ||
        bytes1[i + 3] != bytes2[i + 3] ||
        bytes1[i + 4] != bytes2[i + 4] ||
        bytes1[i + 5] != bytes2[i + 5] ||
        bytes1[i + 6] != bytes2[i + 6] ||
        bytes1[i + 7] != bytes2[i + 7]) {
      return false;
    }
  }

  // Handle remaining bytes
  for (; i < len; i++) {
    if (bytes1[i] != bytes2[i]) return false;
  }

  return true;
}

/// Recursively removes the 'image' key from a map or list.
dynamic removeImageKey(dynamic data) {
  if (data is Map) {
    return Map.fromEntries(
      data.entries
          .where((e) => e.key != 'image')
          .map((e) => MapEntry(e.key, removeImageKey(e.value))),
    );
  } else if (data is List) {
    return data.map(removeImageKey).toList();
  }
  return data;
}

/// Returns the current date/time or converts a timestamp to a formatted string.
///
/// [format] - The date format string (e.g. 'yyyy-MM-dd HH:mm:ss').
///   Common patterns:
///     'yyyy-MM-dd' (2025-04-23)
///     'yyyy-MM-dd HH:mm:ss' (2025-04-23 14:30:00)
///     'HH:mm:ss' (14:30:00)
///
/// [timestamp] - If true, returns the current time as a Unix timestamp (seconds since epoch).
///
/// [convertTimestamp] - If true, converts the [inputTimestamp] to the given [format].
///
/// [inputTimestamp] - The timestamp (in seconds or milliseconds) to convert if [convertTimestamp] is true.
///
/// Example usage:
///   getDateTime(format: 'yyyy-MM-dd') // '2025-04-23'
///
///   getDateTime(timestamp: true) // 1713878400
///
///   getDateTime(format: 'yyyy-MM-dd', convertTimestamp: true, inputTimestamp: 1713878400) // '2025-04-23'
dynamic getDateTimeNow({
  String format = 'yyyy-MM-dd',
  bool timestamp = false,
  bool convertTimestamp = false,
  int? inputTimestamp,
}) {
  if (timestamp) {
    // Return current Unix timestamp (seconds since epoch)
    return DateTime.now().millisecondsSinceEpoch ~/ 1000;
  }
  if (convertTimestamp && inputTimestamp != null) {
    // Convert timestamp (seconds or ms) to formatted string
    DateTime dt;
    if (inputTimestamp > 9999999999) {
      // Assume milliseconds
      dt = DateTime.fromMillisecondsSinceEpoch(inputTimestamp);
    } else {
      // Assume seconds
      dt = DateTime.fromMillisecondsSinceEpoch(inputTimestamp * 1000);
    }
    return DateFormat(format).format(dt);
  }
  // Default: return formatted current date/time
  return DateFormat(format).format(DateTime.now());
}

/// Gets the current address based on the device's location.
Future<Map<String, dynamic>> getCurrentAddress() async {
  try {
    // Try to get current position with a timeout (e.g., 8 seconds)
    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.best,
      timeLimit: const Duration(seconds: 8),
    );

    // Reverse geocode to get address
    List<Placemark> placemarks = await placemarkFromCoordinates(
      position.latitude,
      position.longitude,
    );

    if (placemarks.isNotEmpty) {
      final Placemark place = placemarks.first;
      return {
        "success": true,
        "address":
            "${place.name}, ${place.locality}, ${place.subAdministrativeArea}, ${place.administrativeArea}, ${place.country}",
      };
    } else {
      return {"success": false, "message": "no_address_found"};
    }
  } on TimeoutException {
    return {"success": false, "message": "location_timeout"};
  } on PermissionDeniedException {
    return {"success": false, "message": "location_permission_denied"};
  } catch (e) {
    // Fallback: Try to get location using IP-based service (internet)
    try {
      final uri = Uri.parse('https://ipapi.co/json/');
      final response = await HttpClient()
          .getUrl(uri)
          .then((req) => req.close());
      if (response.statusCode == 200) {
        final jsonStr = await response.transform(utf8.decoder).join();
        final data = json.decode(jsonStr);
        final city = data['city'] ?? '';
        final region = data['region'] ?? '';
        final country = data['country_name'] ?? '';
        final ip = data['ip'] ?? '';
        if (city.isNotEmpty || region.isNotEmpty || country.isNotEmpty) {
          return {
            "success": true,
            "address": "$city, $region, $country",
            "ip": ip,
          };
        }
      }
    } catch (_) {}
    return {"success": false, "message": "failed_to_get_location"};
  }
}
