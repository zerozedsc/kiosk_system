import '../configs/configs.dart';

import '../services/database/db.dart';
import '../services/connection/usb.dart';
import '../services/auth/auth_service.dart';
import '../services/connection/internet.dart';

import '../components/toastmsg.dart';

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
    return GlobalVariablesTab(
      globalVariables: _globalVariables,
      onLoadGlobalVariables: _loadGlobalVariables,
    );
  }

  Widget _buildDatabaseTab() {
    return DatabaseTab(
      tables: _tables,
      isLoading: _isLoading,
      selectedTable: _selectedTable,
      tableData: _tableData,
      sqlQueryController: _sqlQueryController,
      onLoadDatabaseTables: _loadDatabaseTables,
      onQueryTable: _queryTable,
      onExecuteCustomQuery: _executeCustomQuery,
    );
  }

  Widget _buildLogsWatcherTab() {
    return LogsWatcherTab();
  }

  Widget _buildConnectionTab() {
    return ConnectionTab();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    List<Widget> tabs = const [
      Tab(text: 'Variables', icon: Icon(Icons.code, size: 16)),
      Tab(text: 'Database', icon: Icon(Icons.storage, size: 16)),
      Tab(text: 'Logs', icon: Icon(Icons.bug_report, size: 16)),
      Tab(text: 'Connection', icon: Icon(Icons.network_check, size: 16)),
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
        toolbarHeight: 56, // Reduced from default
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48), // Reduced tab height
          child: TabBar(
            controller: _tabController,
            indicatorColor: theme.colorScheme.onPrimary,
            labelColor: theme.colorScheme.onPrimary,
            unselectedLabelColor: theme.colorScheme.onPrimary.withOpacity(0.7),
            tabs: tabs,
            labelStyle: const TextStyle(fontSize: 12), // Smaller font
            unselectedLabelStyle: const TextStyle(fontSize: 12),
            isScrollable: false,
            tabAlignment: TabAlignment.fill,
          ),
        ),
        automaticallyImplyLeading: false,
        centerTitle: true,
      ),
      body: TabBarView(controller: _tabController, children: children),
    );
  }
}

// Separate tab classes for better organization and responsiveness

class GlobalVariablesTab extends StatefulWidget {
  final Map<String, dynamic> globalVariables;
  final VoidCallback onLoadGlobalVariables;

  const GlobalVariablesTab({
    Key? key,
    required this.globalVariables,
    required this.onLoadGlobalVariables,
  }) : super(key: key);

  @override
  State<GlobalVariablesTab> createState() => _GlobalVariablesTabState();
}

class _GlobalVariablesTabState extends State<GlobalVariablesTab> {
  String? _selectedKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appConfigMap =
        widget.globalVariables['appConfig'] is Map
            ? widget.globalVariables['appConfig'] as Map
            : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(theme),
          const SizedBox(height: 12),
          _buildRefreshButton(),
          const SizedBox(height: 12),
          _buildPasswordDecryptor(theme),
          const SizedBox(height: 16),
          if (appConfigMap != null) ...[
            _buildAppConfigSection(theme, appConfigMap),
            const SizedBox(height: 16),
          ],
          _buildOtherVariablesSection(theme),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Text(
      'Global Variables Inspector',
      style: theme.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.bold,
        fontSize: 18, // Smaller title
      ),
    );
  }

  Widget _buildRefreshButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: widget.onLoadGlobalVariables,
        icon: const Icon(Icons.refresh, size: 16),
        label: const Text('Refresh Variables'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 8),
        ),
      ),
    );
  }

  Widget _buildPasswordDecryptor(ThemeData theme) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
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
            _PasswordDecryptorWidget(),
          ],
        ),
      ),
    );
  }

  Widget _buildAppConfigSection(ThemeData theme, Map appConfigMap) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'appConfig',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 600;

                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Keys list on the left
                      SizedBox(
                        width: 200,
                        height: 300,
                        child: _buildAppConfigKeysList(theme, appConfigMap),
                      ),
                      const SizedBox(width: 12),
                      // Details on the right
                      Expanded(
                        child: SizedBox(
                          height: 300,
                          child: _buildAppConfigDetails(theme, appConfigMap),
                        ),
                      ),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      SizedBox(
                        height: 200,
                        child: _buildAppConfigKeysList(theme, appConfigMap),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 200,
                        child: _buildAppConfigDetails(theme, appConfigMap),
                      ),
                    ],
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppConfigKeysList(ThemeData theme, Map appConfigMap) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(4),
      ),
      child: ListView.builder(
        itemCount: appConfigMap.keys.length,
        itemBuilder: (context, index) {
          final key = appConfigMap.keys.elementAt(index).toString();
          final isSelected = _selectedKey == key;

          return Material(
            color:
                isSelected
                    ? theme.colorScheme.primary.withOpacity(0.12)
                    : Colors.transparent,
            child: InkWell(
              onTap:
                  () => setState(() => _selectedKey = isSelected ? null : key),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 12,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        key,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? theme.colorScheme.primary : null,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(
                      isSelected
                          ? Icons.keyboard_arrow_down
                          : Icons.keyboard_arrow_right,
                      size: 16,
                      color:
                          isSelected
                              ? theme.colorScheme.primary
                              : theme.iconTheme.color,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAppConfigDetails(ThemeData theme, Map appConfigMap) {
    if (_selectedKey == null) {
      return Container(
        decoration: BoxDecoration(
          border: Border.all(color: theme.dividerColor),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Center(
          child: Text(
            'Select a key to inspect its value',
            style: theme.textTheme.bodyMedium,
          ),
        ),
      );
    }

    final value = appConfigMap[_selectedKey];
    final valueText =
        value is Map || value is List
            ? APP_LOGS.map2str(value)
            : value.toString();

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceVariant,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(4),
              ),
            ),
            child: Text(
              _selectedKey!,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(8),
              child: SelectableText(
                valueText,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.copy, size: 14),
                    label: const Text('Copy', style: TextStyle(fontSize: 12)),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: valueText));
                      showToastMessage(
                        context,
                        'Value copied to clipboard',
                        ToastLevel.info,
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.bug_report, size: 14),
                    label: const Text('Log', style: TextStyle(fontSize: 12)),
                    onPressed: () {
                      APP_LOGS.console(value);
                      showToastMessage(
                        context,
                        'Logged to console',
                        ToastLevel.info,
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

  Widget _buildOtherVariablesSection(ThemeData theme) {
    final otherKeys =
        widget.globalVariables.keys.where((k) => k != 'appConfig').toList();

    if (otherKeys.isEmpty) return const SizedBox.shrink();

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Other Global Variables',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: otherKeys.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, idx) {
                final key = otherKeys[idx];
                final value = widget.globalVariables[key];
                return ListTile(
                  dense: true,
                  title: Text(
                    key,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    value is Map || value is List
                        ? APP_LOGS.map2str(value)
                        : value.toString(),
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
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
    );
  }
}

class _PasswordDecryptorWidget extends StatefulWidget {
  @override
  State<_PasswordDecryptorWidget> createState() =>
      _PasswordDecryptorWidgetState();
}

class _PasswordDecryptorWidgetState extends State<_PasswordDecryptorWidget> {
  final TextEditingController _decryptController = TextEditingController();
  String? _decryptedPassword;

  @override
  void dispose() {
    _decryptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _decryptController,
                decoration: const InputDecoration(
                  labelText: 'Encrypted Password',
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                ),
                style: const TextStyle(fontSize: 12),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () async {
                final encrypted = _decryptController.text.trim();
                if (encrypted.isEmpty) return;
                try {
                  final result = await EncryptService().decryptPassword(
                    encrypted,
                  );
                  setState(() {
                    _decryptedPassword =
                        result is String ? result : 'Failed to decrypt';
                  });
                } catch (e) {
                  setState(() {
                    _decryptedPassword = 'Error: $e';
                  });
                }
              },
              child: const Text('Decrypt', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
        if (_decryptedPassword != null) ...[
          const SizedBox(height: 8),
          SelectableText(
            'Decrypted: $_decryptedPassword',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontFamily: 'monospace',
              color: Theme.of(context).colorScheme.secondary,
            ),
          ),
        ],
      ],
    );
  }
}

class DatabaseTab extends StatefulWidget {
  final List<String> tables;
  final bool isLoading;
  final String? selectedTable;
  final List<Map<String, dynamic>> tableData;
  final TextEditingController sqlQueryController;
  final VoidCallback onLoadDatabaseTables;
  final Function(String) onQueryTable;
  final VoidCallback onExecuteCustomQuery;

  const DatabaseTab({
    Key? key,
    required this.tables,
    required this.isLoading,
    required this.selectedTable,
    required this.tableData,
    required this.sqlQueryController,
    required this.onLoadDatabaseTables,
    required this.onQueryTable,
    required this.onExecuteCustomQuery,
  }) : super(key: key);

  @override
  State<DatabaseTab> createState() => _DatabaseTabState();
}

class _DatabaseTabState extends State<DatabaseTab> {
  // Helper method to get database information
  Future<Map<String, dynamic>> _getDatabaseInfo() async {
    final result = <String, dynamic>{};
    try {
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(theme),
          const SizedBox(height: 12),
          _buildDatabaseInfo(theme),
          const SizedBox(height: 12),
          _buildControls(theme),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 800;

              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 250, child: _buildTablesSection(theme)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildDataSection(theme)),
                  ],
                );
              } else {
                return Column(
                  children: [
                    _buildTablesSection(theme),
                    const SizedBox(height: 12),
                    _buildDataSection(theme),
                  ],
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Text(
      'Database Inspector',
      style: theme.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.bold,
        fontSize: 18,
      ),
    );
  }

  Widget _buildDatabaseInfo(ThemeData theme) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: FutureBuilder<Map<String, dynamic>>(
          future: _getDatabaseInfo(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final info =
                snapshot.data ?? {'location': 'Unknown', 'size': 'Unknown'};
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
                    style: theme.textTheme.bodySmall,
                    children: [
                      const TextSpan(
                        text: 'Location: ',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(text: '${info['location']}'),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                RichText(
                  text: TextSpan(
                    style: theme.textTheme.bodySmall,
                    children: [
                      const TextSpan(
                        text: 'Size: ',
                        style: TextStyle(fontWeight: FontWeight.bold),
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
    );
  }

  Widget _buildControls(ThemeData theme) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: widget.onLoadDatabaseTables,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Refresh Tables'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 8),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: widget.sqlQueryController,
                decoration: const InputDecoration(
                  labelText: 'Custom SQL Query',
                  hintText: 'SELECT * FROM table_name',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  isDense: true,
                ),
                style: const TextStyle(fontSize: 12),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: widget.onExecuteCustomQuery,
              icon: const Icon(Icons.play_arrow, size: 16),
              label: const Text('Run', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTablesSection(ThemeData theme) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Database Tables',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 300,
              child:
                  widget.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : widget.tables.isEmpty
                      ? const Center(child: Text('No tables found'))
                      : ListView.builder(
                        itemCount: widget.tables.length,
                        itemBuilder: (context, index) {
                          final tableName = widget.tables[index];
                          final isSelected = widget.selectedTable == tableName;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4.0),
                            child: Material(
                              color:
                                  isSelected
                                      ? theme.colorScheme.primary.withOpacity(
                                        0.12,
                                      )
                                      : Colors.transparent,
                              borderRadius: BorderRadius.circular(4),
                              child: InkWell(
                                onTap: () => widget.onQueryTable(tableName),
                                borderRadius: BorderRadius.circular(4),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                    horizontal: 12,
                                  ),
                                  child: Text(
                                    tableName,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontWeight:
                                          isSelected
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                      color:
                                          isSelected
                                              ? theme.colorScheme.primary
                                              : null,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataSection(ThemeData theme) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.selectedTable != null
                  ? 'Table: ${widget.selectedTable}'
                  : 'Table Data',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 400,
              child:
                  widget.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : widget.selectedTable == null
                      ? const Center(child: Text('Select a table to view data'))
                      : widget.tableData.isEmpty
                      ? const Center(child: Text('No data in this table'))
                      : SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingRowHeight: 40,
                            dataRowHeight: 36,
                            headingRowColor: MaterialStateProperty.all(
                              theme.colorScheme.primaryContainer,
                            ),
                            columns:
                                widget.tableData.first.keys
                                    .map(
                                      (key) => DataColumn(
                                        label: Text(
                                          key,
                                          style: theme.textTheme.titleSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                            rows:
                                widget.tableData
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
                                                              .bodySmall,
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
          ],
        ),
      ),
    );
  }
}

class LogsWatcherTab extends StatefulWidget {
  const LogsWatcherTab({Key? key}) : super(key: key);

  @override
  State<LogsWatcherTab> createState() => _LogsWatcherTabState();
}

class _LogsWatcherTabState extends State<LogsWatcherTab> {
  final List<FileSystemEntity> _logFiles = [];
  bool _isLoadingLogs = true;
  String? _selectedLogContent;
  String? _selectedLogName;
  String? _selectedLogPath;

  @override
  void initState() {
    super.initState();
    _loadLogFiles();
  }

  Future<void> _loadLogFiles() async {
    setState(() => _isLoadingLogs = true);
    try {
      final Directory appDocDir = await getApplicationDocumentsDirectory();
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
          _logFiles.clear();
          _logFiles.addAll(files);
          _isLoadingLogs = false;
        });
      } else {
        setState(() {
          _logFiles.clear();
          _isLoadingLogs = false;
        });
      }
    } catch (e) {
      APP_LOGS.error('Failed to load log files: $e');
      setState(() => _isLoadingLogs = false);
    }
  }

  Future<void> _viewLogFile(FileSystemEntity file) async {
    setState(() => _isLoadingLogs = true);
    try {
      final content = await File(file.path).readAsString();
      setState(() {
        _selectedLogContent = content;
        _selectedLogName = file.path.split('/').last;
        _selectedLogPath = file.path;
        _isLoadingLogs = false;
      });
    } catch (e) {
      APP_LOGS.error('Failed to read log file: $e');
      setState(() {
        _selectedLogContent = 'Error reading log file: $e';
        _selectedLogName = file.path.split('/').last;
        _selectedLogPath = file.path;
        _isLoadingLogs = false;
      });
    }
  }

  Future<void> _clearLogFile() async {
    if (_selectedLogPath == null) return;

    final confirmed =
        await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('Clear Log File'),
                content: Text(
                  'Are you sure you want to clear "$_selectedLogName"?',
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
      await File(_selectedLogPath!).writeAsString('');
      setState(() => _selectedLogContent = '');
      showToastMessage(
        context,
        '$_selectedLogName cleared',
        ToastLevel.success,
      );
    } catch (e) {
      APP_LOGS.error('Failed to clear log file: $e');
      showToastMessage(
        context,
        'Failed to clear $_selectedLogName',
        ToastLevel.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(theme),
          const SizedBox(height: 12),
          _buildControls(),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 800;

              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 250, child: _buildLogFilesList(theme)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildLogContent(theme)),
                  ],
                );
              } else {
                return Column(
                  children: [
                    _buildLogFilesList(theme),
                    const SizedBox(height: 12),
                    _buildLogContent(theme),
                  ],
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Text(
      'Logs Watcher',
      style: theme.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.bold,
        fontSize: 18,
      ),
    );
  }

  Widget _buildControls() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _loadLogFiles,
        icon: const Icon(Icons.refresh, size: 16),
        label: const Text('Refresh Logs'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 8),
        ),
      ),
    );
  }

  Widget _buildLogFilesList(ThemeData theme) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Available Log Files',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 300,
              child:
                  _isLoadingLogs
                      ? const Center(child: CircularProgressIndicator())
                      : _logFiles.isEmpty
                      ? const Center(child: Text('No log files found'))
                      : ListView.builder(
                        itemCount: _logFiles.length,
                        itemBuilder: (context, index) {
                          final file = _logFiles[index];
                          final fileName = file.path.split('/').last;
                          final isSelected = _selectedLogName == fileName;

                          return ListTile(
                            dense: true,
                            title: Text(
                              fileName,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight:
                                    isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                              ),
                            ),
                            leading: Icon(
                              Icons.description,
                              size: 16,
                              color:
                                  isSelected ? theme.colorScheme.primary : null,
                            ),
                            selected: isSelected,
                            onTap: () => _viewLogFile(file),
                            tileColor:
                                isSelected
                                    ? theme.colorScheme.primaryContainer
                                        .withOpacity(0.3)
                                    : null,
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogContent(ThemeData theme) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    _selectedLogName != null
                        ? 'Log: $_selectedLogName'
                        : 'Log Content',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_selectedLogContent != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20),
                        onPressed: _clearLogFile,
                        tooltip: 'Clear log file',
                        color: theme.colorScheme.error,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 20),
                        onPressed: () {
                          Clipboard.setData(
                            ClipboardData(text: _selectedLogContent!),
                          );
                          showToastMessage(
                            context,
                            'Log copied to clipboard',
                            ToastLevel.info,
                          );
                        },
                        tooltip: 'Copy log to clipboard',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 400,
              child:
                  _isLoadingLogs
                      ? const Center(child: CircularProgressIndicator())
                      : _selectedLogContent == null
                      ? const Center(child: Text('Select a log file to view'))
                      : Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          border: Border.all(color: theme.dividerColor),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(8.0),
                          child: SelectableText(
                            _selectedLogContent!,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
            ),
          ],
        ),
      ),
    );
  }
}

class ConnectionTab extends StatefulWidget {
  const ConnectionTab({Key? key}) : super(key: key);

  @override
  State<ConnectionTab> createState() => _ConnectionTabState();
}

class _ConnectionTabState extends State<ConnectionTab> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(theme),
          const SizedBox(height: 12),
          _buildConnectionCards(theme),
          const SizedBox(height: 16),
          _buildCashDrawerControls(theme),
          const SizedBox(height: 16),
          _buildConnectedDevices(theme),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Text(
      'Connection Inspector',
      style: theme.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.bold,
        fontSize: 18,
      ),
    );
  }

  Widget _buildConnectionCards(ThemeData theme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 800 ? 4 : 2;

        return GridView.count(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 1.8,
          children: [
            // Bluetooth Connection
            StreamBuilder<bool>(
              stream: btPrinter?.checkBluetoothStateStream(),
              builder: (context, snapshot) {
                final isBluetoothOn = snapshot.data ?? false;
                return _buildConnectionCard(
                  theme: theme,
                  icon: Icons.bluetooth,
                  title: 'Bluetooth',
                  description: isBluetoothOn ? 'ON' : 'OFF',
                  statusColor: isBluetoothOn ? Colors.green : Colors.red,
                  onPressed: () async {
                    try {
                      final isEnabled =
                          await btPrinter?.bluetoothTestingDialog(context) ??
                          false;
                      showToastMessage(
                        context,
                        isEnabled ? 'Bluetooth ready' : 'Bluetooth test failed',
                        isEnabled ? ToastLevel.success : ToastLevel.warning,
                      );
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
            // Wi-Fi Connection
            _buildConnectionCard(
              theme: theme,
              icon: Icons.wifi,
              title: 'Wi-Fi',
              description: 'Not Implemented',
              onPressed: null,
            ),
            // USB Connection
            Builder(
              builder: (context) {
                final bool isUsbInitialized = USB != null && USB!.isInitialized;
                return _buildConnectionCard(
                  theme: theme,
                  icon: Icons.usb,
                  title: 'USB',
                  description: isUsbInitialized ? 'Ready' : 'Not Ready',
                  statusColor: isUsbInitialized ? Colors.green : Colors.red,
                  onPressed: () async {
                    if (USB == null) {
                      await checkPermissionsAndInitUsb(context);
                      setState(() {});
                      showToastMessage(
                        context,
                        'USB Manager initialized',
                        ToastLevel.info,
                      );
                    } else {
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
            // Network
            _buildConnectionCard(
              theme: theme,
              icon: Icons.language,
              title: 'Network',
              description: 'Not Implemented',
              onPressed: null,
            ),
          ],
        );
      },
    );
  }

  Widget _buildConnectionCard({
    required ThemeData theme,
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback? onPressed,
    Color? statusColor,
  }) {
    return Card(
      elevation: 1,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
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
              const SizedBox(height: 4),
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              Text(
                description,
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCashDrawerControls(ThemeData theme) {
    return Card(
      elevation: 1,
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
                  size: 20,
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
                        showToastMessage(
                          context,
                          drawerOpened
                              ? 'Cash drawer opened'
                              : 'Failed to open cash drawer',
                          drawerOpened
                              ? ToastLevel.success
                              : ToastLevel.warning,
                        );
                      } catch (e) {
                        showToastMessage(
                          context,
                          'Error: $e',
                          ToastLevel.error,
                        );
                        APP_LOGS.error('Cash drawer error: $e');
                      }
                    },
                    icon: const Icon(Icons.open_in_browser, size: 16),
                    label: const Text(
                      'Open Drawer',
                      style: TextStyle(fontSize: 12),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 8),
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
                      final hasCashDrawer = await USB!.isCashDrawerConnected();
                      showToastMessage(
                        context,
                        hasCashDrawer
                            ? 'Cash drawer detected'
                            : 'No cash drawer detected',
                        hasCashDrawer ? ToastLevel.success : ToastLevel.warning,
                      );
                    },
                    icon: const Icon(Icons.search, size: 16),
                    label: const Text('Detect', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectedDevices(ThemeData theme) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Connected USB Devices',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => setState(() {}),
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Refresh', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 8),
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
                  return Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      'Error: ${snapshot.error}',
                      style: theme.textTheme.bodySmall,
                    ),
                  );
                } else if (snapshot.data == null || snapshot.data!.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16.0),
                    child: Center(child: Text('No USB devices connected')),
                  );
                }

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
                        size: 20,
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
                              setState(() {});
                              showToastMessage(
                                context,
                                'Connected to ${device['deviceName']}',
                                ToastLevel.success,
                              );
                            } else {
                              showToastMessage(
                                context,
                                'Failed to connect',
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
          ],
        ),
      ),
    );
  }
}

/// Test page to debug and verify internet connectivity detection
class ConnectivityTestPage extends StatefulWidget {
  const ConnectivityTestPage({Key? key}) : super(key: key);

  @override
  State<ConnectivityTestPage> createState() => _ConnectivityTestPageState();
}

class _ConnectivityTestPageState extends State<ConnectivityTestPage> {
  bool? _hasNetworkConnection;
  bool? _hasRealInternet;
  String _testResults = '';
  bool _isTestingNetwork = false;
  bool _isTestingInternet = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connectivity Test'),
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Real-time status
            StreamBuilder<bool>(
              stream: internetConnectionService.onInternetChanged,
              builder: (context, snapshot) {
                final hasInternet = snapshot.data;
                return Card(
                  color:
                      hasInternet == true
                          ? Colors.green.shade100
                          : Colors.red.shade100,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Icon(
                          hasInternet == true ? Icons.wifi : Icons.wifi_off,
                          size: 48,
                          color:
                              hasInternet == true ? Colors.green : Colors.red,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Real-time Status',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          hasInternet == true
                              ? 'Internet Connected'
                              : hasInternet == false
                              ? 'No Internet'
                              : 'Checking...',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color:
                                hasInternet == true ? Colors.green : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 20),

            // Manual tests
            Text('Manual Tests', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),

            // Network connectivity test
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Network Connectivity (Basic)',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed:
                                _isTestingNetwork
                                    ? null
                                    : _testNetworkConnectivity,
                            child:
                                _isTestingNetwork
                                    ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                    : const Text('Test Network'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          _hasNetworkConnection == true
                              ? Icons.check_circle
                              : _hasNetworkConnection == false
                              ? Icons.cancel
                              : Icons.help,
                          color:
                              _hasNetworkConnection == true
                                  ? Colors.green
                                  : _hasNetworkConnection == false
                                  ? Colors.red
                                  : Colors.grey,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Real internet test
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Real Internet Access',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed:
                                _isTestingInternet ? null : _testRealInternet,
                            child:
                                _isTestingInternet
                                    ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                    : const Text('Test Internet'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          _hasRealInternet == true
                              ? Icons.check_circle
                              : _hasRealInternet == false
                              ? Icons.cancel
                              : Icons.help,
                          color:
                              _hasRealInternet == true
                                  ? Colors.green
                                  : _hasRealInternet == false
                                  ? Colors.red
                                  : Colors.grey,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Force refresh
            ElevatedButton.icon(
              onPressed: () async {
                await internetConnectionService.checkAndUpdateStatus();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Connectivity status refreshed'),
                  ),
                );
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Force Refresh Status'),
            ),

            const SizedBox(height: 20),

            // Test results
            if (_testResults.isNotEmpty) ...[
              Text(
                'Test Details',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _testResults,
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _testNetworkConnectivity() async {
    setState(() {
      _isTestingNetwork = true;
      _testResults = 'Testing network connectivity...';
    });

    try {
      final result = await internetConnectionService.hasNetworkConnection();
      setState(() {
        _hasNetworkConnection = result;
        _testResults +=
            '\n✅ Network test completed: ${result ? "Connected" : "Disconnected"}';
      });
    } catch (e) {
      setState(() {
        _hasNetworkConnection = false;
        _testResults += '\n❌ Network test failed: $e';
      });
    } finally {
      setState(() {
        _isTestingNetwork = false;
      });
    }
  }

  Future<void> _testRealInternet() async {
    setState(() {
      _isTestingInternet = true;
      _testResults = 'Testing real internet access...';
    });

    try {
      final result = await internetConnectionService.isConnected();
      setState(() {
        _hasRealInternet = result;
        _testResults +=
            '\n✅ Internet test completed: ${result ? "Has Internet" : "No Internet"}';
      });
    } catch (e) {
      setState(() {
        _hasRealInternet = false;
        _testResults += '\n❌ Internet test failed: $e';
      });
    } finally {
      setState(() {
        _isTestingInternet = false;
      });
    }
  }
}
