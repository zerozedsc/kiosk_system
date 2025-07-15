import '../../configs/configs.dart';
import '../notification/enhanced_notification_service.dart';
import 'kiosk_server.dart';

/// [080725] Global function for emergency data saving (can run in isolate)
Future<void> _saveQueueData(Map<String, dynamic> data) async {
  try {
    final prefs = await SharedPreferences.getInstance();

    // Save operations
    if (data['operations'] != null) {
      await prefs.setString(
        'offline_operations_queue',
        jsonEncode(data['operations']),
      );
    }

    // Save notifications
    if (data['notifications'] != null) {
      await prefs.setString(
        'failure_notifications',
        jsonEncode(data['notifications']),
      );
    }
  } catch (e) {
    // Silent fail in isolate
    print('Emergency save failed: $e');
  }
}

/// Enum for different types of operations that can be queued
enum OperationType { get, post, put, delete }

/// Data class representing a queued operation
class QueuedOperation {
  final String id;
  final OperationType type;
  final String endpoint;
  final Map<String, dynamic>? data;
  final DateTime timestamp;
  final int retryCount;
  final Map<String, String>? headers;

  QueuedOperation({
    required this.id,
    required this.type,
    required this.endpoint,
    this.data,
    required this.timestamp,
    this.retryCount = 0,
    this.headers,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'endpoint': endpoint,
    'data': data,
    'timestamp': timestamp.toIso8601String(),
    'retryCount': retryCount,
    'headers': headers,
  };

  factory QueuedOperation.fromJson(Map<String, dynamic> json) {
    return QueuedOperation(
      id: json['id'],
      type: OperationType.values.firstWhere((e) => e.name == json['type']),
      endpoint: json['endpoint'],
      data: json['data'],
      timestamp: DateTime.parse(json['timestamp']),
      retryCount: json['retryCount'] ?? 0,
      headers:
          json['headers'] != null
              ? Map<String, String>.from(json['headers'])
              : null,
    );
  }

  QueuedOperation copyWith({
    String? id,
    OperationType? type,
    String? endpoint,
    Map<String, dynamic>? data,
    DateTime? timestamp,
    int? retryCount,
    Map<String, String>? headers,
  }) {
    return QueuedOperation(
      id: id ?? this.id,
      type: type ?? this.type,
      endpoint: endpoint ?? this.endpoint,
      data: data ?? this.data,
      timestamp: timestamp ?? this.timestamp,
      retryCount: retryCount ?? this.retryCount,
      headers: headers ?? this.headers,
    );
  }

  @override
  String toString() =>
      'QueuedOperation(id: $id, type: $type, endpoint: $endpoint, retryCount: $retryCount)';
}

/// Safe failure system for handling offline operations

class OfflineQueueManager {
  static final OfflineQueueManager _instance = OfflineQueueManager._internal();
  factory OfflineQueueManager() => _instance;
  OfflineQueueManager._internal();

  static const String _queueKey = 'offline_operations_queue';
  static const String _failureNotificationKey = 'failure_notifications';
  static const int _maxRetries = 3;

  /// [FIX:140725] Retry interval for processing queued operations
  static const Duration _retryInterval = Duration(minutes: 2);
  static const Duration _maxQueueAge = Duration(hours: 24);

  final List<QueuedOperation> _operationQueue = [];
  final List<Map<String, dynamic>> _failureNotifications = [];
  Timer? _retryTimer;
  bool _isProcessing = false;
  bool _isOnline = true;

  final StreamController<bool> _connectivityController =
      StreamController<bool>.broadcast();
  final StreamController<int> _queueSizeController =
      StreamController<int>.broadcast();

  /// Stream to listen for connectivity changes
  Stream<bool> get onConnectivityChanged => _connectivityController.stream;

  /// Stream to listen for queue size changes
  Stream<int> get onQueueSizeChanged => _queueSizeController.stream;

  /// Get current queue size
  int get queueSize => _operationQueue.length;

  /// Get current online status
  bool get isOnline => _isOnline;

  /// Initialize the offline queue manager
  Future<void> initialize() async {
    SERVER_LOGS.info('🔄 Initializing OfflineQueueManager');

    await _loadQueueFromStorage();
    await _loadFailureNotifications();
    await _cleanOldOperations();

    // Start retry timer
    _startRetryTimer();

    SERVER_LOGS.info(
      '✅ OfflineQueueManager initialized with ${_operationQueue.length} queued operations',
    );
  }

  /// Add an operation to the queue
  Future<void> queueOperation({
    required OperationType type,
    required String endpoint,
    Map<String, dynamic>? data,
    Map<String, String>? headers,
  }) async {
    final operation = QueuedOperation(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: type,
      endpoint: endpoint,
      data: data,
      timestamp: DateTime.now(),
      headers: headers,
    );

    _operationQueue.add(operation);
    await _saveQueueToStorage();

    SERVER_LOGS.info('📝 Queued operation: $operation');
    _queueSizeController.add(_operationQueue.length);

    // Save failure notification
    await _saveFailureNotification(
      operation: operation,
      reason: 'Server unavailable - operation queued for retry',
    );

    // Show user notification
    _showOfflineNotification(operation);
  }

  /// Mark system as offline and show notification
  Future<void> markOffline(String reason) async {
    if (_isOnline) {
      _isOnline = false;
      _connectivityController.add(false);

      SERVER_LOGS.warning('📡 System marked as offline: $reason');

      // Show persistent offline notification
      EnhancedNotificationService().notifyError(
        'System Offline',
        'Operations will be queued until connection is restored',
      );

      await _saveFailureNotification(reason: reason, operation: null);
    }
  }

  /// [FIX:150725] Mark system as online and process queue
  Future<void> markOnline() async {
    // Set the state to true, regardless of what it was before.
    // [DEBUG-STEP-3] Add this log line at the very top
    SERVER_LOGS.debug(
      "[DEBUG-STEP-3] markOnline() called at ${DateTime.now()}",
    );
    _isOnline = true;
    _connectivityController.add(true);

    SERVER_LOGS.info(
      '📡 System is online - attempting to process any queued operations.',
    );

    // Show a notification that we're back online.
    EnhancedNotificationService().notifySuccess(
      'Connection Restored',
      'Processing any pending operations.',
    );

    // ALWAYS attempt to process the queue.
    await _processQueue();
  }

  /// Process all queued operations
  Future<void> _processQueue() async {
    // [DEBUG-STEP-4] Add this log line
    SERVER_LOGS.debug(
      "[DEBUG-STEP-4] _processQueue() called. State: isOnline=$_isOnline, isProcessing=$_isProcessing, queueSize=${_operationQueue.length}",
    );

    if (!_isOnline || _isProcessing || _operationQueue.isEmpty) return;

    _isProcessing = true;
    // [DEBUG-STEP-5] Add this log line
    SERVER_LOGS.debug(
      "[DEBUG-STEP-5] Guard clause passed. Starting loop to process operations.",
    );

    SERVER_LOGS.info(
      '🔄 Processing ${_operationQueue.length} queued operations',
    );

    final operationsToProcess = List<QueuedOperation>.from(_operationQueue);
    int successCount = 0;
    int failureCount = 0;

    for (final operation in operationsToProcess) {
      try {
        final success = await _executeOperation(operation);
        if (success) {
          _operationQueue.remove(operation);
          successCount++;
          SERVER_LOGS.info(
            '✅ Successfully processed operation: ${operation.id}',
          );
        } else {
          // Increment retry count
          final updatedOperation = operation.copyWith(
            retryCount: operation.retryCount + 1,
          );

          final index = _operationQueue.indexOf(operation);
          if (index != -1) {
            _operationQueue[index] = updatedOperation;
          }

          failureCount++;

          if (updatedOperation.retryCount >= _maxRetries) {
            _operationQueue.remove(operation);
            SERVER_LOGS.error(
              '❌ Operation ${operation.id} failed after $_maxRetries retries - removing from queue',
            );

            await _saveFailureNotification(
              operation: operation,
              reason: 'Operation failed after maximum retries',
            );
          }
        }
      } catch (e) {
        SERVER_LOGS.error('❌ Error processing operation ${operation.id}: $e');
        failureCount++;
      }
    }

    await _saveQueueToStorage();
    _queueSizeController.add(_operationQueue.length);

    SERVER_LOGS.info(
      '📊 Queue processing complete: $successCount successful, $failureCount failed',
    );

    // Show summary notification
    if (successCount > 0) {
      EnhancedNotificationService().notifySuccess(
        'Queue Processing Complete',
        'Processed $successCount queued operations',
      );
    }

    if (failureCount > 0) {
      EnhancedNotificationService().notifyWarning(
        'Operations Still Pending',
        '$failureCount operations still pending',
      );
    }

    _isProcessing = false;
  }

  /// Execute a single queued operation using the KioskApiService
  Future<bool> _executeOperation(QueuedOperation operation) async {
    // Get the KioskApiService instance and execute the operation
    try {
      return await kioskApiService.executeQueuedOperation(operation);
    } catch (e) {
      SERVER_LOGS.error('❌ Failed to execute queued operation: $e');
      return false;
    }
  }

  /// Save the operation queue to persistent storage
  Future<void> _saveQueueToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueJson = _operationQueue.map((op) => op.toJson()).toList();
      await prefs.setString(_queueKey, jsonEncode(queueJson));
      SERVER_LOGS.debug(
        '💾 Saved ${_operationQueue.length} operations to storage',
      );
    } catch (e) {
      SERVER_LOGS.error('❌ Error saving queue to storage: $e');
    }
  }

  /// Load the operation queue from persistent storage
  Future<void> _loadQueueFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueString = prefs.getString(_queueKey);

      if (queueString != null) {
        final queueJson = jsonDecode(queueString) as List;
        _operationQueue.clear();
        _operationQueue.addAll(
          queueJson.map((json) => QueuedOperation.fromJson(json)),
        );
        SERVER_LOGS.debug(
          '📂 Loaded ${_operationQueue.length} operations from storage',
        );
      }
    } catch (e) {
      SERVER_LOGS.error('❌ Error loading queue from storage: $e');
    }
  }

  /// Save failure notification
  Future<void> _saveFailureNotification({
    required String reason,
    QueuedOperation? operation,
  }) async {
    final notification = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'timestamp': DateTime.now().toIso8601String(),
      'reason': reason,
      'operation': operation?.toJson(),
    };

    _failureNotifications.add(notification);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _failureNotificationKey,
        jsonEncode(_failureNotifications),
      );
      SERVER_LOGS.debug('💾 Saved failure notification: $reason');
    } catch (e) {
      SERVER_LOGS.error('❌ Error saving failure notification: $e');
    }
  }

  /// Load failure notifications from storage
  Future<void> _loadFailureNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notificationsString = prefs.getString(_failureNotificationKey);

      if (notificationsString != null) {
        final notificationsJson = jsonDecode(notificationsString) as List;
        _failureNotifications.clear();
        _failureNotifications.addAll(
          notificationsJson.map((json) => Map<String, dynamic>.from(json)),
        );
        SERVER_LOGS.debug(
          '📂 Loaded ${_failureNotifications.length} failure notifications',
        );
      }
    } catch (e) {
      SERVER_LOGS.error('❌ Error loading failure notifications: $e');
    }
  }

  /// Clean operations older than the maximum age
  Future<void> _cleanOldOperations() async {
    final cutoffTime = DateTime.now().subtract(_maxQueueAge);
    final oldCount = _operationQueue.length;

    _operationQueue.removeWhere((op) => op.timestamp.isBefore(cutoffTime));

    if (_operationQueue.length < oldCount) {
      await _saveQueueToStorage();
      SERVER_LOGS.info(
        '🧹 Cleaned ${oldCount - _operationQueue.length} old operations from queue',
      );
    }
  }

  /// [FIX:150725] Start the retry timer
  void _startRetryTimer() {
    _retryTimer?.cancel();
    _retryTimer = Timer.periodic(_retryInterval, (timer) async {
      // Make it async
      // Check for items to avoid unnecessary work.
      // [DEBUG-STEP-1] Add this log line
      SERVER_LOGS.debug(
        "[DEBUG-STEP-1] Retry Timer Fired at ${DateTime.now()}",
      );
      if (_operationQueue.isNotEmpty && !_isProcessing) {
        SERVER_LOGS.debug(
          '⏰ Retry timer triggered - checking connection and attempting to process.',
        );

        // First, check for a real connection.
        final bool isConnected =
            await KioskApiService().connectivityService.isConnected();

        // [DEBUG-STEP-2] Add this log line
        SERVER_LOGS.debug(
          "[DEBUG-STEP-2] Network check result: isConnected = $isConnected",
        );

        // If connected, call markOnline() to ensure the state is correct
        // and the queue is processed.
        if (isConnected) {
          await markOnline();
        }
      }
    });
  }

  /// Show notification for offline operation
  void _showOfflineNotification(QueuedOperation operation) {
    String message;
    switch (operation.type) {
      case OperationType.post:
        message = 'Data saved offline - will sync when online';
        break;
      case OperationType.put:
        message = 'Update queued - will sync when online';
        break;
      case OperationType.delete:
        message = 'Delete queued - will sync when online';
        break;
      case OperationType.get:
        message = 'Request queued - will retry when online';
        break;
    }

    EnhancedNotificationService().notifyQueue('Operation Queued', message);
  }

  /// Get all failure notifications
  List<Map<String, dynamic>> getFailureNotifications() {
    return List<Map<String, dynamic>>.from(_failureNotifications);
  }

  /// Clear all failure notifications
  Future<void> clearFailureNotifications() async {
    _failureNotifications.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_failureNotificationKey);
      SERVER_LOGS.info('🧹 Cleared all failure notifications');
    } catch (e) {
      SERVER_LOGS.error('❌ Error clearing failure notifications: $e');
    }
  }

  /// Clear all queued operations
  Future<void> clearQueue() async {
    SERVER_LOGS.warning('⚠️ Clearing all queued operations');
    _operationQueue.clear();
    await _saveQueueToStorage();
    _queueSizeController.add(0);

    // Show notification
    EnhancedNotificationService().notifyWarning(
      'Queue Cleared',
      'All pending operations removed',
    );
  }

  /// Get queue statistics
  Map<String, dynamic> getQueueStats() {
    final stats = <OperationType, int>{};
    for (final op in _operationQueue) {
      stats[op.type] = (stats[op.type] ?? 0) + 1;
    }

    return {
      'total': _operationQueue.length,
      'byType': stats,
      'oldestOperation':
          _operationQueue.isNotEmpty
              ? _operationQueue
                  .map((op) => op.timestamp)
                  .reduce((a, b) => a.isBefore(b) ? a : b)
              : null,
      'isProcessing': _isProcessing,
      'isOnline': _isOnline,
    };
  }

  /// Dispose the manager
  void dispose() {
    _retryTimer?.cancel();
    _connectivityController.close();
    _queueSizeController.close();
    SERVER_LOGS.info('🔚 OfflineQueueManager disposed');
  }

  /// [080725] Enhanced persistence - force save queue immediately
  /// Call this before app termination or during critical operations
  Future<void> forceDataPersistence() async {
    SERVER_LOGS.info('💾 Forcing data persistence...');

    try {
      await _saveQueueToStorage();
      await _saveFailureNotificationsToStorage();

      SERVER_LOGS.info(
        '✅ Force persistence complete: ${_operationQueue.length} operations, ${_failureNotifications.length} notifications saved',
      );
    } catch (e) {
      SERVER_LOGS.error('❌ Force persistence failed: $e');
    }
  }

  /// [080725] Handle app lifecycle events
  /// Call this from your main app when lifecycle changes occur
  Future<void> handleAppLifecycleChange(AppLifecycleState state) async {
    switch (state) {
      case AppLifecycleState.paused:
        SERVER_LOGS.info('📱 App paused - saving queue data');
        await forceDataPersistence();
        break;
      case AppLifecycleState.resumed:
        SERVER_LOGS.info('📱 App resumed - reloading queue data');
        await _loadQueueFromStorage();
        await _loadFailureNotifications();
        break;
      case AppLifecycleState.detached:
        SERVER_LOGS.info('📱 App detached - final data save');
        await forceDataPersistence();
        _retryTimer?.cancel();
        break;
      default:
        break;
    }
  }

  /// [080725] Helper method to save failure notifications
  Future<void> _saveFailureNotificationsToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _failureNotificationKey,
        jsonEncode(_failureNotifications),
      );
      SERVER_LOGS.debug(
        '💾 Saved ${_failureNotifications.length} failure notifications',
      );
    } catch (e) {
      SERVER_LOGS.error('❌ Error saving failure notifications: $e');
    }
  }
}
