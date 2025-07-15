import '../../configs/configs.dart';
import 'package:http/http.dart' as http;
import 'offline_queue_manager.dart';
import 'package:intl/intl.dart';

import '../connection/internet.dart';

import 'model_server.dart';
export 'model_server.dart';

late KioskApiService kioskApiService;

/// [050725] InventoryUpdateData
class InventoryUpdateData {
  final int quantity;

  InventoryUpdateData({required this.quantity});

  Map<String, dynamic> toJson() => {'quantity': quantity};

  @override
  String toString() => 'InventoryUpdateData(quantity: $quantity)';
}

// [050725] Kiosk API Service
class KioskApiService {
  static const String baseUrl = const String.fromEnvironment('SERVER_API_URL');
  static const String startApiKey = const String.fromEnvironment(
    'START_API_KEY',
  );

  // Offline queue manager and connectivity service instances
  final OfflineQueueManager _queueManager = OfflineQueueManager();
  final InternetConnectionService _connectivityService =
      InternetConnectionService();

  /// Initialize the API service with offline queue management
  Future<void> initialize() async {
    SERVER_LOGS.info(
      '🚀 Initializing KioskApiService with offline queue support',
    );

    await _queueManager.initialize();

    // Listen for connectivity changes to mark the queue manager online/offline
    _connectivityService.onInternetChanged.listen((isOnline) {
      if (isOnline) {
        _queueManager.markOnline();
      } else {
        _queueManager.markOffline('Network connectivity lost');
      }
    });

    SERVER_LOGS.info('✅ KioskApiService initialized successfully');
  }

  // [Safely execute an API call with error handling and logging]
  /// Checks if the API is reachable and healthy.
  /// Throws [ApiException] if the health check fails.
  Future<void> checkApiHealth() async {
    SERVER_LOGS.info('🔍 Checking API health at $baseUrl/health');
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/health'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        SERVER_LOGS.error(
          '❌ API health check failed with status: ${response.statusCode}',
        );
        throw ApiException(
          'API health check failed with status: ${response.statusCode}',
          response.statusCode,
        );
      }

      SERVER_LOGS.info('✅ API health check passed');
    } catch (e) {
      if (e is ApiException) {
        SERVER_LOGS.error('❌ API health check failed: ${e.message}');
        rethrow;
      }
      SERVER_LOGS.error('❌ API is not reachable: $e');
      throw ApiException(
        'API is not reachable. Please check your network connection.',
        0,
      );
    }
  }

  /// Get stored kiosk key from secure storage
  Future<String?> _getKioskKey() async {
    SERVER_LOGS.debug('🔑 Retrieving kiosk key from secure storage');
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final key = prefs.getString('kiosk_key');
      if (key != null) {
        SERVER_LOGS.debug('✅ Kiosk key found in storage');
      } else {
        SERVER_LOGS.warning('⚠️ No kiosk key found in storage');
      }
      return key;
    } catch (e) {
      SERVER_LOGS.error('❌ Error retrieving kiosk key: $e');
      return null;
    }
  }

  /// Get stored kiosk ID from secure storage
  Future<String?> _getKioskId() async {
    SERVER_LOGS.debug('🆔 Retrieving kiosk ID from secure storage');
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final id = prefs.getString('kiosk_id');
      if (id != null) {
        SERVER_LOGS.debug('✅ Kiosk ID found in storage: $id');
      } else {
        SERVER_LOGS.warning('⚠️ No kiosk ID found in storage');
      }
      return id;
    } catch (e) {
      SERVER_LOGS.error('❌ Error retrieving kiosk ID: $e');
      return null;
    }
  }

  // [CRUD Operations]
  /// Get headers with authentication
  Future<Map<String, String>> _getHeaders() async {
    // Get kiosk key from globalAppConfig first, then fall back to SharedPreferences
    String? kioskKey = globalAppConfig["kiosk_info"]?["kiosk_key"];

    if (kioskKey == null || kioskKey.isEmpty || kioskKey == "KEY") {
      // Fall back to SharedPreferences if not in config or is default value
      kioskKey = await _getKioskKey();
    }

    if (kioskKey == null || kioskKey.isEmpty) {
      throw ApiException(
        'Kiosk key not found. Please register the kiosk first.',
        401,
      );
    }

    final headers = {
      'Content-Type': 'application/json',
      'X-Kiosk-Key': kioskKey,
    };
    SERVER_LOGS.debug('📄 Generated headers with kiosk key: ✅');
    return headers;
  }

  /// Generic GET request for lists
  Future<List<Map<String, dynamic>>> _getList(String endpoint) async {
    SERVER_LOGS.info('📊 Getting list from endpoint: $endpoint');
    await checkApiHealth();

    try {
      final response = await http
          .get(Uri.parse('$baseUrl/$endpoint'), headers: await _getHeaders())
          .timeout(const Duration(seconds: 10));

      SERVER_LOGS.debug(
        '📥 GET $endpoint response status: ${response.statusCode}',
      );

      if (response.statusCode == 200) {
        final data = List<Map<String, dynamic>>.from(jsonDecode(response.body));
        SERVER_LOGS.info(
          '✅ Successfully retrieved ${data.length} items from $endpoint',
        );
        return data;
      } else {
        SERVER_LOGS.error(
          '❌ Failed to load $endpoint with status: ${response.statusCode}',
        );
        throw ApiException('Failed to load $endpoint', response.statusCode);
      }
    } catch (e) {
      SERVER_LOGS.error('❌ Error getting list from $endpoint: $e');
      if (e is ApiException) rethrow;
      throw ApiException('Network error loading $endpoint', 0);
    }
  }

  /// Generic POST request
  Future<Map<String, dynamic>> _post(
    String endpoint,
    Map<String, dynamic> data,
  ) async {
    SERVER_LOGS.info('📤 Posting to endpoint: $endpoint');
    await checkApiHealth();

    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/$endpoint'),
            headers: await _getHeaders(),
            body: jsonEncode(data),
          )
          .timeout(const Duration(seconds: 15));

      SERVER_LOGS.debug(
        '📥 POST $endpoint response status: ${response.statusCode}',
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        SERVER_LOGS.info('✅ Successfully created resource at $endpoint');
        return responseData;
      } else {
        SERVER_LOGS.error(
          '❌ Failed to create resource at $endpoint with status: ${response.statusCode}',
        );
        SERVER_LOGS.error('Response body: ${response.body}');
        throw ApiException(
          'Failed to create resource at $endpoint',
          response.statusCode,
        );
      }
    } catch (e) {
      SERVER_LOGS.error('❌ Error posting to $endpoint: $e');
      if (e is ApiException) rethrow;
      throw ApiException('Network error creating resource at $endpoint', 0);
    }
  }

  /// Generic PUT request
  Future<Map<String, dynamic>> _put(
    String endpoint,
    Map<String, dynamic> data,
  ) async {
    SERVER_LOGS.info('🔄 Updating endpoint: $endpoint');
    SERVER_LOGS.debug('Update data: ${jsonEncode(data)}');
    await checkApiHealth();

    try {
      final response = await http
          .put(
            Uri.parse('$baseUrl/$endpoint'),
            headers: await _getHeaders(),
            body: jsonEncode(data),
          )
          .timeout(const Duration(seconds: 15));

      SERVER_LOGS.debug(
        '📥 PUT $endpoint response status: ${response.statusCode}',
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        SERVER_LOGS.info('✅ Successfully updated resource at $endpoint');
        return responseData;
      } else {
        SERVER_LOGS.error(
          '❌ Failed to update resource at $endpoint with status: ${response.statusCode}',
        );
        SERVER_LOGS.error('Response body: ${response.body}');
        throw ApiException(
          'Failed to update resource at $endpoint',
          response.statusCode,
        );
      }
    } catch (e) {
      SERVER_LOGS.error('❌ Error updating $endpoint: $e');
      if (e is ApiException) rethrow;
      throw ApiException('Network error updating resource at $endpoint', 0);
    }
  }

  /// Generic GET request for single item
  Future<Map<String, dynamic>> _getSingle(String endpoint) async {
    SERVER_LOGS.info('📄 Getting single item from endpoint: $endpoint');
    await checkApiHealth();

    try {
      final response = await http
          .get(Uri.parse('$baseUrl/$endpoint'), headers: await _getHeaders())
          .timeout(const Duration(seconds: 10));

      SERVER_LOGS.debug(
        '📥 GET $endpoint response status: ${response.statusCode}',
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        SERVER_LOGS.info('✅ Successfully retrieved item from $endpoint');
        return data;
      } else {
        SERVER_LOGS.error(
          '❌ Failed to load $endpoint with status: ${response.statusCode}',
        );
        throw ApiException('Failed to load $endpoint', response.statusCode);
      }
    } catch (e) {
      SERVER_LOGS.error('❌ Error getting single item from $endpoint: $e');
      if (e is ApiException) rethrow;
      throw ApiException('Network error loading $endpoint', 0);
    }
  }

  /// Generic DELETE request
  Future<void> _delete(String endpoint) async {
    SERVER_LOGS.info('🗑️ Deleting from endpoint: $endpoint');
    await checkApiHealth();

    try {
      final response = await http
          .delete(Uri.parse('$baseUrl/$endpoint'), headers: await _getHeaders())
          .timeout(const Duration(seconds: 10));

      SERVER_LOGS.debug(
        '📥 DELETE $endpoint response status: ${response.statusCode}',
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        SERVER_LOGS.info('✅ Successfully deleted resource at $endpoint');
      } else {
        SERVER_LOGS.error(
          '❌ Failed to delete $endpoint with status: ${response.statusCode}',
        );
        throw ApiException('Failed to delete $endpoint', response.statusCode);
      }
    } catch (e) {
      SERVER_LOGS.error('❌ Error deleting $endpoint: $e');
      if (e is ApiException) rethrow;
      throw ApiException('Network error deleting $endpoint', 0);
    }
  }

  // [API methods]
  /// Validates the provided admin password against the server.
  ///
  /// This is useful for unlocking admin-only features in the UI.
  ///
  /// Parameters:
  /// - [password]: The admin password to check.
  ///
  /// Returns: `true` if the password is correct, `false` otherwise.
  ///
  /// Throws: [ApiException] if the API health check fails or a network error occurs.
  Future<bool> checkAdminPassword(String password) async {
    SERVER_LOGS.info('🔐 Checking admin password');
    await checkApiHealth();

    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/check_admin'),
            headers: await _getHeaders(),
            body: jsonEncode({'password': password}),
          )
          .timeout(const Duration(seconds: 10));

      SERVER_LOGS.debug(
        '📥 Admin password check response status: ${response.statusCode}',
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final isValid = data['success'] == true;
        SERVER_LOGS.info(
          '✅ Admin password check result: ${isValid ? "Valid" : "Invalid"}',
        );
        return isValid;
      } else {
        SERVER_LOGS.warning(
          '⚠️ Admin password check failed with status: ${response.statusCode}',
        );
        return false;
      }
    } catch (e) {
      SERVER_LOGS.error('❌ Error checking admin password: $e');
      return false;
    }
  }

  /// Test connectivity to the API server
  Future<bool> testConnection() async {
    SERVER_LOGS.info('🔌 Testing API connection');
    try {
      await checkApiHealth();
      SERVER_LOGS.info('✅ API connection test passed');
      return true;
    } catch (e) {
      SERVER_LOGS.error('❌ API connection test failed: $e');
      return false;
    }
  }

  /// Enhanced error handling with detailed logging
  Future<dynamic> handleApiResponse(http.Response response) async {
    SERVER_LOGS.debug(
      '🔍 Handling API response with status: ${response.statusCode}',
    );

    switch (response.statusCode) {
      case 200:
      case 201:
        SERVER_LOGS.info('✅ API request successful');
        return jsonDecode(response.body);
      case 401:
        SERVER_LOGS.error('🔐 Authentication failed. Check kiosk key.');
        throw ApiException('Authentication failed. Check kiosk key.', 401);
      case 404:
        SERVER_LOGS.error('🔍 Resource not found.');
        throw ApiException('Resource not found.', 404);
      case 500:
        SERVER_LOGS.error('💥 Server error. Please try again.');
        throw ApiException('Server error. Please try again.', 500);
      default:
        SERVER_LOGS.error(
          '❓ Unknown error occurred with status: ${response.statusCode}',
        );
        throw ApiException('Unknown error occurred.', response.statusCode);
    }
  }

  // __ [Kiosk Management]
  /// Clear all stored kiosk credentials
  Future<void> clearCredentials() async {
    SERVER_LOGS.info('🧹 Clearing stored kiosk credentials');
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove('kiosk_key');
      await prefs.remove('kiosk_id');
      SERVER_LOGS.info('✅ Kiosk credentials cleared successfully');
    } catch (e) {
      SERVER_LOGS.error('❌ Error clearing credentials: $e');
    }
  }

  /// Get the stored kiosk ID for use in other operations.
  ///
  /// Returns: The stored kiosk ID string, or null if not found
  Future<String?> getStoredKioskId() {
    SERVER_LOGS.debug('🆔 Getting stored kiosk ID');
    return _getKioskId();
  }

  /// Get the stored kiosk key for use in other operations.
  ///
  /// Returns: The stored kiosk key string, or null if not found
  Future<String?> getStoredKioskKey() {
    SERVER_LOGS.debug('🔑 Getting stored kiosk key');
    return _getKioskKey();
  }

  /// Create a new kiosk.
  ///
  /// Parameters:
  /// - [kioskData]: KioskData object containing name, location, and optional description
  ///
  /// Example:
  /// ```dart
  /// final kiosk = KioskData(
  ///   name: 'Main Store Kiosk',
  ///   location: 'Store Front',
  ///   description: 'Customer service kiosk',
  /// );
  /// await apiService.createKiosk(kiosk);
  /// ```
  ///
  /// Returns: Created kiosk data with assigned ID
  ///
  /// Throws: [ApiException] if creation fails
  Future<Map<String, dynamic>> createKiosk(KioskData kioskData) {
    SERVER_LOGS.info('➕ Creating new kiosk: $kioskData');
    return _post('kiosks', kioskData.toJson());
  }

  /// Register a new kiosk with the server.
  ///
  /// Parameters:
  /// - [name]: Name of the kiosk
  /// - [location]: Physical location of the kiosk
  /// - [description]: Optional description for the kiosk
  ///
  /// Returns: A map containing both 'kiosk_key' and 'kiosk_id' that should be stored securely
  ///
  /// Throws: [ApiException] if registration fails
  Future<Map<String, String>> registerKiosk({
    required String name,
    required String location,
    String? description,
  }) async {
    SERVER_LOGS.info('📝 Registering kiosk: $name at $location');
    await checkApiHealth();

    final requestBody = {
      'start_api_key': startApiKey,
      'name': name,
      'location': location,
      'description': description ?? 'Mobile kiosk application',
    };

    SERVER_LOGS.debug(
      '📤 Registration request body: ${jsonEncode(requestBody)}',
    );

    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/kiosks/register'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 15));

      SERVER_LOGS.debug(
        '📥 Registration response status: ${response.statusCode}',
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final kioskId = data['kiosk']['kiosk_id'];
        final kioskKey = data['kiosk_key'];

        SERVER_LOGS.info('✅ Kiosk registered successfully with ID: $kioskId');
        SERVER_LOGS.debug('🔑 Storing kiosk credentials securely');

        // Store both the key and ID
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('kiosk_key', kioskKey);
        await prefs.setString('kiosk_id', kioskId);

        SERVER_LOGS.info('💾 Kiosk credentials stored successfully');
        return {'kiosk_key': kioskKey, 'kiosk_id': kioskId};
      } else {
        SERVER_LOGS.error(
          '❌ Kiosk registration failed with status: ${response.statusCode}',
        );
        SERVER_LOGS.error('Response body: ${response.body}');
        throw ApiException('Failed to register kiosk', response.statusCode);
      }
    } catch (e) {
      SERVER_LOGS.error('❌ Error during kiosk registration: $e');
      if (e is ApiException) rethrow;
      throw ApiException('Network error during registration', 0);
    }
  }

  /// Register a new kiosk with the server including password support.
  ///
  /// Parameters:
  /// - [name]: Name of the kiosk
  /// - [location]: Physical location of the kiosk
  /// - [password]: SHA-256 hashed password for kiosk admin authentication
  /// - [description]: Optional description for the kiosk
  ///
  /// Returns: A map containing both 'kiosk_key' and 'kiosk_id' that should be stored securely
  ///
  /// Throws: [ApiException] if registration fails
  Future<Map<String, String>> registerKioskWithPassword({
    required String name,
    required String location,
    required String password,
    String? description,
  }) async {
    SERVER_LOGS.info('📝 Registering kiosk with password: $name at $location');
    await checkApiHealth();

    final requestBody = {
      'start_api_key': startApiKey,
      'name': name,
      'location': location,
      'password': password, // Include password hash for server
      'description': description ?? 'Mobile kiosk application',
    };

    SERVER_LOGS.debug(
      '📤 Registration request body: ${jsonEncode(requestBody)}',
    );

    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/kiosks/register'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 15));

      SERVER_LOGS.debug(
        '📥 Registration response status: ${response.statusCode}',
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final kioskId = data['kiosk']['kiosk_id'];
        final kioskKey = data['kiosk_key'];

        SERVER_LOGS.info('✅ Kiosk registered successfully with ID: $kioskId');
        SERVER_LOGS.debug('🔑 Storing kiosk credentials securely');

        // Store both the key and ID
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('kiosk_key', kioskKey);
        await prefs.setString('kiosk_id', kioskId);

        SERVER_LOGS.info('💾 Kiosk credentials stored successfully');
        return {'kiosk_key': kioskKey, 'kiosk_id': kioskId};
      } else {
        SERVER_LOGS.error(
          '❌ Kiosk registration failed with status: ${response.statusCode}',
        );
        SERVER_LOGS.error('Response body: ${response.body}');
        throw ApiException('Failed to register kiosk', response.statusCode);
      }
    } catch (e) {
      SERVER_LOGS.error('❌ Error during kiosk registration: $e');
      if (e is ApiException) rethrow;
      throw ApiException('Network error during registration', 0);
    }
  }

  /// Get all kiosks from the server.
  ///
  /// Returns: List of kiosk data containing id, name, location, description, etc.
  ///
  /// Throws: [ApiException] if the request fails
  Future<List<Map<String, dynamic>>> getKiosks() {
    SERVER_LOGS.info('🏪 Getting all kiosks');
    return _getList('kiosks');
  }

  /// Get a specific kiosk by its ID.
  ///
  /// Parameters:
  /// - [kioskId]: The string ID of the kiosk (e.g., "aBc123XyZ01")
  ///
  /// Returns: Kiosk data containing id, name, location, description, etc.
  ///
  /// Throws: [ApiException] if the request fails
  Future<Map<String, dynamic>> getKiosk(String kioskId) {
    SERVER_LOGS.info('🏪 Getting kiosk details for ID: $kioskId');
    return _getSingle('kiosks/$kioskId');
  }

  /// Update a specific kiosk.
  ///
  /// Parameters:
  /// - [kioskId]: The string ID of the kiosk to update
  /// - [kioskData]: KioskData object containing updated information
  ///
  /// Returns: Updated kiosk data
  ///
  /// Throws: [ApiException] if update fails
  Future<Map<String, dynamic>> updateKiosk(
    String kioskId,
    KioskData kioskData,
  ) {
    SERVER_LOGS.info('🔄 Updating kiosk: $kioskId with data: $kioskData');
    return _safeApiCall(
      operationType: OperationType.put,
      endpoint: 'kiosks/$kioskId',
      data: kioskData.toJson(),
      apiCall: () => _put('kiosks/$kioskId', kioskData.toJson()),
    );
  }

  /// Delete a specific kiosk.
  ///
  /// Parameters:
  /// - [kioskId]: The string ID of the kiosk to delete
  ///
  /// Throws: [ApiException] if deletion fails
  Future<void> deleteKiosk(String kioskId) {
    SERVER_LOGS.info('🗑️ Deleting kiosk: $kioskId');
    return _safeApiCall(
      operationType: OperationType.delete,
      endpoint: 'kiosks/$kioskId',
      apiCall: () => _delete('kiosks/$kioskId'),
    );
  }

  /// [FIX:140725] Create a new kiosk transaction record.
  ///
  /// Parameters:
  /// - [transactionData]: TransactionData object containing product_id, quantity, total, and optional employee_id
  ///
  /// Example:
  /// ```dart
  /// final transaction = TransactionData(
  ///   productId: 1,
  ///   quantity: 2,
  ///   total: 5.00,
  ///   employeeId: 1,
  /// );
  /// await apiService.createTransaction(transaction);
  /// ```
  ///
  /// Returns: Created transaction data with assigned ID and timestamp
  ///
  /// Throws: [ApiException] if creation fails
  Future<Map<String, dynamic>> createKioskTransaction(
    KioskTransactionData transactionData,
  ) {
    SERVER_LOGS.info('➕ Creating new transaction: $transactionData');
    return _safeApiCall(
      operationType: OperationType.post,
      endpoint: 'kiosk-transactions',
      data: transactionData.toJson(),
      apiCall: () => _post('kiosk-transactions', transactionData.toJson()),
    );
  }

  /// Get all kiosk transactions from the server.
  ///
  /// Returns: List of transaction data containing id, product_id, quantity, total, employee_id, timestamp, etc.
  ///
  /// Throws: [ApiException] if the request fails
  Future<List<Map<String, dynamic>>> getKioskTransactions() {
    SERVER_LOGS.info('💳 Getting all transactions');
    return _safeApiCall(
      operationType: OperationType.get,
      endpoint: 'kiosk-transactions',
      apiCall: () => _getList('kiosk-transactions'),
    );
  }

  // __ [Product & Set Management]
  /// Add a new product to the system.
  ///
  /// Parameters:
  /// - [productData]: ProductData object containing name, price, and optional description/category
  ///
  /// Example:
  /// ```dart
  /// final product = ProductData(
  ///   name: 'Coffee',
  ///   price: 2.50,
  ///   description: 'Hot brewed coffee',
  ///   category: 'Beverages',
  /// );
  /// await apiService.addProduct(product);
  /// ```
  ///
  /// Returns: Created product data with assigned ID
  ///
  /// Throws: [ApiException] if creation fails
  Future<Map<String, dynamic>> addProduct(ProductData productData) {
    SERVER_LOGS.info('➕ Adding new product: $productData');
    return _safeApiCall(
      operationType: OperationType.post,
      endpoint: 'products',
      data: productData.toJson(),
      apiCall: () => _post('products', productData.toJson()),
    );
  }

  /// Get all products from the server.
  ///
  /// Returns: List of product data containing id, name, price, description, category, etc.
  ///
  /// Throws: [ApiException] if the request fails
  Future<List<Map<String, dynamic>>> getProducts() {
    SERVER_LOGS.info('🛍️ Getting all products');
    return _safeApiCall(
      operationType: OperationType.get,
      endpoint: 'products',
      apiCall: () => _getList('products'),
    );
  }

  /// Create a new discount.
  ///
  /// Parameters:
  /// - [discountData]: DiscountData object containing name, percentage, and optional description/validity dates
  ///
  /// Example:
  /// ```dart
  /// final discount = DiscountData(
  ///   name: 'Student Discount',
  ///   percentage: 10.0,
  ///   description: '10% off for students',
  ///   validFrom: DateTime.now(),
  ///   validTo: DateTime.now().add(Duration(days: 30)),
  /// );
  /// await apiService.createDiscount(discount);
  /// ```
  ///
  /// Returns: Created discount data with assigned ID
  ///
  /// Throws: [ApiException] if creation fails
  Future<Map<String, dynamic>> createDiscount(DiscountData discountData) {
    SERVER_LOGS.info('➕ Creating new discount: $discountData');
    return _post('discounts', discountData.toJson());
  }

  /// Get all discounts from the server.
  ///
  /// Returns: List of discount data containing id, name, percentage, description, valid_from, valid_to, etc.
  ///
  /// Throws: [ApiException] if the request fails
  Future<List<Map<String, dynamic>>> getDiscounts() {
    SERVER_LOGS.info('🎫 Getting all discounts');
    return _safeApiCall(
      operationType: OperationType.get,
      endpoint: 'discounts',
      apiCall: () => _getList('discounts'),
    );
  }

  /// Get the direct image URL for a product.
  ///
  /// Parameters:
  /// - [productId]: The ID of the product
  ///
  /// Returns: Complete URL string for the product image
  ///
  /// Example:
  /// ```dart
  /// Image.network(
  ///   apiService.getProductImageUrl(1),
  ///   headers: await apiService._getHeaders(),
  /// )
  /// ```
  String getProductImageUrl(int productId) {
    final url = '$baseUrl/products/$productId/image';
    SERVER_LOGS.debug('🖼️ Generated product image URL: $url');
    return url;
  }

  /// Get the direct image URL for a set.
  ///
  /// Parameters:
  /// - [setId]: The ID of the set
  ///
  /// Returns: Complete URL string for the set image
  String getSetImageUrl(int setId) {
    final url = '$baseUrl/sets/$setId/image';
    SERVER_LOGS.debug('🖼️ Generated set image URL: $url');
    return url;
  }

  // __ [Employee Management]
  /// Get all employees from the server.
  ///
  /// Returns: List of employee data containing id, name, username, age, position, etc.
  ///
  /// Throws: [ApiException] if the request fails
  Future<List<Map<String, dynamic>>> getEmployees() {
    SERVER_LOGS.info('👥 Getting all employees');
    return _safeApiCall(
      operationType: OperationType.get,
      endpoint: 'employees',
      apiCall: () => _getList('employees'),
    );
  }

  /// Update an existing employee in the system.
  ///
  /// Parameters:
  /// - [username]: The username of the employee to update (e.g., 'RZEMP0001')
  /// - [employeeData]: EmployeeData object containing updated information
  ///
  /// Example:
  /// ```dart
  /// final updatedEmployee = EmployeeData(
  ///   kioskId: 'your-kiosk-id',
  ///   username: 'RZEMP0001',
  ///   name: 'John Doe Updated',
  ///   age: 26,
  ///   password: 'new_hashed_password',
  ///   exist: true,
  ///   isAdmin: false,
  ///   address: '456 New St',
  ///   phoneNumber: '555-5678',
  ///   email: 'john.updated@example.com',
  ///   description: 'Senior cashier - updated',
  ///   image: updatedImageBytes,
  /// );
  /// await apiService.updateEmployee('RZEMP0001', updatedEmployee);
  /// ```
  ///
  /// Returns: Updated employee data
  ///
  /// Throws: [ApiException] if update fails
  Future<Map<String, dynamic>> updateEmployee(
    String username,
    EmployeeData employeeData,
  ) {
    SERVER_LOGS.info(
      '🔄 Updating employee: $username with data: $employeeData',
    );
    return _safeApiCall(
      operationType: OperationType.put,
      endpoint: 'employees/$username',
      data: employeeData.toJson(),
      apiCall: () => _put('employees/$username', employeeData.toJson()),
    );
  }

  /// Add a new employee to the system.
  ///
  /// Parameters:
  /// - [employeeData]: EmployeeData object containing name, username, age, and optional position
  ///
  /// Example:
  /// ```dart
  /// final employee = EmployeeData(
  ///   kioskId: 'your-kiosk-id',
  ///   username: 'johndoe',
  ///   name: 'John Doe',
  ///   age: 25,
  ///   password: 'hashed_password',
  ///   exist: true,
  ///   isAdmin: false,
  ///   // Optional fields:
  ///   // address: '123 Main St',
  ///   // phoneNumber: '555-1234',
  ///   // email: 'john@example.com',
  ///   // description: 'Senior cashier',
  ///   // image: yourImageBytes,
  ///   // createdAt: DateTime.now(),
  /// );
  /// ```
  /// await apiService.addEmployee(employee);
  /// ```
  ///
  /// Returns: Created employee data with assigned ID
  ///
  /// Throws: [ApiException] if creation fails
  Future<Map<String, dynamic>> addEmployee(EmployeeData employeeData) {
    SERVER_LOGS.info('➕ Adding new employee: $employeeData');
    return _safeApiCall(
      operationType: OperationType.post,
      endpoint: 'employees',
      data: employeeData.toJson(),
      apiCall: () => _post('employees', employeeData.toJson()),
    );
  }

  /// Create a new attendance record.
  ///
  /// Parameters:
  /// - [attendanceData]: AttendanceData object containing employee_id, check_in time, and optional check_out/notes
  ///
  /// Example:
  /// ```dart
  /// final attendance = AttendanceData(
  ///   employeeId: 1,
  ///   checkIn: DateTime.now(),
  ///   notes: 'Regular shift',
  /// );
  /// await apiService.createAttendance(attendance);
  /// ```
  ///
  /// Returns: Created attendance data with assigned ID
  ///
  /// Throws: [ApiException] if creation fails
  Future<Map<String, dynamic>> createAttendance(AttendanceData attendanceData) {
    SERVER_LOGS.info('➕ Creating new attendance: $attendanceData');
    return _safeApiCall(
      operationType: OperationType.post,
      endpoint: 'attendances',
      data: attendanceData.toJson(),
      apiCall: () => _post('attendances', attendanceData.toJson()),
    );
  }

  /// Get all attendance records from the server.
  ///
  /// Returns: List of attendance data containing id, employee_id, check_in, check_out, notes, etc.
  ///
  /// Throws: [ApiException] if the request fails
  Future<List<Map<String, dynamic>>> getAttendances() {
    SERVER_LOGS.info('📅 Getting all attendance records');
    return _safeApiCall(
      operationType: OperationType.get,
      endpoint: 'attendances',
      apiCall: () => _getList('attendances'),
    );
  }

  /// Get the direct image URL for an employee.
  ///
  /// Parameters:
  /// - [username]: The username of the employee (e.g., 'RZEMP0001')
  ///
  /// Returns: Complete URL string for the employee image
  String getEmployeeImageUrl(String username) {
    final url = '$baseUrl/employees/$username/image';
    SERVER_LOGS.debug('🖼️ Generated employee image URL: $url');
    return url;
  }

  /// Get a specific employee by username.
  ///
  /// Parameters:
  /// - [username]: The username of the employee to retrieve (e.g., 'RZEMP0001')
  ///
  /// Example:
  /// ```dart
  /// final employee = await apiService.getEmployee('RZEMP0001');
  /// ```
  ///
  /// Returns: Employee data or null if not found
  ///
  /// Throws: [ApiException] if the request fails
  Future<Map<String, dynamic>?> getEmployee(String username) {
    SERVER_LOGS.info('👤 Getting employee: $username');
    return _safeApiCall(
      operationType: OperationType.get,
      endpoint: 'employees/$username',
      apiCall: () => _getSingle('employees/$username'),
    );
  }

  /// Delete an employee from the system.
  ///
  /// Parameters:
  /// - [username]: The username of the employee to delete (e.g., 'RZEMP0001')
  ///
  /// Example:
  /// ```dart
  /// await apiService.deleteEmployee('RZEMP0001');
  /// ```
  ///
  /// Returns: true if deletion was successful
  ///
  /// Throws: [ApiException] if deletion fails
  Future<bool> deleteEmployee(String username) async {
    SERVER_LOGS.info('🗑️ Deleting employee: $username');
    try {
      await _safeApiCall(
        operationType: OperationType.delete,
        endpoint: 'employees/$username',
        apiCall: () => _delete('employees/$username'),
      );
      return true;
    } catch (e) {
      SERVER_LOGS.error('Failed to delete employee $username: $e');
      return false;
    }
  }

  /// Upload an employee image using base64 encoding.
  ///
  /// Parameters:
  /// - [username]: The username of the employee (e.g., 'RZEMP0001')
  /// - [imageFile]: The image file to upload
  ///
  /// Example:
  /// ```dart
  /// final success = await apiService.uploadEmployeeImage('RZEMP0001', imageFile);
  /// ```
  ///
  /// Returns: true if upload was successful
  ///
  /// Throws: [ApiException] if upload fails
  Future<bool> uploadEmployeeImage(String username, File imageFile) async {
    SERVER_LOGS.info('📸 Uploading image for employee: $username');
    try {
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);

      await _safeApiCall(
        operationType: OperationType.post,
        endpoint: 'employees/$username/image',
        data: {'image': base64Image},
        apiCall:
            () => _post('employees/$username/image', {'image': base64Image}),
      );
      return true;
    } catch (e) {
      SERVER_LOGS.error('Failed to upload image for employee $username: $e');
      return false;
    }
  }

  /// Delete an employee image.
  ///
  /// Parameters:
  /// - [username]: The username of the employee (e.g., 'RZEMP0001')
  ///
  /// Example:
  /// ```dart
  /// await apiService.deleteEmployeeImage('RZEMP0001');
  /// ```
  ///
  /// Returns: true if deletion was successful
  ///
  /// Throws: [ApiException] if deletion fails
  Future<bool> deleteEmployeeImage(String username) async {
    SERVER_LOGS.info('🗑️ Deleting image for employee: $username');
    try {
      await _safeApiCall(
        operationType: OperationType.delete,
        endpoint: 'employees/$username/image',
        apiCall: () => _delete('employees/$username/image'),
      );
      return true;
    } catch (e) {
      SERVER_LOGS.error('Failed to delete image for employee $username: $e');
      return false;
    }
  }

  /// Get a specific attendance record by ID.
  ///
  /// Parameters:
  /// - [id]: The ID of the attendance record to retrieve
  ///
  /// Example:
  /// ```dart
  /// final attendance = await apiService.getAttendance(1);
  /// ```
  ///
  /// Returns: Attendance record data or null if not found
  ///
  /// Throws: [ApiException] if the request fails
  Future<Map<String, dynamic>?> getAttendance(int id) {
    SERVER_LOGS.info('📅 Getting attendance record: $id');
    return _safeApiCall(
      operationType: OperationType.get,
      endpoint: 'attendances/$id',
      apiCall: () => _getSingle('attendances/$id'),
    );
  }

  /// Get attendance record for a specific employee on a specific date.
  ///
  /// Parameters:
  /// - [username]: The username of the employee (e.g., 'RZEMP0001')
  /// - [date]: The date in YYYY-MM-DD format (e.g., '2025-01-15')
  ///
  /// Example:
  /// ```dart
  /// final attendance = await apiService.getAttendanceByDate('RZEMP0001', '2025-01-15');
  /// ```
  ///
  /// Returns: Attendance record data for the specified date, or null if not found
  ///
  /// Throws: [ApiException] if the request fails
  Future<Map<String, dynamic>?> getAttendanceByDate(
    String username,
    String date,
  ) {
    SERVER_LOGS.info(
      '📅 Getting attendance for employee: $username on date: $date',
    );
    return _safeApiCall(
      operationType: OperationType.get,
      endpoint: 'attendances/$username/$date',
      apiCall: () => _getSingle('attendances/$username/$date'),
    );
  }

  /// Update an existing attendance record.
  ///
  /// Parameters:
  /// - [id]: The ID of the attendance record to update
  /// - [attendanceData]: AttendanceData object with updated information
  ///
  /// Example:
  /// ```dart
  /// final updatedAttendance = AttendanceData(
  ///   employeeId: 1,
  ///   checkIn: DateTime.now().subtract(Duration(hours: 8)),
  ///   checkOut: DateTime.now(),
  ///   notes: 'Updated shift end time',
  /// );
  /// await apiService.updateAttendance(1, updatedAttendance);
  /// ```
  ///
  /// Returns: Updated attendance data
  ///
  /// Throws: [ApiException] if update fails
  Future<Map<String, dynamic>> updateAttendance(
    int id,
    AttendanceData attendanceData,
  ) {
    SERVER_LOGS.info('✏️ Updating attendance record: $id');
    return _safeApiCall(
      operationType: OperationType.put,
      endpoint: 'attendances/$id',
      data: attendanceData.toJson(),
      apiCall: () => _put('attendances/$id', attendanceData.toJson()),
    );
  }

  /// Delete an attendance record from the system.
  ///
  /// Parameters:
  /// - [id]: The ID of the attendance record to delete
  ///
  /// Example:
  /// ```dart
  /// await apiService.deleteAttendance(1);
  /// ```
  ///
  /// Returns: true if deletion was successful
  ///
  /// Throws: [ApiException] if deletion fails
  Future<bool> deleteAttendance(int id) async {
    SERVER_LOGS.info('🗑️ Deleting attendance record: $id');
    try {
      await _safeApiCall(
        operationType: OperationType.delete,
        endpoint: 'attendances/$id',
        apiCall: () => _delete('attendances/$id'),
      );
      return true;
    } catch (e) {
      SERVER_LOGS.error('Failed to delete attendance record $id: $e');
      return false;
    }
  }

  /// Delete attendance record for a specific employee on a specific date.
  ///
  /// Parameters:
  /// - [username]: The username of the employee (e.g., 'RZEMP0001')
  /// - [date]: The date in YYYY-MM-DD format (e.g., '2025-01-15')
  ///
  /// Example:
  /// ```dart
  /// await apiService.deleteAttendanceByDate('RZEMP0001', '2025-01-15');
  /// ```
  ///
  /// Returns: true if deletion was successful
  ///
  /// Throws: [ApiException] if deletion fails
  Future<bool> deleteAttendanceByDate(String username, String date) async {
    SERVER_LOGS.info(
      '🗑️ Deleting attendance for employee: $username on date: $date',
    );
    try {
      await _safeApiCall(
        operationType: OperationType.delete,
        endpoint: 'attendances/$username/$date',
        apiCall: () => _delete('attendances/$username/$date'),
      );
      return true;
    } catch (e) {
      SERVER_LOGS.error(
        'Failed to delete attendance for employee $username on date $date: $e',
      );
      return false;
    }
  }

  /// Clock in an employee.
  ///
  /// Parameters:
  /// - [username]: The username of the employee to clock in (e.g., 'RZEMP0001')
  ///
  /// Example:
  /// ```dart
  /// final clockInResult = await apiService.clockInEmployee('RZEMP0001');
  /// ```
  ///
  /// Returns: Clock-in result data including attendance record
  ///
  /// Throws: [ApiException] if clock-in fails
  Future<Map<String, dynamic>> clockInEmployee(String username) {
    SERVER_LOGS.info('🕐 Clocking in employee: $username');

    final now = DateTime.now();
    final timeString = now.toIso8601String();

    return _safeApiCall(
      operationType: OperationType.post,
      endpoint: 'attendances/clock-in',
      data: {'username': username, 'time': timeString},
      apiCall:
          () => _post('attendances/clock-in', {
            'username': username,
            'time': timeString,
          }),
    );
  }

  /// Clock out an employee.
  ///
  /// Parameters:
  /// - [username]: The username of the employee to clock out (e.g., 'RZEMP0001')
  ///
  /// Example:
  /// ```dart
  /// final clockOutResult = await apiService.clockOutEmployee('RZEMP0001');
  /// ```
  ///
  /// Returns: Clock-out result data including updated attendance record
  ///
  /// Throws: [ApiException] if clock-out fails
  Future<Map<String, dynamic>> clockOutEmployee(
    String username,
    double totalHours,
  ) {
    SERVER_LOGS.info('🕕 Clocking out employee: $username');
    final now = DateTime.now();
    final timeString = now.toIso8601String();
    return _safeApiCall(
      operationType: OperationType.post,
      endpoint: 'attendances/clock-out',
      data: {
        'username': username,
        'time': timeString,
        'total_hours': totalHours,
      },
      apiCall:
          () => _post('attendances/clock-out', {
            'username': username,
            'time': timeString,
            'total_hours': totalHours,
          }),
    );
  }

  /// Get employee attendance status.
  ///
  /// Parameters:
  /// - [username]: The username of the employee to check status for (e.g., 'RZEMP0001')
  ///
  /// Example:
  /// ```dart
  /// final status = await apiService.getEmployeeAttendanceStatus('RZEMP0001');
  /// print('Is clocked in: ${status['is_clocked_in']}');
  /// ```
  ///
  /// Returns: Employee attendance status data including current status and last clock-in time
  ///
  /// Throws: [ApiException] if the request fails
  Future<Map<String, dynamic>> getEmployeeAttendanceStatus(String username) {
    SERVER_LOGS.info('📊 Getting attendance status for employee: $username');
    return _safeApiCall(
      operationType: OperationType.get,
      endpoint: 'attendances/status/$username',
      apiCall: () => _getSingle('attendances/status/$username'),
    );
  }

  // __ [Inventory Management]
  /// Get all inventory items from the server.
  ///
  /// Returns: List of inventory data containing product_id, quantity, last_updated, etc.
  ///
  /// Throws: [ApiException] if the request fails
  Future<List<Map<String, dynamic>>> getInventory() {
    SERVER_LOGS.info('📦 Getting all inventory items');
    return _safeApiCall(
      operationType: OperationType.get,
      endpoint: 'inventories',
      apiCall: () => _getList('inventories'),
    );
  }

  /// [140725] Create a new inventory record.
  Future<Map<String, dynamic>> createInventoryTransaction(
    InventoryTransactionData inventoryData,
  ) {
    SERVER_LOGS.info(
      '➕ Creating new inventory transaction record: $inventoryData',
    );
    return _safeApiCall(
      operationType: OperationType.post,
      endpoint: 'inventory-transactions',
      data: inventoryData.toJson(),
      apiCall: () => _post('inventory-transactions', inventoryData.toJson()),
    );
  }

  /// Update inventory quantity for a specific product.
  ///
  /// Parameters:
  /// - [productId]: The ID of the product to update
  /// - [quantity]: The new quantity amount
  ///
  /// Example:
  /// ```dart
  /// await apiService.updateInventory(productId: 1, quantity: 50);
  /// ```
  ///
  /// Returns: Updated inventory data
  ///
  /// Throws: [ApiException] if update fails
  Future<Map<String, dynamic>> updateInventoryTransaction(
    InventoryTransactionData inventoryData,
  ) {
    SERVER_LOGS.info(
      '📦 ${inventoryData.employeeId} Updating inventory for product at ${inventoryData.date}',
    );
    return _safeApiCall(
      operationType: OperationType.put,
      endpoint: 'inventory-transactions',
      data: inventoryData.toJson(),
      apiCall: () => _put('inventory-transactions', inventoryData.toJson()),
    );
  }

  // [Queue Management]
  /// Get access to the offline queue manager
  OfflineQueueManager get queueManager => _queueManager;

  /// Get access to the connectivity service
  InternetConnectionService get connectivityService => _connectivityService;

  /// Check if there are any operations in the queue
  bool get hasQueuedOperations => _queueManager.queueSize > 0;

  /// Get the current queue size
  int get queueSize => _queueManager.queueSize;

  /// Get queue status stream
  Stream<int> get onQueueSizeChanged => _queueManager.onQueueSizeChanged;

  /// Get connectivity status stream
  Stream<bool> get onConnectivityChanged => _queueManager.onConnectivityChanged;

  /// Manually trigger queue processing (useful for UI buttons)
  Future<void> processQueue() async {
    await _queueManager.markOnline();
  }

  /// Clear all queued operations (use with caution)
  Future<void> clearQueue() async {
    SERVER_LOGS.warning('⚠️ Manually clearing operation queue');
    await _queueManager.clearQueue();
  }

  /// [FIX:150725] Safe-failure wrapper for API calls that can be queued when offline
  /// This method handles the queue execution logic for operations
  Future<T> _safeApiCall<T>({
    required OperationType operationType,
    required String endpoint,
    Map<String, dynamic>? data,
    required Future<T> Function() apiCall,
  }) async {
    try {
      // Check if we're online first
      final bool isOnline = await _connectivityService.isConnected();

      if (!isOnline) {
        SERVER_LOGS.warning(
          '📡 Device is offline, queueing operation: $operationType $endpoint',
        );

        // Queue the operation for later execution
        await _queueManager.queueOperation(
          type: operationType,
          endpoint: endpoint,
          data: data,
          headers: await _getHeaders(),
        );

        throw ApiException(
          'Device is offline - operation queued for retry when connection is restored',
          0,
        );
      }

      // Execute the API call
      return await apiCall();
    } catch (e) {
      // If it's a network error or server unavailable, queue for retry
      if (e is ApiException && (e.statusCode == 0 || e.statusCode >= 500)) {
        SERVER_LOGS.warning(
          '🔄 Server error, queueing operation: $operationType $endpoint',
        );

        await _queueManager.queueOperation(
          type: operationType,
          endpoint: endpoint,
          data: data,
          headers: await _getHeaders(),
        );

        // await _queueManager.markOffline('Server unavailable: ${e.message}');
      }

      rethrow;
    }
  }

  /// Execute a queued operation (implementation for OfflineQueueManager)
  Future<bool> executeQueuedOperation(QueuedOperation operation) async {
    SERVER_LOGS.info(
      '🔄 Executing queued operation: ${operation.type} ${operation.endpoint}',
    );

    try {
      // Check API health before executing
      // await checkApiHealth();

      switch (operation.type) {
        case OperationType.get:
          // Determine if it's a list or single item GET based on endpoint pattern
          if (operation.endpoint.contains('/') &&
              (operation.endpoint.contains('kiosks/') ||
                  operation.endpoint.contains('products/') ||
                  operation.endpoint.contains('employees/') ||
                  operation.endpoint.contains('attendances/') ||
                  operation.endpoint.contains('transactions/') ||
                  operation.endpoint.contains('inventories/') ||
                  operation.endpoint.contains('sets/') ||
                  operation.endpoint.contains('discounts/'))) {
            // Single item GET
            await _getSingleDirect(operation.endpoint);
          } else {
            // List GET
            await _getListDirect(operation.endpoint);
          }
          break;

        case OperationType.post:
          await _postDirect(operation.endpoint, operation.data ?? {});
          break;

        case OperationType.put:
          await _putDirect(operation.endpoint, operation.data ?? {});
          break;

        case OperationType.delete:
          await _deleteDirect(operation.endpoint);
          break;
      }

      SERVER_LOGS.info(
        '✅ Successfully executed queued operation: ${operation.id}',
      );
      return true;
    } catch (e) {
      SERVER_LOGS.error(
        '❌ Failed to execute queued operation ${operation.id}: $e',
      );
      return false;
    }
  }

  // [Direct API methods (without safe-failure wrapper) for queue execution]

  Future<List<Map<String, dynamic>>> _getListDirect(String endpoint) async {
    final response = await http
        .get(Uri.parse('$baseUrl/$endpoint'), headers: await _getHeaders())
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    } else {
      throw ApiException('Failed to load $endpoint', response.statusCode);
    }
  }

  Future<Map<String, dynamic>> _getSingleDirect(String endpoint) async {
    final response = await http
        .get(Uri.parse('$baseUrl/$endpoint'), headers: await _getHeaders())
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw ApiException('Failed to load $endpoint', response.statusCode);
    }
  }

  Future<Map<String, dynamic>> _postDirect(
    String endpoint,
    Map<String, dynamic> data,
  ) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/$endpoint'),
          headers: await _getHeaders(),
          body: jsonEncode(data),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 201 || response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw ApiException(
        'Failed to create resource at $endpoint',
        response.statusCode,
      );
    }
  }

  Future<Map<String, dynamic>> _putDirect(
    String endpoint,
    Map<String, dynamic> data,
  ) async {
    final response = await http
        .put(
          Uri.parse('$baseUrl/$endpoint'),
          headers: await _getHeaders(),
          body: jsonEncode(data),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw ApiException(
        'Failed to update resource at $endpoint',
        response.statusCode,
      );
    }
  }

  Future<void> _deleteDirect(String endpoint) async {
    final response = await http
        .delete(Uri.parse('$baseUrl/$endpoint'), headers: await _getHeaders())
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw ApiException('Failed to delete $endpoint', response.statusCode);
    }
  }
}

/// Custom exception class for API errors with detailed logging
class ApiException implements Exception {
  final String message;
  final int statusCode;

  ApiException(this.message, this.statusCode) {
    SERVER_LOGS.error('🚨 ApiException: $message (Status Code: $statusCode)');
  }

  @override
  String toString() {
    return 'ApiException: $message (Status Code: $statusCode)';
  }
}
