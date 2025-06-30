import '../configs/configs.dart';
import '../components/toastmsg.dart';
import '../services/database/db.dart';
import '../services/inventory/inventory_services.dart';
import '../services/connection/bluetooth.dart';
import '../services/connection/usb.dart';

class DebugPage extends StatefulWidget {
  final ValueNotifier<int> reloadNotifier;
  const DebugPage({super.key, required this.reloadNotifier});

  @override
  State<DebugPage> createState() => _DebugPageState();
}

class _DebugPageState extends State<DebugPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _tableSearchController = TextEditingController();
  final TextEditingController _sqlQueryController = TextEditingController();

  // For global variables inspection
  final Map<String, dynamic> _globalVariables = {};

  // For database inspection
  List<String> _tables = [];
  String? _selectedTable;
  List<Map<String, dynamic>> _tableData = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadDatabaseTables();
    widget.reloadNotifier.addListener(() async {
      await _loadGlobalVariables();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _tableSearchController.dispose();
    _sqlQueryController.dispose();
    super.dispose();
    widget.reloadNotifier.removeListener(_loadGlobalVariables);
  }

  Future<void> _loadGlobalVariables() async {
    // Collect global variables from various files

    List<Map<String, dynamic>> getAllProductsSet =
        await inventory.getAllProductsAndSets();

    setState(() {
      _globalVariables['appConfig'] = globalAppConfig;
      _globalVariables['theme'] =
          "#${globalAppConfig['userPreferences']['theme']} (${Theme.of(context).brightness})";
      // _globalVariables['log'] = APP_LOGS;
      // _globalVariables['localization'] = LOCALIZATION;
      // _globalVariables['inventory'] = inventory;
      _globalVariables['DEBUG'] = DEBUG;
      _globalVariables['canVibrate'] = canVibrate;
      // _globalVariables['test_set_parsing'] =
      //     getAllProductsSet[getAllProductsSet.length - 1];
    });
  }

  Future<void> _loadDatabaseTables() async {
    setState(() => _isLoading = true);
    try {
      final dbQuery = DatabaseQuery(db: DB, LOGS: APP_LOGS);
      final result = await dbQuery.getTableNames();
      setState(() {
        _tables = result;
        _isLoading = false;
      });
    } catch (e) {
      APP_LOGS.error('Failed to load database tables: $e');
      showToastMessage(
        context,
        'Failed to load database tables',
        ToastLevel.error,
      );
      setState(() => _isLoading = false);
    }
  }

  Future<void> _queryTable(String tableName) async {
    setState(() {
      _isLoading = true;
      _selectedTable = tableName;
    });

    try {
      final dbQuery = DatabaseQuery(db: DB, LOGS: APP_LOGS);
      final data = await dbQuery.fetchAllData(tableName);
      setState(() {
        _tableData = data;
        _isLoading = false;
      });
    } catch (e) {
      APP_LOGS.error('Failed to query table $tableName: $e');
      showToastMessage(
        context,
        'Failed to query table $tableName',
        ToastLevel.error,
      );
      setState(() => _isLoading = false);
    }
  }

  Future<void> _executeCustomQuery() async {
    if (_sqlQueryController.text.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final dbQuery = DatabaseQuery(db: DB, LOGS: APP_LOGS);
      final data = await dbQuery.query(_sqlQueryController.text);
      setState(() {
        _selectedTable = "Custom Query";
        _tableData = data;
        _isLoading = false;
      });
    } catch (e) {
      APP_LOGS.error('SQL query error: $e');
      showToastMessage(context, 'SQL query error: $e', ToastLevel.error);
      setState(() => _isLoading = false);
    }
  }

  Widget _buildGlobalVariablesTab() {
    final theme = Theme.of(context);
    ;

    final appConfigMap =
        _globalVariables['appConfig'] is Map
            ? _globalVariables['appConfig'] as Map
            : null;
    final ValueNotifier<String?> expandedKey = ValueNotifier<String?>(null);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Global Variables Inspector',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          ElevatedButton.icon(
            onPressed: _loadGlobalVariables,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh Variables'),
          ),
          const SizedBox(height: 16),

          // Password Decryptor UI
          StatefulBuilder(
            builder: (context, setState) {
              final TextEditingController _decryptController =
                  TextEditingController();
              final ValueNotifier<String?> _decryptedPassword =
                  ValueNotifier<String?>(null);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Decrypt Password',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _decryptController,
                          decoration: const InputDecoration(
                            labelText: 'Encrypted Password',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () async {
                          final encrypted = _decryptController.text.trim();
                          if (encrypted.isEmpty) return;
                          final result = await decryptPassword(encrypted);
                          _decryptedPassword.value =
                              result is String ? result : 'Failed to decrypt';
                        },
                        child: const Text('Decrypt'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ValueListenableBuilder<String?>(
                    valueListenable: _decryptedPassword,
                    builder: (context, value, _) {
                      if (value == null) return const SizedBox.shrink();
                      return SelectableText(
                        'Decrypted: $value',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontFamily: 'monospace',
                          color: theme.colorScheme.secondary,
                        ),
                      );
                    },
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),

          Expanded(
            child: Row(
              children: [
                // Left: appConfig vertical tab
                if (appConfigMap != null)
                  Container(
                    width: 200,
                    decoration: BoxDecoration(
                      border: Border(
                        right: BorderSide(color: theme.dividerColor, width: 1),
                      ),
                    ),
                    child: Scrollbar(
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: ValueListenableBuilder<String?>(
                          valueListenable: expandedKey,
                          builder: (context, selectedKey, _) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(
                                    'appConfig',
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: theme.colorScheme.primary,
                                        ),
                                  ),
                                ),
                                ...appConfigMap.keys.map<Widget>((k) {
                                  final isSelected = selectedKey == k;
                                  return Material(
                                    color:
                                        isSelected
                                            ? theme.colorScheme.primary
                                                .withOpacity(0.12)
                                            : Colors.transparent,
                                    child: InkWell(
                                      onTap: () {
                                        expandedKey.value =
                                            isSelected ? null : k.toString();
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 14,
                                          horizontal: 12,
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                k.toString(),
                                                style: theme
                                                    .textTheme
                                                    .bodyMedium
                                                    ?.copyWith(
                                                      fontWeight:
                                                          isSelected
                                                              ? FontWeight.bold
                                                              : FontWeight
                                                                  .normal,
                                                      color:
                                                          isSelected
                                                              ? theme
                                                                  .colorScheme
                                                                  .primary
                                                              : null,
                                                    ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            Icon(
                                              isSelected
                                                  ? Icons.keyboard_arrow_down
                                                  : Icons.keyboard_arrow_right,
                                              size: 18,
                                              color:
                                                  isSelected
                                                      ? theme
                                                          .colorScheme
                                                          .primary
                                                      : theme.iconTheme.color,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                // Right: Main content (split into appConfig section and other globals)
                Expanded(
                  child: ValueListenableBuilder<String?>(
                    valueListenable: expandedKey,
                    builder: (context, selectedKey, _) {
                      final otherKeys =
                          _globalVariables.keys
                              .where((k) => k != 'appConfig')
                              .toList();
                      return SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 8.0,
                            horizontal: 8.0,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Section: appConfig details
                              Card(
                                elevation: 2,
                                margin: const EdgeInsets.only(bottom: 24),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'appConfig',
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: theme.colorScheme.primary,
                                            ),
                                      ),
                                      const SizedBox(height: 8),
                                      selectedKey == null
                                          ? Text(
                                            'Select a key from appConfig to inspect its value.',
                                            style: theme.textTheme.bodyMedium,
                                          )
                                          : Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                selectedKey,
                                                style: theme
                                                    .textTheme
                                                    .titleSmall
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                              ),
                                              const SizedBox(height: 8),

                                              Container(
                                                constraints:
                                                    const BoxConstraints(
                                                      minHeight: 60,
                                                      maxHeight: 300,
                                                      minWidth: 300,
                                                      maxWidth: 900,
                                                    ),
                                                child: Scrollbar(
                                                  thumbVisibility: true,
                                                  child: SingleChildScrollView(
                                                    scrollDirection:
                                                        Axis.vertical,
                                                    child: SingleChildScrollView(
                                                      scrollDirection:
                                                          Axis.horizontal,
                                                      child: SelectableText(
                                                        appConfigMap![selectedKey]
                                                                    is Map ||
                                                                appConfigMap[selectedKey]
                                                                    is List
                                                            ? APP_LOGS.map2str(
                                                              appConfigMap[selectedKey],
                                                            )
                                                            : appConfigMap[selectedKey]
                                                                .toString(),
                                                        style: theme
                                                            .textTheme
                                                            .bodyMedium
                                                            ?.copyWith(
                                                              fontFamily:
                                                                  'monospace',
                                                            ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 12),

                                              Row(
                                                children: [
                                                  ElevatedButton.icon(
                                                    icon: const Icon(
                                                      Icons.copy,
                                                    ),
                                                    label: const Text(
                                                      'Copy Value',
                                                    ),
                                                    onPressed: () {
                                                      final value =
                                                          appConfigMap[selectedKey];
                                                      Clipboard.setData(
                                                        ClipboardData(
                                                          text:
                                                              value is Map ||
                                                                      value
                                                                          is List
                                                                  ? APP_LOGS
                                                                      .map2str(
                                                                        value,
                                                                      )
                                                                  : value
                                                                      .toString(),
                                                        ),
                                                      );
                                                      showToastMessage(
                                                        context,
                                                        'Value copied to clipboard',
                                                        ToastLevel.info,
                                                      );
                                                    },
                                                  ),
                                                  const SizedBox(width: 8),
                                                  ElevatedButton.icon(
                                                    icon: const Icon(
                                                      Icons.bug_report,
                                                    ),
                                                    label: const Text(
                                                      'Log to Console',
                                                    ),
                                                    onPressed: () {
                                                      APP_LOGS.console(
                                                        appConfigMap[selectedKey],
                                                      );
                                                      showToastMessage(
                                                        context,
                                                        'Logged appConfig.$selectedKey to console',
                                                        ToastLevel.info,
                                                      );
                                                    },
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                    ],
                                  ),
                                ),
                              ),
                              // Section: Other global variables
                              Card(
                                elevation: 2,
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Other Global Variables',
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                      const SizedBox(height: 8),
                                      ListView.separated(
                                        shrinkWrap: true,
                                        physics:
                                            const NeverScrollableScrollPhysics(),
                                        itemCount: otherKeys.length,
                                        separatorBuilder:
                                            (_, __) => const Divider(),
                                        itemBuilder: (context, idx) {
                                          final key = otherKeys[idx];
                                          final value = _globalVariables[key];
                                          return ListTile(
                                            title: Text(
                                              key,
                                              style: theme.textTheme.titleSmall
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                            ),
                                            subtitle: SelectableText(
                                              value is Map || value is List
                                                  ? APP_LOGS.map2str(value)
                                                  : value.toString(),
                                              style: theme.textTheme.bodyMedium
                                                  ?.copyWith(
                                                    fontFamily: 'monospace',
                                                  ),
                                            ),
                                            onTap: () {
                                              APP_LOGS.console(value);
                                              showToastMessage(
                                                context,
                                                'Logged $key to console',
                                                ToastLevel.info,
                                              );
                                            },
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to get database information
  Future<Map<String, dynamic>> _getDatabaseInfo() async {
    final result = <String, dynamic>{};

    try {
      // Get database size
      final size = await DatabaseConnection.getDatabaseSize(dbName: DBNAME);

      result['location'] = DB;
      result['size'] = size;
    } catch (e) {
      APP_LOGS.error('Error getting database info: $e');
      result['location'] = 'Error: $e';
      result['size'] = 'Unknown';
    }

    return result;
  }

  Widget _buildDatabaseTab() {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left column - Controls and tables list
          Expanded(
            flex: 1,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Database Inspector',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Database info section
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: FutureBuilder<Map<String, dynamic>>(
                        future: _getDatabaseInfo(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          final info =
                              snapshot.data ??
                              {'location': 'Unknown', 'size': 'Unknown'};
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Database Information',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              RichText(
                                text: TextSpan(
                                  style: theme.textTheme.bodyMedium,
                                  children: [
                                    const TextSpan(
                                      text: 'Location: ',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    TextSpan(text: '${info['location']}'),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 4),
                              RichText(
                                text: TextSpan(
                                  style: theme.textTheme.bodyMedium,
                                  children: [
                                    const TextSpan(
                                      text: 'Size: ',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    TextSpan(text: '${info['size']}'),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _loadDatabaseTables,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh Tables'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 40),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Database Tables:',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 200, // Fixed height for the tables list
                    child:
                        _isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : ListView.builder(
                              shrinkWrap: true,
                              itemCount: _tables.length,
                              itemBuilder: (context, index) {
                                final tableName = _tables[index];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 4.0),
                                  child: ElevatedButton(
                                    onPressed: () => _queryTable(tableName),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          _selectedTable == tableName
                                              ? theme.colorScheme.primary
                                              : Colors.white,
                                      foregroundColor:
                                          _selectedTable == tableName
                                              ? theme.colorScheme.onPrimary
                                              : theme.colorScheme.primary,
                                    ),
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(tableName),
                                    ),
                                  ),
                                );
                              },
                            ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),

          const SizedBox(width: 16),

          // Right column - Table data display
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _sqlQueryController,
                        decoration: InputDecoration(
                          labelText: 'Custom SQL Query',
                          hintText: 'SELECT * FROM table_name',
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          isDense: true,
                          filled: true,
                        ),
                        maxLines: 1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _executeCustomQuery,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Run'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  _selectedTable != null
                      ? 'Table: $_selectedTable'
                      : 'Table Data',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child:
                      _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : _selectedTable == null
                          ? Center(
                            child: Text(
                              'Select a table to view data',
                              style: theme.textTheme.bodyLarge,
                            ),
                          )
                          : _tableData.isEmpty
                          ? Center(
                            child: Text(
                              'No data in this table',
                              style: theme.textTheme.bodyLarge,
                            ),
                          )
                          : Card(
                            elevation: 4,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.vertical,
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  headingRowColor: MaterialStateProperty.all(
                                    theme.colorScheme.primaryContainer,
                                  ),
                                  dataRowColor:
                                      MaterialStateProperty.resolveWith<Color>((
                                        Set<MaterialState> states,
                                      ) {
                                        if (states.contains(
                                          MaterialState.selected,
                                        )) {
                                          return theme.colorScheme.primary
                                              .withOpacity(0.1);
                                        }
                                        return states.contains(
                                              MaterialState.hovered,
                                            )
                                            ? theme.colorScheme.surfaceVariant
                                            : (states.any(
                                                  (s) =>
                                                      s ==
                                                      MaterialState.pressed,
                                                )
                                                ? theme
                                                    .colorScheme
                                                    .secondaryContainer
                                                : Colors.transparent);
                                      }),
                                  columns:
                                      _tableData.first.keys
                                          .map(
                                            (key) => DataColumn(
                                              label: Text(
                                                key,
                                                style: theme
                                                    .textTheme
                                                    .titleSmall
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                              ),
                                            ),
                                          )
                                          .toList(),
                                  rows:
                                      _tableData
                                          .map(
                                            (row) => DataRow(
                                              cells:
                                                  row.values
                                                      .map(
                                                        (value) => DataCell(
                                                          Text(
                                                            '$value',
                                                            style:
                                                                theme
                                                                    .textTheme
                                                                    .bodyMedium,
                                                          ),
                                                        ),
                                                      )
                                                      .toList(),
                                            ),
                                          )
                                          .toList(),
                                ),
                              ),
                            ),
                          ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogsWatcherTab() {
    final theme = Theme.of(context);
    final List<FileSystemEntity> logFiles = [];
    bool isLoadingLogs = true;
    String? selectedLogContent;
    String? selectedLogName;
    String? selectedLogPath;

    return StatefulBuilder(
      builder: (context, setState) {
        // Function to load log files
        void loadLogFiles() async {
          setState(() => isLoadingLogs = true);
          try {
            final Directory appDocDir =
                await getApplicationDocumentsDirectory();
            final String logDirPath = '${appDocDir.path}/logs';
            final Directory logDir = Directory(logDirPath);

            if (await logDir.exists()) {
              List<FileSystemEntity> files = await logDir.list().toList();
              files =
                  files
                      .where(
                        (file) =>
                            file.path.endsWith('.txt') ||
                            file.path.endsWith('.log') ||
                            !file.path.contains('.'),
                      )
                      .toList();

              setState(() {
                logFiles.clear();
                logFiles.addAll(files);
                isLoadingLogs = false;
              });
            } else {
              setState(() {
                logFiles.clear();
                isLoadingLogs = false;
              });
            }
          } catch (e) {
            APP_LOGS.error('Failed to load log files: $e');
            setState(() => isLoadingLogs = false);
          }
        }

        // Function to view a log file
        void viewLogFile(FileSystemEntity file) async {
          setState(() => isLoadingLogs = true);
          try {
            final content = await File(file.path).readAsString();
            setState(() {
              selectedLogContent = content;
              selectedLogName = file.path.split('/').last;
              selectedLogPath = file.path;
              isLoadingLogs = false;
            });
          } catch (e) {
            APP_LOGS.error('Failed to read log file: $e');
            setState(() {
              selectedLogContent = 'Error reading log file: $e';
              selectedLogName = file.path.split('/').last;
              selectedLogPath = file.path;
              isLoadingLogs = false;
            });
          }
        }

        // Function to clear a log file
        void clearLogFile() async {
          if (selectedLogPath == null) return;

          // Show confirmation dialog
          final confirmed =
              await showDialog<bool>(
                context: context,
                builder:
                    (context) => AlertDialog(
                      title: const Text('Clear Log File'),
                      content: Text(
                        'Are you sure you want to clear the log file "$selectedLogName"?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: const Text('Clear'),
                        ),
                      ],
                    ),
              ) ??
              false;

          if (!confirmed) return;

          try {
            await File(selectedLogPath!).writeAsString('');
            setState(() {
              selectedLogContent = '';
            });
            showToastMessage(
              context,
              '$selectedLogName cleared successfully',
              ToastLevel.success,
            );
          } catch (e) {
            APP_LOGS.error('Failed to clear log file: $e');
            showToastMessage(
              context,
              'Failed to clear $selectedLogName',
              ToastLevel.error,
            );
          }
        }

        // Load logs when tab is initialized
        if (logFiles.isEmpty && isLoadingLogs) {
          loadLogFiles();
        }

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left column - Log files list
              Expanded(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Logs Watcher',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: loadLogFiles,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Refresh Logs'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 40),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Available Log Files:',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child:
                          isLoadingLogs
                              ? const Center(child: CircularProgressIndicator())
                              : logFiles.isEmpty
                              ? Center(child: Text('No log files found'))
                              : ListView.builder(
                                itemCount: logFiles.length,
                                itemBuilder: (context, index) {
                                  final file = logFiles[index];
                                  final fileName = file.path.split('/').last;
                                  return ListTile(
                                    title: Text(fileName),
                                    leading: const Icon(Icons.description),
                                    selected: selectedLogName == fileName,
                                    onTap: () => viewLogFile(file),
                                    tileColor:
                                        selectedLogName == fileName
                                            ? theme.colorScheme.primaryContainer
                                            : null,
                                  );
                                },
                              ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 16),

              // Right column - Log content display
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          selectedLogName != null
                              ? 'Log: $selectedLogName'
                              : 'Log Content',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (selectedLogContent != null)
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: clearLogFile,
                                tooltip: 'Clear log file',
                                color: theme.colorScheme.error,
                              ),
                              IconButton(
                                icon: const Icon(Icons.copy),
                                onPressed: () {
                                  Clipboard.setData(
                                    ClipboardData(text: selectedLogContent!),
                                  );
                                  showToastMessage(
                                    context,
                                    'Log copied to clipboard',
                                    ToastLevel.info,
                                  );
                                },
                                tooltip: 'Copy log to clipboard',
                              ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child:
                          isLoadingLogs
                              ? const Center(child: CircularProgressIndicator())
                              : selectedLogContent == null
                              ? Center(
                                child: Text(
                                  'Select a log file to view',
                                  style: theme.textTheme.bodyLarge,
                                ),
                              )
                              : Card(
                                elevation: 4,
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: SingleChildScrollView(
                                    child: Text(
                                      selectedLogContent!,
                                      style: const TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildConnectionTab() {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Connection Inspector',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          GridView.count(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 2.5,
            children: [
              // Bluetooth Connection Section with Status
              StreamBuilder<bool>(
                stream: btPrinter?.checkBluetoothStateStream(),
                builder: (context, snapshot) {
                  final isBluetoothOn = snapshot.data ?? false;
                  return _buildConnectionCard(
                    icon: Icons.bluetooth,
                    title: 'Bluetooth',
                    description:
                        isBluetoothOn ? 'Bluetooth is ON' : 'Bluetooth is OFF',
                    buttonLabel: 'Test',
                    buttonIcon: Icons.bluetooth_searching,
                    statusColor: isBluetoothOn ? Colors.green : Colors.red,
                    onPressed: () async {
                      try {
                        final isEnabled =
                            await btPrinter?.bluetoothTestingDialog(context) ??
                            false;
                        if (isEnabled) {
                          showToastMessage(
                            context,
                            'Bluetooth is enabled and ready',
                            ToastLevel.success,
                          );
                        } else {
                          showToastMessage(
                            context,
                            'Bluetooth test canceled or failed',
                            ToastLevel.warning,
                          );
                        }
                      } catch (e) {
                        showToastMessage(
                          context,
                          'Bluetooth error: $e',
                          ToastLevel.error,
                        );
                        APP_LOGS.error('Bluetooth error: $e');
                      }
                    },
                  );
                },
              ),

              // Wi-Fi Connection Management
              _buildConnectionCard(
                icon: Icons.wifi,
                title: 'Wi-Fi',
                description: 'Wi-Fi connection management',
                buttonLabel: 'Not Implemented',
                buttonIcon: Icons.settings,
                onPressed: null,
              ),

              // USB Connection Section with Status
              Builder(
                builder: (context) {
                  final bool isUsbInitialized =
                      USB != null && USB!.isInitialized;
                  return _buildConnectionCard(
                    icon: Icons.usb,
                    title: 'USB',
                    description:
                        isUsbInitialized
                            ? 'USB Manager initialized'
                            : 'USB Manager not initialized',
                    buttonLabel: 'Manage',
                    buttonIcon: Icons.settings,
                    statusColor: isUsbInitialized ? Colors.green : Colors.red,
                    onPressed: () async {
                      if (USB == null) {
                        // Initialize USB Manager if not already done
                        await checkPermissionsAndInitUsb(context);
                        setState(() {}); // Refresh UI after initialization
                        showToastMessage(
                          context,
                          'USB Manager initialized',
                          ToastLevel.info,
                        );
                      } else {
                        // Show USB device management dialog
                        try {
                          final selectedDevice = await USB!
                              .showUsbManagementDialog(context);
                          if (selectedDevice != null) {
                            showToastMessage(
                              context,
                              'USB device selected: ${selectedDevice['deviceName']}',
                              ToastLevel.success,
                            );
                          }
                        } catch (e) {
                          showToastMessage(
                            context,
                            'USB error: $e',
                            ToastLevel.error,
                          );
                          APP_LOGS.error('USB error: $e');
                        }
                      }
                    },
                  );
                },
              ),

              // Network Connectivity Diagnostics
              _buildConnectionCard(
                icon: Icons.language,
                title: 'Network',
                description: 'Network connectivity diagnostics',
                buttonLabel: 'Not Implemented',
                buttonIcon: Icons.settings,
                onPressed: null,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Cash Drawer Control Card
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.point_of_sale,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Cash Drawer Controls',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            if (USB == null || !USB!.isInitialized) {
                              showToastMessage(
                                context,
                                'USB Manager not initialized',
                                ToastLevel.warning,
                              );
                              return;
                            }

                            try {
                              var drawer = await USB!.openCashDrawer();
                              final drawerOpened = drawer.$1;
                              if (drawerOpened) {
                                showToastMessage(
                                  context,
                                  'Cash drawer opened successfully',
                                  ToastLevel.success,
                                );
                              } else {
                                showToastMessage(
                                  context,
                                  'Failed to open cash drawer',
                                  ToastLevel.warning,
                                );
                              }
                            } catch (e) {
                              showToastMessage(
                                context,
                                'Error opening cash drawer: $e',
                                ToastLevel.error,
                              );
                              APP_LOGS.error('Cash drawer error: $e');
                            }
                          },
                          icon: const Icon(Icons.open_in_browser),
                          label: const Text('Open Cash Drawer'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: theme.colorScheme.onPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            if (USB == null || !USB!.isInitialized) {
                              showToastMessage(
                                context,
                                'USB Manager not initialized',
                                ToastLevel.warning,
                              );
                              return;
                            }

                            final hasCashDrawer =
                                await USB!.isCashDrawerConnected();
                            showToastMessage(
                              context,
                              hasCashDrawer
                                  ? 'Cash drawer detected'
                                  : 'No cash drawer detected',
                              hasCashDrawer
                                  ? ToastLevel.success
                                  : ToastLevel.warning,
                            );
                          },
                          icon: const Icon(Icons.search),
                          label: const Text('Detect Drawer'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.surfaceVariant,
                            foregroundColor: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Connected Devices Section - Now with real device data
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Connected USB Devices',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: USB?.refreshDeviceList() ?? Future.value([]),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      } else if (snapshot.hasError) {
                        return Text('Error: ${snapshot.error}');
                      } else if (snapshot.data == null ||
                          snapshot.data!.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: Text('No USB devices connected'),
                        );
                      }

                      // Display connected devices in a list
                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: snapshot.data!.length,
                        itemBuilder: (context, index) {
                          final device = snapshot.data![index];
                          return ListTile(
                            dense: true,
                            leading: Icon(
                              device['isCashDrawer'] == true
                                  ? Icons.point_of_sale
                                  : Icons.usb,
                              color:
                                  device['isConnected'] == true
                                      ? theme.colorScheme.primary
                                      : Colors.grey,
                            ),
                            title: Text(
                              device['deviceName'] ?? 'Unknown Device',
                              style: theme.textTheme.titleSmall,
                            ),
                            subtitle: Text(
                              'VID: ${device['vendorId']?.toRadixString(16) ?? 'N/A'}, '
                              'PID: ${device['productId']?.toRadixString(16) ?? 'N/A'}',
                              style: theme.textTheme.bodySmall,
                            ),
                            trailing:
                                device['isConnected'] == true
                                    ? const Icon(
                                      Icons.link,
                                      color: Colors.green,
                                      size: 16,
                                    )
                                    : null,
                            onTap: () async {
                              try {
                                if (device['isConnected'] == true) {
                                  showToastMessage(
                                    context,
                                    'Device already connected',
                                    ToastLevel.info,
                                  );
                                } else {
                                  final connected = await USB!.connectToDevice(
                                    device['deviceId'],
                                  );
                                  if (connected) {
                                    setState(() {}); // Refresh UI
                                    showToastMessage(
                                      context,
                                      'Connected to ${device['deviceName']}',
                                      ToastLevel.success,
                                    );
                                  } else {
                                    showToastMessage(
                                      context,
                                      'Failed to connect to device',
                                      ToastLevel.error,
                                    );
                                  }
                                }
                              } catch (e) {
                                showToastMessage(
                                  context,
                                  'Connection error: $e',
                                  ToastLevel.error,
                                );
                              }
                            },
                          );
                        },
                      );
                    },
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () {
                        setState(() {}); // This will refresh the FutureBuilder
                      },
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Refresh'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper method remains the same...
  Widget _buildConnectionCard({
    required IconData icon,
    required String title,
    required String description,
    required String buttonLabel,
    required IconData buttonIcon,
    required VoidCallback? onPressed,
    Color? statusColor,
  }) {
    final theme = Theme.of(context);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Icon(icon, color: theme.colorScheme.primary, size: 24),
                if (statusColor != null)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: theme.colorScheme.surface,
                          width: 1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    description,
                    style: theme.textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    height: 28,
                    child: ElevatedButton.icon(
                      onPressed: onPressed,
                      icon: Icon(buttonIcon, size: 14),
                      label: Text(
                        buttonLabel,
                        style: const TextStyle(fontSize: 12),
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 0,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    List<Widget> tabs = const [
      Tab(text: 'Global Variables', icon: Icon(Icons.code)),
      Tab(text: 'Database', icon: Icon(Icons.storage)),
      Tab(text: 'Logs Watcher', icon: Icon(Icons.bug_report)),
      Tab(text: 'Connection', icon: Icon(Icons.network_check)),
    ];

    List<Widget> children = [
      _buildGlobalVariablesTab(),
      _buildDatabaseTab(),
      _buildLogsWatcherTab(),
      _buildConnectionTab(),
    ];

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text('Debug & Inspection'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: theme.colorScheme.onPrimary,
          labelColor: theme.colorScheme.onPrimary,
          unselectedLabelColor: theme.colorScheme.onPrimary.withOpacity(0.7),
          tabs: tabs,
        ),
        automaticallyImplyLeading: false, // This removes the back button
        // Optional: Add other AppBar customizations
        centerTitle: true,
      ),
      body: TabBarView(controller: _tabController, children: children),
    );
  }
}
