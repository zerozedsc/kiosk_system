// ignore_for_file: non_constant_identifier_names

import '../../configs/configs.dart';
import '../database/db.dart';

export '../auth/unified_auth_service.dart';
export '../database/db.dart';
export '../auth/auth_service.dart';

late InventoryServices inventory;
late LoggingService INVENTORY_LOGS;

class InventoryServices {
  // Cache for frequently accessed data
  Map<int, Map<String, dynamic>>? productCatalog;
  Map<int, Map<String, dynamic>>? setCatalog;
  late DatabaseQuery? _dbQuery;

  /// Initializes and preloads essential data into memory.
  /// Call this during app startup.
  Future<InventoryServices> initialize() async {
    try {
      INVENTORY_LOGS =
          await LoggingService(logName: "inventory_logs").initialize();
      _dbQuery = DatabaseQuery(db: DB, LOGS: INVENTORY_LOGS);
      // Preload product catalog and restructure as Map with ID as key
      final productList = await _dbQuery?.fetchAllData('kiosk_product');
      final setList = await _dbQuery?.fetchAllData('set_product');
      productCatalog = {
        for (var product in productList!)
          product['id'] as int: {...product}..remove('id'),
      };
      setCatalog = {
        for (var product in setList!)
          product['id'] as int: {...product}..remove('id'),
      };
      INVENTORY_LOGS.info(
        'Product catalog preloaded: ${productCatalog!.length} items',
      );
      INVENTORY_LOGS.info('Set catalog preloaded: ${setCatalog!.length} items');
    } catch (e, stackTrace) {
      INVENTORY_LOGS.error('Error preloading data', e, stackTrace);
    }
    return this;
  }

  /// update all cache again
  Future<bool> updateDataInVar() async {
    try {
      // Preload product catalog and restructure as Map with ID as key
      final productList = await _dbQuery?.fetchAllData('kiosk_product');
      final setList = await _dbQuery?.fetchAllData('set_product');
      productCatalog = {
        for (var product in productList!)
          product['id'] as int: {...product}..remove('id'),
      };
      setCatalog = {
        for (var product in setList!)
          product['id'] as int: {...product}..remove('id'),
      };
      INVENTORY_LOGS.info(
        'Product catalog preloaded: ${productCatalog!.length} items',
      );
      INVENTORY_LOGS.info('Set catalog preloaded: ${setCatalog!.length} items');
      return true;
    } catch (e, stackTrace) {
      INVENTORY_LOGS.error('Error preloading data', e, stackTrace);
      return false;
    }
  }

  /// Retrieves a list of all product IDs from table .
  Future<List<int>> getKioskProductIds({bool isRetry = false}) async {
    try {
      // Check if we have the product catalog in memory first
      if (productCatalog != null) {
        // Extract keys (IDs) directly from the productCatalog
        final productIds = productCatalog!.keys.toList();

        if (productIds.isNotEmpty) {
          return productIds;
        }

        if (!isRetry) {
          await updateDataInVar();
          return getKioskProductIds(isRetry: true);
        }

        INVENTORY_LOGS.warning('Product catalog is empty even after refresh');
        return [];
      }
      // If productCatalog is null, update data and try only once
      if (!isRetry) {
        await updateDataInVar();
        return getKioskProductIds(isRetry: true);
      }

      INVENTORY_LOGS.warning('Failed to load product catalog after retry');
      return [];
    } catch (e) {
      INVENTORY_LOGS.error('Error retrieving product IDs: $e');
      return [];
    }
  }

  /// Retrieves a list of all product IDs from the database.
  /// Updates product data in the kiosk_product table and cache
  ///
  /// This method can update either a single field for a product or multiple fields
  /// for multiple products in a bulk operation.
  ///
  /// For single updates:
  /// - Pass the product [id], [colName] of the field to update, and new [value]
  ///
  /// For bulk updates:
  /// - Pass a [bulkData] map where keys are product IDs (as strings) and values are maps of column-value pairs
  ///   Example: {'1': {'price': 10.99, 'total_stocks': 50}, '2': {'price': 8.99}}
  ///
  /// Returns true if the operation was successful, false otherwise.
  Future<bool> updateKioskProductData({
    dynamic id,
    String? colName,
    dynamic value,
    Map<String, dynamic>? bulkData,
  }) async {
    try {
      // Handle bulk update
      if (bulkData != null && bulkData.isNotEmpty) {
        for (final entry in bulkData.entries) {
          // Convert string key to integer for database operations
          final productId = int.parse(entry.key);
          final updates = entry.value as Map<String, dynamic>;

          // Update each field in the database
          await _dbQuery?.updateData('kiosk_product', productId, updates);

          // Update cache if available
          if (productCatalog != null &&
              productCatalog!.containsKey(productId)) {
            updates.forEach((field, newValue) {
              productCatalog![productId]![field] = newValue;
            });
          }
        }

        await updateDataInVar(); // Refresh the cache after the update
        INVENTORY_LOGS.info(
          'Bulk update completed for ${bulkData.length} products',
        );
        return true;
      }

      // Handle single field update
      if (id != null && colName != null) {
        await _dbQuery?.updateCell('kiosk_product', id, colName, value);

        // Also update the cached data if available
        if (productCatalog != null && productCatalog!.containsKey(id)) {
          productCatalog![id]![colName] = value;
        }

        await updateDataInVar();
        INVENTORY_LOGS.info('Single update completed for product ID $id');
        return true;
      }

      // Neither method provided valid parameters
      INVENTORY_LOGS.warning('No valid update parameters provided');
      return false;
    } catch (e) {
      INVENTORY_LOGS.error('Error updating product data: $e');
      return false;
    }
  }

  /// Adjusts product quantities for either 'total_stocks' or 'total_pieces_used'
  ///
  /// This method subtracts the provided quantities from the current values in the database.
  ///
  /// For single updates:
  /// - Pass the product [id], the quantities to subtract for 'total_stocks' and/or 'total_pieces_used'
  ///
  /// For bulk updates:
  /// - Pass a [bulkData] map where keys are product IDs (as strings) and values contain the quantities to subtract
  ///   Example: {'1': {'total_stocks': 5, 'total_pieces_used': 3}, '2': {'total_stocks': 2}}
  ///
  /// Returns true if the operation was successful, false otherwise.
  Future<bool> adjustProductQuantities({
    dynamic id,
    int? totalStocks,
    int? totalPiecesUsed,
    Map<String, dynamic>? bulkData,
  }) async {
    try {
      if (productCatalog == null) {
        await updateDataInVar();
        if (productCatalog == null) {
          INVENTORY_LOGS.error('Failed to load product catalog');
          return false;
        }
      }

      // Handle bulk adjustments
      if (bulkData != null && bulkData.isNotEmpty) {
        final adjustments = <String, Map<String, dynamic>>{};

        for (final entry in bulkData.entries) {
          final productIdStr = entry.key;
          final productId = int.parse(productIdStr);
          final data = entry.value as Map<String, dynamic>;

          if (!productCatalog!.containsKey(productId)) {
            INVENTORY_LOGS.warning(
              'Product ID $productId not found in catalog',
            );
            continue;
          }

          final updates = <String, dynamic>{};

          if (data.containsKey('total_stocks')) {
            final currentValue =
                productCatalog![productId]!['total_stocks'] ?? 0;
            final newValue = currentValue - (data['total_stocks'] ?? 0);
            updates['total_stocks'] = newValue < 0 ? 0 : newValue;
          }

          if (data.containsKey('total_pieces_used')) {
            final currentValue =
                productCatalog![productId]!['total_pieces_used'] ?? 0;
            final newValue = currentValue - (data['total_pieces_used'] ?? 0);
            updates['total_pieces_used'] = newValue < 0 ? 0 : newValue;
          }

          if (updates.isNotEmpty) {
            adjustments[productIdStr] = updates;
          }
        }

        if (adjustments.isNotEmpty) {
          return await updateKioskProductData(bulkData: adjustments);
        }
        return true;
      }

      // Handle single adjustment
      if (id != null && (totalStocks != null || totalPiecesUsed != null)) {
        final productId = id is String ? int.parse(id) : id;

        if (!productCatalog!.containsKey(productId)) {
          INVENTORY_LOGS.warning('Product ID $productId not found in catalog');
          return false;
        }

        final updates = <String, dynamic>{};

        if (totalStocks != null) {
          final currentValue = productCatalog![productId]!['total_stocks'] ?? 0;
          final newValue = currentValue - totalStocks;
          updates['total_stocks'] = newValue < 0 ? 0 : newValue;
        }

        if (totalPiecesUsed != null) {
          final currentValue =
              productCatalog![productId]!['total_pieces_used'] ?? 0;
          final newValue = currentValue - totalPiecesUsed;
          updates['total_pieces_used'] = newValue < 0 ? 0 : newValue;
        }

        if (updates.isNotEmpty) {
          final bulkUpdates = <String, dynamic>{id.toString(): updates};
          return await updateKioskProductData(bulkData: bulkUpdates);
        }
        return true;
      }

      INVENTORY_LOGS.warning('No valid adjustment parameters provided');
      return false;
    } catch (e, stackTrace) {
      INVENTORY_LOGS.error('Error adjusting product quantities', e, stackTrace);
      return false;
    }
  }

  /// Parses a set string configuration into a structured data format
  ///
  /// The set string format follows this pattern:
  /// "PIECE/PACKAGE,ID1_maxQty,ID2_maxQty,...,CATEGORY#NAME_maxQty"
  ///
  /// - First segment defines the type (PIECE or PACKAGE)
  /// - Subsequent segments define items and their max quantities
  /// - '#' represents spaces in category names
  /// - '+' combines multiple IDs or categories (e.g., "13+14" or "POPIA#F50+POPIA#F8")
  ///
  /// @param setString The configuration string to parse
  /// @param setMaxQty Expected total maximum quantity for validation
  /// @return Map with 'type', 'details' (IDs with max quantities), and 'total_max_qty'
  Future<Map<String, dynamic>> parseSetString(
    String setString,
    int setMaxQty,
  ) async {
    try {
      if (setString.isEmpty) {
        INVENTORY_LOGS.error('Empty set configuration string provided');
        return {};
      }

      final List<String> segments = setString.split(',');
      if (segments.isEmpty) {
        INVENTORY_LOGS.error('Invalid set configuration format');
        return {};
      }

      // Determine type based on first segment (PIECE or PACKAGE)
      final String type =
          segments[0].trim().toUpperCase() == 'PIECE'
              ? 'total_pieces_used'
              : 'total_stocks';

      final details = <Map<String, dynamic>>[];
      int calculatedTotalMaxQty = 0;

      // Process remaining segments (after the type)
      Map<String, dynamic> output = {};

      // Check for FRY pattern
      int? fryValue;

      for (int i = 1; i < segments.length; i++) {
        final segment = segments[i].trim();

        // Check if this is a FRY segment (e.g., "15 FRY")
        if (segment.endsWith('PIECE')) {
          // Extract the ID before "FRY"
          final idPart = segment.split(' ').first.trim();
          final id = int.tryParse(idPart);
          if (id != null) {
            details.add({
              'ids': [id],
              'max_qty': -1,
            });
            fryValue = 1;
          } else {
            INVENTORY_LOGS.warning(
              'Invalid ID format in FRY segment: $segment',
            );
          }
          continue;
        }

        // Process regular set item format with underscore
        final parts = segment.split('_');
        if (parts.length != 2) {
          INVENTORY_LOGS.warning(
            'Skipping invalid format in segment: $segment',
          );
          continue;
        }

        final itemSpec = parts[0].trim();
        final maxQty = int.tryParse(parts[1]) ?? 0;
        calculatedTotalMaxQty += maxQty;

        // Handle the '+' notation for multiple IDs or categories
        final itemSpecs = itemSpec.split('+');
        final allMatchingIds = <int>[];

        for (final spec in itemSpecs) {
          // Process direct IDs
          if (RegExp(r'^\d+$').hasMatch(spec)) {
            final id = int.parse(spec);
            allMatchingIds.add(id);
          }
          // Process category-based items - either containing # for spaces or pure alphabetic
          else {
            // Replace # with actual spaces to match category names in database
            final category = spec.replaceAll('#', ' ');

            // Use the in-memory cache instead of a database query
            final products =
                productCatalog?.entries
                    .where((entry) => entry.value['categories'] == category)
                    .map((entry) => entry.key)
                    .toList() ??
                [];

            if (products.isNotEmpty) {
              allMatchingIds.addAll(products);
            } else {
              INVENTORY_LOGS.warning(
                'No products found for category: $category',
              );
            }
          }
        }

        if (allMatchingIds.isNotEmpty) {
          details.add({'ids': allMatchingIds, 'max_qty': maxQty});
        } else {
          INVENTORY_LOGS.warning('No matching products found for: $itemSpec');
        }
      }

      // Validate total max quantity matches expected value (skip if FRY option is present)
      if (fryValue == null && calculatedTotalMaxQty != setMaxQty) {
        INVENTORY_LOGS.warning(
          'Total max quantity ($calculatedTotalMaxQty) does not match expected value ($setMaxQty)',
        );
      }

      output.addAll({
        'set': type,
        'details': details,
        'total_max_qty': fryValue == null ? calculatedTotalMaxQty : setMaxQty,
      });

      // Add fry key if present
      if (fryValue != null) {
        output['piece'] = fryValue;
      }

      return output;
    } catch (e, stackTrace) {
      INVENTORY_LOGS.error('Error parsing set configuration', e, stackTrace);
      return {};
    }
  }

  /// get all products and sets for cashier_page
  Future<List<Map<String, dynamic>>> getAllProductsAndSets() async {
    try {
      // Check if we have data in the cache
      List<Map<String, dynamic>> catalogs = [];

      if (productCatalog == null || setCatalog == null) {
        await updateDataInVar();
      }

      // Convert the productCatalog Map to a List of products with their IDs
      List<Map<String, dynamic>> products =
          productCatalog!.entries
              .where((entry) => entry.value['exist'] != 0)
              .map((entry) {
                return {
                  'id': entry.key,
                  'name': entry.value['name'],
                  'shortform': entry.value['shortform'],
                  'categories': entry.value['categories']?.split(',') ?? [],
                  'image': entry.value['image'],
                  'price': entry.value['price'],
                  'total_stocks': entry.value['total_stocks'],
                };
              })
              .toList();

      catalogs = catalogs + products;

      // Convert the setCatalog Map to a List of sets with their IDs
      final sets =
          setCatalog!.entries.where((entry) => entry.value['exist'] != 0).map((
            entry,
          ) async {
            final setData = await parseSetString(
              entry.value['set_items'],
              entry.value['max_qty'],
            );
            final output = {
              'id': entry.key,
              'name': entry.value['name'],
              'shortform': entry.value['shortform'],
              'image': entry.value['image'],
              'price': entry.value['price'],
              'set': setData['set'],
              'details': setData['details'],
              'total_max_qty': setData['total_max_qty'],
            };

            if (setData.containsKey('piece')) {
              output['piece'] = setData['piece'];
            }

            return output;
          }).toList();

      // Wait for all the Futures to complete
      final resolvedSets = await Future.wait(sets);

      catalogs = catalogs + resolvedSets;

      return catalogs;
    } catch (e) {
      INVENTORY_LOGS.error('Error fetching products and sets: $e');
      return [];
    }
  }

  /// Toggles the 'exist' status of a product or set
  ///
  /// This method can toggle a single item or multiple items in bulk.
  ///
  /// For single toggle:
  /// - Pass the [id] and [isProduct] flag to identify the item type
  ///
  /// For bulk toggle:
  /// - Pass a [bulkToggleList] containing maps with 'id' and 'isProduct' keys
  ///   Example: [{'id': 1, 'isProduct': true}, {'id': 2, 'isProduct': false}]
  ///
  /// [forceValue] can be used to set a specific value (0 or 1) instead of toggling
  ///
  /// Returns true if the operation was successful, false otherwise.
  Future<bool> toggleItemExistence({
    int? id,
    bool? isProduct,
    List<Map<String, dynamic>>? bulkToggleList,
    int? forceValue,
  }) async {
    try {
      if (productCatalog == null || setCatalog == null) {
        await updateDataInVar();
        if (productCatalog == null || setCatalog == null) {
          INVENTORY_LOGS.error('Failed to load catalogs for toggle operation');
          return false;
        }
      }

      // Handle bulk toggle
      if (bulkToggleList != null && bulkToggleList.isNotEmpty) {
        for (final item in bulkToggleList) {
          final itemId = item['id'] as int;
          final itemIsProduct = item['isProduct'] as bool;

          final String tableName =
              itemIsProduct ? 'kiosk_product' : 'set_product';
          final cache = itemIsProduct ? productCatalog! : setCatalog!;

          if (!cache.containsKey(itemId)) {
            INVENTORY_LOGS.warning(
              'Item ID $itemId not found in ${itemIsProduct ? 'product' : 'set'} catalog',
            );
            continue;
          }

          final currentValue = cache[itemId]!['exist'] ?? 1;
          final newValue = forceValue ?? (currentValue == 1 ? 0 : 1);

          // Update database
          await _dbQuery?.updateCell(tableName, itemId, 'exist', newValue);

          // Update cache
          cache[itemId]!['exist'] = newValue;
        }
        return true;
      }

      // Handle single toggle
      if (id != null && isProduct != null) {
        final String tableName = isProduct ? 'kiosk_product' : 'set_product';
        final cache = isProduct ? productCatalog! : setCatalog!;

        if (!cache.containsKey(id)) {
          INVENTORY_LOGS.warning(
            'Item ID $id not found in ${isProduct ? 'product' : 'set'} catalog',
          );
          return false;
        }

        final currentValue = cache[id]!['exist'] ?? 1;
        final newValue = forceValue ?? (currentValue == 1 ? 0 : 1);

        // Update database
        await _dbQuery?.updateCell(tableName, id, 'exist', newValue);

        // Update cache
        cache[id]!['exist'] = newValue;
        return true;
      }

      INVENTORY_LOGS.warning('No valid toggle parameters provided');
      return false;
    } catch (e, stackTrace) {
      INVENTORY_LOGS.error('Error toggling item existence', e, stackTrace);
      return false;
    }
  }

  /// Bulk adds new products to the kiosk_product table
  ///
  /// Accepts a list of maps, each containing the field values for a new product.
  /// Each map must contain at least the 'name' field.
  ///
  /// Example usage:
  /// ```
  /// await inventory.bulkAddProducts([
  ///   {'name': 'Product 1', 'price': 10.99, 'total_stocks': 50},
  ///   {'name': 'Product 2', 'price': 8.99, 'total_stocks': 30},
  /// ]);
  /// ```
  ///
  /// Returns a list of the IDs of the newly created products, or an empty list if the operation failed.
  Future<List<int>> addProducts(List<Map<String, dynamic>> products) async {
    try {
      if (products.isEmpty) {
        INVENTORY_LOGS.warning('No products provided for bulk add operation');
        return [];
      }
      final List<int> newProductIds = [];

      for (final product in products) {
        if (!product.containsKey('name') ||
            product['name'].toString().isEmpty) {
          INVENTORY_LOGS.warning('Skipping product with missing name');
          continue;
        }

        // Add default values if not provided
        final Map<String, dynamic> productData = {...product};

        // Insert the product into the database
        final insertedRecord = await _dbQuery?.insertAndRetrieve(
          'kiosk_product',
          productData,
        );

        if (insertedRecord != null && insertedRecord.containsKey('id')) {
          final id = insertedRecord['id'] as int;
          newProductIds.add(id);

          // Update the in-memory cache
          if (productCatalog != null) {
            productCatalog![id] = {...insertedRecord}..remove('id');
          }
        }
      }

      if (newProductIds.isNotEmpty) {
        INVENTORY_LOGS.info('Added ${newProductIds.length} new products');
      } else {
        INVENTORY_LOGS.warning('No products were added during bulk operation');
      }

      return newProductIds;
    } catch (e, stackTrace) {
      INVENTORY_LOGS.error('Error adding bulk products', e, stackTrace);
      return [];
    }
  }

  /// Bulk adds stock to multiple products in the kiosk_product table
  ///
  /// Accepts a map where keys are product IDs (as strings or ints) and values are
  /// the stock quantities to add to the current total_stocks value.
  ///
  /// Example usage:
  /// ```
  /// await inventory.bulkAddStocks({
  ///   1: 20,  // Add 20 stocks to product ID 1
  ///   '2': 15 // Add 15 stocks to product ID 2
  /// });
  /// ```
  ///
  /// Returns true if the operation was successful, false otherwise.
  Future<bool> addStocks(Map<dynamic, int> stocksToAdd) async {
    try {
      if (stocksToAdd.isEmpty) {
        INVENTORY_LOGS.warning('No stocks provided for bulk add operation');
        return false;
      }

      if (productCatalog == null) {
        await updateDataInVar();
        if (productCatalog == null) {
          INVENTORY_LOGS.error(
            'Failed to load product catalog for stock update',
          );
          return false;
        }
      }

      final Map<String, Map<String, dynamic>> updates = {};

      for (final entry in stocksToAdd.entries) {
        // Convert key to int regardless of whether it's a string or int
        final int productId =
            entry.key is int ? entry.key : int.parse(entry.key.toString());
        final int stockToAdd = entry.value;

        if (!productCatalog!.containsKey(productId)) {
          INVENTORY_LOGS.warning('Product ID $productId not found in catalog');
          continue;
        }

        if (stockToAdd <= 0) {
          INVENTORY_LOGS.warning(
            'Skipping invalid stock value for product $productId: $stockToAdd',
          );
          continue;
        }

        // Calculate new stock value
        final int currentStock =
            productCatalog![productId]!['total_stocks'] ?? 0;
        final int newStock = currentStock + stockToAdd;

        // Add to updates map
        updates[productId.toString()] = {'total_stocks': newStock};
      }

      if (updates.isEmpty) {
        INVENTORY_LOGS.warning('No valid stock updates to process');
        return false;
      }

      // Use existing updateKioskProductData method to perform the bulk update
      final result = await updateKioskProductData(bulkData: updates);

      if (result) {
        INVENTORY_LOGS.info(
          'Successfully added stocks to ${updates.length} products',
        );
      }

      await updateDataInVar(); // Refresh the cache after the update
      return result;
    } catch (e, stackTrace) {
      INVENTORY_LOGS.error('Error adding bulk stocks', e, stackTrace);
      return false;
    }
  }

  /// Bulk deletes products from the kiosk_product table
  ///
  /// Accepts a list of product IDs to delete. This operation is permanent
  /// and removes the products from both the database and the in-memory cache.
  ///
  /// Example usage:
  /// ```
  /// await inventory.bulkDeleteProducts([1, 2, 5]); // Delete products with IDs 1, 2, and 5
  /// ```
  ///
  /// Returns true if the operation was successful, false otherwise.
  /// Note: Returns true even if some product IDs were not found.
  Future<bool> deleteProducts(List<dynamic> productIds) async {
    try {
      if (productIds.isEmpty) {
        INVENTORY_LOGS.warning(
          'No product IDs provided for bulk delete operation',
        );
        return false;
      }

      // Convert all IDs to integers for consistency
      final List<int> normalizedIds =
          productIds
              .map((id) => id is int ? id : int.tryParse(id.toString()))
              .where((id) => id != null)
              .cast<int>()
              .toList();

      if (normalizedIds.isEmpty) {
        INVENTORY_LOGS.warning('No valid product IDs provided for deletion');
        return false;
      }

      // Delete each product individually
      for (final productId in normalizedIds) {
        // Delete from database
        await _dbQuery?.deleteRowData('kiosk_product', productId);

        // Remove from in-memory cache if it exists
        if (productCatalog != null) {
          productCatalog!.remove(productId);
        }
      }

      INVENTORY_LOGS.info(
        'Successfully deleted ${normalizedIds.length} products',
      );
      return true;
    } catch (e, stackTrace) {
      INVENTORY_LOGS.error('Error deleting bulk products', e, stackTrace);
      return false;
    }
  }

  /// Creates new set products in the set_product table.
  ///
  /// This method creates one or multiple new set products with the provided details.
  /// Each set in the list should be a map containing the required fields.
  /// The set_items string should follow the format used in parseSetString method:
  /// "PIECE/PACKAGE,ID1_maxQty,ID2_maxQty,...,CATEGORY#NAME_maxQty"
  ///
  /// Required fields in each map:
  /// - name: The name of the set product
  /// - group_names: Comma-separated group names for categorizing the set
  /// - price: The price of the set product
  /// - set_items: The configuration string for items in the set
  /// - max_qty: The maximum quantity for the set
  ///
  /// Optional fields:
  /// - image: Binary image data for the set
  /// - exist: Whether the set is active (1) or not (0), defaults to 1
  ///
  /// Returns:
  /// - A Future<List<int>> with the IDs of the newly created sets, or an empty list if no sets were created
  ///
  /// Example:
  /// ```dart
  /// final newSetIds = await inventory.createNewSets([
  ///   {
  ///     'name': "Combo Meal A",
  ///     'group_names': "Combos,Meals",
  ///     'price': 15.99,
  ///     'set_items': "PACKAGE,101_1,BURGER#CHICKEN_1",
  ///     'max_qty': 2,
  ///   },
  ///   {
  ///     'name': "Combo Meal B",
  ///     'group_names': "Combos,Meals",
  ///     'price': 17.99,
  ///     'set_items': "PACKAGE,103_1,SIDES#FRIES_1",
  ///     'max_qty': 2,
  ///   }
  /// ]);
  /// ```
  Future<List<int>> createNewSets(List<Map<String, dynamic>> setsList) async {
    try {
      if (setsList.isEmpty) {
        INVENTORY_LOGS.warning('No set products provided for creation');
        return [];
      }

      final List<int> newSetIds = [];

      for (final setData in setsList) {
        // Validate required fields
        if (!setData.containsKey('name') ||
            !setData.containsKey('group_names') ||
            !setData.containsKey('price') ||
            !setData.containsKey('set_items') ||
            !setData.containsKey('max_qty')) {
          INVENTORY_LOGS.warning(
            'Skipping set with missing required fields: ${setData['name'] ?? 'unnamed'}',
          );
          continue;
        }

        // Ensure exist is set if not provided
        if (!setData.containsKey('exist')) {
          setData['exist'] = 1;
        }

        // Insert into database and get the record with ID
        final insertedRecord = await _dbQuery?.insertAndRetrieve(
          'set_product',
          setData,
        );

        if (insertedRecord != null && insertedRecord.containsKey('id')) {
          final id = insertedRecord['id'] as int;

          // Update the in-memory cache
          if (setCatalog != null) {
            setCatalog![id] = {...insertedRecord}..remove('id');
          }

          newSetIds.add(id);
        }
      }

      if (newSetIds.isNotEmpty) {
        INVENTORY_LOGS.info('Created ${newSetIds.length} new set products');
      } else {
        INVENTORY_LOGS.warning('No set products were created during operation');
      }

      return newSetIds;
    } catch (e, stackTrace) {
      INVENTORY_LOGS.error('Error creating new set products', e, stackTrace);
      return [];
    }
  }

  /// Updates set data in the set_product table and cache
  ///
  /// This method can update either a single field for a set or multiple fields
  /// for multiple sets in a bulk operation.
  ///
  /// For single updates:
  /// - Pass the set [id], [colName] of the field to update, and new [value]
  ///
  /// For bulk updates:
  /// - Pass a [bulkData] map where keys are set IDs (as strings) and values are maps of column-value pairs
  ///   Example: {'1': {'price': 10.99, 'group_names': 'Combo,Meals'}, '2': {'price': 8.99}}
  ///
  /// Returns true if the operation was successful, false otherwise.
  Future<bool> updateSetProductData({
    dynamic id,
    String? colName,
    dynamic value,
    Map<String, dynamic>? bulkData,
  }) async {
    try {
      // Handle bulk update
      if (bulkData != null && bulkData.isNotEmpty) {
        for (final entry in bulkData.entries) {
          // Convert string key to integer for database operations
          final setId = int.parse(entry.key);
          final updates = entry.value as Map<String, dynamic>;

          // Update each field in the database
          await _dbQuery?.updateData('set_product', setId, updates);

          // Update cache if available
          if (setCatalog != null && setCatalog!.containsKey(setId)) {
            updates.forEach((field, newValue) {
              setCatalog![setId]![field] = newValue;
            });
          }
        }
        await updateDataInVar(); // Refresh the cache after the update

        INVENTORY_LOGS.info(
          'Bulk update completed for ${bulkData.length} set products',
        );

        return true;
      }

      // Handle single field update
      if (id != null && colName != null) {
        await _dbQuery?.updateCell('set_product', id, colName, value);

        // Also update the cached data if available
        if (setCatalog != null && setCatalog!.containsKey(id)) {
          setCatalog![id]![colName] = value;
        }

        await updateDataInVar(); // Refresh the cache after the update
        INVENTORY_LOGS.info('Single update completed for set product ID $id');
        return true;
      }

      // Neither method provided valid parameters
      INVENTORY_LOGS.warning(
        'No valid update parameters provided for set product',
      );

      return false;
    } catch (e) {
      INVENTORY_LOGS.error('Error updating set product data: $e');
      return false;
    }
  }

  /// Deletes set products from the set_product table
  ///
  /// Accepts a list of set product IDs to delete. This operation permanently
  /// removes the sets from both the database and the in-memory cache.
  ///
  /// Example usage:
  /// ```
  /// await inventory.deleteSets([1, 2, 5]); // Delete sets with IDs 1, 2, and 5
  /// ```
  ///
  /// Returns true if the operation was successful, false otherwise.
  /// Note: Returns true even if some set IDs were not found.
  Future<bool> deleteSets(List<dynamic> setIds) async {
    try {
      if (setIds.isEmpty) {
        INVENTORY_LOGS.warning('No set IDs provided for delete operation');
        return false;
      }

      // Convert all IDs to integers for consistency
      final List<int> normalizedIds =
          setIds
              .map((id) => id is int ? id : int.tryParse(id.toString()))
              .where((id) => id != null)
              .cast<int>()
              .toList();

      if (normalizedIds.isEmpty) {
        INVENTORY_LOGS.warning('No valid set IDs provided for deletion');
        return false;
      }

      // Delete each set individually
      for (final setId in normalizedIds) {
        // Delete from database
        await _dbQuery?.deleteRowData('set_product', setId);

        // Remove from in-memory cache if it exists
        if (setCatalog != null) {
          setCatalog!.remove(setId);
        }
      }

      INVENTORY_LOGS.info('Successfully deleted ${normalizedIds.length} sets');
      return true;
    } catch (e, stackTrace) {
      INVENTORY_LOGS.error('Error deleting sets', e, stackTrace);
      return false;
    }
  }
}
