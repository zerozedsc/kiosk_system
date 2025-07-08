import 'package:flutter/material.dart';
import '../../components/notification_island.dart';

/// Service to manage global notifications across the app
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final ValueNotifier<List<NotificationData>> _notifications = ValueNotifier(
    [],
  );

  ValueNotifier<List<NotificationData>> get notifications => _notifications;

  /// Show a notification with specified position and duration
  void showNotification({
    required String message,
    IconData? icon,
    Color? backgroundColor,
    Color? textColor,
    NotificationPosition position = NotificationPosition.top,
    Duration duration = const Duration(seconds: 3),
    bool shouldBlink = false,
    VoidCallback? onTap,
  }) {
    final notification = NotificationData(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      message: message,
      icon: icon,
      backgroundColor: backgroundColor ?? Colors.black87,
      textColor: textColor ?? Colors.white,
      position: position,
      shouldBlink: shouldBlink,
      onTap: onTap,
    );

    _notifications.value = [..._notifications.value, notification];

    // Auto-dismiss after duration
    if (duration.inMilliseconds > 0) {
      Future.delayed(duration, () {
        dismissNotification(notification.id);
      });
    }
  }

  /// Dismiss a specific notification
  void dismissNotification(String id) {
    _notifications.value =
        _notifications.value
            .where((notification) => notification.id != id)
            .toList();
  }

  /// Clear all notifications
  void clearAll() {
    _notifications.value = [];
  }

  /// Predefined notification methods
  void showSuccess(
    String message, {
    NotificationPosition position = NotificationPosition.top,
  }) {
    showNotification(
      message: message,
      icon: Icons.check_circle,
      backgroundColor: Colors.green,
      position: position,
    );
  }

  void showError(
    String message, {
    NotificationPosition position = NotificationPosition.top,
  }) {
    showNotification(
      message: message,
      icon: Icons.error,
      backgroundColor: Colors.red,
      position: position,
      shouldBlink: true,
    );
  }

  void showWarning(
    String message, {
    NotificationPosition position = NotificationPosition.top,
  }) {
    showNotification(
      message: message,
      icon: Icons.warning,
      backgroundColor: Colors.orange,
      position: position,
    );
  }

  void showInfo(
    String message, {
    NotificationPosition position = NotificationPosition.top,
  }) {
    showNotification(
      message: message,
      icon: Icons.info,
      backgroundColor: Colors.blue,
      position: position,
    );
  }

  void showLoading(
    String message, {
    NotificationPosition position = NotificationPosition.center,
  }) {
    showNotification(
      message: message,
      icon: Icons.hourglass_empty,
      backgroundColor: Colors.grey.shade800,
      position: position,
      duration: Duration.zero, // Don't auto-dismiss
      shouldBlink: true,
    );
  }

  void showOffline({NotificationPosition position = NotificationPosition.top}) {
    showNotification(
      message: 'No Internet Connection',
      icon: Icons.wifi_off,
      backgroundColor: Colors.red,
      position: position,
      duration: Duration.zero, // Don't auto-dismiss
      shouldBlink: true,
    );
  }

  void showConnecting({
    NotificationPosition position = NotificationPosition.top,
  }) {
    showNotification(
      message: 'Connecting...',
      icon: Icons.wifi,
      backgroundColor: Colors.orange,
      position: position,
      duration: Duration.zero, // Don't auto-dismiss
      shouldBlink: true,
    );
  }
}

/// Data class for notification information
class NotificationData {
  final String id;
  final String message;
  final IconData? icon;
  final Color backgroundColor;
  final Color textColor;
  final NotificationPosition position;
  final bool shouldBlink;
  final VoidCallback? onTap;

  NotificationData({
    required this.id,
    required this.message,
    this.icon,
    required this.backgroundColor,
    required this.textColor,
    required this.position,
    required this.shouldBlink,
    this.onTap,
  });
}

/// Widget to display all active notifications
class NotificationOverlay extends StatelessWidget {
  const NotificationOverlay({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<NotificationData>>(
      valueListenable: NotificationService().notifications,
      builder: (context, notifications, child) {
        if (notifications.isEmpty) return const SizedBox.shrink();

        return Stack(
          children:
              notifications.map((notification) {
                final notificationWidget = NotificationIsland(
                  message: notification.message,
                  icon: notification.icon,
                  backgroundColor: notification.backgroundColor,
                  textColor: notification.textColor,
                  shouldBlink: notification.shouldBlink,
                  onTap: () {
                    notification.onTap?.call();
                    NotificationService().dismissNotification(notification.id);
                  },
                );

                return _buildPositionedNotification(
                  notification,
                  notificationWidget,
                );
              }).toList(),
        );
      },
    );
  }

  Widget _buildPositionedNotification(
    NotificationData notification,
    NotificationIsland notificationWidget,
  ) {
    switch (notification.position) {
      case NotificationPosition.top:
        return PositionedNotificationIsland.top(
          notification: notificationWidget,
        );
      case NotificationPosition.bottom:
        return PositionedNotificationIsland.bottom(
          notification: notificationWidget,
        );
      case NotificationPosition.topLeft:
        return PositionedNotificationIsland.topLeft(
          notification: notificationWidget,
        );
      case NotificationPosition.topRight:
        return PositionedNotificationIsland.topRight(
          notification: notificationWidget,
        );
      case NotificationPosition.center:
        return PositionedNotificationIsland.center(
          notification: notificationWidget,
        );
      case NotificationPosition.centerLeft:
        return PositionedNotificationIsland(
          notification: notificationWidget,
          position: NotificationPosition.centerLeft,
        );
      case NotificationPosition.centerRight:
        return PositionedNotificationIsland(
          notification: notificationWidget,
          position: NotificationPosition.centerRight,
        );
      case NotificationPosition.bottomLeft:
        return PositionedNotificationIsland.bottomLeft(
          notification: notificationWidget,
        );
      case NotificationPosition.bottomRight:
        return PositionedNotificationIsland.bottomRight(
          notification: notificationWidget,
        );
    }
  }
}

/// Example usage page
class NotificationExamplePage extends StatelessWidget {
  const NotificationExamplePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Examples'),
        actions: [
          IconButton(
            icon: const Icon(Icons.clear_all),
            onPressed: () => NotificationService().clearAll(),
            tooltip: 'Clear All Notifications',
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSectionTitle('Basic Notifications'),
                _buildNotificationButton(
                  'Success Message',
                  Colors.green,
                  () => NotificationService().showSuccess(
                    'Operation completed successfully!',
                  ),
                ),
                _buildNotificationButton(
                  'Error Message',
                  Colors.red,
                  () =>
                      NotificationService().showError('Something went wrong!'),
                ),
                _buildNotificationButton(
                  'Warning Message',
                  Colors.orange,
                  () => NotificationService().showWarning(
                    'Please check your input',
                  ),
                ),
                _buildNotificationButton(
                  'Info Message',
                  Colors.blue,
                  () => NotificationService().showInfo('New update available'),
                ),

                const SizedBox(height: 24),
                _buildSectionTitle('Positioned Notifications'),
                _buildNotificationButton(
                  'Top Left',
                  Colors.purple,
                  () => NotificationService().showInfo(
                    'Top Left Position',
                    position: NotificationPosition.topLeft,
                  ),
                ),
                _buildNotificationButton(
                  'Top Right',
                  Colors.indigo,
                  () => NotificationService().showInfo(
                    'Top Right Position',
                    position: NotificationPosition.topRight,
                  ),
                ),
                _buildNotificationButton(
                  'Center',
                  Colors.teal,
                  () => NotificationService().showInfo(
                    'Center Position',
                    position: NotificationPosition.center,
                  ),
                ),
                _buildNotificationButton(
                  'Bottom Left',
                  Colors.brown,
                  () => NotificationService().showInfo(
                    'Bottom Left Position',
                    position: NotificationPosition.bottomLeft,
                  ),
                ),
                _buildNotificationButton(
                  'Bottom Right',
                  Colors.pink,
                  () => NotificationService().showInfo(
                    'Bottom Right Position',
                    position: NotificationPosition.bottomRight,
                  ),
                ),

                const SizedBox(height: 24),
                _buildSectionTitle('Special Notifications'),
                _buildNotificationButton(
                  'Loading (Center)',
                  Colors.grey,
                  () => NotificationService().showLoading('Processing...'),
                ),
                _buildNotificationButton(
                  'Offline Status',
                  Colors.red,
                  () => NotificationService().showOffline(),
                ),
                _buildNotificationButton(
                  'Connecting Status',
                  Colors.orange,
                  () => NotificationService().showConnecting(),
                ),
              ],
            ),
          ),

          // Notification overlay
          const NotificationOverlay(),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildNotificationButton(
    String label,
    Color color,
    VoidCallback onPressed,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        child: Text(label),
      ),
    );
  }
}
