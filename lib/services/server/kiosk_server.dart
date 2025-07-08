import '../../configs/configs.dart';
import 'package:http/http.dart' as http;
import 'offline_queue_manager.dart';
import '../connection/internet.dart';

/// [050725] KioskData
class KioskData {
  final String name;
  final String location;
  final String? description;

  KioskData({required this.name, required this.location, this.description});

  Map<String, dynamic> toJson() => {
    'name': name,
    'location': location,
    if (description != null) 'description': description,
  };

  @override
  String toString() =>
      'KioskData(name: $name, location: $location, description: $description)';
}

class ProductData {
  final String name;
  final double price;
  final String? description;
  final String? category;

  ProductData({
    required this.name,
    required this.price,
    this.description,
    this.category,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'price': price,
    if (description != null) 'description': description,
    if (category != null) 'category': category,
  };

  @override
  String toString() =>
      'ProductData(name: $name, price: $price, description: $description, category: $category)';
}

/// [050725] EmployeeData
class EmployeeData {
  final int? id;
  final String kioskId;
  final String username;
  final String name;
  final int age;
  final String? address;
  final String? phoneNumber;
  final String? email;
  final String? description;
  final String password;
  final bool exist;
  final bool isAdmin;
  final Uint8List?
  image; // BLOB data as bytes (equivalent to LargeBinary in Python)
  final DateTime? createdAt;

  EmployeeData({
    this.id,
    required this.kioskId,
    required this.username,
    required this.name,
    required this.age,
    this.address,
    this.phoneNumber,
    this.email,
    this.description,
    required this.password,
    required this.exist,
    required this.isAdmin,
    this.image,
    this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'kiosk_id': kioskId,
    'username': username,
    'name': name,
    'age': age,
    if (address != null) 'address': address,
    if (phoneNumber != null) 'phone_number': phoneNumber,
    if (email != null) 'email': email,
    if (description != null) 'description': description,
    'password': password,
    'exist': exist,
    'is_admin': isAdmin,
    if (image != null) 'image': image, // Send as bytes or base64 if needed
    if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
  };

  @override
  String toString() =>
      'EmployeeData(id: $id, kioskId: $kioskId, username: $username, name: $name, age: $age, address: $address, phoneNumber: $phoneNumber, email: $email, description: $description, password: [REDACTED], exist: $exist, isAdmin: $isAdmin, image: ${image != null}, createdAt: $createdAt)';
}

/// [050725] TransactionData
class TransactionData {
  final int productId;
  final int quantity;
  final double total;
  final int? employeeId;

  TransactionData({
    required this.productId,
    required this.quantity,
    required this.total,
    this.employeeId,
  });

  Map<String, dynamic> toJson() => {
    'product_id': productId,
    'quantity': quantity,
    'total': total,
    if (employeeId != null) 'employee_id': employeeId,
  };

  @override
  String toString() =>
      'TransactionData(productId: $productId, quantity: $quantity, total: $total, employeeId: $employeeId)';
}

/// [050725] AttendanceData
class AttendanceData {
  final int employeeId;
  final DateTime checkIn;
  final DateTime? checkOut;
  final String? notes;

  AttendanceData({
    required this.employeeId,
    required this.checkIn,
    this.checkOut,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
    'employee_id': employeeId,
    'check_in': checkIn.toIso8601String(),
    if (checkOut != null) 'check_out': checkOut!.toIso8601String(),
    if (notes != null) 'notes': notes,
  };

  @override
  String toString() =>
      'AttendanceData(employeeId: $employeeId, checkIn: $checkIn, checkOut: $checkOut, notes: $notes)';
}

class DiscountData {
  final String name;
  final double percentage;
  final String? description;
  final DateTime? validFrom;
  final DateTime? validTo;

  DiscountData({
    required this.name,
    required this.percentage,
    this.description,
    this.validFrom,
    this.validTo,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'percentage': percentage,
    if (description != null) 'description': description,
    if (validFrom != null) 'valid_from': validFrom!.toIso8601String(),
    if (validTo != null) 'valid_to': validTo!.toIso8601String(),
  };

  @override
  String toString() =>
      'DiscountData(name: $name, percentage: $percentage, description: $description, validFrom: $validFrom, validTo: $validTo)';
}

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
    SERVER_LOGS.debug('Request data: ${jsonEncode(data)}');
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

  // API methods
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

  /// Get all employees from the server.
  ///
  /// Returns: List of employee data containing id, name, username, age, position, etc.
  ///
  /// Throws: [ApiException] if the request fails
  Future<List<Map<String, dynamic>>> getEmployees() {
    SERVER_LOGS.info('👥 Getting all employees');
    return _getList('employees');
  }

  /// Get all transactions from the server.
  ///
  /// Returns: List of transaction data containing id, product_id, quantity, total, employee_id, timestamp, etc.
  ///
  /// Throws: [ApiException] if the request fails
  Future<List<Map<String, dynamic>>> getTransactions() {
    SERVER_LOGS.info('💳 Getting all transactions');
    return _safeApiCall(
      operationType: OperationType.get,
      endpoint: 'transactions',
      apiCall: () => _getList('transactions'),
    );
  }

  /// Get all inventory items from the server.
  ///
  /// Returns: List of inventory data containing product_id, quantity, last_updated, etc.
  ///
  /// Throws: [ApiException] if the request fails
  Future<List<Map<String, dynamic>>> getInventory() {
    SERVER_LOGS.info('📦 Getting all inventory items');
    return _getList('inventories');
  }

  /// Get all attendance records from the server.
  ///
  /// Returns: List of attendance data containing id, employee_id, check_in, check_out, notes, etc.
  ///
  /// Throws: [ApiException] if the request fails
  Future<List<Map<String, dynamic>>> getAttendances() {
    SERVER_LOGS.info('📅 Getting all attendance records');
    return _getList('attendances');
  }

  /// Get all discounts from the server.
  ///
  /// Returns: List of discount data containing id, name, percentage, description, valid_from, valid_to, etc.
  ///
  /// Throws: [ApiException] if the request fails
  Future<List<Map<String, dynamic>>> getDiscounts() {
    SERVER_LOGS.info('🎫 Getting all discounts');
    return _getList('discounts');
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

  /// Create a new transaction record.
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
  Future<Map<String, dynamic>> createTransaction(
    TransactionData transactionData,
  ) {
    SERVER_LOGS.info('➕ Creating new transaction: $transactionData');
    return _safeApiCall(
      operationType: OperationType.post,
      endpoint: 'transactions',
      data: transactionData.toJson(),
      apiCall: () => _post('transactions', transactionData.toJson()),
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
    return _post('attendances', attendanceData.toJson());
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
  Future<Map<String, dynamic>> updateInventory({
    required int productId,
    required int quantity,
  }) {
    SERVER_LOGS.info(
      '📦 Updating inventory for product $productId to quantity $quantity',
    );
    return _safeApiCall(
      operationType: OperationType.put,
      endpoint: 'inventories/$productId',
      data: InventoryUpdateData(quantity: quantity).toJson(),
      apiCall:
          () => _put(
            'inventories/$productId',
            InventoryUpdateData(quantity: quantity).toJson(),
          ),
    );
  }

  // Image URL helper methods
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

  /// Get the direct image URL for an employee.
  ///
  /// Parameters:
  /// - [employeeId]: The ID of the employee
  ///
  /// Returns: Complete URL string for the employee image
  String getEmployeeImageUrl(int employeeId) {
    final url = '$baseUrl/employees/$employeeId/image';
    SERVER_LOGS.debug('🖼️ Generated employee image URL: $url');
    return url;
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

  /// Safe-failure wrapper for API calls that can be queued when offline
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

        await _queueManager.markOffline('Server unavailable: ${e.message}');
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
      await checkApiHealth();

      switch (operation.type) {
        case OperationType.get:
          // Determine if it's a list or single item GET based on endpoint pattern
          if (operation.endpoint.contains('/') &&
              (operation.endpoint.contains('kiosks/') ||
                  operation.endpoint.contains('products/') ||
                  operation.endpoint.contains('employees/'))) {
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

  /// Direct API methods (without safe-failure wrapper) for queue execution
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
