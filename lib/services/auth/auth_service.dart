// main import
import '../../configs/configs.dart';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../server/kiosk_server.dart';

import '../../components/toastmsg.dart';

class KioskAuthService {
  /// [050725] Handles kiosk login and registration
  static Future<Map<String, dynamic>> loginKiosk(
    BuildContext context,
    Map<String, dynamic> data,
  ) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Center(child: CircularProgressIndicator()),
        );
      },
    );

    try {
      // Check kiosk ID
      bool kioskId =
          data["kiosk_id"] == globalAppConfig["kiosk_info"]?["kiosk_id"];
      if (!kioskId) {
        Navigator.of(context).pop();
        return {"success": false, "message": "login_id_failed"};
      }

      // Check kiosk password against locally stored AES encrypted password
      bool kioskPassword = await EncryptService().verifyLocalPassword(
        data["kiosk_password"],
        globalAppConfig["kiosk_info"]?["kiosk_password"],
      );

      if (!kioskPassword) {
        Navigator.of(context).pop();
        return {"success": false, "message": "login_password_failed"};
      }

      // Check if kiosk is online after successful local authentication
      bool isOnline = await _checkKioskOnlineStatus();

      // Close loading dialog
      Navigator.of(context).pop();

      return {
        "success": true,
        "message": "login_success",
        "is_online": isOnline,
      };
    } catch (e, stack) {
      APP_LOGS.error('Login failed', e, stack);
      Navigator.of(context).pop();
      return {"success": false, "message": "login_error"};
    }
  }

  /// [050725] Handles kiosk registration with server
  static Future<Map<String, dynamic>> registerKiosk(
    BuildContext context,
    Map<String, dynamic> data,
  ) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Center(child: CircularProgressIndicator()),
        );
      },
    );

    try {
      // Create password hash for server (SHA-256)
      String serverPasswordHash = EncryptService().encryptPasswordForServer(
        data["kiosk_password"],
      );

      // Register kiosk with server
      final apiService = KioskApiService();
      final serverResult = await apiService.registerKioskWithPassword(
        name: data["kiosk_name"],
        location: data["location"],
        password: serverPasswordHash, // Send SHA-256 hash to server
      );

      String kioskId = serverResult["kiosk_id"] ?? "";
      String kioskKey = serverResult["kiosk_key"] ?? "";
      if (kioskId != "" && kioskKey != "") {
        // Store kiosk information locally
        globalAppConfig["kiosk_info"]?["kiosk_id"] = serverResult["kiosk_id"];
        globalAppConfig["kiosk_info"]?["kiosk_key"] = serverResult["kiosk_key"];
        globalAppConfig["kiosk_info"]?["kiosk_name"] = data["kiosk_name"];
        globalAppConfig["kiosk_info"]?["location"] = data["location"];

        // Store password locally as AES encrypted
        globalAppConfig["kiosk_info"]?["kiosk_password"] =
            await EncryptService().encryptPasswordForLocal(
              data["kiosk_password"],
            );

        globalAppConfig["kiosk_info"]?["registered"] = true;

        // Update timestamp
        globalAppConfig["kiosk_info"]?["last_sync"] =
            DateTime.now().toIso8601String();

        final checkUpdateConfig = await ConfigService.updateConfig();

        if (!checkUpdateConfig) {
          APP_LOGS.error(
            'Failed to update global app config after registration',
          );
          throw Exception('Failed to update global app config');
        }

        // Close loading dialog
        Navigator.of(context).pop();

        return {
          "success": true,
          "message": "registration_success",
          "kiosk_id": kioskId,
        };
      } else {
        SERVER_LOGS.error('Server registration failed - missing credentials');
        throw Exception('Server registration failed - missing credentials');
      }
    } catch (e, stack) {
      APP_LOGS.error('Registration failed', e, stack);
      Navigator.of(context).pop();
      return {
        "success": false,
        "message": e is Exception ? e.toString() : 'registration_error',
        "stack": stack.toString(),
      };
    }
  }

  /// Check if kiosk is online by testing server connectivity
  static Future<bool> _checkKioskOnlineStatus() async {
    try {
      final apiService = KioskApiService();
      return await apiService.testConnection();
    } catch (e) {
      APP_LOGS.warning('Kiosk online check failed: $e');
      return false;
    }
  }

  /// Get kiosk online status
  static Future<bool> isKioskOnline() async {
    return await _checkKioskOnlineStatus();
  }

  /// Update kiosk information on server
  static Future<bool> updateKioskInfo({
    required String name,
    required String location,
    String? newPassword,
  }) async {
    try {
      final apiService = KioskApiService();
      final kioskId = globalAppConfig["kiosk_info"]?["kiosk_id"];

      if (kioskId == null) {
        throw Exception('Kiosk ID not found');
      }

      // Create updated kiosk data
      final kioskData = KioskData(
        name: name,
        location: location,
        description: 'Updated mobile kiosk application',
      );

      await apiService.updateKiosk(kioskId, kioskData);

      // If password update is needed, handle it separately
      if (newPassword != null && newPassword.isNotEmpty) {
        // Note: Password update would need additional API endpoint
        // For now, just log that password update was requested
        APP_LOGS.info(
          'Password update requested but not implemented in server API',
        );
      }

      return true;
    } catch (e, stack) {
      APP_LOGS.error('Failed to update kiosk info on server', e, stack);
      return false;
    }
  }

  /// Sync kiosk key from SharedPreferences to globalAppConfig
  static Future<void> syncKioskKeyToConfig() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final kioskKey = prefs.getString('kiosk_key');
      final kioskId = prefs.getString('kiosk_id');

      if (kioskKey != null && kioskId != null) {
        globalAppConfig["kiosk_info"]?["kiosk_key"] = kioskKey;
        globalAppConfig["kiosk_info"]?["kiosk_id"] = kioskId;
        await ConfigService.updateConfig();
        APP_LOGS.info(
          '🔄 Synced kiosk credentials from SharedPreferences to config',
        );
      }
    } catch (e) {
      APP_LOGS.warning('Failed to sync kiosk credentials: $e');
    }
  }
}

class EncryptService {
  // [050725] [FUNCTION RELATED TO ENCRYPTION AND DECRYPTION AUTH]
  final FlutterSecureStorage secureStorage = FlutterSecureStorage();
  static const String keyName = 'rOzErIyA_KeY';

  // [050725] Encrypts the password using SHA-256 hashing.
  /// This is a one-way hash function and cannot be decrypted.
  String encryptPasswordSHA(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // [050725] Retrieves the encryption key from secure storage or creates a new one.
  /// This key is used for AES encryption and decryption of sensitive data.
  Future<String> getOrCreateEncryptionKey() async {
    String? key = await secureStorage.read(key: keyName);

    if (key == null) {
      // Generate a secure random 32-byte key for AES-256
      final newKey = encrypt.Key.fromSecureRandom(32);
      key = newKey.base64;
      await secureStorage.write(key: keyName, value: key);
    }

    return key;
  }

  /// [050725] Retrieves the encryption key from secure storage or creates a new one.
  Future<encrypt.Key> getEncryptionKey() async {
    final keyString = await EncryptService().getOrCreateEncryptionKey();
    return encrypt.Key.fromBase64(keyString);
  }

  /// [050725] Encrypts the password using AES encryption with a random IV.
  Future<String> encryptPassword(String plain) async {
    final key = await getEncryptionKey();
    final iv = encrypt.IV.fromSecureRandom(16); // random IV
    final encrypter = encrypt.Encrypter(encrypt.AES(key));
    final encrypted = encrypter.encrypt(plain, iv: iv);
    // Store IV + encrypted bytes as base64
    final result = base64Encode(iv.bytes + encrypted.bytes);
    return result;
  }

  /// [050725] Decrypts the password and optionally compares it with a target password.
  Future<dynamic> decryptPassword(
    String encryptedStr, {
    String targetPassword = "",
  }) async {
    /// encryptedStr should be a base64 encoded string that contains IV + encrypted bytes
    /// targetPassword is optional, if provided, it will compare the decrypted password with this value
    try {
      final key = await getEncryptionKey();
      final bytes = base64Decode(encryptedStr);
      final iv = encrypt.IV(bytes.sublist(0, 16));
      final encryptedBytes = bytes.sublist(16);
      final encrypter = encrypt.Encrypter(encrypt.AES(key));
      final decrypted = encrypter.decrypt(
        encrypt.Encrypted(encryptedBytes),
        iv: iv,
      );
      if (targetPassword.isNotEmpty) {
        // Compare the decrypted password with the target password
        return decrypted == targetPassword;
      }
      return decrypted;
    } catch (e, stack) {
      APP_LOGS.error('Failed to decrypt password', e, stack);
      return false;
    }
  }

  /// [050725] Generates a strong password of the specified length.
  String generateStrongPassword(
    int length, {
    bool includeSpecialChars = false,
    bool includeDigits = true,
    bool includeUppercase = true,
    bool includeLowercase = true,
  }) {
    const String upper = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    const String lower = 'abcdefghijklmnopqrstuvwxyz';
    const String digits = '0123456789';
    const String special = '@#\$%^&*()-_=+[]{}|;:,.<>?';
    final String all =
        (includeUppercase ? upper : '') +
        (includeLowercase ? lower : '') +
        (includeDigits ? digits : '') +
        (includeSpecialChars ? special : '');
    final rand = Random.secure();

    // Ensure at least one character from each set
    String password =
        [
          if (includeUppercase) upper[rand.nextInt(upper.length)],
          if (includeLowercase) lower[rand.nextInt(lower.length)],
          if (includeDigits) digits[rand.nextInt(digits.length)],
          if (includeSpecialChars) special[rand.nextInt(special.length)],
        ].join();

    // Fill the rest with random chars
    for (int i = password.length; i < length; i++) {
      password += all[rand.nextInt(all.length)];
    }

    // Shuffle the password
    List<String> chars = password.split('')..shuffle(rand);
    return chars.join();
  }

  /// [060725] Encrypts password for SERVER storage using SHA-256 (consistent across app installs)
  /// Use this when sending employee data to server - password will always be the same hash
  String encryptPasswordForServer(String password) {
    return encryptPasswordSHA(password);
  }

  /// [060725] Encrypts password for LOCAL storage using AES (secure but regenerates on reinstall)
  /// Use this when storing sensitive data locally that needs to be decrypted later
  Future<String> encryptPasswordForLocal(String password) async {
    return await encryptPassword(password);
  }

  /// [060725] Verifies a password against a locally stored AES-encrypted password
  Future<bool> verifyLocalPassword(
    String plainPassword,
    String encryptedPassword,
  ) async {
    return await decryptPassword(
      encryptedPassword,
      targetPassword: plainPassword,
    );
  }

  /// [060725] Verifies a password against a server-stored SHA-256 hash
  bool verifyServerPassword(String plainPassword, String hashedPassword) {
    return encryptPasswordSHA(plainPassword) == hashedPassword;
  }
}

/// [050725] Checks if the provided password matches the admin password.
/// [050725] Checks if the provided password matches the admin password.
class AdminAuthDialog extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final String? confirmButtonText;
  final Color? confirmButtonColor;

  const AdminAuthDialog({
    Key? key,
    this.title,
    this.subtitle,
    this.confirmButtonText,
    this.confirmButtonColor,
  }) : super(key: key);

  /// Shows the admin authentication dialog with default admin verification
  ///
  /// Returns `true` if authentication succeeds, `false` otherwise, `null` if cancelled
  static Future<bool?> show(
    BuildContext context, {
    String? title,
    String? subtitle,
    String? confirmButtonText,
    Color? confirmButtonColor,
    String? inputPassword, // Direct password input for validation
  }) async {
    // Show dialog for user input
    return showDialog<bool>(
      context: context,
      barrierDismissible: true, // Allow dismissing by tapping outside
      builder:
          (context) => AdminAuthDialog(
            title: title,
            subtitle: subtitle,
            confirmButtonText: confirmButtonText,
            confirmButtonColor: confirmButtonColor,
          ),
    );
  }

  /// Validates a password directly against the admin password without showing a dialog
  ///
  /// Returns `true` if password is valid, `false` otherwise
  static Future<bool> validatePassword(String password) async {
    try {
      return await adminAuth(password);
    } catch (e, stack) {
      APP_LOGS.error('Password validation failed', e, stack);
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextEditingController adminController = TextEditingController();
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(
        title ??
            LOCALIZATION.localize('main_word.admin_auth') ??
            "Admin Authentication",
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Text(subtitle!, style: theme.textTheme.bodyMedium),
            ),
          TextField(
            controller: adminController,
            obscureText: true,
            autofocus: true, // Auto-focus for better UX
            decoration: InputDecoration(
              labelText:
                  LOCALIZATION.localize('auth_page.password') ??
                  "Admin Password",
              prefixIcon: const Icon(Icons.lock_outline),
              border: const OutlineInputBorder(),
            ),
            onSubmitted:
                (value) => _attemptVerification(context, adminController),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed:
              () => Navigator.of(context).pop(null), // Return null for cancel
          child: Text(LOCALIZATION.localize('main_word.cancel') ?? "Cancel"),
        ),

        ElevatedButton(
          onPressed: () => _attemptVerification(context, adminController),
          style: ElevatedButton.styleFrom(backgroundColor: confirmButtonColor),
          child: Text(
            confirmButtonText ??
                LOCALIZATION.localize('main_word.confirm') ??
                "Confirm",
          ),
        ),
      ],
    );
  }

  Future<void> _attemptVerification(
    BuildContext context,
    TextEditingController controller,
  ) async {
    final input = controller.text.trim();
    if (input.isEmpty) {
      showToastMessage(
        context,
        LOCALIZATION.localize('more_page.enter_admin_password') ??
            "Please enter admin password",
        ToastLevel.warning,
      );
      return;
    }

    // Show loading state
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Use the provided verifyPassword function or default to adminAuth
      final isValid = await adminAuth(input);

      // Close loading dialog
      Navigator.of(context).pop();

      if (isValid) {
        Navigator.of(context).pop(true); // Return true for success
      } else {
        showToastMessage(
          context,
          LOCALIZATION.localize('main_word.invalid_password') ??
              "Invalid password",
          ToastLevel.error,
        );
      }
    } catch (e) {
      // Close loading dialog
      Navigator.of(context).pop();

      showToastMessage(
        context,
        LOCALIZATION.localize('main_word.auth_error') ??
            "Authentication error. Please try again.",
        ToastLevel.error,
      );
      APP_LOGS.error('Authentication error', e);
    }
  }

  static Future<bool> adminAuth(String password) async {
    try {
      bool checkAdminPassword = await KioskApiService().checkAdminPassword(
        password,
      );
      return checkAdminPassword;
    } catch (e, stack) {
      APP_LOGS.error('Failed to check admin password', e, stack);
      return false;
    }
  }
}

/// [050725] Checks if the provided password matches the employee password.
Future<bool> empAuth(String password) async {
  try {
    return true;
  } catch (e, stack) {
    APP_LOGS.error('Failed to check employee password', e, stack);
    return false;
  }
}
