import '../../configs/configs.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

export 'package:sqflite/sqflite.dart';

// ignore: non_constant_identifier_names
late String DBNAME;
// ignore: non_constant_identifier_names
late Database DB;
late List<String> existPrefList;

/// A utility class that manages SQLite database connections for the kiosk system.
///
/// The `DatabaseConnection` class provides static methods for initializing, checking,
/// and retrieving database instances. It handles common database operations such as:
/// - Copying database files from assets to the application's writable directory
/// - Comparing database versions to determine if updates are needed
/// - Managing database connections with proper version control
///
/// This class uses a singleton pattern to ensure that only one database connection
/// is active at a time, improving performance and preventing resource conflicts.
///
/// ## Usage Example
///
/// ```dart
/// // Get an instance of the database
/// final Database db = await DatabaseConnection.getDatabase(dbName: 'kiosk.db');
///
/// // Use the database instance with DatabaseQuery for operations
/// final query = DatabaseQuery(db: db);
/// final users = await query.fetchAllData('users');
/// ```
///
/// ## Database Versioning
///
/// The class manages database versions through the `_dbVersion` field, which is used
/// when opening the database connection. When updating your database schema, increase
/// this version number to trigger SQLite's migration process.
///
/// ## Asset Database Management
///
/// When the application starts, the class checks if the database file exists in the
/// writable directory. If not, it copies the file from the assets folder. If the file
/// already exists, it compares the file from assets with the existing one to determine
/// if an update is needed.
///
/// This approach allows for easy database updates by simply replacing the asset file
/// in a new app version.
class DatabaseConnection {
  static int _dbVersion = 1;

  /// Asynchronously gets an instance of the database with the specified name.
  ///
  /// This method ensures only one instance of the database is created and used.
  /// If the database has already been initialized, it returns the cached instance.
  /// Otherwise, it initializes a new database connection.
  ///
  /// Parameters:
  /// - [dbName]: The name of the database to get or initialize
  ///
  /// Returns:
  /// A [Future] that resolves to the [Database] instance
  static Future<Database> getDatabase({required String dbName}) async {
    // Initialize and store the database if not already cached
    final db = await _initDB(dbName);
    return db;
  }

  /// Initialize the database from the assets folder to the application documents directory.
  ///
  /// This method checks if the database exists in the writable directory and copies it from
  /// assets if it doesn't exist. If the database does exist, it compares the asset version
  /// with the writable version to determine if an update is needed.
  ///
  /// [dbName] The name of the database file.
  ///
  /// Returns a [Future] that resolves to the opened [Database] instance.
  ///
  /// Throws an exception if there is an error loading, copying, or opening the database.
  static Future<Database> _initDB(String dbName) async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String dbPath = join(documentsDirectory.path, dbName);

    // Path to the database in assets
    String assetsDbPath = 'assets/db/$dbName';

    // Check if the database already exists in the writable directory
    if (FileSystemEntity.typeSync(dbPath) == FileSystemEntityType.notFound) {
      // Copy the database from assets to the documents directory
      APP_LOGS.warning(
        "Database not found in writable directory. Copying from assets...",
      );
      ByteData data = await rootBundle.load(assetsDbPath);
      List<int> bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      await File(dbPath).writeAsBytes(bytes);
      APP_LOGS.info("Database copied to writable directory.");
    } else {
      // Check if the assets database has been updated
      ByteData assetData = await rootBundle.load(assetsDbPath);
      List<int> assetBytes = assetData.buffer.asUint8List(
        assetData.offsetInBytes,
        assetData.lengthInBytes,
      );

      List<int> writableBytes = await File(dbPath).readAsBytes();

      // Compare the bytes to determine if an update is needed
      if (!compareBytes(assetBytes, writableBytes) && DEBUG) {
        APP_LOGS.warning(
          "Database in assets has been updated. Replacing the writable database...",
        );
        await File(dbPath).writeAsBytes(assetBytes);
        APP_LOGS.info("Database updated successfully.");
      } else {
        APP_LOGS.info("Database in writable directory is up to date.");
      }
    }

    // Open the database
    return await openDatabase(dbPath, version: _dbVersion ?? 1);
  }

  /// Retrieves the current size of the database file in human-readable format.
  ///
  /// This method calculates the size of the database file in bytes and converts it
  /// to the most appropriate unit (KB, MB, or GB) based on the file size. The result
  /// is formatted with two decimal places for readability.
  ///
  /// Returns:
  ///   A [Future<String>] representing the database size with appropriate units.
  ///   Example returns: "156.25 KB", "2.34 MB", or "1.05 GB"
  ///
  /// Throws:
  ///   Any exceptions that might occur during file operations are caught and logged,
  ///   returning "Unknown size" in these cases.
  ///
  /// Example:
  ///   ```dart
  ///   String dbSize = await DatabaseConnection.getDatabaseSize();
  ///   print('Current database size: $dbSize');
  ///   ```
  static Future<String> getDatabaseSize({required String dbName}) async {
    try {
      Directory documentsDirectory = await getApplicationDocumentsDirectory();
      String dbPath = join(documentsDirectory.path, dbName);

      // Get file stats to determine size
      final dbFile = File(dbPath);
      if (!await dbFile.exists()) {
        return "0 KB";
      }

      final int sizeInBytes = await dbFile.length();

      // Convert bytes to appropriate unit
      if (sizeInBytes < 1024) {
        return "$sizeInBytes B";
      } else if (sizeInBytes < 1024 * 1024) {
        final sizeInKB = sizeInBytes / 1024;
        return "${sizeInKB.toStringAsFixed(2)} KB";
      } else if (sizeInBytes < 1024 * 1024 * 1024) {
        final sizeInMB = sizeInBytes / (1024 * 1024);
        return "${sizeInMB.toStringAsFixed(2)} MB";
      } else {
        final sizeInGB = sizeInBytes / (1024 * 1024 * 1024);
        return "${sizeInGB.toStringAsFixed(2)} GB";
      }
    } catch (e) {
      APP_LOGS.error('Error calculating database size: $e');
      return "Unknown size";
    }
  }
}

/// A utility class for performing database operations in a structured way.
///
/// This class provides a wrapper around the sqflite [Database] object to offer
/// higher-level operations like querying, inserting, updating, and deleting data.
/// It also offers utility methods for debugging database content through printing
/// and retrieving random entries.
///
/// Example:
/// ```dart
/// final db = await openDatabase('my_database.db');
/// final dbQuery = DatabaseQuery(db: db);
///
/// // Fetch all users
/// final users = await dbQuery.fetchAllData('users');
///
/// // Insert a new user
/// await dbQuery.insertData('users', {'name': 'Alice', 'age': 30});
///
/// // Get a random product for display
/// final featured = await dbQuery.getRandomRow('products');
/// ```
class DatabaseQuery {
  const DatabaseQuery({required this.db, required this.LOGS});
  final Database db;
  final LoggingService LOGS;

  /// Checks if a database connection is valid and functional.
  ///
  /// This method verifies if the database connection can execute a simple
  /// query successfully, confirming both existence and connectivity.
  ///
  /// Returns:
  ///   A [Future<bool>] that resolves to `true` if the database is
  ///   connected and functioning properly, or `false` otherwise.
  Future<bool> isDatabaseConnected() async {
    try {
      // Attempt to execute a simple query that should work on any database
      await db.rawQuery('SELECT 1');
      return true;
    } catch (e) {
      LOGS.error('Database connection check failed: $e');
      return false;
    }
  }

  /// Checks if a specific table exists in the database.
  ///
  /// Parameters:
  ///   [tableName] - The name of the table to check for existence.
  ///
  /// Returns:
  ///   A [Future<bool>] that resolves to `true` if the table exists,
  ///   or `false` otherwise.
  Future<bool> isTableExist(String tableName) async {
    try {
      final result = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
        [tableName],
      );
      return result.isNotEmpty;
    } catch (e) {
      LOGS.error('Error checking if table exists: $e');
      return false;
    }
  }

  /// Fetches a list of all table names in the database.
  ///
  /// This method queries the SQLite system tables to retrieve the names of all
  /// user-created tables in the database. It does not return system tables like
  /// 'sqlite_sequence', 'android_metadata', etc.
  ///
  /// Returns:
  ///   A [Future<List<String>>] containing the names of all user tables in the database.
  ///   Returns an empty list if an error occurs during the query.
  ///
  /// Example:
  ///   ```dart
  ///   final tables = await dbQuery.getTableNames();
  ///   print('Available tables: $tables');
  ///   ```
  Future<List<String>> getTableNames() async {
    try {
      final result = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' AND name NOT LIKE 'android_%'",
      );

      // Extract table names from the query result
      return result.map((row) => row['name'] as String).toList();
    } catch (e) {
      LOGS.error('Error fetching table names: $e');
      return [];
    }
  }

  /// Executes a raw SQL query and returns the result as a list of maps.
  ///
  /// Each map in the list represents a row in the result set, with column names as keys
  /// and column values as values.
  ///
  /// @param query The raw SQL query to execute
  /// @return A Future that resolves to a list of maps containing the query results
  /// @throws Exception if the query execution fails
  Future<List<Map<String, dynamic>>> query(String query) async {
    return db.rawQuery(query);
  }

  /// Prints the first record from a specified table in the database.
  ///
  /// This function queries the given [tableName] and prints the first record
  /// found (at index 0). If the query is successful but no records exist,
  /// or if any error occurs during the query, the function will print an
  /// error message.
  ///
  /// Parameters:
  ///   [tableName] - The name of the table to query.
  ///
  /// Returns:
  ///   A [Future<void>] that completes when the printing operation is done.
  ///
  /// Throws:
  ///   No exceptions are thrown as they are caught internally and printed
  ///   to the console.
  Future<void> printOneInTable(String tableName) async {
    try {
      final data = await db.query(tableName);
      LOGS.console(data[0]);
    } catch (e) {
      LOGS.error('An error occurred while shows data from $tableName: $e');
    }
  }

  /// Retrieves and prints all rows from the specified table in the database.
  ///
  /// This method performs a query on the given [tableName] and prints each row
  /// to the console for debugging or inspection purposes.
  ///
  /// Parameters:
  ///   [tableName] - The name of the database table to query.
  ///
  /// Throws:
  ///   Catches and logs any exceptions that might occur during the database query.
  ///
  /// Returns:
  ///   A [Future] that completes when all rows have been printed.
  Future<void> printAllInTable(String tableName) async {
    try {
      final data = await db.query(tableName);
      for (var row in data) {
        LOGS.console(row); // Process each row as needed
      }
    } catch (e) {
      LOGS.error('An error occurred while shows data from $tableName: $e');
    }
  }

  /// Returns a random row from the specified table.
  ///
  /// This method queries the database to fetch a single random row from the specified [tableName].
  /// It uses SQLite's RANDOM() function to order the results randomly and limits the query to just 1 row.
  ///
  /// Parameters:
  ///   [tableName] - The name of the table to query from.
  ///
  /// Returns:
  ///   A [Future] that resolves to a [Map<String, dynamic>] representing the random row,
  ///   or `null` if the table is empty.
  ///
  /// Example:
  ///   ```dart
  ///   final randomProduct = await database.getRandomRow('products');
  ///   if (randomProduct != null) {
  ///     print('Random product: ${randomProduct['name']}');
  ///   }
  ///   ```
  Future<Map<String, dynamic>?> getRandomRow(String tableName) async {
    final List<Map<String, dynamic>> result = await db.query(
      tableName,
      orderBy: 'RANDOM()',
      limit: 1,
    );

    // Return the first (and only) result, or null if the table is empty
    return result.isNotEmpty ? result.first : null;
  }

  /// Get a specified number of random rows from a table.
  ///
  /// This method retrieves [count] random rows from the table specified by [tableName].
  /// The rows are selected using SQLite's RANDOM() function to ensure randomness.
  ///
  /// Parameters:
  ///   - [tableName]: The name of the table to query.
  ///   - [count]: The maximum number of rows to retrieve.
  ///
  /// Returns:
  ///   A [Future] that resolves to a [List] of [Map<String, dynamic>] representing the rows.
  ///
  /// Example:
  ///   ```dart
  ///   final randomProducts = await getRandomRows('products', 5);
  ///   ```
  Future<List<Map<String, dynamic>>> getRandomRows(
    String tableName,
    int count,
  ) async {
    final List<Map<String, dynamic>> result = await db.query(
      tableName,
      orderBy: 'RANDOM()',
      limit: count,
    );

    return result;
  }

  /// Inserts data into a specified table in the database.
  ///
  /// Takes a [tableName] which is the name of the table to insert data into,
  /// and a [data] map containing column names as keys and values to be inserted.
  ///
  /// Uses the [ConflictAlgorithm.replace] strategy to handle conflicts,
  /// which replaces existing rows with the same primary key.
  ///
  /// Catches and logs any errors that occur during the insertion process.
  ///
  /// Example:
  /// ```dart
  /// await insertData('users', {
  ///   'id': 1,
  ///   'name': 'John Doe',
  ///   'email': 'john@example.com'
  /// });
  /// ```
  Future<void> insertNewData(tableName, Map<String, dynamic> data) async {
    try {
      await db.insert(
        tableName,
        data,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      // error-handling
      LOGS.error('An error occurred while inserting data: $e');
    }
  }

  /// Retrieves all records from the specified table in the database.
  ///
  /// This method queries the database for all rows in the table specified by [tableName].
  ///
  /// Parameters:
  ///   - [tableName]: The name of the table to query.
  ///
  /// Returns:
  ///   A [Future] that completes with a list of maps where each map represents a row
  ///   in the table. Each map's keys correspond to column names and values to the row values.
  ///   Returns an empty list if an error occurs during the query.
  ///
  /// Throws:
  ///   No exceptions are thrown as they are caught internally and logged to the console.
  Future<List<Map<String, dynamic>>> fetchAllData(String tableName) async {
    try {
      return await db.query(tableName);
    } catch (e) {
      // error-handling
      LOGS.error('An error occurred while fetching data: $e');
      return [];
    }
  }

  /// Retrieves a single record from the database by its ID.
  ///
  /// This method queries the specified [tableName] for a row that matches the given [id].
  ///
  /// Parameters:
  ///   - [tableName]: The name of the table to query.
  ///   - [id]: The ID value to search for.
  ///
  /// Returns:
  ///   A [Future] that resolves to a [Map<String, dynamic>] containing the row data,
  ///   or `null` if no record with the specified ID exists or an error occurs.
  ///
  /// Example:
  ///   ```dart
  ///   final user = await fetchOneById('users', 5);
  ///   if (user != null) {
  ///     print('Found user: ${user['name']}');
  ///   }
  ///   ```
  Future<Map<String, dynamic>?> fetchOneById(
    String tableName,
    dynamic id,
  ) async {
    try {
      final List<Map<String, dynamic>> result = await db.query(
        tableName,
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );

      return result.isNotEmpty ? result.first : null;
    } catch (e) {
      LOGS.error('An error occurred while fetching data by ID: $e');
      return null;
    }
  }

  /// Retrieves values from a single column in the specified table.
  ///
  /// This method executes a query to fetch only the specified column from all rows
  /// in the given table, providing an efficient way to retrieve a list of values
  /// from a single field.
  ///
  /// Parameters:
  ///   - [tableName]: The name of the table to query.
  ///   - [columnName]: The name of the column to retrieve values from.
  ///   - [where]: Optional WHERE clause to filter the results.
  ///   - [whereArgs]: Optional arguments for the WHERE clause placeholders.
  ///   - [orderBy]: Optional column(s) to sort the results by.
  ///
  /// Returns:
  ///   A [Future] that resolves to a [List] containing all values from the specified column.
  ///   If the column contains null values, those will be included in the result list.
  ///
  /// Example:
  ///   ```dart
  ///   // Get all product names
  ///   final productNames = await getColumnData('products', 'name');
  ///
  ///   // Get email addresses for active users only
  ///   final emails = await getColumnData(
  ///     'users',
  ///     'email',
  ///     where: 'is_active = ?',
  ///     whereArgs: [1]
  ///   );
  ///   ```
  Future<List<dynamic>> getColumnData(
    String tableName,
    String columnName, {
    String? where,
    List<dynamic>? whereArgs,
    String? orderBy,
  }) async {
    try {
      final List<Map<String, dynamic>> result = await db.query(
        tableName,
        columns: [columnName],
        where: where,
        whereArgs: whereArgs,
        orderBy: orderBy,
      );

      // Extract the values from the column
      return result.map((row) => row[columnName]).toList();
    } catch (e) {
      LOGS.error('An error occurred while fetching column data: $e');
      return [];
    }
  }

  /// Creates a new record in the database and returns the inserted record with its ID.
  ///
  /// This method inserts the provided [data] into the specified [tableName] and then
  /// fetches the complete record including any auto-generated fields like the ID.
  ///
  /// Parameters:
  ///   - [tableName]: The name of the table to insert data into.
  ///   - [data]: A map containing column names and values to insert.
  ///
  /// Returns:
  ///   A [Future] that resolves to the complete inserted record as a [Map<String, dynamic>],
  ///   or `null` if the insertion fails or the record cannot be retrieved.
  ///
  /// Example:
  ///   ```dart
  ///   final newData = {'name': 'Product X', 'price': 29.99};
  ///   final insertedRecord = await dbQuery.insertAndRetrieve('products', newData);
  ///   print('New product ID: ${insertedRecord?['id']}');
  ///   ```
  Future<Map<String, dynamic>?> insertAndRetrieve(
    String tableName,
    Map<String, dynamic> data,
  ) async {
    try {
      // Insert the data and get the ID
      final id = await db.insert(
        tableName,
        data,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // Fetch the complete record using the returned ID
      final List<Map<String, dynamic>> result = await db.query(
        tableName,
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );

      return result.isNotEmpty ? result.first : null;
    } catch (e) {
      LOGS.error('Error in insertAndRetrieve: $e');
      return null;
    }
  }

  /// Retrieves all records from a table that match specified conditions.
  ///
  /// This method queries the database for rows in the specified [tableName]
  /// that match the provided WHERE clause conditions.
  ///
  /// Parameters:
  ///   - [tableName]: The name of the table to query.
  ///   - [where]: SQL WHERE clause without the 'WHERE' keyword (e.g., 'age > ?').
  ///   - [whereArgs]: Arguments for the WHERE clause placeholders.
  ///   - [orderBy]: Optional SQL ORDER BY clause without the 'ORDER BY' keywords.
  ///   - [limit]: Maximum number of rows to return.
  ///   - [offset]: Number of rows to skip from the beginning.
  ///
  /// Returns:
  ///   A [Future] that resolves to a list of maps representing the matching rows.
  ///   Returns an empty list if no matches are found or if an error occurs.
  ///
  /// Example:
  ///   ```dart
  ///   final activeUsers = await fetchDataWhere(
  ///     'users',
  ///     'status = ? AND age > ?',
  ///     ['active', 18],
  ///     orderBy: 'username ASC',
  ///     limit: 10
  ///   );
  ///   ```
  ///
  /// output:
  /// ```
  ///   [
  ///       {'id': 1, 'username': 'Alice
  /// ', 'status': 'active', 'age': 25},
  ///      {'id': 2, 'username': 'Bob', 'status': 'active', 'age': 30},
  ///  ... up to 10 records
  /// ]
  /// ```
  ///
  /// Throws:
  ///    Catches and logs any exceptions that might occur during the query.
  Future<List<Map<String, dynamic>>> fetchDataWhere(
    String tableName,
    String where,
    List<dynamic> whereArgs, {
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    try {
      return await db.query(
        tableName,
        where: where,
        whereArgs: whereArgs,
        orderBy: orderBy,
        limit: limit,
        offset: offset,
      );
    } catch (e) {
      LOGS.error('An error occurred while fetching filtered data: $e');
      return [];
    }
  }

  /// Counts the number of rows in a table, optionally filtered by conditions.
  ///
  /// This method executes a COUNT query on the specified table and returns the result.
  ///
  /// Parameters:
  ///   - [tableName]: The name of the table to count rows from.
  ///   - [where]: Optional WHERE clause for filtering (without 'WHERE' keyword).
  ///   - [whereArgs]: Arguments for the WHERE clause placeholders.
  ///
  /// Returns:
  ///   A [Future<int>] representing the number of rows that match the conditions.
  ///   Returns 0 if an error occurs.
  ///
  /// Example:
  ///   ```dart
  ///   // Count all products
  ///   final totalProducts = await countRows('products');
  ///
  ///   // Count products in a specific category
  ///   final activeProducts = await countRows(
  ///     'products',
  ///     'category_id = ? AND is_active = ?',
  ///     [5, 1]
  ///   );
  ///   ```
  Future<int> countRows(
    String tableName, {
    String? where,
    List<dynamic>? whereArgs,
  }) async {
    try {
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM $tableName${where != null ? ' WHERE $where' : ''}',
        whereArgs,
      );

      return result.first['count'] as int;
    } catch (e) {
      LOGS.error('Error counting rows in $tableName: $e');
      return 0;
    }
  }

  /// Retrieves specific columns from a record with the given ID.
  ///
  /// This method allows you to fetch only the columns you're interested in
  /// from a single record, which can improve performance when dealing with
  /// tables that have many columns or BLOB data you don't always need.
  ///
  /// Parameters:
  ///   - [tableName]: The name of the table to query.
  ///   - [id]: The ID of the record to retrieve.
  ///   - [columns]: A list of column names to retrieve. If null or empty, all columns will be fetched.
  ///
  /// Returns:
  ///   A [Future] that resolves to a [Map<String, dynamic>] containing the requested column data,
  ///   or `null` if no record with the specified ID exists or an error occurs.
  ///
  /// Example:
  ///   ```dart
  ///   // Get only name and email from user with ID 5
  ///   final userData = await fetchColumnsById('users', 5, ['name', 'email']);
  ///   ```
  Future<Map<String, dynamic>?> fetchCustomById(
    String tableName,
    dynamic id,
    List<String>? columns,
  ) async {
    try {
      final List<Map<String, dynamic>> result = await db.query(
        tableName,
        columns: columns?.isNotEmpty == true ? columns : null,
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );

      return result.isNotEmpty ? result.first : null;
    } catch (e) {
      LOGS.error('An error occurred while fetching columns by ID: $e');
      return null;
    }
  }

  /// Updates a record in the database with new data
  ///
  /// Takes a [tableName] string, [id] of the record to update, and [newData] map containing
  /// column values to update in the record.
  ///
  /// Executes an SQL UPDATE operation on the specified table where id matches.
  /// Any errors during the update operation are caught and printed to the console.
  ///
  /// Example usage:
  /// ```dart
  /// await dbInstance.updateData('users', 5, {'name': 'John', 'email': 'john@example.com'});
  /// ```
  Future<void> updateData(
    tableName,
    whereCol,
    Map<String, dynamic> newData, {
    String whereColName = "id",
  }) async {
    try {
      await db.update(
        tableName,
        newData,
        where: '$whereColName=?',
        whereArgs: [whereCol],
      );
    } catch (e) {
      // error-handling
      LOGS.error('An error occurred while updating data: $e');
    }
  }

  /// Updates a single cell in a database table.
  ///
  /// This method allows updating a specific column value for a record identified by its ID.
  /// It's useful when you only need to change one field without updating the entire record.
  ///
  /// Parameters:
  ///   - [tableName]: The name of the table containing the record to update.
  ///   - [id]: The ID of the record to update.
  ///   - [columnName]: The name of the column to update.
  ///   - [value]: The new value to set for the specified column.
  ///
  /// Returns:
  ///   A [Future] that completes when the update operation is finished.
  ///
  /// Throws:
  ///   Prints error message if the update operation fails but doesn't rethrow the exception.
  ///
  /// Example:
  ///   ```dart
  ///   await updateCell('products', 42, 'in_stock', 0);
  ///   ```
  Future<void> updateCell(
    String tableName,
    dynamic id,
    String columnName,
    dynamic value,
  ) async {
    try {
      await db.update(
        tableName,
        {columnName: value},
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      LOGS.error('An error occurred while updating cell data: $e');
    }
  }

  /// Deletes a record from the specified table based on its ID.
  ///
  /// Parameters:
  ///   [tableName] - The name of the table to delete from.
  ///   [id] - The ID of the record to delete.
  ///
  /// Throws:
  ///   Prints error message if deletion operation fails but doesn't rethrow the exception.
  ///
  /// Example:
  ///   ```dart
  ///   await deleteData('users', 5);
  ///   ```
  Future<void> deleteRowData(tableName, id) async {
    try {
      await db.delete(tableName, where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      // error-handling
      LOGS.error('An error occurred while deleting data: $e');
    }
  }
}
