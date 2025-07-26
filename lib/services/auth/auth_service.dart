// main import
import '../../configs/configs.dart';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../server/kiosk_server.dart';

import '../../components/toastmsg.dart';

class KioskAuthService {
  /// [080725] Handles kiosk login with sync status awareness
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
      // Check kiosk ID (including temporary ID)
      final storedKioskId = globalAppConfig["kiosk_info"]?["kiosk_id"];
      bool kioskId = data["kiosk_id"] == storedKioskId;

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

      // Get sync status
      final syncStatus = getSyncStatus();

      // Close loading dialog
      Navigator.of(context).pop();

      return {
        "success": true,
        "message": "login_success",
        "is_online": isOnline,
        "kiosk_id": storedKioskId,
        "sync_status": syncStatus,
        "needs_sync": syncStatus["needs_sync"],
      };
    } catch (e, stack) {
      APP_LOGS.error('Login failed', e, stack);
      Navigator.of(context).pop();
      return {"success": false, "message": "login_error"};
    }
  }

  /// [080725] Handles kiosk registration with local-first approach
  /// Step 1: Save to local config with temporary kiosk ID
  /// Step 2: Sync with server to get real kiosk ID and key
  /// Step 3: Update local config with server credentials
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
      // STEP 1: Save to local config first with temporary kiosk ID
      APP_LOGS.info('Step 1: Saving kiosk data locally with temporary ID');

      // Store kiosk information locally with temporary ID
      globalAppConfig["kiosk_info"]?["kiosk_id"] = "TMPKIOSK";
      globalAppConfig["kiosk_info"]?["kiosk_key"] = "TMPKEY";
      globalAppConfig["kiosk_info"]?["kiosk_name"] = data["kiosk_name"];
      globalAppConfig["kiosk_info"]?["location"] = data["location"];

      // Store password locally as AES encrypted
      globalAppConfig["kiosk_info"]?["kiosk_password"] = await EncryptService()
          .encryptPasswordForLocal(data["kiosk_password"]);

      globalAppConfig["kiosk_info"]?["registered"] =
          false; // Not fully registered yet
      globalAppConfig["kiosk_info"]?["sync_pending"] =
          true; // Mark as needing server sync

      // Update timestamp
      globalAppConfig["kiosk_info"]?["last_sync"] =
          DateTime.now().toIso8601String();

      // Test local save first
      final checkUpdateConfig = await ConfigService.updateConfig();
      if (!checkUpdateConfig) {
        APP_LOGS.error('Failed to save kiosk data locally');
        Navigator.of(context).pop();
        return {
          "success": false,
          "message": "local_save_failed",
          "details": "Could not save kiosk data to local storage",
        };
      }

      APP_LOGS.info('Step 1 completed: Kiosk data saved locally');

      // STEP 2: Sync with server to get real credentials
      APP_LOGS.info('Step 2: Syncing with server to get real kiosk ID and key');

      // Create password hash for server (SHA-256)
      String serverPasswordHash = EncryptService().encryptPasswordForServer(
        data["kiosk_password"],
      );

      // Register kiosk with server
      final serverResult = await kioskApiService.registerKioskWithPassword(
        name: data["kiosk_name"],
        location: data["location"],
        password: serverPasswordHash, // Send SHA-256 hash to server
      );

      String kioskId = serverResult["kiosk_id"] ?? "";
      String kioskKey = serverResult["kiosk_key"] ?? "";

      if (kioskId.isEmpty || kioskKey.isEmpty) {
        APP_LOGS.warning(
          'Server returned empty credentials, keeping local data with temporary ID',
        );
        Navigator.of(context).pop();
        return {
          "success": true,
          "message": "registration_local_only",
          "kiosk_id": "TMPKIOSK",
          "details":
              "Saved locally but server sync failed. Will retry when connection improves.",
        };
      }

      // STEP 3: Update local config with server credentials
      APP_LOGS.info('Step 3: Updating local config with server credentials');

      globalAppConfig["kiosk_info"]?["kiosk_id"] = kioskId;
      globalAppConfig["kiosk_info"]?["kiosk_key"] = kioskKey;
      globalAppConfig["kiosk_info"]?["registered"] =
          true; // Fully registered now
      globalAppConfig["kiosk_info"]?["sync_pending"] = false; // Sync completed

      // Update timestamp
      globalAppConfig["kiosk_info"]?["last_sync"] =
          DateTime.now().toIso8601String();

      // Save updated config
      final finalUpdateConfig = await ConfigService.updateConfig();
      if (!finalUpdateConfig) {
        APP_LOGS.error('Failed to update config with server credentials');
        // Keep the temporary ID but log the issue
        APP_LOGS.warning(
          'Kiosk is registered on server but local config update failed',
        );
      }

      // Close loading dialog
      Navigator.of(context).pop();

      APP_LOGS.info(
        'Registration completed successfully with kiosk ID: $kioskId',
      );
      return {
        "success": true,
        "message": "registration_success",
        "kiosk_id": kioskId,
        "kiosk_key": kioskKey,
      };
    } catch (e, stack) {
      APP_LOGS.error('Registration failed', e, stack);
      Navigator.of(context).pop();

      // Check if we have local data saved (Step 1 succeeded)
      if (globalAppConfig["kiosk_info"]?["kiosk_id"] == "TMPKIOSK") {
        APP_LOGS.info(
          'Local data preserved with temporary ID despite server error',
        );
        return {
          "success": true,
          "message": "registration_local_fallback",
          "kiosk_id": "TMPKIOSK",
          "details":
              "Saved locally but server sync failed: ${e.toString()}. Will retry when connection improves.",
        };
      }

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
      return await kioskApiService.testConnection();
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

      await kioskApiService.updateKiosk(kioskId, kioskData);

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

  /// [080725] Retry server sync for kiosks with temporary IDs
  /// This method can be called when network connectivity is restored
  static Future<Map<String, dynamic>> retryServerSync() async {
    try {
      // Check if we have a temporary kiosk ID
      final currentKioskId = globalAppConfig["kiosk_info"]?["kiosk_id"];
      final syncPending =
          globalAppConfig["kiosk_info"]?["sync_pending"] ?? false;

      if (currentKioskId != "TMPKIOSK" || !syncPending) {
        APP_LOGS.info(
          'No server sync needed - kiosk already registered or not pending',
        );
        return {
          "success": true,
          "message": "no_sync_needed",
          "kiosk_id": currentKioskId,
        };
      }

      APP_LOGS.info('Retrying server sync for kiosk with temporary ID');

      // Get stored kiosk data
      final kioskName = globalAppConfig["kiosk_info"]?["kiosk_name"];
      final location = globalAppConfig["kiosk_info"]?["location"];
      final encryptedPassword =
          globalAppConfig["kiosk_info"]?["kiosk_password"];

      if (kioskName == null || location == null || encryptedPassword == null) {
        throw Exception('Missing required kiosk data for server sync');
      }

      // Decrypt password for server sync
      final decryptedPassword = await EncryptService().decryptPassword(
        encryptedPassword,
      );
      if (decryptedPassword == null || decryptedPassword == false) {
        throw Exception('Failed to decrypt stored password');
      }

      // Create password hash for server (SHA-256)
      String serverPasswordHash = EncryptService().encryptPasswordForServer(
        decryptedPassword,
      );

      // Register kiosk with server
      final serverResult = await kioskApiService.registerKioskWithPassword(
        name: kioskName,
        location: location,
        password: serverPasswordHash,
      );

      String kioskId = serverResult["kiosk_id"] ?? "";
      String kioskKey = serverResult["kiosk_key"] ?? "";

      if (kioskId.isEmpty || kioskKey.isEmpty) {
        throw Exception('Server returned empty credentials');
      }

      // Update local config with server credentials
      globalAppConfig["kiosk_info"]?["kiosk_id"] = kioskId;
      globalAppConfig["kiosk_info"]?["kiosk_key"] = kioskKey;
      globalAppConfig["kiosk_info"]?["registered"] = true;
      globalAppConfig["kiosk_info"]?["sync_pending"] = false;

      // Update timestamp
      globalAppConfig["kiosk_info"]?["last_sync"] =
          DateTime.now().toIso8601String();

      // Save updated config
      final updateConfig = await ConfigService.updateConfig();
      if (!updateConfig) {
        APP_LOGS.error('Failed to update config with server credentials');
        throw Exception('Failed to update local config');
      }

      APP_LOGS.info(
        'Server sync completed successfully with kiosk ID: $kioskId',
      );
      return {
        "success": true,
        "message": "sync_success",
        "kiosk_id": kioskId,
        "kiosk_key": kioskKey,
      };
    } catch (e, stack) {
      APP_LOGS.error('Server sync retry failed', e, stack);
      return {
        "success": false,
        "message": "sync_failed",
        "details": e.toString(),
      };
    }
  }

  /// [080725] Check if kiosk needs server sync (has temporary ID)
  static bool needsServerSync() {
    final currentKioskId = globalAppConfig["kiosk_info"]?["kiosk_id"];
    final syncPending = globalAppConfig["kiosk_info"]?["sync_pending"] ?? false;
    return currentKioskId == "TMPKIOSK" && syncPending;
  }

  /// [080725] Get kiosk sync status information
  static Map<String, dynamic> getSyncStatus() {
    final currentKioskId = globalAppConfig["kiosk_info"]?["kiosk_id"];
    final syncPending = globalAppConfig["kiosk_info"]?["sync_pending"] ?? false;
    final registered = globalAppConfig["kiosk_info"]?["registered"] ?? false;

    return {
      "kiosk_id": currentKioskId,
      "sync_pending": syncPending,
      "registered": registered,
      "needs_sync": needsServerSync(),
    };
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

  /// [070725] Retrieves the encryption key string from secure storage or creates a new one.
  /// This is a private helper method.
  Future<String> _getOrCreateEncryptionKeyString() async {
    String? key = await secureStorage.read(key: keyName);

    if (key == null) {
      // Generate a secure random 32-byte key for AES-256
      final newKey = encrypt.Key.fromSecureRandom(32);
      key = newKey.base64;
      await secureStorage.write(key: keyName, value: key);
    }

    return key;
  }

  /// [070725] Retrieves the encryption key as a Key object for use with the encrypt package.
  Future<encrypt.Key> getEncryptionKey() async {
    // Correctly call the helper method on the current instance.
    final keyString = await _getOrCreateEncryptionKeyString();
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

      if (bytes.length < 16) {
        APP_LOGS.error('Decryption failed: input is too short to be valid.');
        return null;
      }

      final iv = encrypt.IV(bytes.sublist(0, 16));
      final encryptedBytes = bytes.sublist(16);
      final encrypter = encrypt.Encrypter(encrypt.AES(key));

      final decrypted = encrypter.decrypt(
        encrypt.Encrypted(encryptedBytes),
        iv: iv,
      );
      if (targetPassword.isNotEmpty || targetPassword != "") {
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

/// [260725] Checks if the provided password matches the admin password.
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
      content: SingleChildScrollView(
        child: Column(
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
        LOCALIZATION.localize('auth_page.enter_admin_password') ??
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
      bool checkAdminPassword = await kioskApiService.checkAdminPassword(
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
Future<dynamic> empAuth(
  Map<String, dynamic> employee,
  String password, {
  LoggingService? LOGS,
}) async {
  LOGS ??= APP_LOGS;
  try {
    // Use provided LOGS or fallback to APP_LOGS

    if (DEBUG && password == "test") {
      LOGS.info(
        'Debug mode: bypassing password check for employee ${employee['id']}',
      );
      return true; // Bypass password check in debug mode
    }

    // Example password check (replace with your logic)
    final storedHash = employee['password'];
    if (storedHash == null || storedHash.isEmpty) {
      LOGS.warning('No password stored for employee ${employee['id']}');
      return 'main_word.password_data_error';
    }

    final isValid = await EncryptService().decryptPassword(
      storedHash,
      targetPassword: password,
    );

    return isValid;
  } catch (e, stack) {
    LOGS.error('Failed to check employee password', e, stack);
    return 'main_word.password_incorrect';
  }
}
