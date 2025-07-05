// main import
import '../../configs/configs.dart';
import '../database/db.dart';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AppFirstAuthService {
  static Future<Map<String, dynamic>> login(
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

    bool kioskId =
        data["kiosk_id"] == globalAppConfig["kiosk_info"]?["kiosk_id"];
    bool kioskPassword = await decryptPassword(
      globalAppConfig["kiosk_info"]?["kiosk_password"],
      targetPassword: data["kiosk_password"],
    );

    // Always close the loading dialog before returning
    Navigator.of(context).pop();

    // TODO: [DEBUG COMMENT] uncomment the following lines to enable login validation
    // if (!kioskId) {
    //   return {"success": false, "message": "login_id_failed"};
    // } else if (!kioskPassword) {
    //   return {"success": false, "message": "login_password_failed"};
    // }

    return {"success": true, "message": "login_success"};
  }

  static Future<bool> signup(
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

    globalAppConfig["kiosk_info"]?["kiosk_id"] = data["kiosk_id"];
    globalAppConfig["kiosk_info"]?["kiosk_name"] = data["kiosk_name"];
    globalAppConfig["kiosk_info"]?["location"] = data["location"];
    globalAppConfig["kiosk_info"]?["kiosk_password"] = await encryptPassword(
      data["kiosk_password"],
    );
    globalAppConfig["kiosk_info"]?["registered"] = true;
    final checkUpdateConfig = await ConfigService.updateConfig();

    // Close loading dialog
    Navigator.of(context).pop();

    return checkUpdateConfig;
  }
}

/// [050725] [FUNCTION RELATED TO ENCRYPTION AND DECRYPTION AUTH]
final FlutterSecureStorage secureStorage = FlutterSecureStorage();
const String keyName = 'rOzErIyA_KeY';

String encryptPasswordSHA(String password) {
  final bytes = utf8.encode(password);
  final digest = sha256.convert(bytes);
  return digest.toString();
}

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

Future<encrypt.Key> getEncryptionKey() async {
  final keyString = await getOrCreateEncryptionKey();
  return encrypt.Key.fromBase64(keyString);
}

Future<String> encryptPassword(String plain) async {
  final key = await getEncryptionKey();
  final iv = encrypt.IV.fromSecureRandom(16); // random IV
  final encrypter = encrypt.Encrypter(encrypt.AES(key));
  final encrypted = encrypter.encrypt(plain, iv: iv);
  // Store IV + encrypted bytes as base64
  final result = base64Encode(iv.bytes + encrypted.bytes);
  return result;
}

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

Future<bool> adminAuth(String password) async {
  try {
    // final targetPassword = "password";
    // final adminEncryptedPassword = await secureStorage.read(key: keyName) ?? "";
    // final decrypted = await decryptPassword(
    //   adminEncryptedPassword, targetPassword: targetPassword);
    // if (decrypted is String) {
    //   return decrypted == targetPassword;
    // }
    return true;
  } catch (e, stack) {
    APP_LOGS.error('Failed to check admin password', e, stack);
    return false;
  }
}
