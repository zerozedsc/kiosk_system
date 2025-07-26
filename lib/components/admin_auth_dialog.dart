import '../configs/configs.dart';
import '../services/auth/auth_service.dart';
import '../services/database/db.dart';
import 'toastmsg.dart';

/// Centralized admin authentication dialog
/// Provides a consistent way to prompt for admin password across the app
class AdminAuthDialog {
  /// Shows an admin authentication dialog and returns true if authentication succeeds
  static Future<bool> show(
    BuildContext context, {
    String? title,
    String? message,
  }) async {
    final theme = Theme.of(context);
    final mainColor = theme.colorScheme.primary;
    final adminController = TextEditingController();

    try {
      final result = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  Icon(Icons.admin_panel_settings, color: Colors.red, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title ??
                          LOCALIZATION.localize('main_word.admin_auth') ??
                          "Admin Authentication",
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message ??
                        LOCALIZATION.localize(
                          'more_page.admin_password_required',
                        ) ??
                        "Admin password is required to perform this action.",
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 20),

                  // Admin Password Field
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: mainColor.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: TextField(
                      controller: adminController,
                      obscureText: true,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText:
                            LOCALIZATION.localize('auth_page.admin_password') ??
                            "Admin Password",
                        labelStyle: TextStyle(color: mainColor),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(16),
                        prefixIcon: Icon(
                          Icons.admin_panel_settings,
                          color: mainColor,
                        ),
                        floatingLabelBehavior: FloatingLabelBehavior.always,
                      ),
                      style: theme.textTheme.bodyLarge,
                      onSubmitted: (value) async {
                        if (value.trim().isNotEmpty) {
                          final isValid = await adminAuth(value.trim());
                          Navigator.of(context).pop(isValid);
                        }
                      },
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Warning message
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.orange.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber,
                          color: Colors.orange,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            LOCALIZATION.localize(
                                  'more_page.admin_auth_warning',
                                ) ??
                                "This action requires administrator privileges.",
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.orange.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    adminController.dispose();
                    Navigator.of(context).pop(false);
                  },
                  child: Text(
                    LOCALIZATION.localize('main_word.cancel') ?? "Cancel",
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final password = adminController.text.trim();
                    if (password.isEmpty) {
                      showToastMessage(
                        context,
                        LOCALIZATION.localize(
                              'auth_page.enter_admin_password',
                            ) ??
                            "Please enter admin password",
                        ToastLevel.warning,
                      );
                      return;
                    }

                    final isValid = await adminAuth(password);
                    if (isValid) {
                      adminController.dispose();
                      Navigator.of(context).pop(true);
                    } else {
                      showToastMessage(
                        context,
                        LOCALIZATION.localize(
                              'auth_page.admin_password_incorrect',
                            ) ??
                            "Invalid admin password",
                        ToastLevel.error,
                      );
                      adminController.clear();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    LOCALIZATION.localize('main_word.verify') ?? "Verify",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
      );

      return result ?? false;
    } catch (e) {
      adminController.dispose();
      return false;
    }
  }

  /// Verifies admin password against the stored admin user
  static Future<bool> adminAuth(String password) async {
    try {
      // Ensure EMPQUERY is initialized
      await EMPQUERY.initialize();

      // Find admin user (usually ID "0" with username "ADMIN")
      final adminUser = EMPQUERY.employees["0"];
      if (adminUser != null && adminUser["username"] == "ADMIN") {
        return await EncryptService().decryptPassword(
          adminUser["password"],
          targetPassword: password,
        );
      }

      // Fallback: check all employees for admin role
      for (final employee in EMPQUERY.employees.values) {
        if (employee["username"] == "ADMIN" ||
            (employee["is_admin"] == true || employee["is_admin"] == 1)) {
          return await EncryptService().decryptPassword(
            employee["password"],
            targetPassword: password,
          );
        }
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  /// Quick method to show admin auth dialog and execute action if successful
  static Future<void> requireAdminAuth(
    BuildContext context, {
    required VoidCallback onSuccess,
    String? title,
    String? message,
    VoidCallback? onFailure,
  }) async {
    final isAuthorized = await show(context, title: title, message: message);

    if (isAuthorized) {
      onSuccess();
    } else {
      if (onFailure != null) {
        onFailure();
      } else {
        showToastMessage(
          context,
          LOCALIZATION.localize('more_page.admin_auth_failed') ??
              "Admin authentication failed",
          ToastLevel.error,
        );
      }
    }
  }
}
