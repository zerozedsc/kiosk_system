import '../../configs/configs.dart';
import '../../configs/responsive_layout.dart';
import '../../services/inventory/inventory_services.dart';

/// Detail page for individual inventory items
class InventoryItemDetailPage extends StatefulWidget {
  final Map<String, dynamic> item;
  final VoidCallback onItemUpdated;

  const InventoryItemDetailPage({
    super.key,
    required this.item,
    required this.onItemUpdated,
  });

  @override
  State<InventoryItemDetailPage> createState() =>
      _InventoryItemDetailPageState();
}

class _InventoryItemDetailPageState extends State<InventoryItemDetailPage> {
  late Map<String, dynamic> item;
  bool isEditing = false;
  final _formKey = GlobalKey<FormState>();
  late TextEditingController nameController;
  late TextEditingController priceController;
  late TextEditingController categoryController;
  late TextEditingController stockController;
  late TextEditingController piecesController;
  late TextEditingController piecesUsedController;

  @override
  void initState() {
    super.initState();
    item = Map<String, dynamic>.from(widget.item);
    _initializeControllers();
  }

  void _initializeControllers() {
    nameController = TextEditingController(text: item['name'] ?? '');
    priceController = TextEditingController(
      text: (item['price'] ?? 0.0).toString(),
    );
    categoryController = TextEditingController(text: item['category'] ?? '');
    stockController = TextEditingController(
      text: (item['total_stocks'] ?? 0).toString(),
    );
    piecesController = TextEditingController(
      text: (item['total_pieces'] ?? 0).toString(),
    );
    piecesUsedController = TextEditingController(
      text: (item['total_pieces_used'] ?? 0).toString(),
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    priceController.dispose();
    categoryController.dispose();
    stockController.dispose();
    piecesController.dispose();
    piecesUsedController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isProduct = item['type'] == 'product';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isProduct
              ? LOCALIZATION.localize("inventory_page.product_details")
              : LOCALIZATION.localize("inventory_page.set_details"),
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          if (isProduct) ...[
            IconButton(
              icon: Icon(isEditing ? Icons.save : Icons.edit),
              onPressed: isEditing ? _saveChanges : _toggleEdit,
            ),
            if (isEditing)
              IconButton(icon: Icon(Icons.cancel), onPressed: _cancelEdit),
          ],
        ],
      ),
      body: SingleChildScrollView(
        padding: ResponsiveLayout.getResponsivePadding(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildItemHeader(),
            SizedBox(height: 20),
            if (isProduct) _buildProductDetails() else _buildSetDetails(),
            if (isProduct) ...[SizedBox(height: 20), _buildActionButtons()],
          ],
        ),
      ),
    );
  }

  Widget _buildItemHeader() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.grey.shade200,
              ),
              child: _buildItemImage(),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isEditing) ...[
                    TextFormField(
                      controller: nameController,
                      style: TextStyle(
                        fontSize: ResponsiveLayout.getResponsiveFontSize(
                          context,
                          18,
                        ),
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: InputDecoration(
                        labelText: LOCALIZATION.localize("main_word.name"),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ] else ...[
                    Text(
                      item['name'] ?? 'Unknown Item',
                      style: TextStyle(
                        fontSize: ResponsiveLayout.getResponsiveFontSize(
                          context,
                          18,
                        ),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                  SizedBox(height: 8),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color:
                          item['type'] == 'product'
                              ? Colors.blue.shade100
                              : Colors.purple.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      item['type'] == 'product'
                          ? LOCALIZATION.localize("main_word.product")
                          : LOCALIZATION.localize("inventory_page.set"),
                      style: TextStyle(
                        fontSize: ResponsiveLayout.getResponsiveFontSize(
                          context,
                          12,
                        ),
                        color:
                            item['type'] == 'product'
                                ? Colors.blue.shade800
                                : Colors.purple.shade800,
                        fontWeight: FontWeight.w600,
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

  Widget _buildItemImage() {
    if (item['image'] != null) {
      if (item['image'] is Uint8List) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(
            item['image'] as Uint8List,
            fit: BoxFit.cover,
            width: 100,
            height: 100,
          ),
        );
      } else if (item['image'] is String &&
          (item['image'] as String).isNotEmpty) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.asset(
            item['image'] as String,
            fit: BoxFit.cover,
            width: 100,
            height: 100,
          ),
        );
      }
    }
    return Icon(
      item['type'] == 'product' ? Icons.inventory_2 : Icons.layers,
      size: 40,
      color: Colors.grey.shade400,
    );
  }

  Widget _buildProductDetails() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            LOCALIZATION.localize("inventory_page.product_information"),
            style: TextStyle(
              fontSize: ResponsiveLayout.getResponsiveFontSize(context, 16),
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 12),

          // Price and Category Row
          Row(
            children: [
              Expanded(
                child: _buildDetailField(
                  LOCALIZATION.localize("main_word.price"),
                  priceController,
                  'RM ${(item['price'] ?? 0.0).toStringAsFixed(2)}',
                  keyboardType: TextInputType.number,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: _buildDetailField(
                  LOCALIZATION.localize("main_word.category"),
                  categoryController,
                  item['category'] ?? 'Uncategorized',
                ),
              ),
            ],
          ),

          SizedBox(height: 16),

          // Stock Information
          Text(
            LOCALIZATION.localize("inventory_page.stock_information"),
            style: TextStyle(
              fontSize: ResponsiveLayout.getResponsiveFontSize(context, 16),
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 12),

          // Stock Fields
          Row(
            children: [
              Expanded(
                child: _buildDetailField(
                  LOCALIZATION.localize("inventory_page.total_stocks"),
                  stockController,
                  '${item['total_stocks'] ?? 0}',
                  keyboardType: TextInputType.number,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: _buildDetailField(
                  LOCALIZATION.localize("inventory_page.total_pieces"),
                  piecesController,
                  '${item['total_pieces'] ?? 0}',
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),

          SizedBox(height: 16),

          _buildDetailField(
            LOCALIZATION.localize("inventory_page.total_pieces_used"),
            piecesUsedController,
            '${item['total_pieces_used'] ?? 0}',
            keyboardType: TextInputType.number,
            fullWidth: true,
          ),

          if (item['shortform'] != null &&
              (item['shortform'] as String).isNotEmpty) ...[
            SizedBox(height: 16),
            _buildInfoCard(
              LOCALIZATION.localize("inventory_page.shortform"),
              item['shortform'] ?? '',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSetDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoCard(
          LOCALIZATION.localize("main_word.price"),
          'RM ${(item['price'] ?? 0.0).toStringAsFixed(2)}',
        ),
        SizedBox(height: 12),
        _buildInfoCard(
          LOCALIZATION.localize("inventory_page.items_in_set"),
          '${item['items_count'] ?? 0} ${LOCALIZATION.localize("main_word.items")}',
        ),
      ],
    );
  }

  Widget _buildDetailField(
    String label,
    TextEditingController controller,
    String displayValue, {
    TextInputType? keyboardType,
    bool fullWidth = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: ResponsiveLayout.getResponsiveFontSize(context, 14),
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        SizedBox(height: 8),
        if (isEditing) ...[
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            decoration: InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return LOCALIZATION.localize("main_word.required");
              }
              return null;
            },
          ),
        ] else ...[
          Container(
            width: fullWidth ? double.infinity : null,
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey.shade50,
            ),
            child: Text(
              displayValue,
              style: TextStyle(
                fontSize: ResponsiveLayout.getResponsiveFontSize(context, 14),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildInfoCard(String label, String value) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey.shade50,
      ),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: ResponsiveLayout.getResponsiveFontSize(context, 14),
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: ResponsiveLayout.getResponsiveFontSize(context, 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                icon: Icon(Icons.add),
                label: Text(LOCALIZATION.localize("inventory_page.add_stock")),
                onPressed: _showAddStockDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                icon: Icon(Icons.remove),
                label: Text(LOCALIZATION.localize("inventory_page.use_pieces")),
                onPressed: _showUsePiecesDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _toggleEdit() {
    setState(() {
      isEditing = true;
    });
  }

  void _cancelEdit() {
    setState(() {
      isEditing = false;
      _initializeControllers(); // Reset to original values
    });
  }

  void _saveChanges() async {
    if (_formKey.currentState!.validate()) {
      try {
        final updates = {
          'name': nameController.text,
          'price': double.parse(priceController.text),
          'categories': categoryController.text,
          'total_stocks': int.parse(stockController.text),
          'total_pieces': int.parse(piecesController.text),
          'total_pieces_used': int.parse(piecesUsedController.text),
        };

        final success = await inventory.updateKioskProductData(
          id: item['id'],
          bulkData: {item['id'].toString(): updates},
        );

        if (success) {
          setState(() {
            item.addAll(updates);
            isEditing = false;
          });
          widget.onItemUpdated();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(LOCALIZATION.localize("main_word.edit_success")),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(LOCALIZATION.localize("main_word.error_handling")),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${LOCALIZATION.localize("main_word.error_handling")}: $e',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showAddStockDialog() {
    final stockController = TextEditingController();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(LOCALIZATION.localize("inventory_page.add_stock")),
            content: TextField(
              controller: stockController,
              decoration: InputDecoration(
                labelText: LOCALIZATION.localize("inventory_page.stock_to_add"),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              autofocus: true,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(LOCALIZATION.localize("main_word.cancel")),
              ),
              ElevatedButton(
                onPressed: () async {
                  final stockToAdd = int.tryParse(stockController.text) ?? 0;
                  if (stockToAdd > 0) {
                    final success = await inventory.addStocks({
                      item['id'] as int: stockToAdd,
                    });
                    Navigator.pop(context);
                    if (success) {
                      setState(() {
                        item['total_stocks'] =
                            (item['total_stocks'] ?? 0) + stockToAdd;
                        stockController.text = item['total_stocks'].toString();
                      });
                      widget.onItemUpdated();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '${LOCALIZATION.localize("inventory_page.added_stock")}: $stockToAdd',
                          ),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  }
                },
                child: Text(LOCALIZATION.localize("main_word.add")),
              ),
            ],
          ),
    );
  }

  void _showUsePiecesDialog() {
    final piecesController = TextEditingController();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(LOCALIZATION.localize("inventory_page.use_pieces")),
            content: TextField(
              controller: piecesController,
              decoration: InputDecoration(
                labelText: LOCALIZATION.localize(
                  "inventory_page.pieces_to_use",
                ),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              autofocus: true,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(LOCALIZATION.localize("main_word.cancel")),
              ),
              ElevatedButton(
                onPressed: () async {
                  final piecesToUse = int.tryParse(piecesController.text) ?? 0;
                  if (piecesToUse > 0) {
                    try {
                      final success = await inventory.updateKioskProductData(
                        id: item['id'],
                        colName: 'total_pieces_used',
                        value: (item['total_pieces_used'] ?? 0) + piecesToUse,
                      );
                      Navigator.pop(context);
                      if (success) {
                        setState(() {
                          item['total_pieces_used'] =
                              (item['total_pieces_used'] ?? 0) + piecesToUse;
                          piecesUsedController.text =
                              item['total_pieces_used'].toString();
                        });
                        widget.onItemUpdated();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '${LOCALIZATION.localize("inventory_page.used_pieces")}: $piecesToUse',
                            ),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } catch (e) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '${LOCALIZATION.localize("main_word.error_handling")}: $e',
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                child: Text(LOCALIZATION.localize("main_word.confirm")),
              ),
            ],
          ),
    );
  }
}
