import '../../components/global_toast_notification.dart';
import '../../configs/configs.dart';

/// Notification priority levels
enum NotificationPriority { low, normal, high, critical }

/// Notification types for different scenarios
enum NotificationType {
  info,
  success,
  warning,
  error,
  system,
  transaction,
  inventory,
  connection,
  queue,
}

/// Enhanced notification data model
class AppNotification {
  final String id;
  final String title;
  final String details;
  final DateTime dateTime;
  final NotificationPriority priority;
  final NotificationType type;
  final bool isRead;
  final bool isDismissible;
  final DateTime? expiresAt;
  final Map<String, dynamic>? actionData;
  final String? actionButtonText;

  AppNotification({
    required this.id,
    required this.title,
    required this.details,
    required this.dateTime,
    this.priority = NotificationPriority.normal,
    this.type = NotificationType.info,
    this.isRead = false,
    this.isDismissible = true,
    this.expiresAt,
    this.actionData,
    this.actionButtonText,
  });

  /// Create notification with auto-generated ID
  factory AppNotification.create({
    required String title,
    required String details,
    NotificationPriority priority = NotificationPriority.normal,
    NotificationType type = NotificationType.info,
    bool isDismissible = true,
    Duration? expiresIn,
    Map<String, dynamic>? actionData,
    String? actionButtonText,
  }) {
    return AppNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      details: details,
      dateTime: DateTime.now(),
      priority: priority,
      type: type,
      isDismissible: isDismissible,
      expiresAt: expiresIn != null ? DateTime.now().add(expiresIn) : null,
      actionData: actionData,
      actionButtonText: actionButtonText,
    );
  }

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'details': details,
    'dateTime': dateTime.toIso8601String(),
    'priority': priority.name,
    'type': type.name,
    'isRead': isRead,
    'isDismissible': isDismissible,
    'expiresAt': expiresAt?.toIso8601String(),
    'actionData': actionData,
    'actionButtonText': actionButtonText,
  };

  /// Create from JSON
  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'],
      title: json['title'],
      details: json['details'],
      dateTime: DateTime.parse(json['dateTime']),
      priority: NotificationPriority.values.firstWhere(
        (e) => e.name == json['priority'],
      ),
      type: NotificationType.values.firstWhere((e) => e.name == json['type']),
      isRead: json['isRead'] ?? false,
      isDismissible: json['isDismissible'] ?? true,
      expiresAt:
          json['expiresAt'] != null ? DateTime.parse(json['expiresAt']) : null,
      actionData: json['actionData'],
      actionButtonText: json['actionButtonText'],
    );
  }

  /// Create a copy with modified fields
  AppNotification copyWith({
    String? id,
    String? title,
    String? details,
    DateTime? dateTime,
    NotificationPriority? priority,
    NotificationType? type,
    bool? isRead,
    bool? isDismissible,
    DateTime? expiresAt,
    Map<String, dynamic>? actionData,
    String? actionButtonText,
  }) {
    return AppNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      details: details ?? this.details,
      dateTime: dateTime ?? this.dateTime,
      priority: priority ?? this.priority,
      type: type ?? this.type,
      isRead: isRead ?? this.isRead,
      isDismissible: isDismissible ?? this.isDismissible,
      expiresAt: expiresAt ?? this.expiresAt,
      actionData: actionData ?? this.actionData,
      actionButtonText: actionButtonText ?? this.actionButtonText,
    );
  }

  /// Check if notification is expired
  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);

  /// Get appropriate color for notification type
  Color get color {
    switch (type) {
      case NotificationType.success:
        return Colors.green;
      case NotificationType.warning:
        return Colors.orange;
      case NotificationType.error:
        return Colors.red;
      case NotificationType.info:
        return Colors.blue;
      case NotificationType.system:
        return Colors.purple;
      case NotificationType.transaction:
        return Colors.teal;
      case NotificationType.inventory:
        return Colors.brown;
      case NotificationType.connection:
        return Colors.indigo;
      case NotificationType.queue:
        return Colors.amber;
    }
  }

  /// Get appropriate icon for notification type
  IconData get icon {
    switch (type) {
      case NotificationType.success:
        return Icons.check_circle;
      case NotificationType.warning:
        return Icons.warning;
      case NotificationType.error:
        return Icons.error;
      case NotificationType.info:
        return Icons.info;
      case NotificationType.system:
        return Icons.settings;
      case NotificationType.transaction:
        return Icons.receipt;
      case NotificationType.inventory:
        return Icons.inventory;
      case NotificationType.connection:
        return Icons.wifi;
      case NotificationType.queue:
        return Icons.queue;
    }
  }

  /// Get priority icon
  IconData get priorityIcon {
    switch (priority) {
      case NotificationPriority.low:
        return Icons.keyboard_arrow_down;
      case NotificationPriority.normal:
        return Icons.remove;
      case NotificationPriority.high:
        return Icons.keyboard_arrow_up;
      case NotificationPriority.critical:
        return Icons.priority_high;
    }
  }

  /// Get priority color
  Color get priorityColor {
    switch (priority) {
      case NotificationPriority.low:
        return Colors.grey;
      case NotificationPriority.normal:
        return Colors.blue;
      case NotificationPriority.high:
        return Colors.orange;
      case NotificationPriority.critical:
        return Colors.red;
    }
  }

  @override
  String toString() =>
      'AppNotification(id: $id, title: $title, type: $type, priority: $priority)';
}

/// Enhanced notification service
class EnhancedNotificationService {
  static final EnhancedNotificationService _instance =
      EnhancedNotificationService._internal();
  factory EnhancedNotificationService() => _instance;
  EnhancedNotificationService._internal();

  static const String _storageKey = 'app_notifications';
  static const int _maxStoredNotifications = 100;

  final ValueNotifier<List<AppNotification>> _notifications = ValueNotifier([]);
  final ValueNotifier<int> _unreadCount = ValueNotifier(0);

  /// Stream of all notifications
  ValueNotifier<List<AppNotification>> get notifications => _notifications;

  /// Stream of unread count
  ValueNotifier<int> get unreadCount => _unreadCount;

  /// Initialize the service
  Future<void> initialize() async {
    print('🔔 Initializing Enhanced Notification Service');
    await _loadNotifications();
    await _cleanExpiredNotifications();
    _updateUnreadCount();
    print('✅ Enhanced Notification Service initialized');
  }

  /// Add a new notification
  Future<void> addNotification(AppNotification notification) async {
    print('📬 Adding notification: ${notification.title}');

    final currentNotifications = List<AppNotification>.from(
      _notifications.value,
    );
    currentNotifications.insert(0, notification); // Add to beginning

    // Limit stored notifications
    if (currentNotifications.length > _maxStoredNotifications) {
      currentNotifications.removeRange(
        _maxStoredNotifications,
        currentNotifications.length,
      );
    }

    _notifications.value = currentNotifications;
    _updateUnreadCount();
    await _saveNotifications();

    // Show toast for real-time notification across pages
    await _showToastNotification(notification);
  }

  /// Create and add notification with convenience method
  Future<void> notify({
    required String title,
    required String details,
    NotificationPriority priority = NotificationPriority.normal,
    NotificationType type = NotificationType.info,
    bool isDismissible = true,
    Duration? expiresIn,
    Map<String, dynamic>? actionData,
    String? actionButtonText,
  }) async {
    final notification = AppNotification.create(
      title: title,
      details: details,
      priority: priority,
      type: type,
      isDismissible: isDismissible,
      expiresIn: expiresIn,
      actionData: actionData,
      actionButtonText: actionButtonText,
    );

    await addNotification(notification);
  }

  /// Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    final currentNotifications = List<AppNotification>.from(
      _notifications.value,
    );
    final index = currentNotifications.indexWhere(
      (n) => n.id == notificationId,
    );

    if (index != -1) {
      currentNotifications[index] = currentNotifications[index].copyWith(
        isRead: true,
      );
      _notifications.value = currentNotifications;
      _updateUnreadCount();
      await _saveNotifications();
      print('📖 Marked notification as read: $notificationId');
    }
  }

  /// Delete/dismiss notification
  Future<void> deleteNotification(String notificationId) async {
    final currentNotifications = List<AppNotification>.from(
      _notifications.value,
    );
    currentNotifications.removeWhere((n) => n.id == notificationId);
    _notifications.value = currentNotifications;
    _updateUnreadCount();
    await _saveNotifications();
    print('🗑️ Deleted notification: $notificationId');
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead() async {
    final currentNotifications =
        _notifications.value.map((n) => n.copyWith(isRead: true)).toList();
    _notifications.value = currentNotifications;
    _updateUnreadCount();
    await _saveNotifications();
    print('📖 Marked all notifications as read');
  }

  /// Clear all notifications
  Future<void> clearAll() async {
    _notifications.value = [];
    _updateUnreadCount();
    await _saveNotifications();
    print('🧹 Cleared all notifications');
  }

  /// Get notifications by type
  List<AppNotification> getByType(NotificationType type) {
    return _notifications.value.where((n) => n.type == type).toList();
  }

  /// Get notifications by priority
  List<AppNotification> getByPriority(NotificationPriority priority) {
    return _notifications.value.where((n) => n.priority == priority).toList();
  }

  /// Get unread notifications
  List<AppNotification> getUnread() {
    return _notifications.value.where((n) => !n.isRead).toList();
  }

  /// Clean expired notifications
  Future<void> _cleanExpiredNotifications() async {
    final currentNotifications =
        _notifications.value.where((n) => !n.isExpired).toList();

    if (currentNotifications.length != _notifications.value.length) {
      _notifications.value = currentNotifications;
      _updateUnreadCount();
      await _saveNotifications();
      print('🧹 Cleaned expired notifications');
    }
  }

  /// Update unread count
  void _updateUnreadCount() {
    final count = _notifications.value.where((n) => !n.isRead).length;
    _unreadCount.value = count;
  }

  /// Show toast notification for real-time display
  Future<void> _showToastNotification(AppNotification notification) async {
    try {
      // Use global toast notification instance
      GlobalToastNotification.instance.showToast(notification);
      print('🔔 Showed toast: ${notification.title}');
    } catch (e) {
      print('❌ Error showing toast notification: $e');
    }
  }

  /// Save notifications to storage
  Future<void> _saveNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notificationsJson =
          _notifications.value.map((n) => n.toJson()).toList();
      await prefs.setString(_storageKey, jsonEncode(notificationsJson));
      print('💾 Saved ${_notifications.value.length} notifications');
    } catch (e) {
      print('❌ Error saving notifications: $e');
    }
  }

  /// Load notifications from storage
  Future<void> _loadNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notificationsString = prefs.getString(_storageKey);

      if (notificationsString != null) {
        final notificationsJson = jsonDecode(notificationsString) as List;
        final notifications =
            notificationsJson
                .map((json) => AppNotification.fromJson(json))
                .toList();
        _notifications.value = notifications;
        print('📂 Loaded ${notifications.length} notifications');
      }
    } catch (e) {
      print('❌ Error loading notifications: $e');
    }
  }

  /// Convenience methods for common notification types
  Future<void> notifySuccess(
    String title,
    String details, {
    Duration? expiresIn,
  }) async {
    await notify(
      title: title,
      details: details,
      type: NotificationType.success,
      priority: NotificationPriority.normal,
      expiresIn: expiresIn,
    );
  }

  Future<void> notifyError(
    String title,
    String details, {
    bool critical = false,
  }) async {
    await notify(
      title: title,
      details: details,
      type: NotificationType.error,
      priority:
          critical ? NotificationPriority.critical : NotificationPriority.high,
      isDismissible: !critical,
    );
  }

  Future<void> notifyWarning(String title, String details) async {
    await notify(
      title: title,
      details: details,
      type: NotificationType.warning,
      priority: NotificationPriority.normal,
    );
  }

  Future<void> notifyInfo(
    String title,
    String details, {
    Duration? expiresIn,
  }) async {
    await notify(
      title: title,
      details: details,
      type: NotificationType.info,
      priority: NotificationPriority.normal,
      expiresIn: expiresIn,
    );
  }

  Future<void> notifyConnection(
    String title,
    String details, {
    bool isOffline = false,
  }) async {
    await notify(
      title: title,
      details: details,
      type: NotificationType.connection,
      priority:
          isOffline ? NotificationPriority.high : NotificationPriority.normal,
    );
  }

  Future<void> notifyQueue(
    String title,
    String details, {
    String? actionButtonText,
    Map<String, dynamic>? actionData,
  }) async {
    await notify(
      title: title,
      details: details,
      type: NotificationType.queue,
      priority: NotificationPriority.normal,
      actionButtonText: actionButtonText,
      actionData: actionData,
    );
  }

  Future<void> notifyTransaction(String title, String details) async {
    await notify(
      title: title,
      details: details,
      type: NotificationType.transaction,
      priority: NotificationPriority.normal,
    );
  }

  Future<void> notifyInventory(String title, String details) async {
    await notify(
      title: title,
      details: details,
      type: NotificationType.inventory,
      priority: NotificationPriority.normal,
    );
  }

  /// Example: Add a security notification when encryption key changes
  Future<void> notifyEncryptionKeyRotation() async {
    await notify(
      title: 'Security Update',
      details: 'Local encryption key has been rotated for enhanced security',
      type: NotificationType.info,
      priority: NotificationPriority.normal,
      expiresIn: Duration(hours: 24),
    );
  }

  /// Example: Add notification for authentication events
  Future<void> notifyAuthenticationEvent(
    String eventType,
    String details,
  ) async {
    final priority =
        eventType.contains('failed')
            ? NotificationPriority.high
            : NotificationPriority.normal;

    await notify(
      title: 'Authentication Event',
      details: details,
      type: NotificationType.info,
      priority: priority,
      expiresIn: Duration(hours: 1),
    );
  }
}
