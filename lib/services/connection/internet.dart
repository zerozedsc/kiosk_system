import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';

export 'package:connectivity_plus/connectivity_plus.dart';

late InternetConnectionService internetConnectionService;

/// A service class to monitor and check internet connectivity.
///
/// This service uses the `connectivity_plus` package combined with real HTTP tests
/// to provide a reliable way to check actual internet access, not just network connectivity.
///
/// It is implemented as a singleton to ensure a single source of truth for
/// the app's connectivity state.
class InternetConnectionService {
  // Singleton instance
  static final InternetConnectionService _instance =
      InternetConnectionService._internal();

  factory InternetConnectionService() {
    return _instance;
  }

  InternetConnectionService._internal() {
    // Listen to connectivity changes and validate real internet access
    Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> result,
    ) async {
      // When connectivity changes, validate if we have real internet access
      final bool hasInternet = await _validateInternetAccess();
      _internetStreamController.add(hasInternet);
    });
  }

  // Stream controller to broadcast real internet connectivity changes
  final StreamController<bool> _internetStreamController =
      StreamController<bool>.broadcast();

  /// A stream that emits the REAL internet connectivity status whenever it changes.
  ///
  /// Unlike the raw connectivity stream, this validates actual internet access
  /// by attempting to reach reliable endpoints.
  ///
  /// Example:
  /// ```dart
  /// _internetSubscription = InternetConnectionService().onInternetChanged.listen((hasInternet) {
  ///   // Handle UI update with real internet status
  /// });
  /// ```
  Stream<bool> get onInternetChanged => _internetStreamController.stream;

  /// Legacy stream for connectivity changes (network only, not internet validation)
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      Connectivity().onConnectivityChanged;

  /// Checks the current internet connectivity status of the device.
  ///
  /// This method performs both network connectivity check AND real internet validation.
  /// Returns `true` only if the device has actual internet access.
  /// Returns `false` if the device is offline, in airplane mode, or connected to network without internet.
  ///
  /// This is useful for one-time checks, for example before making an API call.
  ///
  /// Example:
  /// ```dart
  /// bool isOnline = await InternetConnectionService().isConnected();
  /// if (isOnline) {
  ///   // Make API call
  /// } else {
  ///   // Show offline message
  /// }
  /// ```
  Future<bool> isConnected() async {
    // First check network connectivity
    final List<ConnectivityResult> result =
        await Connectivity().checkConnectivity();

    final bool hasNetworkConnection =
        result.contains(ConnectivityResult.mobile) ||
        result.contains(ConnectivityResult.wifi);

    if (!hasNetworkConnection) {
      return false;
    }

    // If we have network connection, validate real internet access
    return await _validateInternetAccess();
  }

  /// Legacy method for basic connectivity check (network only, no internet validation)
  /// @deprecated Use isConnected() instead for real internet validation
  Future<bool> hasNetworkConnection() async {
    final List<ConnectivityResult> result =
        await Connectivity().checkConnectivity();
    return result.contains(ConnectivityResult.mobile) ||
        result.contains(ConnectivityResult.wifi);
  }

  /// Validates real internet access by attempting to reach reliable endpoints
  Future<bool> _validateInternetAccess() async {
    try {
      // List of reliable endpoints to test
      final List<String> testUrls = [
        'https://www.google.com',
        'https://www.cloudflare.com',
        'https://1.1.1.1',
      ];

      // Try each endpoint with a short timeout
      for (String url in testUrls) {
        try {
          final HttpClient client = HttpClient();
          client.connectionTimeout = const Duration(seconds: 3);

          final HttpClientRequest request = await client.getUrl(Uri.parse(url));
          final HttpClientResponse response = await request.close();

          client.close();

          // If we get any response (even error), we have internet
          if (response.statusCode >= 200 && response.statusCode < 500) {
            return true;
          }
        } catch (e) {
          // Try next URL
          continue;
        }
      }

      return false;
    } catch (e) {
      // If all tests fail, assume no internet
      return false;
    }
  }

  /// Manually trigger an internet connectivity check and update the stream
  /// This is useful for initial app startup or when you want to force a recheck
  Future<void> checkAndUpdateStatus() async {
    final bool hasInternet = await isConnected();
    _internetStreamController.add(hasInternet);
  }

  /// Disposes the stream controller when it's no longer needed.
  ///
  /// Call this in your app's main dispose method if necessary, though as a
  /// singleton, it will typically live for the entire app lifecycle.
  void dispose() {
    _internetStreamController.close();
  }
}
