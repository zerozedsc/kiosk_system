import '../../configs/configs.dart';
import '../../configs/responsive_layout.dart';
import '../../services/inventory/inventory_services.dart';
import 'inventory_item_detail_page.dart';
import 'dart:typed_data';

/// Responsive inventory list that displays both products and sets
/// in a unified, mobile-friendly layout optimized for landscape tablets
class ResponsiveInventoryList extends StatefulWidget {
  final ValueNotifier<int> reloadNotifier;

  const ResponsiveInventoryList({super.key, required this.reloadNotifier});

  @override
  State<ResponsiveInventoryList> createState() =>
      _ResponsiveInventoryListState();
}

class _ResponsiveInventoryListState extends State<ResponsiveInventoryList> {
  List<Map<String, dynamic>> allItems = [];
  List<Map<String, dynamic>> filteredItems = [];
  String searchQuery = '';
  String selectedFilter = 'all'; // 'all', 'products', 'sets', 'low_stock'
  String sortBy = 'name';
  bool sortAsc = true;

  // Filter options - will be populated with localized strings
  List<Map<String, String>> get filterOptions => [
    {'value': 'all', 'label': LOCALIZATION.localize("main_word.all_items")},
    {'value': 'products', 'label': LOCALIZATION.localize("main_word.product")},
    {'value': 'sets', 'label': 'Sets'},
    {
      'value': 'low_stock',
      'label': LOCALIZATION.localize("inventory_page.stock_low"),
    },
  ];

  // Sort options - will be populated with localized strings
  List<Map<String, String>> get sortOptions => [
    {'value': 'name', 'label': LOCALIZATION.localize("main_word.name")},
    {'value': 'stock', 'label': LOCALIZATION.localize("main_word.stock")},
    {'value': 'price', 'label': LOCALIZATION.localize("main_word.price")},
    {'value': 'category', 'label': LOCALIZATION.localize("main_word.category")},
  ];

  @override
  void initState() {
    super.initState();
    _loadInventoryItems();
    widget.reloadNotifier.addListener(_reloadInventory);
  }

  @override
  void dispose() {
    widget.reloadNotifier.removeListener(_reloadInventory);
    super.dispose();
  }

  Future<void> _reloadInventory() async {
    await inventory.updateDataInVar();
    await _loadInventoryItems();
  }

  Future<void> _loadInventoryItems() async {
    final List<Map<String, dynamic>> items = [];

    // Load products
    if (inventory.productCatalog != null) {
      for (var entry in inventory.productCatalog!.entries) {
        items.add({
          'id': entry.key,
          'type': 'product',
          'name': entry.value['name'] ?? 'Unknown Product',
          'image': entry.value['image'],
          'price': entry.value['price'] ?? 0.0,
          'stock': entry.value['total_stocks'] ?? 0,
          'total_stocks': entry.value['total_stocks'] ?? 0,
          'total_pieces': entry.value['total_pieces'] ?? 0,
          'total_pieces_used': entry.value['total_pieces_used'] ?? 0,
          'category': entry.value['categories'] ?? 'Uncategorized',
          'unit': 'pcs',
          'max_stock': entry.value['max_qty'] ?? 0,
          'shortform': entry.value['shortform'] ?? '',
          ...entry.value,
        });
      }
    }

    // Load sets
    if (inventory.setCatalog != null) {
      for (var entry in inventory.setCatalog!.entries) {
        items.add({
          'id': entry.key,
          'type': 'set',
          'name': entry.value['name'] ?? 'Unknown Set',
          'image': entry.value['image'],
          'price': entry.value['price'] ?? 0.0,
          'items_count': entry.value['max_qty'] ?? 0,
          'category': 'Set',
          ...entry.value,
        });
      }
    }

    setState(() {
      allItems = items;
      _applyFiltersAndSort();
    });
  }

  void _applyFiltersAndSort() {
    var items = List<Map<String, dynamic>>.from(allItems);

    // Apply search filter
    if (searchQuery.isNotEmpty) {
      items =
          items.where((item) {
            final name = (item['name'] ?? '').toString().toLowerCase();
            final category = (item['category'] ?? '').toString().toLowerCase();
            final query = searchQuery.toLowerCase();
            return name.contains(query) || category.contains(query);
          }).toList();
    }

    // Apply type filter
    switch (selectedFilter) {
      case 'products':
        items = items.where((item) => item['type'] == 'product').toList();
        break;
      case 'sets':
        items = items.where((item) => item['type'] == 'set').toList();
        break;
      case 'low_stock':
        items =
            items.where((item) {
              if (item['type'] == 'product') {
                final stock = item['stock'] ?? 0;
                final maxStock = item['max_stock'] ?? 0;
                return maxStock > 0 &&
                    stock < (maxStock * 0.2); // Less than 20% of max stock
              }
              return false;
            }).toList();
        break;
    }

    // Apply sorting
    items.sort((a, b) {
      int comparison = 0;
      switch (sortBy) {
        case 'name':
          comparison = (a['name'] ?? '').toString().compareTo(
            (b['name'] ?? '').toString(),
          );
          break;
        case 'stock':
          if (a['type'] == 'product' && b['type'] == 'product') {
            comparison = (a['stock'] ?? 0).compareTo(b['stock'] ?? 0);
          } else {
            comparison = a['type'].compareTo(b['type']);
          }
          break;
        case 'price':
          comparison = (a['price'] ?? 0.0).compareTo(b['price'] ?? 0.0);
          break;
        case 'category':
          comparison = (a['category'] ?? '').toString().compareTo(
            (b['category'] ?? '').toString(),
          );
          break;
      }
      return sortAsc ? comparison : -comparison;
    });

    setState(() {
      filteredItems = items;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // _buildHeader(),
          _buildSearchAndFilters(),
          Expanded(child: _buildItemsList()),
        ],
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: ResponsiveLayout.getResponsivePadding(context),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            Icon(Icons.inventory_2, color: Colors.white, size: 24),
            SizedBox(width: 12),
            Text(
              LOCALIZATION.localize("inventory_page.title"),
              style: TextStyle(
                color: Colors.white,
                fontSize: ResponsiveLayout.getResponsiveFontSize(context, 20),
                fontWeight: FontWeight.bold,
              ),
            ),
            Spacer(),
            Text(
              '${filteredItems.length} ${LOCALIZATION.localize("main_word.items")}',
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: ResponsiveLayout.getResponsiveFontSize(context, 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    return FloatingActionButton(
      onPressed: () => _showBulkOperationsDialog(),
      backgroundColor: Theme.of(context).colorScheme.primary,
      child: Icon(Icons.build, color: Colors.white),
      tooltip: 'Bulk Operations',
    );
  }

  Widget _buildSearchAndFilters() {
    return Container(
      padding: ResponsiveLayout.getResponsivePadding(context),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Column(
        children: [
          // Search Bar
          TextField(
            decoration: InputDecoration(
              hintText: LOCALIZATION.localize("inventory_page.search_product"),
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            onChanged: (value) {
              setState(() {
                searchQuery = value;
                _applyFiltersAndSort();
              });
            },
          ),
          SizedBox(height: 12),

          // Filter Chips and Sort Button
          Row(
            children: [
              // Filter Chips
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children:
                        filterOptions.map((option) {
                          final isSelected = selectedFilter == option['value'];
                          return Padding(
                            padding: EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(
                                option['label']!,
                                style: TextStyle(
                                  fontSize:
                                      ResponsiveLayout.getResponsiveFontSize(
                                        context,
                                        12,
                                      ),
                                  color: isSelected ? Colors.white : null,
                                ),
                              ),
                              selected: isSelected,
                              onSelected: (selected) {
                                setState(() {
                                  selectedFilter = option['value']!;
                                  _applyFiltersAndSort();
                                });
                              },
                              backgroundColor: Colors.grey.shade200,
                              selectedColor:
                                  Theme.of(context).colorScheme.primary,
                            ),
                          );
                        }).toList(),
                  ),
                ),
              ),

              // Sort Button
              PopupMenuButton<String>(
                icon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.sort, size: 20),
                    Icon(
                      sortAsc ? Icons.arrow_upward : Icons.arrow_downward,
                      size: 16,
                    ),
                  ],
                ),
                onSelected: (value) {
                  setState(() {
                    if (value == sortBy) {
                      sortAsc = !sortAsc;
                    } else {
                      sortBy = value;
                      sortAsc = true;
                    }
                    _applyFiltersAndSort();
                  });
                },
                itemBuilder:
                    (context) =>
                        sortOptions.map((option) {
                          return PopupMenuItem<String>(
                            value: option['value'],
                            child: Row(
                              children: [
                                Icon(
                                  sortBy == option['value']
                                      ? (sortAsc
                                          ? Icons.arrow_upward
                                          : Icons.arrow_downward)
                                      : Icons.sort,
                                  size: 16,
                                ),
                                SizedBox(width: 8),
                                Text(option['label']!),
                              ],
                            ),
                          );
                        }).toList(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildItemsList() {
    if (filteredItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            SizedBox(height: 16),
            Text(
              searchQuery.isNotEmpty
                  ? 'No items found for "$searchQuery"'
                  : 'No items available',
              style: TextStyle(
                fontSize: ResponsiveLayout.getResponsiveFontSize(context, 16),
                color: Colors.grey.shade600,
              ),
            ),
            if (searchQuery.isNotEmpty) ...[
              SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  setState(() {
                    searchQuery = '';
                    _applyFiltersAndSort();
                  });
                },
                child: Text('Clear search'),
              ),
            ],
          ],
        ),
      );
    }

    return ListView.builder(
      padding: ResponsiveLayout.getResponsivePadding(context),
      itemCount: filteredItems.length,
      itemBuilder: (context, index) {
        final item = filteredItems[index];
        return _buildInventoryCard(item);
      },
    );
  }

  Widget _buildInventoryCard(Map<String, dynamic> item) {
    final isProduct = item['type'] == 'product';

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _navigateToItemDetail(item),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              // Image
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey.shade200,
                ),
                child: _buildItemImage(item),
              ),

              SizedBox(width: 16),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name and Type Badge
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item['name'] ?? 'Unknown',
                            style: TextStyle(
                              fontSize: ResponsiveLayout.getResponsiveFontSize(
                                context,
                                16,
                              ),
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color:
                                isProduct
                                    ? Colors.blue.shade100
                                    : Colors.purple.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            isProduct ? 'Product' : 'Set',
                            style: TextStyle(
                              fontSize: ResponsiveLayout.getResponsiveFontSize(
                                context,
                                10,
                              ),
                              color:
                                  isProduct
                                      ? Colors.blue.shade800
                                      : Colors.purple.shade800,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 8),

                    // Category
                    Text(
                      item['category'] ?? 'Uncategorized',
                      style: TextStyle(
                        fontSize: ResponsiveLayout.getResponsiveFontSize(
                          context,
                          12,
                        ),
                        color: Colors.grey.shade600,
                      ),
                    ),

                    SizedBox(height: 8),

                    // Price and Stock/Items Info
                    Row(
                      children: [
                        // Price
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'RM ${(item['price'] ?? 0.0).toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: ResponsiveLayout.getResponsiveFontSize(
                                context,
                                12,
                              ),
                              color: Colors.green.shade800,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),

                        SizedBox(width: 8),

                        // Stock or Items Count
                        if (isProduct) ...[
                          // Total Stocks
                          _buildStockInfoChip(
                            LOCALIZATION.localize("main_word.stock"),
                            '${item['total_stocks'] ?? 0}',
                            Colors.blue,
                          ),
                          SizedBox(width: 4),
                          // Total Pieces
                          _buildStockInfoChip(
                            LOCALIZATION.localize("inventory_page.pieces"),
                            '${item['total_pieces'] ?? 0}',
                            Colors.orange,
                          ),
                          SizedBox(width: 4),
                          // Total Pieces Used
                          _buildStockInfoChip(
                            LOCALIZATION.localize("main_word.used"),
                            '${item['total_pieces_used'] ?? 0}',
                            Colors.red,
                          ),
                        ] else ...[
                          Icon(
                            Icons.layers,
                            size: 16,
                            color: Colors.grey.shade600,
                          ),
                          SizedBox(width: 4),
                          Text(
                            '${item['items_count'] ?? 0} ${LOCALIZATION.localize("main_word.items")}',
                            style: TextStyle(
                              fontSize: ResponsiveLayout.getResponsiveFontSize(
                                context,
                                12,
                              ),
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Arrow Icon and Quick Actions
              Column(
                children: [
                  if (isProduct) ...[
                    IconButton(
                      icon: Icon(Icons.add, size: 20),
                      onPressed: () => _showQuickStockDialog(item),
                      tooltip: 'Add Stock',
                      constraints: BoxConstraints(minWidth: 32, minHeight: 32),
                      padding: EdgeInsets.all(4),
                    ),
                    SizedBox(height: 4),
                  ],
                  IconButton(
                    icon: Icon(Icons.arrow_forward_ios, size: 16),
                    onPressed: () => _navigateToItemDetail(item),
                    tooltip: 'View Details',
                    constraints: BoxConstraints(minWidth: 32, minHeight: 32),
                    padding: EdgeInsets.all(4),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStockInfoChip(String label, String value, MaterialColor color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.shade100,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          fontSize: ResponsiveLayout.getResponsiveFontSize(context, 10),
          color: color.shade800,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildItemImage(Map<String, dynamic> item) {
    final isProduct = item['type'] == 'product';

    if (item['image'] != null) {
      // Handle both Uint8List (from database) and String (asset path) images
      if (item['image'] is Uint8List) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(
            item['image'] as Uint8List,
            fit: BoxFit.cover,
            width: 80,
            height: 80,
            errorBuilder:
                (context, error, stackTrace) =>
                    _buildPlaceholderImage(isProduct),
          ),
        );
      } else if (item['image'] is String &&
          (item['image'] as String).isNotEmpty) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.asset(
            item['image'] as String,
            fit: BoxFit.cover,
            width: 80,
            height: 80,
            errorBuilder:
                (context, error, stackTrace) =>
                    _buildPlaceholderImage(isProduct),
          ),
        );
      }
    }
    return _buildPlaceholderImage(isProduct);
  }

  Widget _buildPlaceholderImage(bool isProduct) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey.shade200,
      ),
      child: Icon(
        isProduct ? Icons.inventory_2 : Icons.layers,
        size: 32,
        color: Colors.grey.shade400,
      ),
    );
  }

  void _showBulkOperationsDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Bulk Operations'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(Icons.add, color: Colors.green),
                  title: Text('Add New Products'),
                  onTap: () {
                    Navigator.pop(context);
                    _showAddProductDialog();
                  },
                ),
                ListTile(
                  leading: Icon(Icons.layers, color: Colors.purple),
                  title: Text('Add New Sets'),
                  onTap: () {
                    Navigator.pop(context);
                    _showAddSetDialog();
                  },
                ),
                ListTile(
                  leading: Icon(Icons.inventory, color: Colors.blue),
                  title: Text('Bulk Add Stock'),
                  onTap: () {
                    Navigator.pop(context);
                    _showBulkAddStockDialog();
                  },
                ),
                ListTile(
                  leading: Icon(Icons.delete, color: Colors.red),
                  title: Text('Bulk Delete Items'),
                  onTap: () {
                    Navigator.pop(context);
                    _showBulkDeleteDialog();
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Close'),
              ),
            ],
          ),
    );
  }

  void _showAddProductDialog() {
    // TODO: Implement add product dialog
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Add New Product'),
            content: Text(
              'Add Product functionality will be implemented here.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Close'),
              ),
            ],
          ),
    );
  }

  void _showAddSetDialog() {
    // TODO: Implement add set dialog
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Add New Set'),
            content: Text('Add Set functionality will be implemented here.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Close'),
              ),
            ],
          ),
    );
  }

  void _showBulkAddStockDialog() {
    final Map<int, int> stockUpdates = {};
    final List<Map<String, dynamic>> products =
        filteredItems.where((item) => item['type'] == 'product').toList();

    if (products.isEmpty) {
      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: Text('No Products Found'),
              content: Text('No products available for stock update.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('OK'),
                ),
              ],
            ),
      );
      return;
    }

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => AlertDialog(
                  title: Text('Bulk Add Stock'),
                  content: Container(
                    width: ResponsiveLayout.getDialogWidth(context),
                    height: 400,
                    child: Column(
                      children: [
                        Text(
                          'Enter stock quantities to add for each product:',
                          style: TextStyle(
                            fontSize: ResponsiveLayout.getResponsiveFontSize(
                              context,
                              14,
                            ),
                          ),
                        ),
                        SizedBox(height: 16),
                        Expanded(
                          child: ListView.builder(
                            itemCount: products.length,
                            itemBuilder: (context, index) {
                              final product = products[index];
                              final productId = product['id'] as int;

                              return Card(
                                margin: EdgeInsets.only(bottom: 8),
                                child: Padding(
                                  padding: EdgeInsets.all(12),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 2,
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              product['name'] ?? 'Unknown',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize:
                                                    ResponsiveLayout.getResponsiveFontSize(
                                                      context,
                                                      14,
                                                    ),
                                              ),
                                            ),
                                            Text(
                                              'Current: ${product['stock'] ?? 0}',
                                              style: TextStyle(
                                                color: Colors.grey.shade600,
                                                fontSize:
                                                    ResponsiveLayout.getResponsiveFontSize(
                                                      context,
                                                      12,
                                                    ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        child: TextField(
                                          decoration: InputDecoration(
                                            labelText: 'Add Stock',
                                            border: OutlineInputBorder(),
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 8,
                                                ),
                                          ),
                                          keyboardType: TextInputType.number,
                                          onChanged: (value) {
                                            final stockToAdd =
                                                int.tryParse(value) ?? 0;
                                            if (stockToAdd > 0) {
                                              stockUpdates[productId] =
                                                  stockToAdd;
                                            } else {
                                              stockUpdates.remove(productId);
                                            }
                                          },
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
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed:
                          stockUpdates.isEmpty
                              ? null
                              : () async {
                                try {
                                  final success = await inventory.addStocks(
                                    stockUpdates,
                                  );
                                  Navigator.pop(context);

                                  if (success) {
                                    await _reloadInventory();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Stock updated successfully for ${stockUpdates.length} products',
                                        ),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Failed to update stock'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Error: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              },
                      child: Text('Update Stock (${stockUpdates.length})'),
                    ),
                  ],
                ),
          ),
    );
  }

  void _showBulkDeleteDialog() {
    // TODO: Implement bulk delete dialog
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Bulk Delete Items'),
            content: Text(
              'Bulk Delete functionality will be implemented here.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Close'),
              ),
            ],
          ),
    );
  }

  void _showQuickStockDialog(Map<String, dynamic> item) {
    final TextEditingController stockController = TextEditingController();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Add Stock'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Product: ${item['name']}',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text('Current Stock: ${item['stock'] ?? 0}'),
                SizedBox(height: 16),
                TextField(
                  controller: stockController,
                  decoration: InputDecoration(
                    labelText: 'Stock to Add',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  autofocus: true,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final stockToAdd = int.tryParse(stockController.text) ?? 0;
                  if (stockToAdd > 0) {
                    try {
                      final success = await inventory.addStocks({
                        item['id'] as int: stockToAdd,
                      });

                      Navigator.pop(context);

                      if (success) {
                        await _reloadInventory();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Added $stockToAdd stock to ${item['name']}',
                            ),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to add stock'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    } catch (e) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Please enter a valid stock quantity'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  }
                },
                child: Text('Add Stock'),
              ),
            ],
          ),
    );
  }

  void _navigateToItemDetail(Map<String, dynamic> item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => InventoryItemDetailPage(
              item: item,
              onItemUpdated: () async {
                await _reloadInventory();
              },
            ),
      ),
    );
  }
}
