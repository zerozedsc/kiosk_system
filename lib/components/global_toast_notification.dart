import 'package:flutter/material.dart';
import '../components/toastmsg.dart';
import '../services/notification/enhanced_notification_service.dart';

/// Global toast notification wrapper that works with EnhancedNotificationService
class GlobalToastNotification {
  static GlobalToastNotification? _instance;
  static GlobalToastNotification get instance {
    _instance ??= GlobalToastNotification._internal();
    return _instance!;
  }

  GlobalToastNotification._internal();

  BuildContext? _context;

  /// Set the context for toast notifications (call this in main.dart)
  void setContext(BuildContext context) {
    _context = context;
  }

  /// Show toast notification based on AppNotification
  void showToast(AppNotification notification) {
    if (_context == null || !_context!.mounted) return;

    ToastLevel level;
    ToastPosition position = ToastPosition.top;

    // Map notification type to toast level
    switch (notification.type) {
      case NotificationType.success:
        level = ToastLevel.success;
        break;
      case NotificationType.warning:
        level = ToastLevel.warning;
        break;
      case NotificationType.error:
        level = ToastLevel.error;
        break;
      default:
        level = ToastLevel.info;
    }

    // Adjust position based on priority
    if (notification.priority == NotificationPriority.critical) {
      position = ToastPosition.center;
    } else if (notification.priority == NotificationPriority.high) {
      position = ToastPosition.top;
    }

    // Show the toast
    showToastMessage(
      _context!,
      '${notification.title}: ${notification.details}',
      level,
      position: position,
    );
  }

  /// Convenience methods for direct toast creation
  void showSuccessToast(String title, String details) {
    if (_context == null || !_context!.mounted) return;
    showToastMessage(_context!, '$title: $details', ToastLevel.success);
  }

  void showErrorToast(String title, String details) {
    if (_context == null || !_context!.mounted) return;
    showToastMessage(_context!, '$title: $details', ToastLevel.error);
  }

  void showWarningToast(String title, String details) {
    if (_context == null || !_context!.mounted) return;
    showToastMessage(_context!, '$title: $details', ToastLevel.warning);
  }

  void showInfoToast(String title, String details) {
    if (_context == null || !_context!.mounted) return;
    showToastMessage(_context!, '$title: $details', ToastLevel.info);
  }
}
